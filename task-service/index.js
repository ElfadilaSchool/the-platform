const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
require('dotenv').config({ path: '../.env' });

const app = express();
const PORT = process.env.TASK_SERVICE_PORT || 3004;

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
  res.json({ status: 'OK', service: 'Task Service' });
});

// Get tasks (filtered by role, status, employee)
app.get('/tasks', verifyToken, async (req, res) => {
  try {
    const { status, employee_id, type } = req.query;
    
    let query = `
      SELECT 
        t.*,
        assigned_to_emp.first_name as assigned_to_first_name,
        assigned_to_emp.last_name as assigned_to_last_name,
        assigned_by_emp.first_name as assigned_by_first_name,
        assigned_by_emp.last_name as assigned_by_last_name
      FROM tasks t
      LEFT JOIN employees assigned_to_emp ON t.assigned_to = assigned_to_emp.id
      LEFT JOIN employees assigned_by_emp ON t.assigned_by = assigned_by_emp.id
    `;
    
    const conditions = [];
    const params = [];
    let paramCount = 1;

    // Role-based filtering
    if (req.user.role === 'Employee') {
      // Employees can only see their own tasks
      const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
      if (empResult.rows.length > 0) {
        conditions.push(`t.assigned_to = $${paramCount}`);
        params.push(empResult.rows[0].id);
        paramCount++;
      }
    } else if (req.user.role === 'Department_Responsible') {
      // Responsibles can see tasks they assigned or tasks for their department employees
      const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
      if (empResult.rows.length > 0) {
        conditions.push(`(t.assigned_by = $${paramCount} OR t.assigned_to IN (
          SELECT ed.employee_id FROM employee_departments ed 
          JOIN departments d ON ed.department_id = d.id 
          WHERE d.responsible_id = $${paramCount}
        ))`);
        params.push(empResult.rows[0].id);
        paramCount++;
      }
    }
    // HR Manager can see all tasks (no additional filtering)

    if (status) {
      conditions.push(`t.status = $${paramCount}`);
      params.push(status);
      paramCount++;
    }

    if (employee_id) {
      conditions.push(`t.assigned_to = $${paramCount}`);
      params.push(employee_id);
      paramCount++;
    }

    if (type) {
      conditions.push(`t.type = $${paramCount}`);
      params.push(type);
      paramCount++;
    }

    if (conditions.length > 0) {
      query += ` WHERE ${conditions.join(' AND ')}`;
    }

    query += ` ORDER BY t.created_at DESC`;
    
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Get tasks error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get task by ID with comments
app.get('/tasks/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    // Get task details
    const taskResult = await pool.query(`
      SELECT 
        t.*,
        assigned_to_emp.first_name as assigned_to_first_name,
        assigned_to_emp.last_name as assigned_to_last_name,
        assigned_by_emp.first_name as assigned_by_first_name,
        assigned_by_emp.last_name as assigned_by_last_name
      FROM tasks t
      LEFT JOIN employees assigned_to_emp ON t.assigned_to = assigned_to_emp.id
      LEFT JOIN employees assigned_by_emp ON t.assigned_by = assigned_by_emp.id
      WHERE t.id = $1
    `, [id]);
    
    if (taskResult.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    // Get task comments
    const commentsResult = await pool.query(`
      SELECT 
        tc.*,
        e.first_name,
        e.last_name
      FROM task_comments tc
      LEFT JOIN employees e ON tc.employee_id = e.id
      WHERE tc.task_id = $1
      ORDER BY tc.created_at ASC
    `, [id]);
    
    const task = taskResult.rows[0];
    task.comments = commentsResult.rows;
    
    res.json(task);
  } catch (error) {
    console.error('Get task error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create new task
app.post('/tasks', verifyToken, async (req, res) => {
  try {
    // Only Department Responsible and HR Manager can create tasks
    if (req.user.role === 'Employee') {
      return res.status(403).json({ error: 'Access denied' });
    }

    const { title, description, type, assigned_to, due_date } = req.body;
    
    if (!title || !type || !assigned_to) {
      return res.status(400).json({ error: 'Title, type, and assigned_to are required' });
    }

    // Get the employee ID of the user creating the task
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
    if (empResult.rows.length === 0) {
      return res.status(400).json({ error: 'Employee record not found' });
    }

    const assigned_by = empResult.rows[0].id;

    // If user is Department Responsible, check if they can assign to this employee
    if (req.user.role === 'Department_Responsible') {
      const deptCheck = await pool.query(`
        SELECT 1 FROM employee_departments ed 
        JOIN departments d ON ed.department_id = d.id 
        WHERE d.responsible_id = $1 AND ed.employee_id = $2
      `, [assigned_by, assigned_to]);
      
      if (deptCheck.rows.length === 0) {
        return res.status(403).json({ error: 'You can only assign tasks to employees in your department' });
      }
    }

    const result = await pool.query(`
      INSERT INTO tasks (title, description, type, assigned_to, assigned_by, due_date)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `, [title, description, type, assigned_to, assigned_by, due_date || null]);

    res.status(201).json({
      message: 'Task created successfully',
      task: result.rows[0]
    });
  } catch (error) {
    console.error('Create task error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update task
app.put('/tasks/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, status, due_date } = req.body;
    
    // Get current task to check permissions
    const currentTask = await pool.query('SELECT * FROM tasks WHERE id = $1', [id]);
    if (currentTask.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    const task = currentTask.rows[0];
    
    // Check permissions
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
    if (empResult.rows.length === 0) {
      return res.status(400).json({ error: 'Employee record not found' });
    }

    const currentEmployeeId = empResult.rows[0].id;
    
    // Employees can only update status of their own tasks
    if (req.user.role === 'Employee') {
      if (task.assigned_to !== currentEmployeeId) {
        return res.status(403).json({ error: 'Access denied' });
      }
      // Employees can only update status
      if (title !== undefined || description !== undefined || due_date !== undefined) {
        return res.status(403).json({ error: 'Employees can only update task status' });
      }
    }
    // Department Responsible can update tasks they assigned
    else if (req.user.role === 'Department_Responsible') {
      if (task.assigned_by !== currentEmployeeId) {
        return res.status(403).json({ error: 'You can only update tasks you assigned' });
      }
    }
    // HR Manager can update any task

    const updateFields = [];
    const values = [];
    let paramCount = 1;

    if (title !== undefined) {
      updateFields.push(`title = $${paramCount}`);
      values.push(title);
      paramCount++;
    }

    if (description !== undefined) {
      updateFields.push(`description = $${paramCount}`);
      values.push(description);
      paramCount++;
    }

    if (status !== undefined) {
      updateFields.push(`status = $${paramCount}`);
      values.push(status);
      paramCount++;
    }

    if (due_date !== undefined) {
      updateFields.push(`due_date = $${paramCount}`);
      values.push(due_date || null);
      paramCount++;
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    values.push(id);
    const query = `UPDATE tasks SET ${updateFields.join(', ')} WHERE id = $${paramCount} RETURNING *`;
    
    const result = await pool.query(query, values);

    res.json({
      message: 'Task updated successfully',
      task: result.rows[0]
    });
  } catch (error) {
    console.error('Update task error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete task
app.delete('/tasks/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    // Get current task to check permissions
    const currentTask = await pool.query('SELECT * FROM tasks WHERE id = $1', [id]);
    if (currentTask.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    const task = currentTask.rows[0];
    
    // Only the person who assigned the task or HR Manager can delete it
    if (req.user.role === 'Employee') {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    if (req.user.role === 'Department_Responsible') {
      const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
      if (empResult.rows.length === 0 || task.assigned_by !== empResult.rows[0].id) {
        return res.status(403).json({ error: 'You can only delete tasks you assigned' });
      }
    }

    await pool.query('DELETE FROM tasks WHERE id = $1', [id]);

    res.json({ message: 'Task deleted successfully' });
  } catch (error) {
    console.error('Delete task error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Add comment to task
app.post('/tasks/:id/comments', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { comment } = req.body;
    
    if (!comment) {
      return res.status(400).json({ error: 'Comment is required' });
    }

    // Check if task exists
    const taskCheck = await pool.query('SELECT id FROM tasks WHERE id = $1', [id]);
    if (taskCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    // Get employee ID
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
    if (empResult.rows.length === 0) {
      return res.status(400).json({ error: 'Employee record not found' });
    }

    const result = await pool.query(`
      INSERT INTO task_comments (task_id, employee_id, comment)
      VALUES ($1, $2, $3)
      RETURNING *
    `, [id, empResult.rows[0].id, comment]);

    res.status(201).json({
      message: 'Comment added successfully',
      comment: result.rows[0]
    });
  } catch (error) {
    console.error('Add comment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get task statistics for dashboard
app.get('/tasks/stats/dashboard', verifyToken, async (req, res) => {
  try {
    let whereClause = '';
    const params = [];
    
    if (req.user.role === 'Employee') {
      const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
      if (empResult.rows.length > 0) {
        whereClause = 'WHERE t.assigned_to = $1';
        params.push(empResult.rows[0].id);
      }
    } else if (req.user.role === 'Department_Responsible') {
      const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
      if (empResult.rows.length > 0) {
        whereClause = `WHERE t.assigned_to IN (
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
      FROM tasks t
      ${whereClause}
      GROUP BY status
    `, params);

    const stats = {
      pending: 0,
      in_progress: 0,
      completed: 0,
      not_done: 0
    };

    result.rows.forEach(row => {
      const status = row.status.toLowerCase().replace(' ', '_');
      stats[status] = parseInt(row.count);
    });

    res.json(stats);
  } catch (error) {
    console.error('Get task stats error:', error);
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
  console.log(`Task Service running on port ${PORT}`);
});

module.exports = app;

