const express = require('express');
const { Pool } = require('pg');
const moment = require('moment-timezone');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const AutoSubstitutionMatcher = require('./auto-substitution-matcher');

// JWT verification middleware (will be injected)
let verifyToken;

const setAuthMiddleware = (authMiddleware) => {
  verifyToken = authMiddleware;
};

// Helper function to get user's timezone from request
const getUserTimezone = (req) => {
  return req.headers['x-user-timezone'] || req.query.timezone || 'UTC';
};

const initializeRoutes = (dbPool) => {
  const router = express.Router();
  const pool = dbPool;
  const autoSubMatcher = new AutoSubstitutionMatcher(dbPool);

  // Ensure uploads directory exists (same as attendance-server)
  const uploadsDir = path.join(__dirname, 'uploads');
  if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
  }

  // Configure multer for exception attachments
  const storage = multer.diskStorage({
    destination: function (req, file, cb) {
      cb(null, uploadsDir);
    },
    filename: function (req, file, cb) {
      const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
      cb(null, 'exception-justification-' + uniqueSuffix + path.extname(file.originalname));
    }
  });

  const upload = multer({
    storage,
    limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
    fileFilter: function (req, file, cb) {
      const allowedTypes = /jpeg|jpg|png|gif|pdf|doc|docx|txt/;
      const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
      const mimetype = allowedTypes.test(file.mimetype);
      if (mimetype && extname) return cb(null, true);
      cb(new Error('Invalid file type. Only images, PDFs, and documents are allowed.'));
    }
  });

  // Get pending exception requests
  router.get('/pending', verifyToken, async (req, res) => {
  try {
    const { page = 1, limit = 20, departmentId } = req.query;
    // Accept both camelCase and snake_case for compatibility
    const employeeId = req.query.employeeId || req.query.employee_id;
    const year = req.query.year ? parseInt(req.query.year) : null;
    const month = req.query.month ? parseInt(req.query.month) : null;
    const offset = (page - 1) * limit;
    
    console.log('🔍 [Exceptions API] Received filter params:', { year, month, employeeId, departmentId });

    let whereConditions = ["ae.status = 'Pending'"];
    let queryParams = [limit, offset];
    let paramIndex = 3;

    if (departmentId) {
      whereConditions.push(`ed.department_id = $${paramIndex}`);
      queryParams.push(departmentId);
      paramIndex++;
    }

    if (employeeId) {
      whereConditions.push(`ae.employee_id = $${paramIndex}`);
      queryParams.push(employeeId);
      paramIndex++;
    }

    // Filter by date range
    if (year && month) {
      // Month + Year: filter specific month
      whereConditions.push(`ae.date >= make_date($${paramIndex}, $${paramIndex + 1}, 1)`);
      whereConditions.push(`ae.date < (make_date($${paramIndex}, $${paramIndex + 1}, 1) + interval '1 month')`);
      queryParams.push(year, month);
      paramIndex += 2;
    } else if (year) {
      // Year only: filter entire year
      whereConditions.push(`EXTRACT(YEAR FROM ae.date) = $${paramIndex}`);
      queryParams.push(year);
      paramIndex++;
    }
    // No date filter = all time

    const whereClause = `WHERE ${whereConditions.join(' AND ')}`;

    const query = `
      SELECT
        ae.id,
        ae.employee_id,
        ae.type,
        ae.status,
        ae.payload,
        ae.submitted_by_user_id,
        ae.reviewed_by_user_id,
        ae.created_at,
        ae.updated_at,
        ae.reviewed_at,
        ae.document_upload_id,
        ae.document_url,
        ae.end_date::text AS end_date,
        ae.date::text AS date,
        (SELECT ao.override_type FROM attendance_overrides ao WHERE ao.exception_id = ae.id LIMIT 1) AS override_type,
        CONCAT(e.first_name, ' ', e.last_name) as employee_name,
        e.id as employee_number,
        d.name as department_name,
        u.username as submitted_by_username,
        CONCAT(e_submitter.first_name, ' ', e_submitter.last_name) as submitted_by_name,
        COUNT(*) OVER() as total_count
      FROM attendance_exceptions ae
      LEFT JOIN employees e ON ae.employee_id = e.id
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      LEFT JOIN users u ON ae.submitted_by_user_id = u.id
      LEFT JOIN employees e_submitter ON u.id = e_submitter.user_id
      ${whereClause}
      ORDER BY ae.created_at DESC
      LIMIT $1 OFFSET $2
    `;

    console.log('📊 [Exceptions API] WHERE conditions:', whereConditions);
    console.log('📊 [Exceptions API] Query params:', queryParams);
    
    const result = await pool.query(query, queryParams);

    console.log(`✅ Pending exceptions query returned ${result.rows.length} exceptions`);

    const exceptions = result.rows.map(row => ({
      id: row.id,
      employee_id: row.employee_id,
      employee_name: row.employee_name,
      employee_number: row.employee_number,
      department_name: row.department_name,
      type: row.type,
      status: row.status,
      date: row.date,
      end_date: row.end_date,
      payload: row.payload,
      override_type: row.override_type,
      submitted_by: row.submitted_by_name || row.submitted_by_username || 'Unknown',
      created_at: row.created_at,
      description: getExceptionDescription(row.type, row.payload)
    }));

    const totalCount = result.rows.length > 0 ? result.rows[0].total_count : 0;

    res.json({
      success: true,
      exceptions,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: parseInt(totalCount),
        pages: Math.ceil(totalCount / limit)
      }
    });

  } catch (error) {
    console.error('Get pending exceptions error:', error);
    res.status(500).json({ 
      error: 'Failed to retrieve pending exceptions',
      details: error.message 
    });
  }
});

// Get exception history
router.get('/history', verifyToken, async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      departmentId,
      employeeId,
      employee_id,
      status,
      startDate,
      endDate,
      year,
      month,
      type
    } = req.query;

    const offset = (page - 1) * limit;

    let whereConditions = [];
    let queryParams = [limit, offset];
    let paramIndex = 3;

    if (departmentId) {
      // Validate that department exists
      const deptCheck = await pool.query('SELECT id FROM departments WHERE id = $1', [departmentId]);
      if (deptCheck.rows.length === 0) {
        console.log(`Invalid department ID in history: ${departmentId}`);
        return res.status(400).json({
          error: 'Invalid department ID'
        });
      }
      whereConditions.push(`ed.department_id = $${paramIndex}`);
      queryParams.push(departmentId);
      paramIndex++;
    }

    const effectiveEmployeeId = employeeId || employee_id;
    if (effectiveEmployeeId) {
      whereConditions.push(`ae.employee_id = $${paramIndex}`);
      queryParams.push(effectiveEmployeeId);
      paramIndex++;
    }

    if (status) {
      whereConditions.push(`ae.status = $${paramIndex}`);
      queryParams.push(status);
      paramIndex++;
    }

    if (type) {
      whereConditions.push(`ae.type = $${paramIndex}`);
      queryParams.push(type);
      paramIndex++;
    }

    // If year/month provided and no explicit start/end, constrain to that month
    const ymYear = year ? parseInt(year) : null;
    const ymMonth = month ? parseInt(month) : null;
    if (ymYear && ymMonth && !startDate && !endDate) {
      whereConditions.push(`ae.date >= make_date($${paramIndex}, $${paramIndex + 1}, 1)`);
      whereConditions.push(`ae.date < (make_date($${paramIndex}, $${paramIndex + 1}, 1) + interval '1 month')`);
      queryParams.push(ymYear, ymMonth);
      paramIndex += 2;
    }

    if (startDate) {
      whereConditions.push(`ae.date >= $${paramIndex}`);
      queryParams.push(startDate);
      paramIndex++;
    }

    if (endDate) {
      whereConditions.push(`ae.date <= $${paramIndex}`);
      queryParams.push(endDate);
      paramIndex++;
    }

    const whereClause = `WHERE ${whereConditions.join(' AND ')}`;

    const query = `
      SELECT
        ae.id,
        ae.employee_id,
        ae.type,
        ae.status,
        ae.payload,
        ae.submitted_by_user_id,
        ae.reviewed_by_user_id,
        ae.created_at,
        ae.updated_at,
        ae.reviewed_at,
        ae.document_upload_id,
        ae.document_url,
        ae.end_date::text AS end_date,
        ae.date::text AS date,
        (SELECT ao.override_type FROM attendance_overrides ao WHERE ao.exception_id = ae.id LIMIT 1) AS override_type,
        CONCAT(e.first_name, ' ', e.last_name) as employee_name,
        e.id as employee_number,
        d.name as department_name,
        u1.username as submitted_by_username,
        u2.username as reviewed_by_username,
        CONCAT(e_submitter.first_name, ' ', e_submitter.last_name) as submitted_by_name,
        CONCAT(e_reviewer.first_name, ' ', e_reviewer.last_name) as reviewed_by_name,
        COUNT(*) OVER() as total_count
      FROM attendance_exceptions ae
      LEFT JOIN employees e ON ae.employee_id = e.id
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      LEFT JOIN users u1 ON ae.submitted_by_user_id = u1.id
      LEFT JOIN users u2 ON ae.reviewed_by_user_id = u2.id
      LEFT JOIN employees e_submitter ON u1.id = e_submitter.user_id
      LEFT JOIN employees e_reviewer ON u2.id = e_reviewer.user_id
      ${whereClause}
      ORDER BY COALESCE(ae.reviewed_at, ae.updated_at) DESC, ae.created_at DESC
      LIMIT $1 OFFSET $2
    `;

    // First, get total count of all exceptions in the table for comparison
    const totalCountQuery = `SELECT COUNT(*) as total FROM attendance_exceptions`;
    const totalCountResult = await pool.query(totalCountQuery);
    const totalExceptionsInTable = parseInt(totalCountResult.rows[0].total);
    console.log(`Total exceptions in attendance_exceptions table: ${totalExceptionsInTable}`);

    const result = await pool.query(query, queryParams);

    console.log(`History query returned ${result.rows.length} exceptions`);
    console.log(`Query params:`, queryParams);
    console.log(`Where conditions:`, whereConditions);
    console.log(`Generated WHERE clause:`, whereClause);
    console.log(`Full query:`, query);
    console.log(`First few exceptions:`, result.rows.slice(0, 3).map(row => ({
      id: row.id,
      status: row.status,
      date: row.date,
      reviewed_at: row.reviewed_at,
      created_at: row.created_at,
      employee_id: row.employee_id,
      submitted_by_user_id: row.submitted_by_user_id
    })));

    // Check for exceptions that might be missing due to join issues
    const checkMissingQuery = `
      SELECT ae.id, ae.employee_id, ae.submitted_by_user_id, ae.reviewed_by_user_id,
             e.id as emp_exists, u1.id as submitter_exists, u2.id as reviewer_exists
      FROM attendance_exceptions ae
      LEFT JOIN employees e ON ae.employee_id = e.id
      LEFT JOIN users u1 ON ae.submitted_by_user_id = u1.id
      LEFT JOIN users u2 ON ae.reviewed_by_user_id = u2.id
      WHERE e.id IS NULL OR u1.id IS NULL OR u2.id IS NULL
      LIMIT 10
    `;
    const missingCheck = await pool.query(checkMissingQuery);
    console.log(`Exceptions with missing related records: ${missingCheck.rows.length}`);
    if (missingCheck.rows.length > 0) {
      console.log(`Sample missing records:`, missingCheck.rows.slice(0, 3));
    }

    const exceptions = result.rows.map(row => ({
      id: row.id,
      employee_id: row.employee_id,
      employee_name: row.employee_name,
      employee_number: row.employee_number,
      department_name: row.department_name,
      type: row.type,
      status: row.status,
      date: row.date,
      end_date: row.end_date,
      payload: row.payload,
      override_type: row.override_type,
      submitted_by: row.submitted_by_name || row.submitted_by_username || 'Unknown',
      document_url: row.document_url,
      reviewed_by: row.reviewed_by_name || row.reviewed_by_username || null,
      created_at: row.created_at,
      reviewed_at: row.reviewed_at,
      description: getExceptionDescription(row.type, row.payload)
    }));

    const totalCount = result.rows.length > 0 ? result.rows[0].total_count : 0;

    res.json({
      success: true,
      exceptions,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: parseInt(totalCount),
        pages: Math.ceil(totalCount / limit)
      }
    });

  } catch (error) {
    console.error('Get exception history error:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({
      error: 'Failed to retrieve exception history',
      details: error.message
    });
  }
});

// Create new exception request
router.post('/request', verifyToken, upload.single('justificationFile'), async (req, res) => {
  try {
    const {
      type,
      date: dateString,
      end_date: endDateString,
      reason
    } = req.body;

    // Payload may be provided as JSON string in multipart form
    let payload;
    if (req.body.payload) {
      try {
        payload = typeof req.body.payload === 'string' ? JSON.parse(req.body.payload) : req.body.payload;
      } catch (e) {
        return res.status(400).json({ error: 'Invalid payload JSON' });
      }
    }

    const userId = req.user.userId;

  // Parse dates using user's timezone to avoid day-shift issues
  const userTz = getUserTimezone(req);
  let date, end_date;

    if (dateString) {
      if (dateString.includes('T')) {
        // Interpret provided datetime in user's timezone and extract local calendar day
        date = moment.tz(dateString, userTz).format('YYYY-MM-DD');
      } else {
        // Treat as date-only already in local calendar day
        date = dateString;
      }
    }

    if (endDateString) {
      if (endDateString.includes('T')) {
        end_date = moment.tz(endDateString, userTz).format('YYYY-MM-DD');
      } else {
        end_date = endDateString;
      }
    }

    // Validate required fields
    if (!type || !date || !payload) {
      return res.status(400).json({
        error: 'Missing required fields: type, date, payload'
      });
    }

    // Validate exception type
    const validTypes = ['MissingPunchFix', 'LeaveRequest', 'HolidayAssignment', 'DayEdit', 'editday'];
    if (!validTypes.includes(type)) {
      return res.status(400).json({
        error: 'Invalid exception type. Must be one of: ' + validTypes.join(', ')
      });
    }

    // Check if the user exists
    const userResult = await pool.query('SELECT id FROM users WHERE id = $1', [userId]);
    const submittedByUserId = userResult.rows.length > 0 ? userId : null;

    // Get employee ID for the current user
    const employee_id = req.user.employeeId;

    if (!employee_id) {
      return res.status(404).json({ error: 'Employee not found' });
    }

    // If a file is attached, create an uploads record
    let document_upload_id = null;
    let document_url = null;
    if (req.file) {
      const file = req.file;
      const storage_path = path.relative(path.join(__dirname, '..'), file.path).replace(/\\/g, '/');
      const uploadsInsert = await pool.query(`
        INSERT INTO uploads (file_name, original_name, mime_type, file_size, storage_path, storage_type, uploader_user_id)
        VALUES ($1, $2, $3, $4, $5, 'file', $6)
        RETURNING id
      `, [file.filename, file.originalname, file.mimetype, file.size, storage_path, submittedByUserId]);
      document_upload_id = uploadsInsert.rows[0].id;
      document_url = `/uploads/${file.filename}`;
    }

    // Create exception request
    const result = await pool.query(`
      INSERT INTO attendance_exceptions
      (employee_id, type, date, end_date, payload, submitted_by_user_id, document_upload_id, document_url)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *
    `, [employee_id, type, date, end_date, JSON.stringify(payload), submittedByUserId, document_upload_id, document_url]);

    const exception = result.rows[0];

    res.json({
      success: true,
      exception: {
        ...exception,
        description: getExceptionDescription(exception.type, exception.payload)
      },
      message: 'Exception request created successfully'
    });

  } catch (error) {
    console.error('Create exception request error:', error);
    res.status(500).json({ 
      error: 'Failed to create exception request',
      details: error.message 
    });
  }
});

// Download/redirect to exception document
router.get('/:exceptionId/document', verifyToken, async (req, res) => {
  try {
    const { exceptionId } = req.params;
    const result = await pool.query('SELECT document_url FROM attendance_exceptions WHERE id = $1', [exceptionId]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Exception not found' });
    const url = result.rows[0].document_url;
    if (!url) return res.status(404).json({ error: 'No document attached' });
    // Redirect to static file served by attendance-server
    return res.redirect(url);
  } catch (error) {
    console.error('Get exception document error:', error);
    res.status(500).json({ error: 'Failed to retrieve document', details: error.message });
  }
});

// Approve exception request
router.post('/approve/:exceptionId', verifyToken, async (req, res) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const { exceptionId } = req.params;
    const { comments } = req.body;
    const userId = req.user.userId;

    // Check if the user exists
    const userResult = await pool.query('SELECT id FROM users WHERE id = $1', [userId]);
    const reviewedByUserId = userResult.rows.length > 0 ? userId : null;

    console.log(`Approving exception ${exceptionId} by user ${userId}`);

    // Get exception details
    const exceptionResult = await client.query(`
      SELECT * FROM attendance_exceptions WHERE id = $1 AND status = 'Pending'
    `, [exceptionId]);

    console.log(`Exception query result: ${exceptionResult.rows.length} rows found`);

    if (exceptionResult.rows.length === 0) {
      console.log(`Exception ${exceptionId} not found or not in Pending status`);
      throw new Error('Exception not found or already processed');
    }

    const exception = exceptionResult.rows[0];
    console.log(`Exception found: ID=${exception.id}, Status=${exception.status}, Date=${exception.date}`);

    // Update exception status
    const updateResult = await client.query(`
      UPDATE attendance_exceptions
      SET status = 'Approved',
          reviewed_by_user_id = $1,
          reviewed_at = CURRENT_TIMESTAMP,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = $2
    `, [reviewedByUserId, exceptionId]);

    console.log(`Update result: ${updateResult.rowCount} rows affected`);

    // Apply the exception based on type (supports date intervals)
    await applyException(client, exception);

    await client.query('COMMIT');

    // After successful approval, check if we need to generate substitution invitations
    // (For teachers with leave/holiday exceptions)
    try {
      if (exception.type === 'LeaveRequest' || exception.type === 'HolidayAssignment') {
        console.log(`\n🔄 [EXCEPTION-APPROVAL] Triggering auto-substitution for exception ${exceptionId}`);
        const subResult = await autoSubMatcher.generateSubstitutionInvitations(exceptionId, exception);
        console.log(`✓ [EXCEPTION-APPROVAL] Auto-substitution result:`, subResult);
      }
    } catch (subError) {
      console.error('⚠️  [EXCEPTION-APPROVAL] Auto-substitution failed (non-critical):', subError.message);
      // Don't fail the approval if auto-substitution fails
    }

    res.json({
      success: true,
      message: 'Exception approved and applied successfully'
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Approve exception error:', error);
    res.status(500).json({ 
      error: 'Failed to approve exception',
      details: error.message 
    });
  } finally {
    client.release();
  }
});

// Reject exception request
router.post('/reject/:exceptionId', verifyToken, async (req, res) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const { exceptionId } = req.params;
    const { comments } = req.body;
    const userId = req.user.userId;

    // Check if the user exists
    const userResult = await pool.query('SELECT id FROM users WHERE id = $1', [userId]);
    const reviewedByUserId = userResult.rows.length > 0 ? userId : null;

    console.log(`Rejecting exception ${exceptionId} by user ${userId}`);

    // Update exception status
    const result = await client.query(`
      UPDATE attendance_exceptions
      SET status = 'Rejected',
          reviewed_by_user_id = $1,
          reviewed_at = CURRENT_TIMESTAMP,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = $2 AND status = 'Pending'
      RETURNING *
    `, [userId, exceptionId]);

    console.log(`Reject update result: ${result.rows.length} rows affected`);

    if (result.rows.length === 0) {
      console.log(`Exception ${exceptionId} not found or not in Pending status for rejection`);
      throw new Error('Exception not found or already processed');
    }

    console.log(`Exception ${exceptionId} rejected successfully. Status updated to: ${result.rows[0].status}`);

    await client.query('COMMIT');

    res.json({
      success: true,
      message: 'Exception rejected successfully'
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Reject exception error:', error);
    res.status(500).json({
      error: 'Failed to reject exception',
      details: error.message
    });
  } finally {
    client.release();
  }
});

// Get current user's own exceptions (for employee UI)
router.get('/mine', verifyToken, async (req, res) => {
  try {
    const status = req.query.status;
    let employeeId = req.user.employeeId;

    // If employeeId is not in token, look it up from userId
    if (!employeeId && req.user.userId) {
      const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
      if (empResult.rows.length > 0) {
        employeeId = empResult.rows[0].id;
      }
    }

    if (!employeeId) {
      return res.status(401).json({ error: 'Unauthorized: no employee context' });
    }

    const where = ['ae.employee_id = $1'];
    const params = [employeeId];
    if (status && status !== 'all') {
      where.push('ae.status = $2');
      params.push(status);
    }

    const query = `
      SELECT ae.id, ae.type, ae.status, ae.payload,
             ae.date::text AS date, ae.end_date::text AS end_date,
             ae.created_at, ae.updated_at
      FROM attendance_exceptions ae
      WHERE ${where.join(' AND ')}
      ORDER BY ae.created_at DESC
      LIMIT 200
    `;

    const result = await pool.query(query, params);
    const rows = result.rows.map(r => ({
      id: r.id,
      type: r.type,
      status: r.status,
      date: r.date,
      end_date: r.end_date,
      payload: r.payload,
      created_at: r.created_at,
      updated_at: r.updated_at,
      // Try to surface a human reason from payload
      reason: (() => {
        try {
          const p = typeof r.payload === 'string' ? JSON.parse(r.payload) : r.payload;
          return p && (p.reason || p.description || p.justification_reason || '');
        } catch (_) { return ''; }
      })()
    }));
    res.json(rows);
  } catch (error) {
    console.error('Get my exceptions error:', error);
    res.status(500).json({ error: 'Failed to retrieve my exceptions', details: error.message });
  }
});

// Get exception details
router.get('/:exceptionId', verifyToken, async (req, res) => {
  try {
    const { exceptionId } = req.params;

    const result = await pool.query(`
      SELECT
        ae.id,
        ae.employee_id,
        ae.type,
        ae.status,
        ae.payload,
        ae.submitted_by_user_id,
        ae.reviewed_by_user_id,
        ae.created_at,
        ae.updated_at,
        ae.reviewed_at,
        ae.document_upload_id,
        ae.document_url,
        ae.end_date::text AS end_date,
        ae.date::text AS date,
        (SELECT ao.override_type FROM attendance_overrides ao WHERE ao.exception_id = ae.id LIMIT 1) AS override_type,
        CONCAT(e.first_name, ' ', e.last_name) as employee_name,
        e.id as employee_number,
        d.name as department_name,
        u1.username as submitted_by_username,
        u2.username as reviewed_by_username,
        CONCAT(e_submitter.first_name, ' ', e_submitter.last_name) as submitted_by_name,
        CONCAT(e_reviewer.first_name, ' ', e_reviewer.last_name) as reviewed_by_name
      FROM attendance_exceptions ae
      LEFT JOIN employees e ON ae.employee_id = e.id
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      LEFT JOIN users u1 ON ae.submitted_by_user_id = u1.id
      LEFT JOIN users u2 ON ae.reviewed_by_user_id = u2.id
      LEFT JOIN employees e_submitter ON u1.id = e_submitter.user_id
      LEFT JOIN employees e_reviewer ON u2.id = e_reviewer.user_id
      WHERE ae.id = $1
    `, [exceptionId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Exception not found' });
    }

    const exception = result.rows[0];

    res.json({
      success: true,
      exception: {
        ...exception,
        override_type: exception.override_type,
        submitted_by: exception.submitted_by_username || 'Unknown',
        reviewed_by: exception.reviewed_by_username || null,
        description: getExceptionDescription(exception.type, exception.payload)
      }
    });

  } catch (error) {
    console.error('Get exception details error:', error);
    res.status(500).json({
      error: 'Failed to retrieve exception details',
      details: error.message
    });
  }
});

// Helper function to generate exception description
function getExceptionDescription(type, payload) {
  try {
    const data = typeof payload === 'string' ? JSON.parse(payload) : payload;

    switch (type) {
      case 'MissingPunchFix':
        // Handle bulk operations differently
        if (data.bulk_operation) {
          return `Bulk missing punch ${data.reason || 'justification'}`;
        }
        return `Missing punch fix: ${data.punch_type || 'Unknown'} at ${data.time || 'Unknown time'}`;

      case 'LeaveRequest':
        return `Leave request: ${data.leave_type || 'Unknown type'} - ${data.reason || 'No reason provided'}`;

      case 'HolidayAssignment':
        return `Holiday assignment: ${data.holiday_name || 'Unknown holiday'}`;

      case 'DayEdit':
        return `Day edit: ${data.justification_reason || data.absence_reason || 'Manual adjustment'}`;

      case 'editday':
        return `Day edit: ${data.justification_reason || data.absence_reason || 'Manual adjustment'}`;

      default:
        return `${type}: ${data.reason || 'No description available'}`;
    }
  } catch (error) {
    return `${type}: Invalid payload data`;
  }
}

// Helper function to apply approved exceptions
async function applyException(client, exception) {
  const payload = typeof exception.payload === 'string'
    ? JSON.parse(exception.payload)
    : exception.payload;

  // Determine interval bounds
  const startDate = moment(exception.date).startOf('day');
  const endDate = exception.end_date ? moment(exception.end_date).startOf('day') : startDate;

  if (!startDate.isValid() || !endDate.isValid() || endDate.isBefore(startDate)) {
    throw new Error('Invalid date interval on exception');
  }

  // Iterate over each date in the interval and apply per day
  for (let d = moment(startDate); d.isSameOrBefore(endDate); d.add(1, 'day')) {
    const perDayException = { ...exception, date: d.format('YYYY-MM-DD') };
    switch (exception.type) {
      case 'MissingPunchFix':
        await applyMissingPunchFix(client, perDayException, payload);
        break;

      case 'LeaveRequest':
        await applyLeaveRequest(client, perDayException, payload);
        break;

      case 'HolidayAssignment':
        await applyHolidayAssignment(client, perDayException, payload);
        break;

      case 'DayEdit':
        await applyDayEdit(client, perDayException, payload);
        break;

      case 'editday':
        await applyDayEdit(client, perDayException, payload);
        break;

      default:
        throw new Error(`Unknown exception type: ${exception.type}`);
    }
  }
}

// Apply missing punch fix
async function applyMissingPunchFix(client, exception, payload) {
  const { punch_type, time, reason } = payload;

  if (!punch_type || !time) {
    throw new Error('Missing punch fix requires punch_type and time');
  }

  // Validate time format
  if (!moment(time, 'HH:mm', true).isValid()) {
    throw new Error(`Invalid time format: ${time}. Expected format: HH:mm`);
  }

  // Create attendance override
  await client.query(`
    INSERT INTO attendance_overrides
    (employee_id, date, override_type, details, exception_id, created_by_user_id)
    VALUES ($1, $2, 'punch_add', $3, $4, $5)
  `, [
    exception.employee_id,
    exception.date,
    JSON.stringify({
      punch_type,
      time,
      reason,
      original_exception_id: exception.id
    }),
    exception.id,
    exception.reviewed_by_user_id
  ]);

  // Create the actual punch record with proper validation in user's timezone, then store UTC
  const userTz = payload && payload.timezone ? payload.timezone : 'UTC';
  const dateStr = moment(exception.date).format('YYYY-MM-DD');
  const punchDateTime = moment.tz(`${dateStr} ${time}`, 'YYYY-MM-DD HH:mm', userTz);

  if (!punchDateTime.isValid()) {
    throw new Error(`Failed to parse punch date/time: ${dateStr} ${time}`);
  }

  const punchTimeISOString = punchDateTime.utc().toISOString();

  await client.query(`
    INSERT INTO attendance_punches
    (employee_id, punch_time, source, raw_employee_name)
    VALUES ($1, $2, 'manual_fix', (SELECT CONCAT(first_name, ' ', last_name) FROM employees WHERE id = $1))
  `, [exception.employee_id, punchTimeISOString]);
}

// Delete an exception and its linked overrides
router.delete('/:exceptionId', verifyToken, async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const { exceptionId } = req.params;
    const userId = req.user.userId;

    // Fetch the exception first
    const excRes = await client.query('SELECT * FROM attendance_exceptions WHERE id = $1 FOR UPDATE', [exceptionId]);
    if (excRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Exception not found' });
    }

    const exception = excRes.rows[0];

    // Only allow deleting MissingPunchFix exceptions
    if (exception.type !== 'MissingPunchFix') {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Only Missing Punch exceptions can be deleted' });
    }

    // Delete any overrides linked to this exception
    const delOverrides = await client.query(
      'DELETE FROM attendance_overrides WHERE exception_id = $1 RETURNING id, override_type, date',
      [exceptionId]
    );

    // Delete the exception itself
    await client.query('DELETE FROM attendance_exceptions WHERE id = $1', [exceptionId]);

    // Audit log
    await client.query(`
      INSERT INTO audit_logs (entity_type, entity_id, action, actor_user_id, data)
      VALUES ($1, $2, $3, $4, $5)
    `, [
      'attendance_exception',
      exceptionId,
      'delete',
      userId,
      JSON.stringify({ deleted_exception: { id: exceptionId, type: exception.type, employee_id: exception.employee_id, date: exception.date }, deleted_overrides: delOverrides.rows })
    ]);

    await client.query('COMMIT');

    res.json({
      success: true,
      message: 'Exception and linked overrides deleted successfully',
      deleted_overrides: delOverrides.rowCount
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Delete exception error:', error);
    res.status(500).json({ error: 'Failed to delete exception', details: error.message });
  } finally {
    client.release();
  }
});

// Apply leave request
async function applyLeaveRequest(client, exception, payload) {
  const { leave_type, reason } = payload;

  // Create attendance override for leave
  await upsertOverride(client, {
    employee_id: exception.employee_id,
    date: exception.date,
    override_type: 'leave',
    details: {
      leave_type,
      reason,
      end_date: exception.end_date,
      original_exception_id: exception.id
    },
    exception_id: exception.id,
    created_by_user_id: exception.reviewed_by_user_id
  });
}

// Apply holiday assignment
async function applyHolidayAssignment(client, exception, payload) {
  const { holiday_name, reason } = payload;

  // Create attendance override for holiday
  await upsertOverride(client, {
    employee_id: exception.employee_id,
    date: exception.date,
    override_type: 'holiday',
    details: {
      holiday_name,
      reason,
      end_date: exception.end_date,
      original_exception_id: exception.id
    },
    exception_id: exception.id,
    created_by_user_id: exception.reviewed_by_user_id
  });
}

// Apply day edit
async function applyDayEdit(client, exception, payload) {
  const { entry_time, exit_time, mark_justified, force_absent, justification_reason, absence_reason, validated } = payload;

  // Create attendance override for day edit
  await upsertOverride(client, {
    employee_id: exception.employee_id,
    date: exception.date,
    override_type: 'day_edit',
    details: {
      entry_time,
      exit_time,
      mark_justified,
      force_absent,
      justification_reason,
      absence_reason,
      validated,
      original_exception_id: exception.id
    },
    exception_id: exception.id,
    created_by_user_id: exception.reviewed_by_user_id
  });
}

// Upsert helper to avoid duplicate overrides when applying over intervals
async function upsertOverride(client, { employee_id, date, override_type, details, exception_id, created_by_user_id }) {
  // Check if an override already exists for this employee/date
  const existing = await client.query(
    'SELECT id FROM attendance_overrides WHERE employee_id = $1 AND date = $2',
    [employee_id, date]
  );

  if (existing.rows.length > 0) {
    await client.query(
      'UPDATE attendance_overrides SET override_type = $1, details = $2, exception_id = $3 WHERE id = $4',
      [override_type, JSON.stringify(details), exception_id, existing.rows[0].id]
    );
  } else {
    await client.query(
      'INSERT INTO attendance_overrides (employee_id, date, override_type, details, exception_id, created_by_user_id) VALUES ($1, $2, $3, $4, $5, $6)',
      [employee_id, date, override_type, JSON.stringify(details), exception_id, created_by_user_id]
    );
  }
}

  return router;
};

module.exports = {
  initializeRoutes,
  setAuthMiddleware
};

