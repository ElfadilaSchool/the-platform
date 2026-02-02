const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
require('dotenv').config({ path: '../.env' });

const app = express();
const PORT = process.env.PAYMENT_SERVICE_PORT || 3006;

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
  res.json({ status: 'OK', service: 'Payment Service' });
});

// Get all position salaries
app.get('/payments/position-salaries', verifyToken, async (req, res) => {
  try {
    // All authenticated users can view position salaries
    const result = await pool.query(`
      SELECT 
        ps.*,
        p.name as position_name,
        COUNT(e.id) as employee_count
      FROM position_salaries ps
      JOIN positions p ON ps.position_id = p.id
      LEFT JOIN employees e ON e.position_id = p.id
      GROUP BY ps.id, p.name
      ORDER BY p.name
    `);
    
    res.json(result.rows);
  } catch (error) {
    console.error('Get position salaries error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get position salary by position ID
app.get('/payments/position-salaries/position/:position_id', verifyToken, async (req, res) => {
  try {
    const { position_id } = req.params;
    
    const result = await pool.query(`
      SELECT 
        ps.*,
        p.name as position_name
      FROM position_salaries ps
      JOIN positions p ON ps.position_id = p.id
      WHERE ps.position_id = $1
      ORDER BY ps.effective_date DESC
      LIMIT 1
    `, [position_id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Position salary not found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get position salary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create or update position salary
app.post('/payments/position-salaries', verifyToken, async (req, res) => {
  try {
    // Only HR Manager can create/update position salaries
    if (req.user.role !== 'HR_Manager') {
      return res.status(403).json({ error: 'Access denied' });
    }

    const { 
      position_id, 
      base_salary, 
      hourly_rate, 
      overtime_rate, 
      bonus_rate,
      effective_date 
    } = req.body;
    
    if (!position_id || (!base_salary && !hourly_rate)) {
      return res.status(400).json({ error: 'Position ID and either base salary or hourly rate are required' });
    }

    // Check if position exists
    const positionCheck = await pool.query('SELECT id FROM positions WHERE id = $1', [position_id]);
    if (positionCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Position not found' });
    }

    const result = await pool.query(`
      INSERT INTO position_salaries (
        position_id, base_salary, hourly_rate, overtime_rate, bonus_rate, effective_date
      ) VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `, [
      position_id,
      base_salary || null,
      hourly_rate || null,
      overtime_rate || null,
      bonus_rate || null,
      effective_date || new Date()
    ]);

    res.status(201).json({
      message: 'Position salary created successfully',
      salary: result.rows[0]
    });
  } catch (error) {
    console.error('Create position salary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update position salary
app.put('/payments/position-salaries/:id', verifyToken, async (req, res) => {
  try {
    // Only HR Manager can update position salaries
    if (req.user.role !== 'HR_Manager') {
      return res.status(403).json({ error: 'Access denied' });
    }

    const { id } = req.params;
    const { 
      base_salary, 
      hourly_rate, 
      overtime_rate, 
      bonus_rate,
      effective_date 
    } = req.body;
    
    const updateFields = [];
    const values = [];
    let paramCount = 1;

    if (base_salary !== undefined) {
      updateFields.push(`base_salary = $${paramCount}`);
      values.push(base_salary);
      paramCount++;
    }

    if (hourly_rate !== undefined) {
      updateFields.push(`hourly_rate = $${paramCount}`);
      values.push(hourly_rate);
      paramCount++;
    }

    if (overtime_rate !== undefined) {
      updateFields.push(`overtime_rate = $${paramCount}`);
      values.push(overtime_rate);
      paramCount++;
    }

    if (bonus_rate !== undefined) {
      updateFields.push(`bonus_rate = $${paramCount}`);
      values.push(bonus_rate);
      paramCount++;
    }

    if (effective_date !== undefined) {
      updateFields.push(`effective_date = $${paramCount}`);
      values.push(effective_date);
      paramCount++;
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    values.push(id);
    const query = `UPDATE position_salaries SET ${updateFields.join(', ')} WHERE id = $${paramCount} RETURNING *`;
    
    const result = await pool.query(query, values);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Position salary not found' });
    }

    res.json({
      message: 'Position salary updated successfully',
      salary: result.rows[0]
    });
  } catch (error) {
    console.error('Update position salary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Calculate employee salary based on attendance
app.get('/payments/calculate-salary/:employee_id', verifyToken, async (req, res) => {
  try {
    const { employee_id } = req.params;
    const { start_date, end_date } = req.query;
    
    // Check permissions - employees can only view their own salary calculation
    if (req.user.role === 'Employee') {
      const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
      if (empResult.rows.length === 0 || empResult.rows[0].id !== employee_id) {
        return res.status(403).json({ error: 'Access denied' });
      }
    }

    // Get employee position and salary info
    const empResult = await pool.query(`
      WITH comp AS (
        SELECT 
          escv.employee_id,
          escv.base_salary,
          escv.hourly_rate,
          escv.overtime_rate
        FROM employee_salary_calculation_view escv
        WHERE escv.employee_id = $1
      )
      SELECT 
        e.*,
        p.name as position_name,
        COALESCE(comp.base_salary, ps.base_salary) AS base_salary,
        COALESCE(comp.hourly_rate, ps.hourly_rate) AS hourly_rate,
        COALESCE(comp.overtime_rate, ps.overtime_rate) AS overtime_rate,
        ps.bonus_rate
      FROM employees e
      JOIN positions p ON e.position_id = p.id
      LEFT JOIN comp ON comp.employee_id = e.id
      LEFT JOIN position_salaries ps ON p.id = ps.position_id
      WHERE e.id = $1
      ORDER BY ps.effective_date DESC NULLS LAST
      LIMIT 1
    `, [employee_id]);

    if (empResult.rows.length === 0) {
      return res.status(404).json({ error: 'Employee not found' });
    }

    const employee = empResult.rows[0];
    
    if (!employee.base_salary && !employee.hourly_rate) {
      return res.status(404).json({ error: 'No salary configuration found for this position' });
    }

    // Get attendance data for the period
    const attendanceResult = await pool.query(`
      SELECT 
        DATE(check_in) as work_date,
        MIN(check_in) as first_check_in,
        MAX(check_out) as last_check_out,
        COUNT(*) as check_count
      FROM attendance 
      WHERE employee_id = $1 
        AND check_in >= $2 
        AND check_in <= $3
        AND check_out IS NOT NULL
      GROUP BY DATE(check_in)
      ORDER BY work_date
    `, [employee_id, start_date || '2024-01-01', end_date || new Date().toISOString().split('T')[0]]);

    let totalHours = 0;
    let overtimeHours = 0;
    let workDays = 0;

    attendanceResult.rows.forEach(day => {
      const checkIn = new Date(day.first_check_in);
      const checkOut = new Date(day.last_check_out);
      const hoursWorked = (checkOut - checkIn) / (1000 * 60 * 60); // Convert to hours
      
      totalHours += hoursWorked;
      workDays++;
      
      // Calculate overtime (assuming 8 hours is standard work day)
      if (hoursWorked > 8) {
        overtimeHours += (hoursWorked - 8);
      }
    });

    let calculatedSalary = 0;
    let breakdown = {};

    if (employee.base_salary) {
      // Fixed salary calculation
      const daysInPeriod = attendanceResult.rows.length;
      const expectedWorkDays = 22; // Assuming 22 working days per month
      const salaryPerDay = employee.base_salary / expectedWorkDays;
      
      calculatedSalary = salaryPerDay * workDays;
      breakdown = {
        type: 'fixed',
        base_salary: employee.base_salary,
        work_days: workDays,
        expected_work_days: expectedWorkDays,
        salary_per_day: salaryPerDay,
        base_amount: calculatedSalary
      };
    } else if (employee.hourly_rate) {
      // Hourly rate calculation
      const regularHours = totalHours - overtimeHours;
      const regularPay = regularHours * employee.hourly_rate;
      const overtimePay = overtimeHours * (employee.overtime_rate || employee.hourly_rate * 1.5);
      
      calculatedSalary = regularPay + overtimePay;
      breakdown = {
        type: 'hourly',
        hourly_rate: employee.hourly_rate,
        overtime_rate: employee.overtime_rate || employee.hourly_rate * 1.5,
        total_hours: totalHours,
        regular_hours: regularHours,
        overtime_hours: overtimeHours,
        regular_pay: regularPay,
        overtime_pay: overtimePay
      };
    }

    // Add bonus if applicable
    if (employee.bonus_rate && workDays > 0) {
      const bonus = calculatedSalary * (employee.bonus_rate / 100);
      calculatedSalary += bonus;
      breakdown.bonus_rate = employee.bonus_rate;
      breakdown.bonus_amount = bonus;
    }

    res.json({
      employee: {
        id: employee.id,
        name: `${employee.first_name} ${employee.last_name}`,
        position: employee.position_name
      },
      period: {
        start_date: start_date || '2024-01-01',
        end_date: end_date || new Date().toISOString().split('T')[0]
      },
      attendance_summary: {
        work_days: workDays,
        total_hours: totalHours,
        overtime_hours: overtimeHours
      },
      salary_calculation: {
        total_amount: Math.round(calculatedSalary * 100) / 100,
        breakdown: breakdown
      }
    });
  } catch (error) {
    console.error('Calculate salary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get employee salary calculation (for employees to view their own)
app.get('/payments/my-salary', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'Employee') {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Get employee ID from user
    const empResult = await pool.query('SELECT id FROM employees WHERE user_id = $1', [req.user.userId]);
    if (empResult.rows.length === 0) {
      return res.status(404).json({ error: 'Employee record not found' });
    }

    const employeeId = empResult.rows[0].id;
    const { start_date, end_date } = req.query;

    // Redirect to calculate salary endpoint
    req.params.employee_id = employeeId;
    return res.redirect(`/payments/calculate-salary/${employeeId}?start_date=${start_date || ''}&end_date=${end_date || ''}`);
  } catch (error) {
    console.error('Get my salary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get all positions for salary assignment
app.get('/payments/positions', verifyToken, async (req, res) => {
  try {
    // All authenticated users can view positions for salary assignment
    const result = await pool.query(`
      SELECT 
        p.*,
        ps.base_salary,
        ps.hourly_rate,
        ps.overtime_rate,
        ps.bonus_rate,
        ps.effective_date,
        COUNT(e.id) as employee_count
      FROM positions p
      LEFT JOIN position_salaries ps ON p.id = ps.position_id
      LEFT JOIN employees e ON e.position_id = p.id
      GROUP BY p.id, ps.id
      ORDER BY p.name
    `);
    
    res.json(result.rows);
  } catch (error) {
    console.error('Get positions error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete position salary
app.delete('/payments/position-salaries/:id', verifyToken, async (req, res) => {
  try {
    // Only HR Manager can delete position salaries
    if (req.user.role !== 'HR_Manager') {
      return res.status(403).json({ error: 'Access denied' });
    }

    const { id } = req.params;
    
    const result = await pool.query('DELETE FROM position_salaries WHERE id = $1 RETURNING *', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Position salary not found' });
    }

    res.json({ message: 'Position salary deleted successfully' });
  } catch (error) {
    console.error('Delete position salary error:', error);
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
  console.log(`Payment Service running on port ${PORT}`);
});

module.exports = app;

