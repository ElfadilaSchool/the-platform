const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { Pool } = require('pg');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: '../.env' });

const app = express();
const PORT = process.env.USER_MANAGEMENT_SERVICE_PORT || 3002;

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
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: parseInt(process.env.MAX_FILE_SIZE) || 5242880 }, // 5MB default
  fileFilter: (req, file, cb) => {
    if (file.fieldname === 'profile_picture') {
      if (file.mimetype.startsWith('image/')) {
        cb(null, true);
      } else {
        cb(new Error('Only image files are allowed for profile pictures'));
      }
    } else if (file.fieldname === 'cv') {
      if (file.mimetype === 'application/pdf' || file.mimetype.startsWith('image/')) {
        cb(null, true);
      } else {
        cb(new Error('Only PDF and image files are allowed for CV'));
      }
    } else {
      cb(new Error('Unexpected field'));
    }
  }
});

// CORS configuration - this is the key fix
const corsOptions = {
  origin: function (origin, callback) {
    // Allow requests with no origin (mobile apps, curl, postman, etc.)
    if (!origin) return callback(null, true);
    
    // Allow localhost on any port for development
    if (origin.includes('localhost') || origin.includes('127.0.0.1')) {
      return callback(null, true);
    }
    
    // Add your production domains here
    const allowedOrigins = [
      'http://localhost:3000',
      'http://localhost:3001', 
      'http://localhost:8080',
      // Add your production domain here
    ];
    
    if (allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      callback(null, true); // Allow all for development - change this in production
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Origin', 'X-Requested-With', 'Accept'],
};

// Middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" } // Allow cross-origin resource sharing
}));
app.use(cors(corsOptions));
app.use(morgan('combined'));
app.use(express.json());

// Serve static uploads with proper CORS headers
app.use('/uploads', (req, res, next) => {
  // Set CORS headers for static files
  const origin = req.headers.origin;
  if (origin && (origin.includes('localhost') || origin.includes('127.0.0.1'))) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  }
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
  next();
}, express.static(uploadsDir));

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

// Helper function to get employee by user ID
async function getEmployeeByUserId(userId) {
  const result = await pool.query(`
    SELECT e.*, p.name as position_name, u.username, u.role
    FROM employees e
    LEFT JOIN positions p ON e.position_id = p.id
    LEFT JOIN users u ON e.user_id = u.id
    WHERE u.id = $1
  `, [userId]);
  
  return result.rows[0] || null;
}

// Helper function to get employee by ID
async function getEmployeeById(employeeId) {
  const result = await pool.query(`
    SELECT e.*, p.name as position_name, u.username, u.role
    FROM employees e
    LEFT JOIN positions p ON e.position_id = p.id
    LEFT JOIN users u ON e.user_id = u.id
    WHERE e.id = $1
  `, [employeeId]);
  
  return result.rows[0] || null;
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', service: 'User Management Service' });
});

// Get current user's profile
app.get('/profile', verifyToken, async (req, res) => {
  try {
    const employee = await getEmployeeByUserId(req.user.userId);
    
    if (!employee) {
      // If no employee record exists, return user data from token
      // This handles cases like Directors who may not have employee records
      return res.json({
        id: req.user.userId,
        username: req.user.username,
        role: req.user.role,
        first_name: req.user.firstName || '',
        last_name: req.user.lastName || '',
        email: '',
        phone: '',
        position_name: null,
        department: null
      });
    }
    
    // Remove sensitive information
    const { password_hash, ...profileData } = employee;
    
    res.json(profileData);
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Change password endpoint (must come before /profile route)
app.put('/profile/password', verifyToken, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Current password and new password are required' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'New password must be at least 6 characters long' });
    }

    // Get user from database
    const userResult = await pool.query('SELECT id, password_hash FROM users WHERE id = $1', [req.user.userId]);
    
    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const user = userResult.rows[0];

    // Verify current password
    const isValidPassword = await bcrypt.compare(currentPassword, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Current password is incorrect' });
    }

    // Hash new password
    const saltRounds = 10;
    const newPasswordHash = await bcrypt.hash(newPassword, saltRounds);

    // Update password in database
    await pool.query(
      'UPDATE users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
      [newPasswordHash, req.user.userId]
    );

    res.json({
      message: 'Password changed successfully'
    });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update current user's profile
app.put('/profile', verifyToken, upload.single('profile_picture'), async (req, res) => {
  try {
    const employee = await getEmployeeByUserId(req.user.userId);
    
    if (!employee) {
      return res.status(404).json({ error: 'Employee profile not found' });
    }

    const updateFields = [];
    const values = [];
    let paramCount = 1;

    const allowedFields = [
      'first_name', 'last_name', 'gender', 'birth_date', 'phone', 
      'email', 'nationality', 'address', 'marital_status', 
      'language_preference', 'theme_preference'
    ];

    // Handle regular fields
    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        updateFields.push(`${field} = $${paramCount}`);
        let value = req.body[field];
        
        if (value === '') {
          value = null;
        }
        
        values.push(value);
        paramCount++;
      }
    }

    // Handle notification preferences
    if (req.body.notification_preferences) {
      updateFields.push(`notification_preferences = $${paramCount}`);
      values.push(JSON.stringify(req.body.notification_preferences));
      paramCount++;
    }

    // Handle profile picture upload
    if (req.file) {
      // Delete old profile picture if it exists
      if (employee.profile_picture_url) {
        const oldImagePath = path.join(__dirname, employee.profile_picture_url);
        if (fs.existsSync(oldImagePath)) {
          fs.unlinkSync(oldImagePath);
        }
      }
      
      updateFields.push(`profile_picture_url = $${paramCount}`);
      values.push(`/uploads/${req.file.filename}`);
      paramCount++;
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    values.push(employee.id);
    const query = `UPDATE employees SET ${updateFields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = $${paramCount} RETURNING *`;

    const result = await pool.query(query, values);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Employee not found' });
    }

    // Get updated profile with position and user info
    const updatedEmployee = await getEmployeeById(result.rows[0].id);

    res.json({
      message: 'Profile updated successfully',
      profile: updatedEmployee
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Upload profile picture only
app.post('/profile/picture', verifyToken, upload.single('profile_picture'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No image file provided' });
    }

    const employee = await getEmployeeByUserId(req.user.userId);
    
    if (!employee) {
      return res.status(404).json({ error: 'Employee profile not found' });
    }

    // Delete old profile picture if it exists
    if (employee.profile_picture_url) {
      const oldImagePath = path.join(__dirname, employee.profile_picture_url);
      if (fs.existsSync(oldImagePath)) {
        fs.unlinkSync(oldImagePath);
      }
    }

    const profilePictureUrl = `/uploads/${req.file.filename}`;

    // Update profile picture URL in database
    await pool.query(
      'UPDATE employees SET profile_picture_url = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
      [profilePictureUrl, employee.id]
    );

    res.json({
      message: 'Profile picture updated successfully',
      profile_picture_url: profilePictureUrl
    });
  } catch (error) {
    console.error('Upload profile picture error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Profile image endpoint with proper CORS handling
app.get('/profile-image/:employeeId', verifyToken, async (req, res) => {
  try {
    const { employeeId } = req.params;
    
    // Get employee data
    const employee = await getEmployeeById(employeeId);
    if (!employee || !employee.profile_picture_url) {
      return res.status(404).json({ error: 'Profile image not found' });
    }
    
    let imagePath;
    if (employee.profile_picture_url.startsWith('/uploads/')) {
      imagePath = path.join(__dirname, employee.profile_picture_url);
    } else if (employee.profile_picture_url.startsWith('uploads/')) {
      imagePath = path.join(__dirname, employee.profile_picture_url);
    } else {
      imagePath = path.join(__dirname, 'uploads', employee.profile_picture_url);
    }
    
    // Check if file exists
    if (!fs.existsSync(imagePath)) {
      return res.status(404).json({ error: 'Image file not found' });
    }
    
    // Set proper headers with CORS
    const ext = path.extname(imagePath).toLowerCase();
    const mimeTypes = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.webp': 'image/webp'
    };
    
    res.setHeader('Content-Type', mimeTypes[ext] || 'image/jpeg');
    res.setHeader('Cache-Control', 'public, max-age=86400');
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    
    // Set CORS headers
    const origin = req.headers.origin;
    if (origin && (origin.includes('localhost') || origin.includes('127.0.0.1'))) {
      res.setHeader('Access-Control-Allow-Origin', origin);
    }
    res.setHeader('Access-Control-Allow-Credentials', 'true');
    
    // Stream the file
    const fileStream = fs.createReadStream(imagePath);
    fileStream.pipe(res);
    
  } catch (error) {
    console.error('Error serving profile image:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get all employees
app.get('/employees', verifyToken, async (req, res) => {
  try {
    const { search, sort_by = 'first_name', user_id } = req.query;
    
    let query = `
      SELECT e.*, p.name as position_name, u.username, u.role
      FROM employees e
      LEFT JOIN positions p ON e.position_id = p.id
      LEFT JOIN users u ON e.user_id = u.id
    `;
    
    const params = [];
    const conditions = [];
    
    if (search) {
      conditions.push(`(e.first_name ILIKE $${params.length + 1} OR e.last_name ILIKE $${params.length + 1} OR p.name ILIKE $${params.length + 1})`);
      params.push(`%${search}%`);
    }
    
    if (user_id) {
      conditions.push(`u.id = $${params.length + 1}`);
      params.push(user_id);
    }
    
    if (conditions.length > 0) {
      query += ` WHERE ${conditions.join(' AND ')}`;
    }
    
    query += ` ORDER BY e.${sort_by}`;
    
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Get employees error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get employee by ID
app.get('/employees/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await pool.query(`
      SELECT e.*, p.name as position_name, u.username, u.role
      FROM employees e
      LEFT JOIN positions p ON e.position_id = p.id
      LEFT JOIN users u ON e.user_id = u.id
      WHERE e.id = $1
    `, [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Employee not found' });
    }
    
    const employee = result.rows[0];
    console.log('📥 [Get Employee] Returning employee data:', {
      employeeId: id,
      role: employee.role,
      username: employee.username,
      user_id: employee.user_id
    });
    
    res.json(employee);
  } catch (error) {
    console.error('Get employee error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get all positions
app.get('/positions', verifyToken, async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM positions ORDER BY name');
    res.json(result.rows);
  } catch (error) {
    console.error('Get positions error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create a new position (HR only)
app.post('/positions', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'HR_Manager') {
      return res.status(403).json({ error: 'Access denied' });
    }

    const { name } = req.body;
    if (!name || String(name).trim() === '') {
      return res.status(400).json({ error: 'Position name is required' });
    }

    const insert = await pool.query(
      'INSERT INTO positions (name) VALUES ($1) RETURNING *',
      [name.trim()]
    );

    res.status(201).json({ success: true, position: insert.rows[0] });
  } catch (error) {
    if (error && error.code === '23505') { // unique violation
      return res.status(409).json({ error: 'Position name already exists' });
    }
    console.error('Create position error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update a position name (HR only)
app.put('/positions/:id', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'HR_Manager') {
      return res.status(403).json({ error: 'Access denied' });
    }

    const { id } = req.params;
    const { name } = req.body;
    if (!name || String(name).trim() === '') {
      return res.status(400).json({ error: 'Position name is required' });
    }

    const upd = await pool.query(
      'UPDATE positions SET name = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 RETURNING *',
      [name.trim(), id]
    );

    if (upd.rows.length === 0) {
      return res.status(404).json({ error: 'Position not found' });
    }

    res.json({ success: true, position: upd.rows[0] });
  } catch (error) {
    if (error && error.code === '23505') { // unique violation
      return res.status(409).json({ error: 'Position name already exists' });
    }
    console.error('Update position error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete a position (HR only)
app.delete('/positions/:id', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'HR_Manager') {
      return res.status(403).json({ error: 'Access denied' });
    }

    const { id } = req.params;

    // Prevent delete if any employees still reference this position
    const ref = await pool.query('SELECT 1 FROM employees WHERE position_id = $1 LIMIT 1', [id]);
    if (ref.rows.length > 0) {
      return res.status(409).json({ error: 'Cannot delete: position is assigned to employees' });
    }

    const del = await pool.query('DELETE FROM positions WHERE id = $1 RETURNING *', [id]);
    if (del.rows.length === 0) {
      return res.status(404).json({ error: 'Position not found' });
    }
    res.json({ success: true });
  } catch (error) {
    console.error('Delete position error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Add new employee with user account
app.post('/employees', verifyToken, upload.fields([
  { name: 'profile_picture', maxCount: 1 },
  { name: 'cv', maxCount: 1 }
]), async (req, res) => {
  const client = await pool.connect();
  
  try {
    // Only HR Manager can add employees
    if (req.user.role !== 'HR_Manager') {
      return res.status(403).json({ error: 'Access denied' });
    }

    const {
      username, password, role = 'Employee',
      position_id, institution, first_name, last_name,
      foreign_name, foreign_last_name, gender, birth_date, phone,
      email, nationality, address, foreign_address, join_date,
      marital_status, visible_to_parents_in_chat, education_level
    } = req.body;

    if (!username || !password || !first_name || !last_name || !email) {
      return res.status(400).json({ 
        error: 'Username, password, first name, last name, and email are required' 
      });
    }

    await client.query('BEGIN');

    // Check if username already exists
    const existingUser = await client.query('SELECT id FROM users WHERE username = $1', [username]);
    if (existingUser.rows.length > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Username already exists' });
    }

    // Hash password
    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // Create user account
    const userResult = await client.query(
      'INSERT INTO users (username, password_hash, role) VALUES ($1, $2, $3) RETURNING id, username, role',
      [username, passwordHash, role]
    );

    const userId = userResult.rows[0].id;

    let profile_picture_url = null;
    let cv_url = null;

    if (req.files) {
      if (req.files.profile_picture) {
        profile_picture_url = `/uploads/${req.files.profile_picture[0].filename}`;
      }
      if (req.files.cv) {
        cv_url = `/uploads/${req.files.cv[0].filename}`;
      }
    }

    // Create employee record
    const employeeResult = await client.query(`
      INSERT INTO employees (
        user_id, position_id, institution, first_name, last_name,
        foreign_name, foreign_last_name, gender, birth_date, phone,
        email, nationality, address, foreign_address, join_date,
        marital_status, visible_to_parents_in_chat, profile_picture_url,
        cv_url, education_level
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20)
      RETURNING *
    `, [
      userId, position_id || null, institution, first_name, last_name,
      foreign_name, foreign_last_name, gender || null, birth_date || null, phone,
      email, nationality, address, foreign_address, join_date || null,
      marital_status || null, visible_to_parents_in_chat === 'true', profile_picture_url,
      cv_url, education_level
    ]);

    // Optionally insert an employee-specific compensation row if provided
    try {
      const compBase = req.body.base_salary;
      const compHourly = req.body.hourly_rate;
      const compOvertime = req.body.overtime_rate;
      const compEffective = req.body.effective_date;

      if (compBase || compHourly || compOvertime) {
        await client.query(`
          INSERT INTO employee_compensations (
            employee_id, base_salary, hourly_rate, overtime_rate, effective_date
          ) VALUES ($1, $2, $3, $4, COALESCE($5, CURRENT_DATE))
        `, [
          employeeResult.rows[0].id,
          compBase ? parseFloat(compBase) : null,
          compHourly ? parseFloat(compHourly) : null,
          compOvertime ? parseFloat(compOvertime) : null,
          compEffective || null
        ]);
      }
    } catch (e) {
      console.warn('Compensation insert skipped (table might not exist or bad input):', e.message);
    }

    await client.query('COMMIT');

    res.status(201).json({
      message: 'Employee and user account created successfully',
      employee: employeeResult.rows[0],
      user: userResult.rows[0]
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Add employee error:', error);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    client.release();
  }
});

// Update employee
app.put('/employees/:id', verifyToken, upload.fields([
  { name: 'profile_picture', maxCount: 1 },
  { name: 'cv', maxCount: 1 }
]), async (req, res) => {
  try {
    const { id } = req.params;
    
    // Debug: Log incoming request
    console.log('📥 [Update Employee] Request received:', {
      employeeId: id,
      role: req.body.role,
      bodyKeys: Object.keys(req.body)
    });
    
    // Check if user can update this employee
    if (req.user.role === 'Employee') {
      // Get employee's user_id to check if it matches the current user
      const employeeCheck = await pool.query('SELECT user_id FROM employees WHERE id = $1', [id]);
      if (employeeCheck.rows.length === 0 || employeeCheck.rows[0].user_id !== req.user.userId) {
        return res.status(403).json({ error: 'Access denied' });
      }
    }

    const updateFields = [];
    const values = [];
    let paramCount = 1;

    const allowedFields = [
      'position_id', 'institution', 'first_name', 'last_name',
      'gender', 'birth_date', 'phone', 'email', 'nationality', 
      'address', 'join_date', 'marital_status', 'education_level'
    ];

    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        updateFields.push(`${field} = $${paramCount}`);
        let value = req.body[field];
        
        if (value === '') {
          value = null;
        }
        
        values.push(value);
        paramCount++;
      }
    }

    if (req.files) {
      if (req.files.profile_picture) {
        updateFields.push(`profile_picture_url = $${paramCount}`);
        values.push(`/uploads/${req.files.profile_picture[0].filename}`);
        paramCount++;
      }
      if (req.files.cv) {
        updateFields.push(`cv_url = $${paramCount}`);
        values.push(`/uploads/${req.files.cv[0].filename}`);
        paramCount++;
      }
    }

    // Handle role update - role is stored in users table, not employees table
    // Check both req.body.role (from JSON) and req.body.role (from form)
    const roleValue = req.body.role;
    console.log('🔍 [Update Employee] Role value check:', {
      roleValue: roleValue,
      roleType: typeof roleValue,
      roleUndefined: roleValue === undefined,
      roleNull: roleValue === null,
      bodyKeys: Object.keys(req.body || {}),
      rawBody: JSON.stringify(req.body).substring(0, 200)
    });
    
    if (roleValue !== undefined && roleValue !== null && roleValue !== '') {
      // Get the employee's user_id
      const employeeCheck = await pool.query('SELECT user_id FROM employees WHERE id = $1', [id]);
      console.log('🔍 [Update Employee] Employee check result:', {
        found: employeeCheck.rows.length > 0,
        user_id: employeeCheck.rows[0]?.user_id
      });
      
      if (employeeCheck.rows.length > 0 && employeeCheck.rows[0].user_id) {
        const userId = employeeCheck.rows[0].user_id;
        
        // Validate role
        const validRoles = ['Employee', 'Department_Responsible', 'HR_Manager', 'Director'];
        if (!validRoles.includes(roleValue)) {
          console.error('❌ [Update Employee] Invalid role:', roleValue);
          return res.status(400).json({ error: 'Invalid role. Must be one of: ' + validRoles.join(', ') });
        }
        
        // Update user role
        const updateResult = await pool.query(
          'UPDATE users SET role = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 RETURNING id, role',
          [roleValue, userId]
        );
        
        console.log(`✅ [Update Employee] Updated user role to ${roleValue} for employee ${id} (user_id: ${userId})`, {
          updateResult: updateResult.rows[0]
        });
      } else {
        console.warn(`⚠️ [Update Employee] Employee ${id} has no user_id linked, cannot update role`);
      }
    } else {
      console.log('⚠️ [Update Employee] Role not provided or empty, skipping role update');
    }

    if (updateFields.length === 0 && !req.body.role) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    let result;
    if (updateFields.length > 0) {
      values.push(id);
      const query = `UPDATE employees SET ${updateFields.join(', ')} WHERE id = $${paramCount} RETURNING *`;
      result = await pool.query(query, values);
    } else {
      // If only role was updated, fetch the employee record
      result = await pool.query('SELECT * FROM employees WHERE id = $1', [id]);
    }

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Employee not found' });
    }

    // Optionally append a new compensation snapshot if provided
    try {
      const compBase = req.body.base_salary;
      const compHourly = req.body.hourly_rate;
      const compOvertime = req.body.overtime_rate;
      const compEffective = req.body.effective_date;

      if (compBase || compHourly || compOvertime) {
        await pool.query(`
          INSERT INTO employee_compensations (
            employee_id, base_salary, hourly_rate, overtime_rate, effective_date
          ) VALUES ($1, $2, $3, $4, COALESCE($5, CURRENT_DATE))
        `, [
          id,
          compBase ? parseFloat(compBase) : null,
          compHourly ? parseFloat(compHourly) : null,
          compOvertime ? parseFloat(compOvertime) : null,
          compEffective || null
        ]);
      }
    } catch (e) {
      console.warn('Compensation insert skipped (table might not exist or bad input):', e.message);
    }

    // Fetch updated employee with role from users table
    const updatedEmployee = await pool.query(`
      SELECT e.*, p.name as position_name, u.username, u.role
      FROM employees e
      LEFT JOIN positions p ON e.position_id = p.id
      LEFT JOIN users u ON e.user_id = u.id
      WHERE e.id = $1
    `, [id]);
    
    res.json({
      message: 'Employee updated successfully',
      employee: updatedEmployee.rows[0] || result.rows[0]
    });
  } catch (error) {
    console.error('Update employee error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete employee
app.delete('/employees/:id', verifyToken, async (req, res) => {
  const client = await pool.connect();
  
  try {
    // Only HR Manager can delete employees
    if (req.user.role !== 'HR_Manager') {
      return res.status(403).json({ error: 'Access denied' });
    }

    const { id } = req.params;

    await client.query('BEGIN');

    // Get employee's user_id before deletion
    const employeeResult = await client.query('SELECT user_id FROM employees WHERE id = $1', [id]);
    
    if (employeeResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Employee not found' });
    }

    const userId = employeeResult.rows[0].user_id;

    // Delete employee (this will cascade to delete user due to foreign key constraint)
    await client.query('DELETE FROM employees WHERE id = $1', [id]);

    // Delete user account if it exists
    if (userId) {
      await client.query('DELETE FROM users WHERE id = $1', [userId]);
    }

    await client.query('COMMIT');

    res.json({ message: 'Employee and user account deleted successfully' });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Delete employee error:', error);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    client.release();
  }
});

// Get dashboard statistics
app.get('/dashboard/stats', verifyToken, async (req, res) => {
  try {
    const stats = {};

    // Total employees
    const employeeCount = await pool.query('SELECT COUNT(*) as count FROM employees');
    stats.totalEmployees = parseInt(employeeCount.rows[0].count);

    // Active employees (those with user accounts)
    const activeEmployees = await pool.query(`
      SELECT COUNT(*) as count 
      FROM employees e 
      INNER JOIN users u ON e.user_id = u.id
    `);
    stats.activeEmployees = parseInt(activeEmployees.rows[0].count);

    // Employees by department
    const departmentStats = await pool.query(`
      SELECT d.name, COUNT(ed.employee_id) as count
      FROM departments d
      LEFT JOIN employee_departments ed ON d.id = ed.department_id
      GROUP BY d.id, d.name
      ORDER BY count DESC
    `);
    stats.departmentBreakdown = departmentStats.rows;

    // Employees by position
    const positionStats = await pool.query(`
      SELECT p.name, COUNT(e.id) as count
      FROM positions p
      LEFT JOIN employees e ON p.id = e.position_id
      GROUP BY p.id, p.name
      ORDER BY count DESC
    `);
    stats.positionBreakdown = positionStats.rows;

    res.json(stats);
  } catch (error) {
    console.error('Get dashboard stats error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ error: 'File too large' });
    }
  }
  
  console.error('Unhandled error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`User Management Service running on port ${PORT}`);
});

module.exports = app;

