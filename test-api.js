const express = require('express');
const { Pool } = require('pg');

// Create a simple test server that bypasses authentication
const app = express();
app.use(express.json());

// Database connection
const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'attendance_db',
  password: process.env.DB_PASSWORD || 'password',
  port: process.env.DB_PORT || 5432,
});

// Simple middleware that sets a fake user
const fakeAuth = (req, res, next) => {
  req.user = { userId: 1, employeeId: 1 };
  next();
};

// Test the monthly attendance route
app.get('/test-monthly', fakeAuth, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const { year, month, department, status, search } = req.query;

    const offset = (page - 1) * limit;
    let whereConditions = [];
    let queryParams = [limit, offset, parseInt(year), parseInt(month)];
    let paramIndex = 5;

    // Get grace period settings
    const settingsQuery = `
      SELECT grace_period_lateness_minutes, grace_period_early_departure_minutes
      FROM attendance_settings 
      WHERE scope = 'global' 
      ORDER BY created_at DESC 
      LIMIT 1
    `;
    const settingsResult = await pool.query(settingsQuery);
    const settings = settingsResult.rows[0] || { grace_period_lateness_minutes: 15, grace_period_early_departure_minutes: 15 };
    const latenessGrace = settings.grace_period_lateness_minutes || 15;
    const earlyGrace = settings.grace_period_early_departure_minutes || 15;

    // Add filters
    if (department) {
      whereConditions.push(`ed.department_id = $${paramIndex}`);
      queryParams.push(department);
      paramIndex++;
    }

    if (status) {
      if (status === 'Validated') {
        whereConditions.push(`cms.is_validated = true`);
      } else if (status === 'Calculated') {
        whereConditions.push(`(cms.is_validated = false OR cms.is_validated IS NULL)`);
      }
    }

    if (search) {
      whereConditions.push(`(
        LOWER(e.first_name || ' ' || e.last_name) LIKE LOWER($${paramIndex}) OR
        LOWER(e.last_name || ' ' || e.first_name) LIKE LOWER($${paramIndex})
      )`);
      queryParams.push(`%${search}%`);
      paramIndex++;
    }

    const whereClause = whereConditions.length > 0 ? `WHERE ${whereConditions.join(' AND ')}` : '';

    const query = `
      WITH employee_stats AS (
        SELECT
          e.id as employee_id,
          e.first_name || ' ' || e.last_name AS employee_name,
          d.name AS department_name,
          p.name AS position_name,
          $3 AS year,
          $4 AS month,
          -- Simple counts for testing
          0 AS scheduled_days,
          0 AS worked_days,
          0 AS absence_days,
          0 AS late_minutes,
          0 AS early_minutes,
          0 AS overtime_hours,
          0 AS wage_changes,
          false AS validation_status_bool,
          'Calculated' AS validation_status
        FROM employees e
        LEFT JOIN comprehensive_monthly_statistics cms ON e.id = cms.employee_id AND cms.year = $3 AND cms.month = $4
        LEFT JOIN employee_departments ed ON e.id = ed.employee_id
        LEFT JOIN departments d ON ed.department_id = d.id
        LEFT JOIN positions p ON e.position_id = p.id
        ${whereClause}
      )
      SELECT
        employee_id,
        employee_name,
        department_name,
        position_name,
        year,
        month,
        scheduled_days,
        worked_days,
        absence_days,
        late_minutes,
        early_minutes,
        overtime_hours,
        wage_changes,
        validation_status_bool,
        validation_status,
        COUNT(*) OVER() AS total_count
      FROM employee_stats
      ORDER BY employee_name, year DESC, month DESC
      LIMIT $1 OFFSET $2
    `;

    const result = await pool.query(query, queryParams);
    
    res.json({
      success: true,
      data: result.rows,
      pagination: {
        page,
        limit,
        total: result.rows[0]?.total_count || 0
      }
    });

  } catch (error) {
    console.error('Error in test monthly route:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message,
      stack: error.stack
    });
  }
});

app.listen(3001, () => {
  console.log('Test server running on port 3001');
});
