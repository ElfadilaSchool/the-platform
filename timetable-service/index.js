const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const { v4: uuidv4 } = require('uuid');
const moment = require('moment-timezone');
require('dotenv').config({ path: '../.env' });

const app = express();
const PORT = process.env.TIMETABLE_SERVICE_PORT || 3011;

// Database connection
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());

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
  res.json({ status: 'OK', service: 'Timetable Service' });
});

// ==================== EDUCATION LEVELS ENDPOINTS ====================

// Get all unique education levels from employees
app.get('/education-levels', verifyToken, async (req, res) => {
  try {
    const query = `
      SELECT DISTINCT education_level 
      FROM employees 
      WHERE education_level IS NOT NULL AND education_level != ''
      ORDER BY education_level
    `;
    const result = await pool.query(query);
    res.json(result.rows.map(row => ({ name: row.education_level })));
  } catch (error) {
    console.error('Error fetching education levels:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==================== TIMETABLE LIBRARY ENDPOINTS ====================

// Get all timetables with filtering
app.get('/timetables', verifyToken, async (req, res) => {
  try {
    const { type, search, page = 1, limit = 10 } = req.query;
    const offset = (page - 1) * limit;
    
    let query = `
      SELECT t.*, 
             COUNT(ti.id) as interval_count,
             COUNT(et.id) as assignment_count
      FROM timetables t
      LEFT JOIN timetable_intervals ti ON t.id = ti.timetable_id
      LEFT JOIN employee_timetables et ON t.id = et.timetable_id
      WHERE 1=1
    `;
    
    const params = [];
    let paramIndex = 1;
    
    if (type && type !== 'All') {
      query += ` AND t.type = $${paramIndex}`;
      params.push(type);
      paramIndex++;
    }
    
    if (search) {
      query += ` AND t.name ILIKE $${paramIndex}`;
      params.push(`%${search}%`);
      paramIndex++;
    }
    
    query += ` GROUP BY t.id ORDER BY t.created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    params.push(limit, offset);
    
    const result = await pool.query(query, params);
    
    // Get total count for pagination
    let countQuery = 'SELECT COUNT(*) FROM timetables WHERE 1=1';
    const countParams = [];
    let countParamIndex = 1;
    
    if (type && type !== 'All') {
      countQuery += ` AND type = $${countParamIndex}`;
      countParams.push(type);
      countParamIndex++;
    }
    
    if (search) {
      countQuery += ` AND name ILIKE $${countParamIndex}`;
      countParams.push(`%${search}%`);
    }
    
    const countResult = await pool.query(countQuery, countParams);
    const totalCount = parseInt(countResult.rows[0].count);
    
    res.json({
      timetables: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalCount,
        pages: Math.ceil(totalCount / limit)
      }
    });
  } catch (error) {
    console.error('Error fetching timetables:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get timetable by ID with intervals
app.get('/timetables/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    // Get timetable details
    const timetableQuery = 'SELECT * FROM timetables WHERE id = $1';
    const timetableResult = await pool.query(timetableQuery, [id]);
    
    if (timetableResult.rows.length === 0) {
      return res.status(404).json({ error: 'Timetable not found' });
    }
    
    // Get intervals
    const intervalsQuery = `
      SELECT * FROM timetable_intervals 
      WHERE timetable_id = $1 
      ORDER BY weekday, start_time
    `;
    const intervalsResult = await pool.query(intervalsQuery, [id]);
    
    const timetable = {
      ...timetableResult.rows[0],
      intervals: intervalsResult.rows
    };
    
    res.json(timetable);
  } catch (error) {
    console.error('Error fetching timetable:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create new timetable
app.post('/timetables', verifyToken, async (req, res) => {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    const { name, type, timezone = 'UTC', gradeLevelMode = 'none', gradeLevel, intervals = [] } = req.body;
    
    if (!name || !type) {
      return res.status(400).json({ error: 'Name and type are required' });
    }
    
    // Validate grade level mode
    if (!['none', 'single', 'multiple'].includes(gradeLevelMode)) {
      return res.status(400).json({ error: 'Invalid grade level mode' });
    }
    
    // Validate single grade level mode
    if (gradeLevelMode === 'single' && (!gradeLevel || gradeLevel < 1 || gradeLevel > 5)) {
      return res.status(400).json({ error: 'Grade level (1-5) is required for single grade level mode' });
    }
    
    // Create timetable
    const timetableId = uuidv4();
    const timetableQuery = `
      INSERT INTO timetables (id, name, type, timezone, grade_level_mode, grade_level, created_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
      RETURNING *
    `;
    
    const timetableResult = await client.query(timetableQuery, [
      timetableId, name, type, timezone, gradeLevelMode, gradeLevel || null
    ]);
    
    // Create intervals
    const createdIntervals = [];
    for (const interval of intervals) {
      const intervalId = uuidv4();
      
      // Determine grade level for this interval
      let intervalGradeLevel = null;
      
      if (gradeLevelMode === 'single') {
        // Use timetable-level grade for all intervals
        intervalGradeLevel = gradeLevel;
      } else if (gradeLevelMode === 'multiple') {
        // Use interval-specific grade level
        intervalGradeLevel = interval.grade_level || null;
      }
      
      const intervalQuery = `
        INSERT INTO timetable_intervals 
        (id, timetable_id, weekday, start_time, end_time, break_minutes, on_call_flag, overnight, grade_level, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
        RETURNING *
      `;
      
      const intervalResult = await client.query(intervalQuery, [
        intervalId,
        timetableId,
        interval.weekday,
        interval.start_time,
        interval.end_time,
        interval.break_minutes || 0,
        interval.on_call_flag || false,
        interval.overnight || false,
        intervalGradeLevel
      ]);
      
      createdIntervals.push(intervalResult.rows[0]);
    }
    
    await client.query('COMMIT');
    
    const response = {
      ...timetableResult.rows[0],
      intervals: createdIntervals
    };
    
    res.status(201).json(response);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error creating timetable:', error);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    client.release();
  }
});

// Update timetable
app.put('/timetables/:id', verifyToken, async (req, res) => {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    const { id } = req.params;
    const { name, type, timezone, gradeLevelMode = 'none', gradeLevel, intervals = [] } = req.body;
    
    // Validate grade level mode
    if (!['none', 'single', 'multiple'].includes(gradeLevelMode)) {
      return res.status(400).json({ error: 'Invalid grade level mode' });
    }
    
    // Validate single grade level mode
    if (gradeLevelMode === 'single' && (!gradeLevel || gradeLevel < 1 || gradeLevel > 5)) {
      return res.status(400).json({ error: 'Grade level (1-5) is required for single grade level mode' });
    }
    
    // Update timetable
    const timetableQuery = `
      UPDATE timetables 
      SET name = $1, type = $2, timezone = $3, grade_level_mode = $4, grade_level = $5, updated_at = NOW()
      WHERE id = $6
      RETURNING *
    `;
    
    const timetableResult = await client.query(timetableQuery, [
      name, type, timezone, gradeLevelMode, gradeLevel || null, id
    ]);
    
    if (timetableResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Timetable not found' });
    }
    
    // Delete existing intervals
    await client.query('DELETE FROM timetable_intervals WHERE timetable_id = $1', [id]);
    
    // Create new intervals
    const createdIntervals = [];
    for (const interval of intervals) {
      const intervalId = uuidv4();
      
      // Determine grade level for this interval
      let intervalGradeLevel = null;
      
      if (gradeLevelMode === 'single') {
        // Use timetable-level grade for all intervals
        intervalGradeLevel = gradeLevel;
      } else if (gradeLevelMode === 'multiple') {
        // Use interval-specific grade level
        intervalGradeLevel = interval.grade_level || null;
      }
      
      const intervalQuery = `
        INSERT INTO timetable_intervals 
        (id, timetable_id, weekday, start_time, end_time, break_minutes, on_call_flag, overnight, grade_level, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
        RETURNING *
      `;
      
      const intervalResult = await client.query(intervalQuery, [
        intervalId,
        id,
        interval.weekday,
        interval.start_time,
        interval.end_time,
        interval.break_minutes || 0,
        interval.on_call_flag || false,
        interval.overnight || false,
        intervalGradeLevel
      ]);
      
      createdIntervals.push(intervalResult.rows[0]);
    }
    
    await client.query('COMMIT');
    
    const response = {
      ...timetableResult.rows[0],
      intervals: createdIntervals
    };
    
    res.json(response);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error updating timetable:', error);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    client.release();
  }
});

// Duplicate timetable
app.post('/timetables/:id/duplicate', verifyToken, async (req, res) => {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    const { id } = req.params;
    const { name } = req.body;
    
    if (!name) {
      return res.status(400).json({ error: 'Name is required for duplicate' });
    }
    
    // Get original timetable
    const originalQuery = 'SELECT * FROM timetables WHERE id = $1';
    const originalResult = await pool.query(originalQuery, [id]);
    
    if (originalResult.rows.length === 0) {
      return res.status(404).json({ error: 'Timetable not found' });
    }
    
    const original = originalResult.rows[0];
    
    // Create new timetable
    const newTimetableId = uuidv4();
    const timetableQuery = `
      INSERT INTO timetables (id, name, type, timezone, grade_level_mode, grade_level, created_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
      RETURNING *
    `;
    
    const timetableResult = await client.query(timetableQuery, [
      newTimetableId, name, original.type, original.timezone, original.grade_level_mode, original.grade_level
    ]);
    
    // Copy intervals
    const intervalsQuery = 'SELECT * FROM timetable_intervals WHERE timetable_id = $1';
    const intervalsResult = await pool.query(intervalsQuery, [id]);
    
    const createdIntervals = [];
    for (const interval of intervalsResult.rows) {
      const intervalId = uuidv4();
      const intervalQuery = `
        INSERT INTO timetable_intervals 
        (id, timetable_id, weekday, start_time, end_time, break_minutes, on_call_flag, overnight, grade_level, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
        RETURNING *
      `;
      
      const intervalResult = await client.query(intervalQuery, [
        intervalId,
        newTimetableId,
        interval.weekday,
        interval.start_time,
        interval.end_time,
        interval.break_minutes,
        interval.on_call_flag,
        interval.overnight,
        interval.grade_level
      ]);
      
      createdIntervals.push(intervalResult.rows[0]);
    }
    
    await client.query('COMMIT');
    
    const response = {
      ...timetableResult.rows[0],
      intervals: createdIntervals
    };
    
    res.status(201).json(response);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error duplicating timetable:', error);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    client.release();
  }
});

// Delete timetable
app.delete('/timetables/:id', verifyToken, async (req, res) => {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    const { id } = req.params;
    
    // Check if timetable is assigned to employees
    const assignmentQuery = 'SELECT COUNT(*) FROM employee_timetables WHERE timetable_id = $1';
    const assignmentResult = await pool.query(assignmentQuery, [id]);
    const assignmentCount = parseInt(assignmentResult.rows[0].count);
    
    if (assignmentCount > 0) {
      return res.status(400).json({ 
        error: 'Cannot delete timetable that is assigned to employees',
        assignedCount: assignmentCount
      });
    }
    
    // Delete intervals first (due to foreign key constraint)
    await client.query('DELETE FROM timetable_intervals WHERE timetable_id = $1', [id]);
    
    // Delete timetable
    const deleteQuery = 'DELETE FROM timetables WHERE id = $1 RETURNING *';
    const deleteResult = await client.query(deleteQuery, [id]);
    
    if (deleteResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Timetable not found' });
    }
    
    await client.query('COMMIT');
    
    res.json({ message: 'Timetable deleted successfully' });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error deleting timetable:', error);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    client.release();
  }
});

// ==================== EMPLOYEE TIMETABLE ASSIGNMENTS ====================

// Get all employees with their timetable assignments
app.get('/employee-assignments', verifyToken, async (req, res) => {
  try {
    const { filter = 'all', search, department, page = 1, limit = 10 } = req.query;
    const offset = (page - 1) * limit;
    
    let query = `
      SELECT 
        e.id,
        e.first_name,
        e.last_name,
        e.email,
        p.name as position_name,
        d.name as department_name,
        t.id as timetable_id,
        t.name as timetable_name,
        t.type as timetable_type,
        et.effective_from,
        et.effective_to,
        et.priority,
        CASE 
          WHEN t.id IS NOT NULL THEN 'Assigned'
          ELSE 'Not Assigned'
        END as assignment_status
      FROM employees e
      LEFT JOIN positions p ON e.position_id = p.id
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      LEFT JOIN employee_timetables et ON e.id = et.employee_id 
        AND (et.effective_to IS NULL OR et.effective_to >= CURRENT_DATE)
        AND et.effective_from <= CURRENT_DATE
      LEFT JOIN timetables t ON et.timetable_id = t.id
      WHERE 1=1
    `;
    
    const params = [];
    let paramIndex = 1;
    
    if (filter === 'assigned') {
      query += ` AND t.id IS NOT NULL`;
    } else if (filter === 'not_assigned') {
      query += ` AND t.id IS NULL`;
    }
    
    if (search) {
      query += ` AND (e.first_name ILIKE $${paramIndex} OR e.last_name ILIKE $${paramIndex} OR e.email ILIKE $${paramIndex})`;
      params.push(`%${search}%`);
      paramIndex++;
    }
    
    if (department) {
      query += ` AND d.id = $${paramIndex}`;
      params.push(department);
      paramIndex++;
    }
    
    query += ` ORDER BY e.first_name, e.last_name LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    params.push(limit, offset);
    
    const result = await pool.query(query, params);
    
    // Get total count for pagination
    let countQuery = `
      SELECT COUNT(DISTINCT e.id) 
      FROM employees e
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      LEFT JOIN employee_timetables et ON e.id = et.employee_id 
        AND (et.effective_to IS NULL OR et.effective_to >= CURRENT_DATE)
        AND et.effective_from <= CURRENT_DATE
      LEFT JOIN timetables t ON et.timetable_id = t.id
      WHERE 1=1
    `;
    
    const countParams = [];
    let countParamIndex = 1;
    
    if (filter === 'assigned') {
      countQuery += ` AND t.id IS NOT NULL`;
    } else if (filter === 'not_assigned') {
      countQuery += ` AND t.id IS NULL`;
    }
    
    if (search) {
      countQuery += ` AND (e.first_name ILIKE $${countParamIndex} OR e.last_name ILIKE $${countParamIndex} OR e.email ILIKE $${countParamIndex})`;
      countParams.push(`%${search}%`);
      countParamIndex++;
    }
    
    if (department) {
      countQuery += ` AND d.id = $${countParamIndex}`;
      countParams.push(department);
    }
    
    const countResult = await pool.query(countQuery, countParams);
    const totalCount = parseInt(countResult.rows[0].count);
    
    res.json({
      employees: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalCount,
        pages: Math.ceil(totalCount / limit)
      }
    });
  } catch (error) {
    console.error('Error fetching employee assignments:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get employee timetable assignment details
app.get('/employee-assignments/:employeeId', verifyToken, async (req, res) => {
  try {
    const { employeeId } = req.params;
    
    // Get employee details
    const employeeQuery = `
      SELECT 
        e.*,
        p.name as position_name,
        d.name as department_name
      FROM employees e
      LEFT JOIN positions p ON e.position_id = p.id
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      WHERE e.id = $1
    `;
    
    const employeeResult = await pool.query(employeeQuery, [employeeId]);
    
    if (employeeResult.rows.length === 0) {
      return res.status(404).json({ error: 'Employee not found' });
    }
    
    // Get current timetable assignment
    const assignmentQuery = `
      SELECT 
        et.*,
        t.name as timetable_name,
        t.type as timetable_type,
        t.timezone
      FROM employee_timetables et
      JOIN timetables t ON et.timetable_id = t.id
      WHERE et.employee_id = $1 
        AND (et.effective_to IS NULL OR et.effective_to >= CURRENT_DATE)
        AND et.effective_from <= CURRENT_DATE
      ORDER BY et.priority DESC, et.effective_from DESC
      LIMIT 1
    `;
    
    const assignmentResult = await pool.query(assignmentQuery, [employeeId]);
    
    // Get timetable intervals if assigned
    let intervals = [];
    if (assignmentResult.rows.length > 0) {
      const intervalsQuery = `
        SELECT * FROM timetable_intervals 
        WHERE timetable_id = $1 
        ORDER BY weekday, start_time
      `;
      const intervalsResult = await pool.query(intervalsQuery, [assignmentResult.rows[0].timetable_id]);
      intervals = intervalsResult.rows;
    }
    
    const response = {
      employee: employeeResult.rows[0],
      assignment: assignmentResult.rows[0] || null,
      intervals: intervals
    };
    
    res.json(response);
  } catch (error) {
    console.error('Error fetching employee assignment:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Assign timetable to employee
app.post('/employee-assignments', verifyToken, async (req, res) => {
  try {
    const { employeeId, timetableId, effectiveFrom, effectiveTo, priority = 1 } = req.body;
    
    if (!employeeId || !timetableId || !effectiveFrom) {
      return res.status(400).json({ error: 'Employee ID, timetable ID, and effective from date are required' });
    }
    
    // Check if employee exists
    const employeeCheck = await pool.query('SELECT id FROM employees WHERE id = $1', [employeeId]);
    if (employeeCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Employee not found' });
    }
    
    // Check if timetable exists
    const timetableCheck = await pool.query('SELECT id FROM timetables WHERE id = $1', [timetableId]);
    if (timetableCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Timetable not found' });
    }
    
    // Create assignment
    const assignmentId = uuidv4();
    const assignmentQuery = `
      INSERT INTO employee_timetables 
      (id, employee_id, timetable_id, effective_from, effective_to, priority, created_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
      RETURNING *
    `;
    
    const assignmentResult = await pool.query(assignmentQuery, [
      assignmentId, employeeId, timetableId, effectiveFrom, effectiveTo, priority
    ]);
    
    res.status(201).json(assignmentResult.rows[0]);
  } catch (error) {
    console.error('Error creating employee assignment:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update employee timetable assignment
app.put('/employee-assignments/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { timetableId, effectiveFrom, effectiveTo, priority } = req.body;
    
    const updateQuery = `
      UPDATE employee_timetables 
      SET timetable_id = $1, effective_from = $2, effective_to = $3, priority = $4, updated_at = NOW()
      WHERE id = $5
      RETURNING *
    `;
    
    const result = await pool.query(updateQuery, [
      timetableId, effectiveFrom, effectiveTo, priority, id
    ]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Assignment not found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error updating employee assignment:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Remove employee timetable assignment
app.delete('/employee-assignments/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    const deleteQuery = 'DELETE FROM employee_timetables WHERE id = $1 RETURNING *';
    const result = await pool.query(deleteQuery, [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Assignment not found' });
    }
    
    res.json({ message: 'Assignment removed successfully' });
  } catch (error) {
    console.error('Error removing employee assignment:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Timetable Service running on port ${PORT}`);
});

module.exports = app;
