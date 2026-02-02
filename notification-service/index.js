const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
require('dotenv').config({ path: '../.env' });

const app = express();
const PORT = process.env.NOTIFICATION_SERVICE_PORT || 3007;

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
  res.json({ status: 'OK', service: 'Notification Service' });
});

// Get notifications for the current user
app.get('/notifications', verifyToken, async (req, res) => {
  try {
    const { limit = 50, offset = 0, unread_only = false } = req.query;
    
    // Get employee ID for the current user
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
    if (empResult.rows.length === 0) {
      return res.status(400).json({ error: 'Employee record not found' });
    }

    const employeeId = empResult.rows[0].id;
    
    let query = `
      SELECT 
        n.*,
        sender.first_name as sender_first_name,
        sender.last_name as sender_last_name
      FROM notifications n
      LEFT JOIN employees sender ON n.sender_id = sender.id
      WHERE n.recipient_id = $1
    `;
    
    const params = [employeeId];
    let paramCount = 2;

    if (unread_only === 'true') {
      query += ` AND n.is_read = false`;
    }

    query += ` ORDER BY n.created_at DESC LIMIT $${paramCount} OFFSET $${paramCount + 1}`;
    params.push(parseInt(limit), parseInt(offset));
    
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get unread notification count
app.get('/notifications/unread/count', verifyToken, async (req, res) => {
  try {
    // Get employee ID for the current user
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
    if (empResult.rows.length === 0) {
      return res.status(400).json({ error: 'Employee record not found' });
    }

    const employeeId = empResult.rows[0].id;
    
    const result = await pool.query(
      'SELECT COUNT(*) as unread_count FROM notifications WHERE recipient_id = $1 AND is_read = false',
      [employeeId]
    );
    
    res.json({ unread_count: parseInt(result.rows[0].unread_count) });
  } catch (error) {
    console.error('Get unread count error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Mark notification as read
app.put('/notifications/:id/read', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    // Get employee ID for the current user
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
    if (empResult.rows.length === 0) {
      return res.status(400).json({ error: 'Employee record not found' });
    }

    const employeeId = empResult.rows[0].id;
    
    const result = await pool.query(
      'UPDATE notifications SET is_read = true WHERE id = $1 AND recipient_id = $2 RETURNING *',
      [id, employeeId]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Notification not found or access denied' });
    }

    res.json({ message: 'Notification marked as read' });
  } catch (error) {
    console.error('Mark notification as read error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Mark all notifications as read
app.put('/notifications/read-all', verifyToken, async (req, res) => {
  try {
    // Get employee ID for the current user
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
    if (empResult.rows.length === 0) {
      return res.status(400).json({ error: 'Employee record not found' });
    }

    const employeeId = empResult.rows[0].id;
    
    const result = await pool.query(
      'UPDATE notifications SET is_read = true WHERE recipient_id = $1 AND is_read = false RETURNING id',
      [employeeId]
    );

    res.json({ 
      message: 'All notifications marked as read',
      updated_count: result.rows.length
    });
  } catch (error) {
    console.error('Mark all notifications as read error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Send notification (internal API for other services)
app.post('/notifications/send', verifyToken, async (req, res) => {
  try {
    const { recipient_id, sender_id, type, message } = req.body;
    
    if (!recipient_id || !type || !message) {
      return res.status(400).json({ error: 'recipient_id, type, and message are required' });
    }

    const result = await pool.query(`
      INSERT INTO notifications (recipient_id, sender_id, type, message)
      VALUES ($1, $2, $3, $4)
      RETURNING *
    `, [recipient_id, sender_id || null, type, message]);

    res.status(201).json({
      message: 'Notification sent successfully',
      notification: result.rows[0]
    });
  } catch (error) {
    console.error('Send notification error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Send bulk notifications (internal API for other services)
app.post('/notifications/send-bulk', verifyToken, async (req, res) => {
  try {
    const { recipient_ids, sender_id, type, message } = req.body;
    
    if (!recipient_ids || !Array.isArray(recipient_ids) || !type || !message) {
      return res.status(400).json({ error: 'recipient_ids (array), type, and message are required' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const notifications = [];
      for (const recipient_id of recipient_ids) {
        const result = await client.query(`
          INSERT INTO notifications (recipient_id, sender_id, type, message)
          VALUES ($1, $2, $3, $4)
          RETURNING *
        `, [recipient_id, sender_id || null, type, message]);
        
        notifications.push(result.rows[0]);
      }

      await client.query('COMMIT');

      res.status(201).json({
        message: 'Bulk notifications sent successfully',
        notifications: notifications,
        count: notifications.length
      });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    console.error('Send bulk notifications error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete notification
app.delete('/notifications/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    // Get employee ID for the current user
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
    if (empResult.rows.length === 0) {
      return res.status(400).json({ error: 'Employee record not found' });
    }

    const employeeId = empResult.rows[0].id;
    
    const result = await pool.query(
      'DELETE FROM notifications WHERE id = $1 AND recipient_id = $2 RETURNING *',
      [id, employeeId]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Notification not found or access denied' });
    }

    res.json({ message: 'Notification deleted successfully' });
  } catch (error) {
    console.error('Delete notification error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get notification statistics for dashboard
app.get('/notifications/stats/dashboard', verifyToken, async (req, res) => {
  try {
    // Get employee ID for the current user
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
    if (empResult.rows.length === 0) {
      return res.status(400).json({ error: 'Employee record not found' });
    }

    const employeeId = empResult.rows[0].id;
    
    const result = await pool.query(`
      SELECT 
        COUNT(*) as total_notifications,
        COUNT(CASE WHEN is_read = false THEN 1 END) as unread_notifications,
        COUNT(CASE WHEN created_at >= NOW() - INTERVAL '24 hours' THEN 1 END) as notifications_today,
        COUNT(CASE WHEN created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as notifications_this_week
      FROM notifications 
      WHERE recipient_id = $1
    `, [employeeId]);

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get notification stats error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Helper function to create system notifications (can be called by other services)
const createSystemNotification = async (recipientId, type, message, senderId = null) => {
  try {
    const result = await pool.query(`
      INSERT INTO notifications (recipient_id, sender_id, type, message)
      VALUES ($1, $2, $3, $4)
      RETURNING *
    `, [recipientId, senderId, type, message]);
    
    return result.rows[0];
  } catch (error) {
    console.error('Create system notification error:', error);
    throw error;
  }
};

// Export helper function for use by other services
module.exports = { createSystemNotification };

// Error handling middleware
app.use((error, req, res, next) => {
  console.error(error);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Notification Service running on port ${PORT}`);
});

module.exports = app;

