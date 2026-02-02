const express = require('express');
const { Pool } = require('pg');
const moment = require('moment-timezone');

// JWT verification middleware (will be injected)
let verifyToken;

const setAuthMiddleware = (authMiddleware) => {
  verifyToken = authMiddleware;
};

const initializeRoutes = (dbPool) => {
  const router = express.Router();
  const pool = dbPool;

  // ============================================================================
  // EXPORT ROUTES
  // ============================================================================

  // Export attendance data
  router.get('/export', verifyToken, async (req, res) => {
    try {
      const { 
        format = 'csv',
        year, 
        month, 
        department, 
        status, 
        search,
        includeValidation = 'true',
        includeSource = 'true'
      } = req.query;

      // Build the query to get export data
      let whereConditions = [];
      let queryParams = [];
      let paramIndex = 1;

      if (year) {
        whereConditions.push(`cms.year = $${paramIndex}`);
        queryParams.push(parseInt(year));
        paramIndex++;
      }

      if (month) {
        whereConditions.push(`cms.month = $${paramIndex}`);
        queryParams.push(parseInt(month));
        paramIndex++;
      }

      if (department) {
        whereConditions.push(`ed.department_id = $${paramIndex}`);
        queryParams.push(department);
        paramIndex++;
      }

      if (status) {
        if (status === 'Validated') {
          whereConditions.push(`cms.is_validated = true`);
        } else if (status === 'Calculated') {
          whereConditions.push(`cms.is_validated = false`);
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
        SELECT 
          e.first_name || ' ' || e.last_name AS employee_name,
          d.name AS department_name,
          p.name AS position_name,
          cms.year,
          cms.month,
          -- Calculate scheduled days
          (SELECT COUNT(DISTINCT generate_series(
            date_trunc('month', make_date(cms.year, cms.month, 1)), 
            date_trunc('month', make_date(cms.year, cms.month, 1)) + interval '1 month - 1 day',
            '1 day'::interval
          )::date) 
          FROM timetable_intervals ti
          JOIN employee_timetables et ON ti.timetable_id = et.timetable_id
          WHERE et.employee_id = cms.employee_id
            AND EXTRACT(DOW FROM generate_series) = ti.weekday
            AND generate_series::date BETWEEN COALESCE(et.effective_from, '1900-01-01') 
            AND COALESCE(et.effective_to, '2100-12-31')
          ) AS scheduled_days,
          cms.total_worked_days AS worked_days,
          cms.absence_days,
          ROUND(cms.late_hours * 60) AS late_minutes,
          ROUND(cms.early_departure_hours * 60) AS early_departure_minutes,
          cms.overtime_hours,
          cms.wage_changes,
          ${includeValidation === 'true' ? "CASE WHEN cms.is_validated THEN 'Validated' ELSE 'Calculated' END AS validation_status," : ''}
          ${includeSource === 'true' ? 'cms.data_source,' : ''}
          cms.validated_at,
          u.username AS validated_by
        FROM comprehensive_monthly_statistics cms
        JOIN employees e ON cms.employee_id = e.id
        LEFT JOIN employee_departments ed ON e.id = ed.employee_id  
        LEFT JOIN departments d ON ed.department_id = d.id
        LEFT JOIN positions p ON e.position_id = p.id
        LEFT JOIN users u ON cms.validated_by_user_id = u.id
        ${whereClause}
        ORDER BY d.name, e.last_name, e.first_name, cms.year DESC, cms.month DESC
      `;

      const result = await pool.query(query, queryParams);

      if (format === 'csv') {
        // Generate CSV
        const headers = [
          'Employee Name',
          'Department',
          'Position',
          'Year',
          'Month',
          'Scheduled Days',
          'Worked Days',
          'Absence Days',
          'Late Minutes',
          'Early Minutes',
          'Overtime Hours',
          'Wage Changes',
          ...(includeValidation === 'true' ? ['Validation Status'] : []),
          ...(includeSource === 'true' ? ['Data Source'] : []),
          'Validated At',
          'Validated By'
        ];

        const csvRows = [headers.join(',')];
        
        result.rows.forEach(row => {
          const rowData = [
            `"${row.employee_name}"`,
            `"${row.department_name || ''}"`,
            `"${row.position_name || ''}"`,
            row.year,
            row.month,
            row.scheduled_days || 0,
            row.worked_days || 0,
            row.absence_days || 0,
            row.late_minutes || 0,
            row.early_departure_minutes || 0,
            row.overtime_hours || 0,
            row.wage_changes || 0,
            ...(includeValidation === 'true' ? [`"${row.validation_status || 'Calculated'}"`] : []),
            ...(includeSource === 'true' ? [`"${row.data_source || 'calculated'}"`] : []),
            row.validated_at ? `"${moment(row.validated_at).format('YYYY-MM-DD HH:mm')}"` : '',
            `"${row.validated_by || ''}"`
          ];
          csvRows.push(rowData.join(','));
        });

        const csvContent = csvRows.join('\n');
        const filename = `attendance-export-${moment().format('YYYY-MM-DD-HHmm')}.csv`;

        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
        res.send(csvContent);

      } else if (format === 'xlsx') {
        // For XLSX, you would typically use a library like 'xlsx' or 'exceljs'
        // For now, we'll return JSON that can be processed client-side
        res.json({
          success: true,
          data: result.rows,
          headers: [
            'Employee Name',
            'Department', 
            'Position',
            'Year',
            'Month',
            'Scheduled Days',
            'Worked Days',
            'Absence Days',
            'Late Minutes',
            'Early Minutes',
            'Overtime Hours',
            'Wage Changes',
            ...(includeValidation === 'true' ? ['Validation Status'] : []),
            ...(includeSource === 'true' ? ['Data Source'] : []),
            'Validated At',
            'Validated By'
          ],
          filename: `attendance-export-${moment().format('YYYY-MM-DD-HHmm')}.xlsx`
        });
      } else {
        return res.status(400).json({ error: 'Invalid export format' });
      }

    } catch (error) {
      console.error('Export attendance data error:', error);
      res.status(500).json({ 
        error: 'Failed to export attendance data',
        details: error.message 
      });
    }
  });

  // ============================================================================
  // NAME MATCHING UTILITY ROUTES (using existing function)
  // ============================================================================

  // Match employee names from raw punches
  router.post('/match-employees', verifyToken, async (req, res) => {
    try {
      const { employee_names } = req.body;

      if (!employee_names || !Array.isArray(employee_names)) {
        return res.status(400).json({ error: 'employee_names array is required' });
      }

      const results = [];

      for (const name of employee_names) {
        // Use the existing name matching function
        const query = `
          SELECT 
            e.id,
            e.first_name,
            e.last_name,
            e.first_name || ' ' || e.last_name AS full_name,
            $1 AS raw_name
          FROM employees e
          WHERE ${await getEmployeeNameMatchCondition(name)}
          LIMIT 1
        `;

        const result = await pool.query(query, [name]);
        
        results.push({
          raw_name: name,
          matched: result.rows.length > 0,
          employee: result.rows[0] || null
        });
      }

      res.json({
        success: true,
        matches: results
      });

    } catch (error) {
      console.error('Match employees error:', error);
      res.status(500).json({ 
        error: 'Failed to match employee names',
        details: error.message 
      });
    }
  });

  // Helper function to get name matching condition
  async function getEmployeeNameMatchCondition(rawName) {
    // Implementation of the existing database function logic
    const cleanRawName = rawName.toLowerCase().trim().replace(/\s+/g, '');
    
    return `(
      LOWER(TRIM(REPLACE(e.first_name || ' ' || e.last_name, ' ', ''))) = '${cleanRawName}' OR
      LOWER(TRIM(REPLACE(e.last_name || ' ' || e.first_name, ' ', ''))) = '${cleanRawName}' OR
      LOWER(TRIM(REPLACE(e.first_name || e.last_name, ' ', ''))) = '${cleanRawName}' OR
      LOWER(TRIM(REPLACE(e.last_name || e.first_name, ' ', ''))) = '${cleanRawName}'
    )`;
  }

  // Process raw punches and match to employees
  router.post('/process-raw-punches', verifyToken, async (req, res) => {
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');

      const userId = req.user.userId;

      // Get unprocessed raw punches
      const rawPunchesQuery = `
        SELECT DISTINCT rp.employee_name
        FROM raw_punches rp
        LEFT JOIN attendance_punches ap ON rp.id = ap.upload_id
        WHERE ap.id IS NULL
      `;

      const rawResult = await pool.query(rawPunchesQuery);
      let processedCount = 0;
      let errorCount = 0;
      const errors = [];

      for (const row of rawResult.rows) {
        try {
          // Use the existing name matching function
          const matchQuery = `
            SELECT e.id
            FROM employees e
            WHERE (
              LOWER(TRIM(REPLACE($1, ' ', ''))) = LOWER(TRIM(REPLACE(e.first_name || ' ' || e.last_name, ' ', ''))) OR
              LOWER(TRIM(REPLACE($1, ' ', ''))) = LOWER(TRIM(REPLACE(e.last_name || ' ' || e.first_name, ' ', ''))) OR
              LOWER(TRIM(REPLACE($1, ' ', ''))) = LOWER(TRIM(REPLACE(e.first_name || e.last_name, ' ', ''))) OR
              LOWER(TRIM(REPLACE($1, ' ', ''))) = LOWER(TRIM(REPLACE(e.last_name || e.first_name, ' ', '')))
            )
            LIMIT 1
          `;

          const matchResult = await client.query(matchQuery, [row.employee_name]);

          if (matchResult.rows.length > 0) {
            const employeeId = matchResult.rows[0].id;

            // Insert processed punches
            await client.query(`
              INSERT INTO attendance_punches (employee_id, punch_time, source, raw_employee_name)
              SELECT $1, rp.punch_time, 'processed_from_raw', rp.employee_name
              FROM raw_punches rp
              WHERE rp.employee_name = $2
                AND NOT EXISTS (
                  SELECT 1 FROM attendance_punches ap 
                  WHERE ap.employee_id = $1 
                    AND ap.punch_time = rp.punch_time
                    AND ap.raw_employee_name = rp.employee_name
                )
            `, [employeeId, row.employee_name]);

            processedCount++;
          } else {
            errors.push(`No employee match found for: ${row.employee_name}`);
            errorCount++;
          }
        } catch (error) {
          errors.push(`Error processing ${row.employee_name}: ${error.message}`);
          errorCount++;
        }
      }

      await client.query('COMMIT');

      res.json({
        success: true,
        message: `Raw punches processed: ${processedCount} successful, ${errorCount} errors`,
        results: {
          processed: processedCount,
          errors: errorCount,
          error_details: errors
        }
      });

    } catch (error) {
      await client.query('ROLLBACK');
      console.error('Process raw punches error:', error);
      res.status(500).json({ 
        error: 'Failed to process raw punches',
        details: error.message 
      });
    } finally {
      client.release();
    }
  });

  return router;
};

module.exports = {
  initializeRoutes,
  setAuthMiddleware
};