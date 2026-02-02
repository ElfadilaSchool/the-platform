const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
require('dotenv').config({ path: '../.env' });

const app = express();
const PORT = process.env.MEETING_SERVICE_PORT || 3005;

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
  res.json({ status: 'OK', service: 'Meeting Service' });
});

// Get meetings (filtered by employee, date)
app.get('/meetings', verifyToken, async (req, res) => {
  try {
    const { employee_id, start_date, end_date } = req.query;
    
    let query = `
      SELECT
        m.id,
        m.title,
        m.description,
        m.scheduled_by,
        m.start_time,
        m.end_time,
        m.notes,
        m.created_at,
        m.updated_at,
        e.first_name as scheduled_by_first_name,
        e.last_name as scheduled_by_last_name,
        ARRAY_AGG(ma.employee_id) AS attendees
      FROM meetings m
      LEFT JOIN employees e ON m.scheduled_by = e.id
      LEFT JOIN meeting_attendees ma ON m.id = ma.meeting_id
    `;
    
    const conditions = [];
    const params = [];
    let paramCount = 1;

    // Get current employee ID once
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.id]);
    const currentEmployeeId = empResult.rows.length > 0 ? empResult.rows[0].id : null;

    // Role-based filtering
    if (req.user.role === 'Employee') {
      if (currentEmployeeId) {
        // An employee sees meetings they scheduled OR are an attendee of.
        conditions.push(`(
          m.scheduled_by = $${paramCount} OR 
          m.id IN (SELECT meeting_id FROM meeting_attendees WHERE employee_id = $${paramCount})
        )`);
        params.push(currentEmployeeId);
        paramCount++;
      } else {
         return res.json([]); // No employee record, so no meetings
      }
    } else if (req.user.role === 'Department_Responsible') {
      if (currentEmployeeId) {
        // A department responsible sees meetings they scheduled, OR meetings involving anyone in their department.
        conditions.push(`(
          m.scheduled_by = $${paramCount} OR 
          m.id IN (SELECT meeting_id FROM meeting_attendees WHERE employee_id IN (
            SELECT ed.employee_id FROM employee_departments ed JOIN departments d ON ed.department_id = d.id WHERE d.responsible_id = $${paramCount}
          ))
        )`);
        params.push(currentEmployeeId);
        paramCount++;
      } else {
        return res.json([]);
      }
    }
    // HR Manager can see all meetings (no additional filtering)

    if (employee_id) {
      conditions.push(`ma.employee_id = $${paramCount++}`);
      params.push(employee_id);
    }

    if (start_date) {
      conditions.push(`m.start_time >= $${paramCount++}`);
      params.push(start_date);
    }

    if (end_date) {
      conditions.push(`m.end_time <= $${paramCount++}`);
      params.push(end_date);
    }

    if (conditions.length > 0) {
      query += ` WHERE ${conditions.join(' AND ')}`;
    }

    query += ` GROUP BY m.id, e.first_name, e.last_name ORDER BY m.start_time ASC`;
    
    const result = await pool.query(query, params);
    
    // Get attendees details for each meeting
    const meetingsWithAttendees = await Promise.all(result.rows.map(async (meeting) => {
      const attendeesResult = await pool.query(`
        SELECT e.id, e.first_name, e.last_name
        FROM meeting_attendees ma
        JOIN employees e ON ma.employee_id = e.id
        WHERE ma.meeting_id = $1
        ORDER BY e.first_name, e.last_name
      `, [meeting.id]);
      
      return {
        ...meeting,
        attendees: meeting.attendees || [],
        attendee_details: attendeesResult.rows
      };
    }));
    
    res.json(meetingsWithAttendees);
  } catch (error) {
    console.error('Get meetings error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get meeting by ID with attendees
app.get('/meetings/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    // Get meeting details
    const meetingResult = await pool.query(`
      SELECT 
        m.*,
        e.first_name as scheduled_by_first_name,
        e.last_name as scheduled_by_last_name
      FROM meetings m
      LEFT JOIN employees e ON m.scheduled_by = e.id
      WHERE m.id = $1
    `, [id]);
    
    if (meetingResult.rows.length === 0) {
      return res.status(404).json({ error: 'Meeting not found' });
    }

    // Get meeting attendees
    const attendeesResult = await pool.query(`
      SELECT 
        e.id,
        e.first_name,
        e.last_name,
        p.name as position_name
      FROM meeting_attendees ma
      JOIN employees e ON ma.employee_id = e.id
      LEFT JOIN positions p ON e.position_id = p.id
      WHERE ma.meeting_id = $1
      ORDER BY e.first_name, e.last_name
    `, [id]);
    
    const meeting = meetingResult.rows[0];
    meeting.attendees = attendeesResult.rows.map(r => r.id); // Return array of IDs
    meeting.attendee_details = attendeesResult.rows; // Return full details
    
    res.json(meeting);
  } catch (error) {
    console.error('Get meeting error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create new meeting
app.post('/meetings', verifyToken, async (req, res) => {
  try {
    // Only HR Manager and Department Responsible can create meetings
    if (req.user.role === 'Employee') {
      return res.status(403).json({ error: 'Access denied' });
    }

    const { title, description, start_time, end_time, notes, attendees } = req.body;
    
    if (!title || !start_time || !end_time) {
      return res.status(400).json({ error: 'Title, start_time, and end_time are required' });
    }

    // Get the employee ID of the user creating the meeting
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.id]);
    if (empResult.rows.length === 0) {
      return res.status(400).json({ error: 'Employee record not found for the current user' });
    }

    const scheduled_by = empResult.rows[0].id;

    // Start transaction
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Insert meeting
      const meetingResult = await client.query(`
        INSERT INTO meetings (title, description, scheduled_by, start_time, end_time, notes)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING *
      `, [title, description, scheduled_by, start_time, end_time, notes || null]);

      const meeting = meetingResult.rows[0];

      // Insert attendees if provided
      if (attendees && attendees.length > 0) {
        const attendeeValues = attendees.map(attendeeId => `('${meeting.id}', '${attendeeId}')`).join(',');
        await client.query(`INSERT INTO meeting_attendees (meeting_id, employee_id) VALUES ${attendeeValues}`);
      }

      await client.query('COMMIT');

      // Refetch the created meeting with all details
      const finalResult = await pool.query(`
        SELECT m.*, e.first_name as scheduled_by_first_name, e.last_name as scheduled_by_last_name
        FROM meetings m
        LEFT JOIN employees e ON m.scheduled_by = e.id
        WHERE m.id = $1
      `, [meeting.id]);

      res.status(201).json(finalResult.rows[0]);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    console.error('Create meeting error:', error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Update meeting
app.put('/meetings/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, start_time, end_time, notes, attendees } = req.body;
    
    // Get current meeting to check permissions
    const currentMeetingResult = await pool.query('SELECT * FROM meetings WHERE id = $1', [id]);
    if (currentMeetingResult.rows.length === 0) {
      return res.status(404).json({ error: 'Meeting not found' });
    }
    const meeting = currentMeetingResult.rows[0];
    
    // Check permissions
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.id]);
    const currentEmployeeId = empResult.rows.length > 0 ? empResult.rows[0].id : null;
    
    if (req.user.role === 'Employee' || !currentEmployeeId) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    if (req.user.role === 'Department_Responsible' && meeting.scheduled_by !== currentEmployeeId) {
      return res.status(403).json({ error: 'You can only update meetings you scheduled' });
    }

    // Start transaction
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const updateResult = await client.query(`
        UPDATE meetings 
        SET 
          title = $1, 
          description = $2, 
          start_time = $3, 
          end_time = $4, 
          notes = $5
        WHERE id = $6
        RETURNING *
      `, [title, description, start_time, end_time, notes, id]);

      // Update attendees
      await client.query('DELETE FROM meeting_attendees WHERE meeting_id = $1', [id]);
      if (attendees && attendees.length > 0) {
        const attendeeValues = attendees.map(attendeeId => `('${id}', '${attendeeId}')`).join(',');
        await client.query(`INSERT INTO meeting_attendees (meeting_id, employee_id) VALUES ${attendeeValues}`);
      }

      await client.query('COMMIT');

      res.json(updateResult.rows[0]);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    console.error('Update meeting error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete meeting
app.delete('/meetings/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    const currentMeetingResult = await pool.query('SELECT * FROM meetings WHERE id = $1', [id]);
    if (currentMeetingResult.rows.length === 0) {
      return res.status(404).json({ error: 'Meeting not found' });
    }
    const meeting = currentMeetingResult.rows[0];
    
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.id]);
    const currentEmployeeId = empResult.rows.length > 0 ? empResult.rows[0].id : null;

    if (req.user.role === 'Employee' || !currentEmployeeId) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    if (req.user.role === 'Department_Responsible' && meeting.scheduled_by !== currentEmployeeId) {
      return res.status(403).json({ error: 'You can only delete meetings you scheduled' });
    }

    await pool.query('DELETE FROM meetings WHERE id = $1', [id]);

    res.status(204).send(); // No content
  } catch (error) {
    console.error('Delete meeting error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get upcoming meetings for dashboard
app.get('/meetings/upcoming/dashboard', verifyToken, async (req, res) => {
  try {
    console.log('User role:', req.user.role);
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.id]);
    const currentEmployeeId = empResult.rows.length > 0 ? empResult.rows[0].id : null;
    console.log('Current employee ID:', currentEmployeeId);

    const conditions = ['m.start_time > NOW()'];
    const params = [];
    let paramCount = 1;

    // Role-based filtering
    if (req.user.role === 'Employee') {
      if (!currentEmployeeId) return res.json([]);
      // An employee sees meetings they scheduled OR are an attendee of.
      conditions.push(`(
        m.scheduled_by = $${paramCount} OR 
        m.id IN (SELECT meeting_id FROM meeting_attendees WHERE employee_id = $${paramCount})
      )`);
      params.push(currentEmployeeId);
      paramCount++;
    } else if (req.user.role === 'Department_Responsible') {
      if (!currentEmployeeId) return res.json([]);
      // A department responsible sees meetings they scheduled, OR meetings involving anyone in their department.
      conditions.push(`(
        m.scheduled_by = $${paramCount} OR 
        m.id IN (SELECT meeting_id FROM meeting_attendees WHERE employee_id IN (
          SELECT ed.employee_id FROM employee_departments ed JOIN departments d ON ed.department_id = d.id WHERE d.responsible_id = $${paramCount}
        ))
      )`);
      params.push(currentEmployeeId);
      paramCount++;
    }
    // HR Manager can see all meetings (no additional filtering)

    const whereClause = `WHERE ${conditions.join(' AND ')}`;

    const query = `
      SELECT
        m.id,
        m.title,
        m.description,
        m.scheduled_by,
        m.start_time,
        m.end_time,
        m.notes,
        m.created_at,
        m.updated_at,
        e.first_name as scheduled_by_first_name,
        e.last_name as scheduled_by_last_name,
        ARRAY_AGG(ma.employee_id) AS attendees
      FROM meetings m
      LEFT JOIN employees e ON m.scheduled_by = e.id
      LEFT JOIN meeting_attendees ma ON m.id = ma.meeting_id
      ${whereClause}
      GROUP BY m.id, e.first_name, e.last_name
      ORDER BY m.start_time ASC
      LIMIT 5
    `;

    console.log('Final query:', query);
    console.log('Query params:', params);

    const result = await pool.query(query, params);

    // Get attendees details for each meeting
    const meetingsWithAttendees = await Promise.all(result.rows.map(async (meeting) => {
      const attendeesResult = await pool.query(`
        SELECT e.id, e.first_name, e.last_name
        FROM meeting_attendees ma
        JOIN employees e ON ma.employee_id = e.id
        WHERE ma.meeting_id = $1
        ORDER BY e.first_name, e.last_name
      `, [meeting.id]);
      
      return {
        ...meeting,
        attendees: meeting.attendees || [],
        attendee_details: attendeesResult.rows
      };
    }));

    res.json(meetingsWithAttendees);
  } catch (error) {
    console.error('Get upcoming meetings error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error(error);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Meeting Service running on port ${PORT}`);
});

module.exports = app;
