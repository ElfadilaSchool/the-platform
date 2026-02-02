const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: '../.env' });

const app = express();
const PORT = process.env.REQUEST_SERVICE_PORT || 3009;

// Database connection
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

// Create uploads directory if it doesn't exist
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Multer configuration for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'document-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: parseInt(process.env.MAX_FILE_SIZE) || 5242880 }, // 5MB default
  fileFilter: (req, file, cb) => {
    // Allow images and PDFs for supporting documents
    if (file.mimetype.startsWith('image/') || file.mimetype === 'application/pdf') {
      cb(null, true);
    } else {
      cb(new Error('Only image and PDF files are allowed'));
    }
  }
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use('/uploads', express.static(uploadsDir));

// JWT verification middleware
const verifyToken = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', service: 'Request Service' });
});

// Get permission requests (filtered by role, status, employee)
app.get('/requests', verifyToken, async (req, res) => {
  try {
    const { status, employee_id, type } = req.query;
    
    let query = `
      SELECT 
        pr.*,
        emp.first_name as employee_first_name,
        emp.last_name as employee_last_name,
        reviewer.first_name as reviewed_by_first_name,
        reviewer.last_name as reviewed_by_last_name
      FROM permission_requests pr
      LEFT JOIN employees emp ON pr.employee_id = emp.id
      LEFT JOIN employees reviewer ON pr.reviewed_by = reviewer.id
    `;
    
    const conditions = [];
    const params = [];
    let paramCount = 1;

    // Role-based filtering
    if (req.user.role === 'Employee') {
      // Employees can only see their own requests
      const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
      if (empResult.rows.length > 0) {
        conditions.push(`pr.employee_id = $${paramCount}`);
        params.push(empResult.rows[0].id);
        paramCount++;
      }
    } else if (req.user.role === 'Department_Responsible') {
      // Responsibles can see requests from their department employees
      const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
      if (empResult.rows.length > 0) {
        conditions.push(`pr.employee_id IN (
          SELECT ed.employee_id FROM employee_departments ed 
          JOIN departments d ON ed.department_id = d.id 
          WHERE d.responsible_id = $${paramCount}
        )`);
        params.push(empResult.rows[0].id);
        paramCount++;
      }
    }
    // HR Manager can see all requests (no additional filtering)

    if (status) {
      conditions.push(`pr.status = $${paramCount}`);
      params.push(status);
      paramCount++;
    }

    if (employee_id) {
      conditions.push(`pr.employee_id = $${paramCount}`);
      params.push(employee_id);
      paramCount++;
    }

    if (type) {
      conditions.push(`pr.type = $${paramCount}`);
      params.push(type);
      paramCount++;
    }

    if (conditions.length > 0) {
      query += ` WHERE ${conditions.join(' AND ')}`;
    }

    query += ` ORDER BY pr.created_at DESC`;
    
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Get requests error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get request by ID
app.get('/requests/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await pool.query(`
      SELECT 
        pr.*,
        emp.first_name as employee_first_name,
        emp.last_name as employee_last_name,
        reviewer.first_name as reviewed_by_first_name,
        reviewer.last_name as reviewed_by_last_name
      FROM permission_requests pr
      LEFT JOIN employees emp ON pr.employee_id = emp.id
      LEFT JOIN employees reviewer ON pr.reviewed_by = reviewer.id
      WHERE pr.id = $1
    `, [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Request not found' });
    }

    // Check permissions
    const request = result.rows[0];
    if (req.user.role === 'Employee') {
      const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
      if (empResult.rows.length === 0 || request.employee_id !== empResult.rows[0].id) {
        return res.status(403).json({ error: 'Access denied' });
      }
    }
    
    res.json(request);
  } catch (error) {
    console.error('Get request error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Submit new permission request
app.post('/requests', verifyToken, upload.single('document'), async (req, res) => {
  try {
    // Only employees can submit requests
    if (req.user.role !== 'Employee') {
      return res.status(403).json({ error: 'Only employees can submit permission requests' });
    }

    const { type, start_date, end_date, reason } = req.body;
    
    if (!type || !start_date || !end_date || !reason) {
      return res.status(400).json({ error: 'Type, start_date, end_date, and reason are required' });
    }

    // Get employee ID for the current user
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
    if (empResult.rows.length === 0) {
      return res.status(400).json({ error: 'Employee record not found' });
    }

    const employeeId = empResult.rows[0].id;
    let documentUrl = null;

    if (req.file) {
      documentUrl = `/uploads/${req.file.filename}`;
    }

    const result = await pool.query(`
      INSERT INTO permission_requests (employee_id, type, start_date, end_date, reason, document_url)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `, [employeeId, type, start_date, end_date, reason, documentUrl]);

    res.status(201).json({
      message: 'Permission request submitted successfully',
      request: result.rows[0]
    });
  } catch (error) {
    console.error('Submit request error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update request status (accept/deny)
app.put('/requests/:id/status', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    
    if (!status || !['Accepted', 'Denied'].includes(status)) {
      return res.status(400).json({ error: 'Status must be either "Accepted" or "Denied"' });
    }

    // Only Department Responsible and HR Manager can update request status
    if (req.user.role === 'Employee') {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Get current request to check permissions
    const currentRequest = await pool.query('SELECT * FROM permission_requests WHERE id = $1', [id]);
    if (currentRequest.rows.length === 0) {
      return res.status(404).json({ error: 'Request not found' });
    }

    const request = currentRequest.rows[0];
    
    // Get reviewer employee ID
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
    if (empResult.rows.length === 0) {
      return res.status(400).json({ error: 'Employee record not found' });
    }

    const reviewerId = empResult.rows[0].id;

    // If Department Responsible, check if they can review this request
    if (req.user.role === 'Department_Responsible') {
      const deptCheck = await pool.query(`
        SELECT 1 FROM employee_departments ed 
        JOIN departments d ON ed.department_id = d.id 
        WHERE d.responsible_id = $1 AND ed.employee_id = $2
      `, [reviewerId, request.employee_id]);
      
      if (deptCheck.rows.length === 0) {
        return res.status(403).json({ error: 'You can only review requests from employees in your department' });
      }
    }

    const result = await pool.query(`
      UPDATE permission_requests 
      SET status = $1, reviewed_by = $2, reviewed_at = CURRENT_TIMESTAMP
      WHERE id = $3
      RETURNING *
    `, [status, reviewerId, id]);

    res.json({
      message: 'Request status updated successfully',
      request: result.rows[0]
    });
  } catch (error) {
    console.error('Update request status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update request details (only by the employee who submitted it, and only if pending)
app.put('/requests/:id', verifyToken, upload.single('document'), async (req, res) => {
  try {
    const { id } = req.params;
    const { type, start_date, end_date, reason } = req.body;
    
    // Get current request to check permissions
    const currentRequest = await pool.query('SELECT * FROM permission_requests WHERE id = $1', [id]);
    if (currentRequest.rows.length === 0) {
      return res.status(404).json({ error: 'Request not found' });
    }

    const request = currentRequest.rows[0];
    
    // Only the employee who submitted the request can update it
    if (req.user.role !== 'Employee') {
      return res.status(403).json({ error: 'Only the employee who submitted the request can update it' });
    }

    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
    if (empResult.rows.length === 0 || request.employee_id !== empResult.rows[0].id) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Can only update pending requests
    if (request.status !== 'Pending') {
      return res.status(400).json({ error: 'Can only update pending requests' });
    }

    const updateFields = [];
    const values = [];
    let paramCount = 1;

    if (type !== undefined) {
      updateFields.push(`type = $${paramCount}`);
      values.push(type);
      paramCount++;
    }

    if (start_date !== undefined) {
      updateFields.push(`start_date = $${paramCount}`);
      values.push(start_date);
      paramCount++;
    }

    if (end_date !== undefined) {
      updateFields.push(`end_date = $${paramCount}`);
      values.push(end_date);
      paramCount++;
    }

    if (reason !== undefined) {
      updateFields.push(`reason = $${paramCount}`);
      values.push(reason);
      paramCount++;
    }

    if (req.file) {
      updateFields.push(`document_url = $${paramCount}`);
      values.push(`/uploads/${req.file.filename}`);
      paramCount++;
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    values.push(id);
    const query = `UPDATE permission_requests SET ${updateFields.join(', ')} WHERE id = $${paramCount} RETURNING *`;
    
    const result = await pool.query(query, values);

    res.json({
      message: 'Request updated successfully',
      request: result.rows[0]
    });
  } catch (error) {
    console.error('Update request error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete request (only by the employee who submitted it, and only if pending)
app.delete('/requests/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    // Get current request to check permissions
    const currentRequest = await pool.query('SELECT * FROM permission_requests WHERE id = $1', [id]);
    if (currentRequest.rows.length === 0) {
      return res.status(404).json({ error: 'Request not found' });
    }

    const request = currentRequest.rows[0];
    
    // Only the employee who submitted the request or HR Manager can delete it
    if (req.user.role === 'Employee') {
      const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
      if (empResult.rows.length === 0 || request.employee_id !== empResult.rows[0].id) {
        return res.status(403).json({ error: 'Access denied' });
      }
      
      // Employees can only delete pending requests
      if (request.status !== 'Pending') {
        return res.status(400).json({ error: 'Can only delete pending requests' });
      }
    }

    await pool.query('DELETE FROM permission_requests WHERE id = $1', [id]);

    res.json({ message: 'Request deleted successfully' });
  } catch (error) {
    console.error('Delete request error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get request statistics for dashboard
app.get('/requests/stats/dashboard', verifyToken, async (req, res) => {
  try {
    let whereClause = '';
    const params = [];
    
    if (req.user.role === 'Employee') {
      const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
      if (empResult.rows.length > 0) {
        whereClause = 'WHERE pr.employee_id = $1';
        params.push(empResult.rows[0].id);
      }
    } else if (req.user.role === 'Department_Responsible') {
      const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
      if (empResult.rows.length > 0) {
        whereClause = `WHERE pr.employee_id IN (
          SELECT ed.employee_id FROM employee_departments ed 
          JOIN departments d ON ed.department_id = d.id 
          WHERE d.responsible_id = $1
        )`;
        params.push(empResult.rows[0].id);
      }
    }

    const result = await pool.query(`
      SELECT 
        status,
        COUNT(*) as count
      FROM permission_requests pr
      ${whereClause}
      GROUP BY status
    `, params);

    const stats = {
      pending: 0,
      accepted: 0,
      denied: 0
    };

    result.rows.forEach(row => {
      const status = row.status.toLowerCase();
      stats[status] = parseInt(row.count);
    });

    res.json(stats);
  } catch (error) {
    console.error('Get request stats error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error(error);
  res.status(500).json({ error: error.message || 'Internal server error' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Request Service running on port ${PORT}`);
});

module.exports = app;

