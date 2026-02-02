/**
 * Optimized Dashboard Routes for HR Operations Platform
 * Provides consolidated statistics for the HR dashboard
 */

const express = require('express');

let authMiddleware = null;

function setAuthMiddleware(middleware) {
  authMiddleware = middleware;
}

const initializeRoutes = (dbPool) => {
  const router = express.Router();
  const pool = dbPool;
  const verifyToken = authMiddleware;

  /**
   * GET /api/attendance/dashboard-stats
   * Get comprehensive dashboard statistics in a single optimized query
   * 
   * Query params:
   * - month: Month number (1-12), defaults to current month
   * - year: Year (YYYY), defaults to current year  
   * - department: Optional department filter UUID
   */
  router.get('/dashboard-stats', verifyToken, async (req, res) => {
    try {
      const { month, year, department } = req.query;
      const currentDate = new Date();
      const currentMonth = month ? parseInt(month) : (currentDate.getMonth() + 1);
      const currentYear = year ? parseInt(year) : currentDate.getFullYear();
      
      console.log(`📊 Dashboard Stats Request: month=${currentMonth}, year=${currentYear}, department=${department || 'all'}`);
      
      // 1. Get employee statistics with proper salary data (ALL EMPLOYEES, NOT FILTERED BY MONTH)
      const employeeStatsQuery = `
        SELECT 
          e.id,
          e.first_name,
          e.last_name,
          e.institution,
          e.education_level,
          e.created_at,
          p.name as position_name,
          COALESCE(s.amount, ps.base_salary, 0) as salary,
          COALESCE(ps.base_salary, 0) as base_salary,
          COALESCE(ps.hourly_rate, 0) as hourly_rate,
          COALESCE(ps.overtime_rate, 0) as overtime_rate,
          d.name as department_name,
          d.id as department_id
        FROM employees e
        LEFT JOIN positions p ON e.position_id = p.id
        LEFT JOIN position_salaries ps ON p.id = ps.position_id 
          AND ps.effective_date = (
            SELECT MAX(ps2.effective_date) 
            FROM position_salaries ps2 
            WHERE ps2.position_id = p.id 
            AND ps2.effective_date <= CURRENT_DATE
          )
        LEFT JOIN salaries s ON e.id = s.employee_id
          AND s.effective_date = (
            SELECT MAX(s2.effective_date)
            FROM salaries s2
            WHERE s2.employee_id = e.id
            AND s2.effective_date <= CURRENT_DATE
          )
        LEFT JOIN employee_departments ed ON e.id = ed.employee_id
        LEFT JOIN departments d ON ed.department_id = d.id
        ${department ? 'WHERE d.id = $1' : ''}
        ORDER BY e.first_name, e.last_name
      `;
      
      const employeeStatsParams = department ? [department] : [];
      const employeeStatsResult = await pool.query(employeeStatsQuery, employeeStatsParams);
      
      // 2. Get attendance statistics for the specified month/year
      const attendanceStatsQuery = `
        WITH employee_list AS (
          SELECT DISTINCT e.id as employee_id
          FROM employees e
          LEFT JOIN employee_departments ed ON e.id = ed.employee_id
          ${department ? 'WHERE ed.department_id = $3' : ''}
        ),
        scheduled_days AS (
          SELECT 
            el.employee_id,
            COUNT(DISTINCT gs.date) as scheduled_count
          FROM employee_list el
          CROSS JOIN generate_series(
            date_trunc('month', make_date($1::integer, $2::integer, 1))::date,
            (date_trunc('month', make_date($1::integer, $2::integer, 1)) + interval '1 month - 1 day')::date,
            '1 day'::interval
          ) AS gs(date)
          WHERE EXISTS (
            SELECT 1 FROM timetable_intervals ti
            JOIN employee_timetables et ON ti.timetable_id = et.timetable_id
            WHERE et.employee_id = el.employee_id
              AND (
                EXTRACT(ISODOW FROM gs.date) = ti.weekday
                OR (ti.weekday = 0 AND EXTRACT(ISODOW FROM gs.date) = 7)
              )
              AND gs.date BETWEEN COALESCE(et.effective_from, '1900-01-01')
              AND COALESCE(et.effective_to, '2100-12-31')
          )
          GROUP BY el.employee_id
        ),
        worked_days AS (
          SELECT
            el.employee_id,
            COUNT(DISTINCT CASE 
              WHEN dp.punch_count >= 2 THEN d.date
              WHEN ao.override_type = 'status_override' AND (ao.details->>'pending_treatment' = 'full_day' OR ao.details->>'pending_treatment' = 'half_day') THEN d.date
              WHEN ao.override_type IS NOT NULL AND ao.override_type != 'status_override' THEN d.date
              WHEN ao.override_type = 'status_override' AND ao.details->>'pending_treatment' IS NULL THEN d.date
            END) as present_days,
            COUNT(DISTINCT CASE 
              WHEN dp.punch_count = 1 AND (ao.override_type IS NULL OR (ao.override_type = 'status_override' AND ao.details->>'pending_treatment' IS NULL))
              THEN d.date 
            END) as pending_days
          FROM employee_list el
          CROSS JOIN generate_series(
            date_trunc('month', make_date($1::integer, $2::integer, 1))::date,
            (date_trunc('month', make_date($1::integer, $2::integer, 1)) + interval '1 month - 1 day')::date,
            '1 day'::interval
          ) AS d(date)
          LEFT JOIN (
            SELECT
              ap.employee_id,
              ap.punch_time::date AS date,
              COUNT(*) AS punch_count
            FROM attendance_punches ap
            WHERE EXTRACT(YEAR FROM ap.punch_time) = $1
              AND EXTRACT(MONTH FROM ap.punch_time) = $2
              AND ap.deleted_at IS NULL
            GROUP BY ap.employee_id, ap.punch_time::date
          ) dp ON el.employee_id = dp.employee_id AND d.date = dp.date
          LEFT JOIN attendance_overrides ao ON ao.employee_id = el.employee_id AND ao.date = d.date
          WHERE EXISTS (
            SELECT 1 FROM timetable_intervals ti
            JOIN employee_timetables et ON ti.timetable_id = et.timetable_id
            WHERE et.employee_id = el.employee_id
              AND (
                EXTRACT(ISODOW FROM d.date) = ti.weekday
                OR (ti.weekday = 0 AND EXTRACT(ISODOW FROM d.date) = 7)
              )
              AND d.date BETWEEN COALESCE(et.effective_from, '1900-01-01')
              AND COALESCE(et.effective_to, '2100-12-31')
          )
          GROUP BY el.employee_id
        ),
        validation_stats AS (
          SELECT
            el.employee_id,
            COALESCE(ems.is_validated, false) as is_validated
          FROM employee_list el
          LEFT JOIN employee_monthly_summaries ems 
            ON el.employee_id = ems.employee_id 
            AND ems.month = $2 
            AND ems.year = $1
        )
        SELECT 
          COUNT(DISTINCT el.employee_id) as total_employees,
          SUM(sd.scheduled_count) as total_scheduled_days,
          SUM(wd.present_days) as total_present_days,
          SUM(wd.pending_days) as total_pending_days,
          COUNT(DISTINCT CASE WHEN vs.is_validated THEN el.employee_id END) as validated_employees,
          COUNT(DISTINCT CASE WHEN NOT COALESCE(vs.is_validated, false) THEN el.employee_id END) as pending_validation_employees,
          COUNT(DISTINCT CASE WHEN wd.pending_days > 0 THEN el.employee_id END) as partial_pending_employees,
          CASE 
            WHEN SUM(sd.scheduled_count) > 0 
            THEN ROUND((SUM(wd.present_days)::numeric / SUM(sd.scheduled_count)::numeric * 100), 1)
            ELSE 0 
          END as attendance_rate
        FROM employee_list el
        LEFT JOIN scheduled_days sd ON el.employee_id = sd.employee_id
        LEFT JOIN worked_days wd ON el.employee_id = wd.employee_id
        LEFT JOIN validation_stats vs ON el.employee_id = vs.employee_id
      `;
      
      const attendanceStatsParams = department ? [currentYear, currentMonth, department] : [currentYear, currentMonth];
      const attendanceStatsResult = await pool.query(attendanceStatsQuery, attendanceStatsParams);
      const attendanceStats = attendanceStatsResult.rows[0] || {
        attendance_rate: 0,
        validated_employees: 0,
        pending_validation_employees: 0,
        partial_pending_employees: 0
      };
      
      // 3. Process employee data
      const employees = employeeStatsResult.rows.map(emp => ({
        ...emp,
        salary_amount: parseFloat(emp.salary || 0),
        base_salary: parseFloat(emp.base_salary || 0),
        has_salary_data: !!(emp.salary || emp.base_salary)
      }));
      
      // 4. Calculate aggregate statistics
      const totalEmployees = employees.length;
      const institutions = [...new Set(employees.map(e => e.institution).filter(Boolean))];
      const totalSalary = employees.reduce((sum, e) => sum + parseFloat(e.salary_amount || 0), 0);
      
      // Count employees added in the selected period
      let employeesThisPeriod = 0;
      if (month && year) {
        // Filter by specific month/year
        const periodStart = new Date(currentYear, currentMonth - 1, 1);
        const periodEnd = new Date(currentYear, currentMonth, 0);
        employeesThisPeriod = employees.filter(e => {
          const createdDate = new Date(e.created_at);
          return createdDate >= periodStart && createdDate <= periodEnd;
        }).length;
      } else if (year) {
        // Filter by entire year
        const yearStart = new Date(currentYear, 0, 1);
        const yearEnd = new Date(currentYear, 11, 31);
        employeesThisPeriod = employees.filter(e => {
          const createdDate = new Date(e.created_at);
          return createdDate >= yearStart && createdDate <= yearEnd;
        }).length;
      } else {
        // All time - count all employees
        employeesThisPeriod = employees.length;
      }
      
      console.log(`✅ Dashboard Stats: ${totalEmployees} employees, ${institutions.length} institutions, attendance rate: ${attendanceStats.attendance_rate}%`);
      
      res.json({
        success: true,
        data: {
          // Top Statistics Cards
          total_employees: totalEmployees,
          employees_added_this_month: employeesThisPeriod,
          institutions_count: institutions.length,
          total_salary: Math.round(totalSalary),
          attendance_rate: parseFloat(attendanceStats.attendance_rate || 0),
          
          // Attendance Validation Stats
          validated_records: parseInt(attendanceStats.validated_employees || 0),
          pending_validation: parseInt(attendanceStats.pending_validation_employees || 0),
          partial_pending: parseInt(attendanceStats.partial_pending_employees || 0),
          
          // Employee data for charts
          employees: employees,
          institutions: institutions,
          
          // Salary breakdown
          employees_with_salary: employees.filter(e => e.has_salary_data).length,
          employees_without_salary: employees.filter(e => !e.has_salary_data).length
        },
        period: {
          month: currentMonth,
          year: currentYear
        },
        filters: {
          department: department || null
        }
      });
      
    } catch (error) {
      console.error('❌ Dashboard stats error:', error);
      res.status(500).json({ 
        success: false,
        error: 'Failed to fetch dashboard statistics',
        details: error.message 
      });
    }
  });
  
  return router;
};

module.exports = {
  initializeRoutes,
  setAuthMiddleware
};

