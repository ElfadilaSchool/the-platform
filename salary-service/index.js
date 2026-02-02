const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const { v4: uuidv4 } = require('uuid');
const moment = require('moment-timezone');
const ExcelJS = require('exceljs');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: '../.env' });

// Import fixed salary calculation functions
const {
  calculateSalaryAlgerian,
  calculateSalaryWorkedDays,
  getSalaryParameters
} = require('./fixed_salary_calculation');

const app = express();
const PORT = process.env.SALARY_SERVICE_PORT || 3010;

// Database connection
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

// Ensure required indexes/constraints exist for upsert logic
(async function ensureIndexes() {
  try {
    await pool.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS ux_payslips_emp_month_year
      ON payslips (employee_id, month, year)
    `);
    console.log('Verified: unique index ux_payslips_emp_month_year');
  } catch (e) {
    console.error('Failed to ensure unique index on payslips:', e.message);
  }
})();

// Middleware
app.use(helmet());
app.use(cors({
  origin: function (origin, callback) {
    // Allow all origins in dev; restrict in prod as needed
    callback(null, true);
  },
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-user-timezone', 'x-dev-role']
}));
app.options('*', cors());
app.use(morgan('combined'));
app.use(express.json());

// JWT verification middleware
const verifyToken = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  // Dev bypass: allow a simple 'dev' token when explicitly enabled
  if (process.env.ALLOW_DEV_TOKEN === 'true' && token === 'dev') {
    req.user = {
      userId: 'dev-user',
      role: req.headers['x-dev-role'] || 'HR_Manager'
    };
    return next();
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};

// Role-based access middleware
const requireRole = (roles) => (req, res, next) => {
  try {
    const userRole = req.user?.role;
    if (!userRole || !roles.includes(userRole)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    next();
  } catch (e) {
    return res.status(403).json({ error: 'Forbidden' });
  }
};

// Normalize known salary calculation errors to proper HTTP responses
const mapSalaryErrorToHttp = (error, defaultMessage = 'Failed to fetch salary details') => {
  const message = error?.message || defaultMessage;
  if (message === 'Employee not found') {
    return { status: 404, message };
  }
  if (message.includes('Monthly attendance not validated')) {
    return { status: 409, message };
  }
  return { status: 500, message: defaultMessage };
};

// Identify the common "attendance not validated" failure so we can downgrade it
const isAttendanceNotValidatedError = (error) => {
  const msg = (error?.message || '').toLowerCase();
  return msg.includes('attendance not validated');
};

// Register payslip routes from separate module
const registerPayslipRoutes = require('./payslips');
registerPayslipRoutes(app, pool, verifyToken, requireRole);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', service: 'Salary Service' });
});

// Minimal employee details for payslips pages
app.get('/employees/:employeeId', verifyToken, async (req, res) => {
  try {
    const { employeeId } = req.params;
    const row = await pool.query(`
      SELECT 
        e.id,
        e.first_name,
        e.last_name,
        p.name as position_name,
        d.name as department_name
      FROM employees e
      LEFT JOIN positions p ON e.position_id = p.id
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      WHERE e.id = $1
      LIMIT 1
    `, [employeeId]);
    if (row.rows.length === 0) return res.status(404).json({ error: 'Employee not found' });
    res.json({ success: true, employee: row.rows[0] });
  } catch (error) {
    console.error('Error fetching employee details:', error);
    res.status(500).json({ error: 'Failed to fetch employee details' });
  }
});

// ==================== SALARY PARAMETERS ENDPOINTS ====================

// Get salary parameters
app.get('/salary-parameters', verifyToken, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT * FROM salary_parameters 
      ORDER BY parameter_name
    `);

    res.json({
      success: true,
      parameters: result.rows
    });
  } catch (error) {
    console.error('Error fetching salary parameters:', error);
    res.status(500).json({ error: 'Failed to fetch salary parameters' });
  }
});

// Update salary parameter
app.put('/salary-parameters/:parameterName', verifyToken, async (req, res) => {
  try {
    const { parameterName } = req.params;
    const { parameter_value, description } = req.body;

    const result = await pool.query(`
      UPDATE salary_parameters 
      SET parameter_value = $1, description = $2, updated_at = CURRENT_TIMESTAMP
      WHERE parameter_name = $3
      RETURNING *
    `, [parameter_value, description, parameterName]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Parameter not found' });
    }

    res.json({
      success: true,
      parameter: result.rows[0]
    });
  } catch (error) {
    console.error('Error updating salary parameter:', error);
    res.status(500).json({ error: 'Failed to update salary parameter' });
  }
});

// ==================== EMPLOYEE ADJUSTMENTS ENDPOINTS ====================

// Get employee salary adjustments
app.get('/employees/:employeeId/adjustments', verifyToken, async (req, res) => {
  try {
    const { employeeId } = req.params;
    const { year, month } = req.query;

    let query = `
      SELECT * FROM employee_salary_adjustments
      WHERE employee_id = $1
    `;
    const params = [employeeId];

    if (year && month) {
      query += ` AND EXTRACT(YEAR FROM effective_date) = $2 AND EXTRACT(MONTH FROM effective_date) = $3`;
      params.push(year, month);
    }

    query += ` ORDER BY effective_date DESC`;

    const result = await pool.query(query, params);

    res.json({
      success: true,
      adjustments: result.rows
    });
  } catch (error) {
    console.error('Error fetching employee adjustments:', error);
    res.status(500).json({ error: 'Failed to fetch employee adjustments' });
  }
});

// Add employee salary adjustment
app.post('/employees/:employeeId/adjustments', verifyToken, async (req, res) => {
  try {
    const { employeeId } = req.params;
    const { adjustment_type, amount, description, effective_date } = req.body;
    const userId = req.user.userId;

    // Parse the effective date to get month and year
    const effectiveDate = new Date(effective_date);
    const month = effectiveDate.getMonth() + 1;
    const year = effectiveDate.getFullYear();

    // Calculate the wage change amount based on adjustment type
    let wageChangeAmount = 0;
    switch (adjustment_type) {
      case 'raise':
        wageChangeAmount = parseFloat(amount);
        break;
      case 'decrease':
        wageChangeAmount = -parseFloat(amount);
        break;
      case 'credit':
        wageChangeAmount = -parseFloat(amount);
        break;
      default:
        throw new Error('Invalid adjustment type');
    }

    // Check if employee_monthly_summaries record exists for this month/year
    const existingRecord = await pool.query(`
      SELECT id, total_wage_changes FROM employee_monthly_summaries
      WHERE employee_id = $1 AND month = $2 AND year = $3
    `, [employeeId, month, year]);

    if (existingRecord.rows.length > 0) {
      // Update existing record
      const newTotalWageChanges = (parseFloat(existingRecord.rows[0].total_wage_changes) || 0) + wageChangeAmount;

      await pool.query(`
        UPDATE employee_monthly_summaries 
        SET total_wage_changes = $1, updated_at = CURRENT_TIMESTAMP
        WHERE employee_id = $2 AND month = $3 AND year = $4
      `, [newTotalWageChanges, employeeId, month, year]);

      res.json({
        success: true,
        message: 'Wage change updated in monthly summary',
        wage_change: wageChangeAmount,
        total_wage_changes: newTotalWageChanges
      });
    } else {
      // Create new record with basic values
      await pool.query(`
        INSERT INTO employee_monthly_summaries 
        (employee_id, month, year, total_wage_changes, is_validated, created_at, updated_at)
        VALUES ($1, $2, $3, $4, false, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      `, [employeeId, month, year, wageChangeAmount]);

      res.json({
        success: true,
        message: 'Wage change added to monthly summary',
        wage_change: wageChangeAmount,
        total_wage_changes: wageChangeAmount
      });
    }
  } catch (error) {
    console.error('Error adding employee adjustment:', error);
    res.status(500).json({ error: 'Failed to add employee adjustment' });
  }
});

// Delete employee salary adjustment
app.delete('/adjustments/:adjustmentId', verifyToken, async (req, res) => {
  try {
    const { adjustmentId } = req.params;

    const result = await pool.query(`
      DELETE FROM employee_salary_adjustments 
      WHERE id = $1
      RETURNING *
    `, [adjustmentId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Adjustment not found' });
    }

    res.json({
      success: true,
      message: 'Adjustment deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting employee adjustment:', error);
    res.status(500).json({ error: 'Failed to delete employee adjustment' });
  }
});

// ==================== SALARY ENDPOINTS ====================

// Get salary list for a specific month
app.get('/salaries', verifyToken, async (req, res) => {
  try {
    const {
      month = moment().month() + 1,
      year = moment().year(),
      page = 1,
      limit = 10,
      search,
      department
    } = req.query;

    const offset = (page - 1) * limit;

    // Get employees list
    let employeeQuery = `
      SELECT DISTINCT 
        e.id, 
        e.first_name, 
        e.last_name, 
        e.email, 
        p.name as position_name, 
        d.name as department_name
      FROM employees e
      LEFT JOIN positions p ON e.position_id = p.id
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      WHERE 1=1
    `;

    const params = [];
    let paramIndex = 1;

    if (search) {
      employeeQuery += ` AND (e.first_name ILIKE $${paramIndex} OR e.last_name ILIKE $${paramIndex} OR e.email ILIKE $${paramIndex})`;
      params.push(`%${search}%`);
      paramIndex++;
    }

    if (department) {
      employeeQuery += ` AND d.id = $${paramIndex}`;
      params.push(department);
      paramIndex++;
    }

    employeeQuery += ` ORDER BY e.first_name, e.last_name LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    params.push(limit, offset);

    const employeesResult = await pool.query(employeeQuery, params);

    // Calculate salary for each employee using the new Algerian formula
    const salaries = [];
    for (const employee of employeesResult.rows) {
      try {
        const salaryData = await calculateSalaryAlgerian(pool, employee.id, parseInt(month), parseInt(year));

        // Check if salary is already marked as paid
        const paymentQuery = `
          SELECT status, calculation_method, paid_at, amount FROM salary_payments
          WHERE employee_id = $1
            AND month = $2
            AND year = $3
        `;
        const paymentResult = await pool.query(paymentQuery, [employee.id, month, year]);
        const paymentRecord = paymentResult.rows[0] || null;
        const paymentStatus = paymentRecord?.status || 'Not Paid';

        salaries.push({
          ...salaryData,
          payment_status: paymentStatus,
          payment_method: paymentRecord?.calculation_method || null,
          payment_date: paymentRecord?.paid_at || null,
          payment_amount: paymentRecord?.amount || null
        });
      } catch (error) {
        // Only log unexpected errors, not validation failures
        if (!error.message.includes('Employee not found') && !error.message.includes('not validated')) {
          console.error(`Error calculating salary for employee ${employee.id}:`, error);
        }
        // Add employee with zero salary if calculation fails
        salaries.push({
          employee_id: employee.id,
          employee_name: `${employee.first_name} ${employee.last_name}`,
          position: employee.position_name,
          department_name: employee.department_name,
          month: parseInt(month),
          year: parseInt(year),
          currency: 'DA',
          net_salary: 0,
          payment_status: 'Error',
          error: error.message
        });
      }
    }

    // Get total count for pagination
    let countQuery = `
      SELECT COUNT(DISTINCT e.id)
      FROM employees e
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      WHERE 1=1
    `;

    const countParams = [];
    let countParamIndex = 1;

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
      success: true,
      salaries,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalCount,
        pages: Math.ceil(totalCount / limit)
      },
      period: {
        month: parseInt(month),
        year: parseInt(year)
      }
    });
  } catch (error) {
    console.error('Error fetching salaries:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get salary summary statistics for a specific month
app.get('/salaries/summary', verifyToken, async (req, res) => {
  try {
    const {
      month = moment().month() + 1,
      year = moment().year(),
      department
    } = req.query;

    // Build base query for employees
    let employeeQuery = `
      SELECT DISTINCT e.id
      FROM employees e
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      WHERE 1=1
    `;

    const params = [];
    let paramIndex = 1;

    if (department) {
      employeeQuery += ` AND d.id = $${paramIndex}`;
      params.push(department);
      paramIndex++;
    }

    const employeesResult = await pool.query(employeeQuery, params);
    const employeeIds = employeesResult.rows.map(row => row.id);

    if (employeeIds.length === 0) {
      return res.json({
        success: true,
        summary: {
          total_employees: 0,
          total_payroll: 0,
          paid_count: 0,
          pending_count: 0,
          total_raise: 0,
          total_decrease: 0
        },
        period: {
          month: parseInt(month),
          year: parseInt(year)
        }
      });
    }

    // Get wage changes summary from employee_monthly_summaries
    const wageChangesQuery = `
      SELECT 
        SUM(CASE WHEN total_wage_changes > 0 THEN total_wage_changes ELSE 0 END) as total_raise,
        SUM(CASE WHEN total_wage_changes < 0 THEN ABS(total_wage_changes) ELSE 0 END) as total_decrease
      FROM employee_monthly_summaries
      WHERE employee_id = ANY($1) 
        AND month = $2 
        AND year = $3
        AND is_validated = true
    `;

    const wageChangesResult = await pool.query(wageChangesQuery, [
      employeeIds,
      parseInt(month),
      parseInt(year)
    ]);

    // Debug: Log the wage changes result
    console.log('Wage changes query result:', wageChangesResult.rows[0]);
    console.log('Employee IDs:', employeeIds);
    console.log('Month:', month, 'Year:', year);

    // Debug: Check wage changes from monthly summaries
    const debugQuery = `
      SELECT employee_id, total_wage_changes, is_validated
      FROM employee_monthly_summaries
      WHERE employee_id = ANY($1) 
        AND month = $2 
        AND year = $3
      ORDER BY total_wage_changes DESC
    `;
    const debugResult = await pool.query(debugQuery, [employeeIds, parseInt(month), parseInt(year)]);
    console.log('Debug - Monthly wage changes:', debugResult.rows);

    // Get salary totals
    let totalPayroll = 0;
    let paidCount = 0;
    let pendingCount = 0;

    for (const employeeId of employeeIds) {
      try {
        const salaryData = await calculateSalaryAlgerian(pool, employeeId, parseInt(month), parseInt(year));
        totalPayroll += salaryData.net_salary || 0;

        // Check payment status
        const paymentQuery = `
          SELECT status FROM salary_payments
          WHERE employee_id = $1
            AND month = $2
            AND year = $3
        `;
        const paymentResult = await pool.query(paymentQuery, [employeeId, month, year]);
        const paymentStatus = paymentResult.rows[0]?.status || 'Not Paid';

        if (paymentStatus === 'Paid') {
          paidCount++;
        } else {
          pendingCount++;
        }
      } catch (error) {
        // Silently count failed calculations as pending (validation not completed)
        // This is expected when attendance is not yet validated
        if (!error.message.includes('not validated') && !error.message.includes('Employee not found')) {
          console.error(`Error calculating salary for employee ${employeeId}:`, error.message);
        }
        pendingCount++;
      }
    }

    const summary = {
      total_employees: employeeIds.length,
      total_payroll: totalPayroll,
      paid_count: paidCount,
      pending_count: pendingCount,
      total_raise: parseFloat(wageChangesResult.rows[0]?.total_raise) || 0,
      total_decrease: parseFloat(wageChangesResult.rows[0]?.total_decrease) || 0
    };

    res.json({
      success: true,
      summary,
      period: {
        month: parseInt(month),
        year: parseInt(year)
      }
    });
  } catch (error) {
    console.error('Error fetching salary summary:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get detailed salary breakdown for an employee
app.get('/salaries/:employeeId', verifyToken, async (req, res) => {
  try {
    const { employeeId } = req.params;
    const { month = moment().month() + 1, year = moment().year() } = req.query;

    const salaryData = await calculateSalaryAlgerian(pool, employeeId, parseInt(month), parseInt(year));

    // Get raises history for this employee and month
    const raisesQuery = `
      SELECT * FROM salary_raises
      WHERE employee_id = $1
        AND EXTRACT(YEAR FROM effective_date) = $2
        AND EXTRACT(MONTH FROM effective_date) = $3
      ORDER BY effective_date DESC
    `;

    const raisesResult = await pool.query(raisesQuery, [employeeId, year, month]);

    // Get adjustments for this employee and month
    const adjustmentsQuery = `
      SELECT * FROM employee_salary_adjustments
      WHERE employee_id = $1
        AND EXTRACT(YEAR FROM effective_date) = $2
        AND EXTRACT(MONTH FROM effective_date) = $3
      ORDER BY effective_date DESC
    `;

    const adjustmentsResult = await pool.query(adjustmentsQuery, [employeeId, year, month]);

    // Check payment status
    const paymentQuery = `
      SELECT * FROM salary_payments
      WHERE employee_id = $1
        AND month = $2
        AND year = $3
    `;
    const paymentResult = await pool.query(paymentQuery, [employeeId, month, year]);

    const response = {
      success: true,
      ...salaryData,
      raises: raisesResult.rows,
      adjustments: adjustmentsResult.rows,
      payment_record: paymentResult.rows[0] || null,
      payment_status: paymentResult.rows[0]?.status || 'Not Paid'
    };

    res.json(response);
  } catch (error) {
    console.error('Error fetching salary details:', error);
    if (isAttendanceNotValidatedError(error)) {
      // Gracefully return a usable response so the UI can show "Not Calculated"
      return res.json({
        success: false,
        notValidated: true,
        message: error.message,
        net_salary: 0,
        payment_status: 'Not Calculated'
      });
    }
    const { status, message } = mapSalaryErrorToHttp(error);
    res.status(status).json({ error: message });
  }
});

// Get both calculation methods for comparison
app.get('/salaries/:employeeId/compare', verifyToken, async (req, res) => {
  try {
    const { employeeId } = req.params;
    const { month = moment().month() + 1, year = moment().year() } = req.query;

    // Calculate both methods
    const algerianData = await calculateSalaryAlgerian(pool, employeeId, parseInt(month), parseInt(year));
    const workedDaysData = await calculateSalaryWorkedDays(pool, employeeId, parseInt(month), parseInt(year));

    // Get adjustments for this employee and month
    const adjustmentsQuery = `
      SELECT * FROM employee_salary_adjustments
      WHERE employee_id = $1
        AND EXTRACT(YEAR FROM effective_date) = $2
        AND EXTRACT(MONTH FROM effective_date) = $3
      ORDER BY effective_date DESC
    `;

    const adjustmentsResult = await pool.query(adjustmentsQuery, [employeeId, year, month]);

    // Check payment status
    const paymentQuery = `
      SELECT * FROM salary_payments
      WHERE employee_id = $1
        AND month = $2
        AND year = $3
    `;
    const paymentResult = await pool.query(paymentQuery, [employeeId, month, year]);

    // Fetch current attendance statistics - use the same comprehensive_monthly_statistics view as attendance page
    let currentAttendanceStats = null;
    try {
      // Get grace period settings first
      const settingsResult = await pool.query(`
        SELECT grace_period_lateness_minutes, grace_period_early_departure_minutes
        FROM attendance_settings WHERE scope = 'global' ORDER BY created_at DESC LIMIT 1
      `);
      const settings = settingsResult.rows[0] || { grace_period_lateness_minutes: 15, grace_period_early_departure_minutes: 15 };
      const latenessGrace = parseInt(settings.grace_period_lateness_minutes || 15);
      const earlyGrace = parseInt(settings.grace_period_early_departure_minutes || 15);

      // Get employee name for matching
      const employeeResult = await pool.query('SELECT first_name, last_name FROM employees WHERE id = $1', [employeeId]);
      if (employeeResult.rows.length === 0) {
        throw new Error('Employee not found');
      }
      const employee = employeeResult.rows[0];

      // Use the EXACT same query logic as attendance-routes.js /monthly endpoint
      // Note: latenessGrace and earlyGrace are safe to interpolate as they're integers from our own settings
      // We'll use string replacement to insert the grace period values directly
      const currentStatsQuery = `
        WITH employee_stats AS (
          SELECT
            e.id as employee_id,
            $1::integer AS year,
            $2::integer AS month,
            -- Calculate scheduled days from timetable
            (SELECT COUNT(DISTINCT gs.date)
            FROM generate_series(
              date_trunc('month', make_date($1::integer, $2::integer, 1))::date,
              (date_trunc('month', make_date($1::integer, $2::integer, 1)) + interval '1 month - 1 day')::date,
              '1 day'::interval
            ) AS gs(date)
            WHERE EXISTS (
              SELECT 1 FROM timetable_intervals ti
              JOIN employee_timetables et ON ti.timetable_id = et.timetable_id
              WHERE et.employee_id = e.id
                AND (
                  EXTRACT(ISODOW FROM gs.date) = ti.weekday
                  OR (ti.weekday = 0 AND EXTRACT(ISODOW FROM gs.date) = 7)
                )
                AND gs.date BETWEEN COALESCE(et.effective_from, '1900-01-01')
                AND COALESCE(et.effective_to, '2100-12-31')
            )
            ) AS scheduled_days,
            -- Calculate worked days (Present status) - excluding pending cases
            (
              SELECT COUNT(*)
              FROM (
                SELECT
                  d.date,
                  CASE
                    -- Treated pending cases (stored in details field)
                    WHEN ao.override_type = 'status_override' AND ao.details->>'pending_treatment' = 'full_day' THEN 'Present'
                    WHEN ao.override_type = 'status_override' AND ao.details->>'pending_treatment' = 'half_day' THEN 'Present'
                    WHEN ao.override_type = 'status_override' AND ao.details->>'pending_treatment' = 'refuse' THEN 'Absent'
                    -- Single punch cases go to Pending (if not treated)
                    WHEN dp.punch_count = 1 AND (ao.override_type IS NULL OR (ao.override_type = 'status_override' AND ao.details->>'pending_treatment' IS NULL)) THEN 'Pending'
                    -- Other overrides
                    WHEN ao.override_type IS NOT NULL THEN 'Present'
                    -- Complete attendance (2+ punches)
                    WHEN dp.punch_count >= 2 THEN 'Present'
                    ELSE 'Absent'
                  END AS status
                FROM
                  generate_series(
                    date_trunc('month', make_date($1::integer, $2::integer, 1))::date,
                    (date_trunc('month', make_date($1::integer, $2::integer, 1)) + interval '1 month - 1 day')::date,
                    '1 day'::interval
                  ) AS d(date)
                LEFT JOIN (
                  SELECT
                    rp.punch_time::date AS date,
                    COUNT(*) AS punch_count
                  FROM raw_punches rp
                  WHERE
                    lower(TRIM(BOTH FROM replace(rp.employee_name, ' ', ''))) IN (
                      lower(TRIM(BOTH FROM replace(e.first_name || ' ' || e.last_name, ' ', ''))),
                      lower(TRIM(BOTH FROM replace(e.last_name || ' ' || e.first_name, ' ', ''))),
                      lower(TRIM(BOTH FROM replace(e.first_name || e.last_name, ' ', ''))),
                      lower(TRIM(BOTH FROM replace(e.last_name || e.first_name, ' ', '')))
                    )
                    AND EXTRACT(YEAR FROM rp.punch_time) = $1
                    AND EXTRACT(MONTH FROM rp.punch_time) = $2
                  GROUP BY rp.punch_time::date
                ) dp ON d.date = dp.date
                LEFT JOIN attendance_overrides ao ON ao.employee_id = e.id AND ao.date = d.date
                WHERE EXISTS (
                  SELECT 1 FROM timetable_intervals ti
                  JOIN employee_timetables et ON ti.timetable_id = et.timetable_id
                  WHERE et.employee_id = e.id
                    AND (
                      EXTRACT(ISODOW FROM d.date) = ti.weekday
                      OR (ti.weekday = 0 AND EXTRACT(ISODOW FROM d.date) = 7)
                    )
                    AND d.date BETWEEN COALESCE(et.effective_from, '1900-01-01')
                    AND COALESCE(et.effective_to, '2100-12-31')
                )
              ) daily_records
              WHERE status = 'Present'
            ) AS worked_days,
            -- Calculate absence days
            (
              SELECT COUNT(*)
              FROM (
                SELECT
                  d.date,
                  CASE
                    -- Treated pending cases (stored in details field)
                    WHEN ao.override_type = 'status_override' AND ao.details->>'pending_treatment' = 'full_day' THEN 'Present'
                    WHEN ao.override_type = 'status_override' AND ao.details->>'pending_treatment' = 'half_day' THEN 'Present'
                    WHEN ao.override_type = 'status_override' AND ao.details->>'pending_treatment' = 'refuse' THEN 'Absent'
                    -- Single punch cases go to Pending (if not treated)
                    WHEN dp.punch_count = 1 AND (ao.override_type IS NULL OR (ao.override_type = 'status_override' AND ao.details->>'pending_treatment' IS NULL)) THEN 'Pending'
                    -- Other overrides
                    WHEN ao.override_type IS NOT NULL THEN 'Present'
                    -- Complete attendance (2+ punches)
                    WHEN dp.punch_count >= 2 THEN 'Present'
                    ELSE 'Absent'
                  END AS status
                FROM
                  generate_series(
                    date_trunc('month', make_date($1::integer, $2::integer, 1)),
                    date_trunc('month', make_date($1::integer, $2::integer, 1)) + interval '1 month - 1 day',
                    '1 day'::interval
                  ) AS d(date)
                LEFT JOIN (
                  SELECT
                    rp.punch_time::date AS date,
                    COUNT(*) AS punch_count
                  FROM raw_punches rp
                  WHERE
                    lower(TRIM(BOTH FROM replace(rp.employee_name, ' ', ''))) IN (
                      lower(TRIM(BOTH FROM replace(e.first_name || ' ' || e.last_name, ' ', ''))),
                      lower(TRIM(BOTH FROM replace(e.last_name || ' ' || e.first_name, ' ', ''))),
                      lower(TRIM(BOTH FROM replace(e.first_name || e.last_name, ' ', ''))),
                      lower(TRIM(BOTH FROM replace(e.last_name || e.first_name, ' ', '')))
                    )
                    AND EXTRACT(YEAR FROM rp.punch_time) = $1
                    AND EXTRACT(MONTH FROM rp.punch_time) = $2
                  GROUP BY rp.punch_time::date
                ) dp ON d.date = dp.date
                LEFT JOIN attendance_overrides ao ON ao.employee_id = e.id AND ao.date = d.date
                WHERE EXISTS (
                  SELECT 1 FROM timetable_intervals ti
                  JOIN employee_timetables et ON ti.timetable_id = et.timetable_id
                  WHERE et.employee_id = e.id
                    AND (
                      EXTRACT(ISODOW FROM d.date) = ti.weekday
                      OR (ti.weekday = 0 AND EXTRACT(ISODOW FROM d.date) = 7)
                    )
                    AND d.date BETWEEN COALESCE(et.effective_from, '1900-01-01')
                    AND COALESCE(et.effective_to, '2100-12-31')
                )
              ) daily_records
              WHERE status = 'Absent'
            ) AS absence_days,
            -- Calculate pending days
            (
              SELECT COUNT(*)
              FROM (
                SELECT
                  d.date,
                  CASE
                    -- Treated pending cases (stored in details field)
                    WHEN ao.override_type = 'status_override' AND ao.details->>'pending_treatment' = 'full_day' THEN 'Present'
                    WHEN ao.override_type = 'status_override' AND ao.details->>'pending_treatment' = 'half_day' THEN 'Present'
                    WHEN ao.override_type = 'status_override' AND ao.details->>'pending_treatment' = 'refuse' THEN 'Absent'
                    -- Single punch cases go to Pending (if not treated)
                    WHEN dp.punch_count = 1 AND (ao.override_type IS NULL OR (ao.override_type = 'status_override' AND ao.details->>'pending_treatment' IS NULL)) THEN 'Pending'
                    -- Other overrides
                    WHEN ao.override_type IS NOT NULL THEN 'Present'
                    -- Complete attendance (2+ punches)
                    WHEN dp.punch_count >= 2 THEN 'Present'
                    ELSE 'Absent'
                  END AS status
                FROM
                  generate_series(
                    date_trunc('month', make_date($1::integer, $2::integer, 1)),
                    date_trunc('month', make_date($1::integer, $2::integer, 1)) + interval '1 month - 1 day',
                    '1 day'::interval
                  ) AS d(date)
                LEFT JOIN (
                  SELECT
                    rp.punch_time::date AS date,
                    COUNT(*) AS punch_count
                  FROM raw_punches rp
                  WHERE
                    lower(TRIM(BOTH FROM replace(rp.employee_name, ' ', ''))) IN (
                      lower(TRIM(BOTH FROM replace(e.first_name || ' ' || e.last_name, ' ', ''))),
                      lower(TRIM(BOTH FROM replace(e.last_name || ' ' || e.first_name, ' ', ''))),
                      lower(TRIM(BOTH FROM replace(e.first_name || e.last_name, ' ', ''))),
                      lower(TRIM(BOTH FROM replace(e.last_name || e.first_name, ' ', '')))
                    )
                    AND EXTRACT(YEAR FROM rp.punch_time) = $1
                    AND EXTRACT(MONTH FROM rp.punch_time) = $2
                  GROUP BY rp.punch_time::date
                ) dp ON d.date = dp.date
                LEFT JOIN attendance_overrides ao ON ao.employee_id = e.id AND ao.date = d.date
                WHERE EXISTS (
                  SELECT 1 FROM timetable_intervals ti
                  JOIN employee_timetables et ON ti.timetable_id = et.timetable_id
                  WHERE et.employee_id = e.id
                    AND (
                      EXTRACT(ISODOW FROM d.date) = ti.weekday
                      OR (ti.weekday = 0 AND EXTRACT(ISODOW FROM d.date) = 7)
                    )
                    AND d.date BETWEEN COALESCE(et.effective_from, '1900-01-01')
                    AND COALESCE(et.effective_to, '2100-12-31')
                )
              ) daily_records
              WHERE status = 'Pending'
            ) AS pending_days,
            -- Calculate late minutes (EXACT same as attendance-routes.js)
            (
              SELECT SUM(late_minutes)
              FROM (
                SELECT
                  d.date,
                  dp.punch_count,
                  (ao.override_type IS NOT NULL) AS is_overridden,
                  CASE
                    WHEN dp.entry_time_ts IS NOT NULL AND jsonb_array_length(si.intervals) > 0 THEN
                      GREATEST(0,
                        EXTRACT(EPOCH FROM ((dp.entry_time_ts - (si.intervals->0->>'start_time')::time)))/60 - ${latenessGrace}
                      )::integer
                    ELSE 0
                  END AS late_minutes
                FROM
                  generate_series(
                    date_trunc('month', make_date($1::integer, $2::integer, 1)),
                    date_trunc('month', make_date($1::integer, $2::integer, 1)) + interval '1 month - 1 day',
                    '1 day'::interval
                  ) AS d(date)
                JOIN (
                  SELECT
                    sd.date,
                    sd.day_of_week,
                    jsonb_agg(
                      jsonb_build_object(
                        'start_time', ti.start_time::text,
                        'end_time', ti.end_time::text,
                        'break_minutes', ti.break_minutes
                      ) ORDER BY ti.start_time
                    ) AS intervals
                  FROM (
                    SELECT
                      d.date,
                      EXTRACT(DOW FROM d.date)::integer AS day_of_week
                    FROM
                      generate_series(
                        date_trunc('month', make_date($1::integer, $2::integer, 1)),
                        date_trunc('month', make_date($1::integer, $2::integer, 1)) + interval '1 month - 1 day',
                        '1 day'::interval
                      ) AS d(date)
                  ) sd
                  JOIN employee_timetables et ON et.employee_id = e.id
                    AND sd.date BETWEEN COALESCE(et.effective_from, '1900-01-01')
                    AND COALESCE(et.effective_to, '2100-12-31')
                  JOIN timetable_intervals ti ON ti.timetable_id = et.timetable_id
                    AND ti.weekday = sd.day_of_week
                  GROUP BY sd.date, sd.day_of_week
                ) si ON d.date = si.date
                LEFT JOIN (
                  SELECT
                    rp.punch_time::date AS date,
                    CASE
                      WHEN COUNT(*) = 1 THEN
                        CASE
                          WHEN EXTRACT(HOUR FROM MIN(rp.punch_time)) < 12 THEN MIN(rp.punch_time)::time
                          ELSE NULL
                        END
                      ELSE MIN(rp.punch_time)::time
                    END AS entry_time_ts,
                    COUNT(*) AS punch_count
                  FROM raw_punches rp
                  WHERE
                    lower(TRIM(BOTH FROM replace(rp.employee_name, ' ', ''))) IN (
                      lower(TRIM(BOTH FROM replace(e.first_name || ' ' || e.last_name, ' ', ''))),
                      lower(TRIM(BOTH FROM replace(e.last_name || ' ' || e.first_name, ' ', ''))),
                      lower(TRIM(BOTH FROM replace(e.first_name || e.last_name, ' ', ''))),
                      lower(TRIM(BOTH FROM replace(e.last_name || e.first_name, ' ', '')))
                    )
                    AND EXTRACT(YEAR FROM rp.punch_time) = $1
                    AND EXTRACT(MONTH FROM rp.punch_time) = $2
                  GROUP BY rp.punch_time::date
                ) dp ON d.date = dp.date
                LEFT JOIN attendance_overrides ao ON ao.employee_id = e.id AND ao.date = d.date
              ) late_calc
              WHERE punch_count >= 1 AND NOT is_overridden
            ) AS late_minutes,
            -- Calculate early minutes (EXACT same as attendance-routes.js)
            (
              SELECT SUM(early_minutes)
              FROM (
                SELECT
                  d.date,
                  dp.punch_count,
                  (ao.override_type IS NOT NULL) AS is_overridden,
                  CASE
                    WHEN dp.exit_time_ts IS NOT NULL AND jsonb_array_length(si.intervals) > 0 THEN
                      GREATEST(0,
                        EXTRACT(EPOCH FROM (((si.intervals->-1->>'end_time')::time - dp.exit_time_ts)))/60 - ${earlyGrace}
                      )::integer
                    ELSE 0
                  END AS early_minutes
                FROM
                  generate_series(
                    date_trunc('month', make_date($1::integer, $2::integer, 1)),
                    date_trunc('month', make_date($1::integer, $2::integer, 1)) + interval '1 month - 1 day',
                    '1 day'::interval
                  ) AS d(date)
                JOIN (
                  SELECT
                    sd.date,
                    sd.day_of_week,
                    jsonb_agg(
                      jsonb_build_object(
                        'start_time', ti.start_time::text,
                        'end_time', ti.end_time::text,
                        'break_minutes', ti.break_minutes
                      ) ORDER BY ti.start_time
                    ) AS intervals
                  FROM (
                    SELECT
                      d.date,
                      EXTRACT(DOW FROM d.date)::integer AS day_of_week
                    FROM
                      generate_series(
                        date_trunc('month', make_date($1::integer, $2::integer, 1)),
                        date_trunc('month', make_date($1::integer, $2::integer, 1)) + interval '1 month - 1 day',
                        '1 day'::interval
                      ) AS d(date)
                  ) sd
                  JOIN employee_timetables et ON et.employee_id = e.id
                    AND sd.date BETWEEN COALESCE(et.effective_from, '1900-01-01')
                    AND COALESCE(et.effective_to, '2100-12-31')
                  JOIN timetable_intervals ti ON ti.timetable_id = et.timetable_id
                    AND ti.weekday = sd.day_of_week
                  GROUP BY sd.date, sd.day_of_week
                ) si ON d.date = si.date
                LEFT JOIN (
                  SELECT
                    rp.punch_time::date AS date,
                    CASE
                      WHEN COUNT(*) = 1 THEN
                        CASE
                          WHEN EXTRACT(HOUR FROM MIN(rp.punch_time)) >= 12 THEN MIN(rp.punch_time)::time
                          ELSE NULL
                        END
                      ELSE MAX(rp.punch_time)::time
                    END AS exit_time_ts,
                    COUNT(*) AS punch_count
                  FROM raw_punches rp
                  WHERE
                    lower(TRIM(BOTH FROM replace(rp.employee_name, ' ', ''))) IN (
                      lower(TRIM(BOTH FROM replace(e.first_name || ' ' || e.last_name, ' ', ''))),
                      lower(TRIM(BOTH FROM replace(e.last_name || ' ' || e.first_name, ' ', ''))),
                      lower(TRIM(BOTH FROM replace(e.first_name || e.last_name, ' ', ''))),
                      lower(TRIM(BOTH FROM replace(e.last_name || e.first_name, ' ', '')))
                    )
                    AND EXTRACT(YEAR FROM rp.punch_time) = $1
                    AND EXTRACT(MONTH FROM rp.punch_time) = $2
                  GROUP BY rp.punch_time::date
                ) dp ON d.date = dp.date
                LEFT JOIN attendance_overrides ao ON ao.employee_id = e.id AND ao.date = d.date
              ) early_calc
              WHERE punch_count >= 1 AND NOT is_overridden
            ) AS early_minutes
          FROM employees e
          WHERE e.id = $3
        )
        SELECT
          scheduled_days,
          worked_days,
          absence_days,
          pending_days,
          late_minutes,
          early_minutes
        FROM employee_stats
      `;

      const currentStatsResult = await pool.query(
        currentStatsQuery.replace(/\$\{latenessGrace\}/g, latenessGrace).replace(/\$\{earlyGrace\}/g, earlyGrace),
        [parseInt(year), parseInt(month), employeeId]
      );
      if (currentStatsResult.rows.length > 0) {
        currentAttendanceStats = currentStatsResult.rows[0];
        // Ensure all values are properly converted to integers/numbers
        currentAttendanceStats.scheduled_days = parseInt(currentAttendanceStats.scheduled_days || 0);
        currentAttendanceStats.worked_days = parseInt(currentAttendanceStats.worked_days || 0);
        currentAttendanceStats.absence_days = parseInt(currentAttendanceStats.absence_days || 0);
        currentAttendanceStats.pending_days = parseInt(currentAttendanceStats.pending_days || 0);
        currentAttendanceStats.late_minutes = parseInt(currentAttendanceStats.late_minutes || 0);
        currentAttendanceStats.early_minutes = parseInt(currentAttendanceStats.early_minutes || 0);
        currentAttendanceStats.late_hours = parseFloat((currentAttendanceStats.late_minutes / 60).toFixed(2));
        currentAttendanceStats.early_departure_hours = parseFloat((currentAttendanceStats.early_minutes / 60).toFixed(2));
      }
    } catch (attError) {
      console.warn('Could not fetch current attendance stats:', attError.message);
      // Continue without current stats
    }

    const response = {
      success: true,
      employee_id: employeeId,
      employee_name: algerianData.employee_name,
      position: algerianData.position,
      department_name: algerianData.department_name,
      month: parseInt(month),
      year: parseInt(year),
      currency: 'DA',

      // Both calculation methods
      algerian_method: algerianData,
      worked_days_method: workedDaysData,

      // Common data
      adjustments: adjustmentsResult.rows,
      payment_record: paymentResult.rows[0] || null,
      payment_status: paymentResult.rows[0]?.status || 'Not Paid',

      // Current attendance statistics (for comparison)
      current_attendance_stats: currentAttendanceStats
    };

    res.json(response);
  } catch (error) {
    console.error('Error fetching salary comparison:', error);
    console.error('Error stack:', error.stack);
    if (isAttendanceNotValidatedError(error)) {
      // Return a friendly payload so frontend can keep rendering
      return res.json({
        success: false,
        notValidated: true,
        message: error.message
      });
    }
    const { status, message } = mapSalaryErrorToHttp(error, 'Failed to fetch salary comparison');
    res.status(status).json({
      error: message,
      message: error.message || 'Unknown error occurred',
      details: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});

// Add raise to employee
app.post('/salaries/:employeeId/raises', verifyToken, async (req, res) => {
  try {
    const { employeeId } = req.params;
    const { raise_type, amount, effective_date, reason } = req.body;
    const userId = req.user.userId;

    const result = await pool.query(`
      INSERT INTO salary_raises 
      (employee_id, raise_type, amount, effective_date, reason, created_by_user_id)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `, [employeeId, raise_type, amount, effective_date, reason, userId]);

    res.json({
      success: true,
      raise: result.rows[0]
    });
  } catch (error) {
    console.error('Error adding raise:', error);
    res.status(500).json({ error: 'Failed to add raise' });
  }
});

// Mark salary as paid
app.post('/salaries/:employeeId/pay', verifyToken, async (req, res) => {
  try {
    const { employeeId } = req.params;
    const { month, year, calculation_method = 'algerian' } = req.body;
    const userId = req.user.userId;

    // Validate calculation method
    if (!['algerian', 'worked_days'].includes(calculation_method)) {
      return res.status(400).json({ error: 'Invalid calculation method. Must be "algerian" or "worked_days"' });
    }

    // Calculate the salary using the selected method
    let salaryData;
    if (calculation_method === 'worked_days') {
      salaryData = await calculateSalaryWorkedDays(pool, employeeId, month, year);
    } else {
      salaryData = await calculateSalaryAlgerian(pool, employeeId, month, year);
    }

    // Check if already paid
    const existingPayment = await pool.query(`
      SELECT id FROM salary_payments
      WHERE employee_id = $1 AND month = $2 AND year = $3
    `, [employeeId, month, year]);

    if (existingPayment.rows.length > 0) {
      return res.status(400).json({ error: 'Salary already marked as paid for this period' });
    }

    // Check if deductions exceed gross salary (net salary is 0 or negative)
    const grossSalary = parseFloat(salaryData.gross_salary || 0);
    const totalDeductions = parseFloat(salaryData.total_deductions || 0);
    const excessDeduction = totalDeductions > grossSalary ? totalDeductions - grossSalary : 0;

    // Calculate next month/year (for potential carry-forward)
    let nextMonth = parseInt(month) + 1;
    let nextYear = parseInt(year);
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear += 1;
    }

    // Insert payment record with calculation method
    const result = await pool.query(`
      INSERT INTO salary_payments 
      (employee_id, month, year, amount, currency, status, paid_by_user_id, paid_at, calculation_method)
      VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_TIMESTAMP, $8)
      RETURNING *
    `, [employeeId, month, year, salaryData.net_salary, 'DA', 'Paid', userId, calculation_method]);

    // If there's excess deduction, carry it forward to next month
    if (excessDeduction > 0) {
      try {

        // Create adjustment for next month dated 1st of next month
        const nextMonthDate = `${nextYear}-${String(nextMonth).padStart(2, '0')}-01`;

        // Check if employee_monthly_summaries record exists for next month
        const nextMonthRecord = await pool.query(`
          SELECT id, total_wage_changes FROM employee_monthly_summaries
          WHERE employee_id = $1 AND month = $2 AND year = $3
        `, [employeeId, nextMonth, nextYear]);

        const wageChangeAmount = -excessDeduction; // Negative for decrease

        if (nextMonthRecord.rows.length > 0) {
          // Update existing record
          const newTotalWageChanges = (parseFloat(nextMonthRecord.rows[0].total_wage_changes) || 0) + wageChangeAmount;

          await pool.query(`
            UPDATE employee_monthly_summaries 
            SET total_wage_changes = $1, updated_at = CURRENT_TIMESTAMP
            WHERE employee_id = $2 AND month = $3 AND year = $4
          `, [newTotalWageChanges, employeeId, nextMonth, nextYear]);
        } else {
          // Create new record with the carried forward deduction
          await pool.query(`
            INSERT INTO employee_monthly_summaries 
            (employee_id, month, year, total_wage_changes, is_validated, created_at, updated_at)
            VALUES ($1, $2, $3, $4, false, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          `, [employeeId, nextMonth, nextYear, wageChangeAmount]);
        }

        // Also create an adjustment record for tracking
        try {
          const adjustmentResult = await pool.query(`
            INSERT INTO employee_salary_adjustments
            (employee_id, adjustment_type, amount, effective_date, description, created_by_user_id)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING *
          `, [
            employeeId,
            'decrease',
            excessDeduction,
            nextMonthDate,
            `Carried forward excess deduction from ${month}/${year}. Gross: ${grossSalary.toFixed(2)} DA, Deductions: ${totalDeductions.toFixed(2)} DA, Excess: ${excessDeduction.toFixed(2)} DA`,
            userId
          ]);

          console.log(`Excess deduction of ${excessDeduction.toFixed(2)} DA carried forward to ${nextMonth}/${nextYear}`);
          console.log('Adjustment record created:', adjustmentResult.rows[0]?.id);
        } catch (adjError) {
          console.error('Error creating adjustment record (continuing anyway):', adjError);
          // Continue even if adjustment record creation fails
        }
      } catch (carryForwardError) {
        console.error('Error carrying forward excess deduction:', carryForwardError);
        // Don't fail the payment if carry-forward fails
      }
    }

    res.json({
      success: true,
      payment: result.rows[0],
      excessDeductionCarriedForward: excessDeduction > 0 ? excessDeduction : null,
      nextMonth: excessDeduction > 0 ? {
        month: nextMonth,
        year: nextYear
      } : null
    });
  } catch (error) {
    console.error('Error marking salary as paid:', error);
    res.status(500).json({ error: 'Failed to mark salary as paid' });
  }
});

// Export salaries to Excel
app.get('/salaries/export/excel', verifyToken, async (req, res) => {
  try {
    const { month = moment().month() + 1, year = moment().year() } = req.query;

    // Get all employees
    const employeesResult = await pool.query(`
      SELECT DISTINCT 
        e.id, 
        e.first_name, 
        e.last_name, 
        p.name as position_name, 
        d.name as department_name
      FROM employees e
      LEFT JOIN positions p ON e.position_id = p.id
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      ORDER BY e.first_name, e.last_name
    `);

    // Calculate salaries for all employees
    const salaries = [];
    for (const employee of employeesResult.rows) {
      try {
        const salaryData = await calculateSalaryAlgerian(pool, employee.id, parseInt(month), parseInt(year));
        salaries.push(salaryData);
      } catch (error) {
        // Only log unexpected errors, not validation failures
        if (!error.message.includes('Employee not found') && !error.message.includes('not validated')) {
          console.error(`Error calculating salary for employee ${employee.id}:`, error);
        }
      }
    }

    // Create Excel workbook
    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('Salary Report');

    // Add headers
    worksheet.columns = [
      { header: 'Employee Name', key: 'employee_name', width: 20 },
      { header: 'Position', key: 'position', width: 15 },
      { header: 'Department', key: 'department_name', width: 15 },
      { header: 'Base Salary (DA)', key: 'base_salary', width: 15 },
      { header: 'Worked Days', key: 'worked_days', width: 12 },
      { header: 'Absent Days', key: 'absent_days', width: 12 },
      { header: 'Late Hours', key: 'late_hours', width: 12 },
      { header: 'Overtime Hours', key: 'overtime_hours', width: 15 },
      { header: 'Overtime Amount (DA)', key: 'overtime_amount', width: 18 },
      { header: 'Raises (DA)', key: 'raise_amount', width: 12 },
      { header: 'Absence Deduction (DA)', key: 'absence_deduction', width: 20 },
      { header: 'Late Deduction (DA)', key: 'late_deduction', width: 18 },
      { header: 'Credit Deduction (DA)', key: 'credit_deduction', width: 18 },
      { header: 'Decrease Deduction (DA)', key: 'decrease_deduction', width: 20 },
      { header: 'Total Deductions (DA)', key: 'total_deductions', width: 20 },
      { header: 'Net Salary (DA)', key: 'net_salary', width: 15 }
    ];

    // Add data
    salaries.forEach(salary => {
      worksheet.addRow({
        employee_name: salary.employee_name,
        position: salary.position,
        department_name: salary.department_name,
        base_salary: salary.base_salary,
        worked_days: salary.worked_days,
        absent_days: salary.absent_days,
        late_hours: salary.late_hours?.toFixed(2) || '0.00',
        overtime_hours: salary.overtime_hours?.toFixed(2) || '0.00',
        overtime_amount: salary.overtime_amount?.toFixed(2) || '0.00',
        raise_amount: salary.raise_amount?.toFixed(2) || '0.00',
        absence_deduction: salary.absence_deduction?.toFixed(2) || '0.00',
        late_deduction: salary.late_deduction?.toFixed(2) || '0.00',
        credit_deduction: salary.credit_deduction?.toFixed(2) || '0.00',
        decrease_deduction: salary.decrease_deduction?.toFixed(2) || '0.00',
        total_deductions: salary.total_deductions?.toFixed(2) || '0.00',
        net_salary: salary.net_salary?.toFixed(2) || '0.00'
      });
    });

    // Style the header row
    worksheet.getRow(1).font = { bold: true };
    worksheet.getRow(1).fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: 'FFE0E0E0' }
    };

    // Set response headers
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=salary-report-${year}-${month}.xlsx`);

    // Write to response
    await workbook.xlsx.write(res);
    res.end();

  } catch (error) {
    console.error('Error exporting salaries:', error);
    res.status(500).json({ error: 'Failed to export salary report' });
  }
});

// Get departments for filter
app.get('/departments', verifyToken, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT id, name FROM departments ORDER BY name
    `);

    res.json({
      success: true,
      departments: result.rows
    });
  } catch (error) {
    console.error('Error fetching departments:', error);
    res.status(500).json({ error: 'Failed to fetch departments' });
  }
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Salary service running on port ${PORT}`);
});

module.exports = app;

