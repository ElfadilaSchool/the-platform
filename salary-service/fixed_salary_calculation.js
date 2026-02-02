/**
 * Fixed Salary Calculation Logic for Algerian System
 * 
 * This module provides two salary calculation methods:
 * 1. Standard (Algerian) Method: Base salary - deductions
 * 2. Partial Month Method: Worked days × daily rate - deductions
 * 
 * Both methods now calculate attendance data from raw punches using the exact same logic as the attendance page,
 * ensuring consistency across the system. The employee_monthly_summaries table is only used for validation status.
 * 
 * Key functions:
 * - calculateSalaryAlgerian: Standard salary calculation with absence deductions
 * - calculateSalaryWorkedDays: Partial month calculation for new employees
 * - calculateAttendanceDataFromRaw: Calculate worked/absent days from raw_punches (SAME as attendance page)
 * - getSalaryParameters: Get configurable salary parameters
 */

// Helper function to get salary parameters
const getSalaryParameters = async (pool) => {
  try {
    const result = await pool.query(`
      SELECT parameter_name, parameter_value 
      FROM salary_parameters
    `);

    const params = {};
    result.rows.forEach(row => {
      params[row.parameter_name] = parseFloat(row.parameter_value);
    });

    // Set defaults if not found
    return {
      working_days_per_month: params.working_days_per_month || 22,
      overtime_multiplier: params.overtime_multiplier || 1.5,
      grace_minutes: params.grace_minutes || 15,
      currency_code: params.currency_code || 1 // 1=DA
    };
  } catch (error) {
    console.error('Error getting salary parameters:', error);
    return {
      working_days_per_month: 22,
      overtime_multiplier: 1.5,
      grace_minutes: 15,
      currency_code: 1
    };
  }
};

// Alternative salary calculation function using worked days method
const calculateSalaryWorkedDays = async (pool, employeeId, month, year) => {
  try {
    // Get salary parameters
    const params = await getSalaryParameters(pool);

    // Get employee and position details with latest salary info
    const employeeQuery = `
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
        e.id,
        e.first_name,
        e.last_name,
        p.name as position_name,
        COALESCE(comp.base_salary, ps.base_salary) AS base_salary,
        COALESCE(comp.hourly_rate, ps.hourly_rate) AS hourly_rate,
        COALESCE(comp.overtime_rate, ps.overtime_rate) AS overtime_rate,
        d.name as department_name
      FROM employees e
      JOIN positions p ON e.position_id = p.id
      LEFT JOIN comp ON comp.employee_id = e.id
      LEFT JOIN position_salaries ps ON p.id = ps.position_id AND ps.effective_date <= $2
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      WHERE e.id = $1
      ORDER BY ps.effective_date DESC NULLS LAST
      LIMIT 1
    `;

    const employeeResult = await pool.query(employeeQuery, [
      employeeId,
      `${year}-${month.toString().padStart(2, '0')}-01`
    ]);

    if (employeeResult.rows.length === 0) {
      throw new Error('Employee not found');
    }

    const employee = employeeResult.rows[0];

    // Check if validated and get validation metadata
    const validationCheck = await pool.query(`
      SELECT is_validated, validated_at, validated_by_user_id FROM employee_monthly_summaries 
      WHERE employee_id = $1 AND month = $2 AND year = $3
    `, [employeeId, month, year]);

    if (!validationCheck.rows[0] || validationCheck.rows[0].is_validated !== true) {
      throw new Error('Monthly attendance not validated. Please validate first.');
    }
    const validationMetadata = validationCheck.rows[0];

    // CALCULATE ATTENDANCE DATA FROM RAW PUNCHES (SAME AS ATTENDANCE PAGE)
    const attendanceData = await calculateAttendanceDataFromRaw(pool, employeeId, month, year);
    const workedDays = attendanceData.workedDays;
    const halfDays = attendanceData.halfDays;
    const absenceDays = attendanceData.absenceDays;
    const lateHours = attendanceData.lateHours;
    const earlyHours = attendanceData.earlyHours;
    const overtimeHours = attendanceData.overtimeHours;
    const wageChanges = attendanceData.wageChanges;

    // Calculate base salary components
    const baseSalary = parseFloat(employee.base_salary) || 0;

    // Calculate daily rate: Base Salary ÷ 22 (standard working days per month)
    const dailyRate = baseSalary / params.working_days_per_month;

    // Calculate hourly and overtime rates
    // If provided in database, use them; otherwise calculate from base salary
    const standardHoursPerDay = 8; // Standard working hours per day
    const monthlyHours = params.working_days_per_month * standardHoursPerDay; // 22 * 8 = 176 hours

    let hourlyRate = parseFloat(employee.hourly_rate);
    if (!hourlyRate || hourlyRate === 0) {
      // Calculate hourly rate from base salary: Base ÷ (22 days × 8 hours)
      hourlyRate = baseSalary / monthlyHours;
    }

    let overtimeRate = parseFloat(employee.overtime_rate);
    if (!overtimeRate || overtimeRate === 0) {
      // Calculate overtime rate: Hourly Rate × Overtime Multiplier (default 1.5)
      overtimeRate = hourlyRate * params.overtime_multiplier;
    }

    // Use overtime_rate for overtime calculations, hourly_rate for late/early deductions
    const overtimeHourRate = overtimeRate;

    // Use data from calculateAttendanceDataFromRaw (already calculated above)
    const fullDays = workedDays - halfDays; // Full days (excluding half days from worked days)

    // SPECIAL CASE: If employee worked 0 days, salary is 0 regardless of other factors
    if (workedDays === 0) {
      return {
        employee_id: employeeId,
        employee_name: `${employee.first_name} ${employee.last_name}`,
        position: employee.position_name,
        department_name: employee.department_name,
        month,
        year,
        currency: 'DA',

        // Base components
        base_salary: baseSalary,
        daily_rate: dailyRate,
        hourly_rate: hourlyRate,
        overtime_hour_rate: overtimeHourRate,

        // Attendance data
        worked_days: 0,
        absent_days: 0,

        // Time calculations
        overtime_hours: 0,
        late_hours: 0,
        early_departure_hours: 0,

        // All amounts are 0
        worked_days_salary: 0,
        overtime_amount: 0,
        raise_amount: 0,
        wage_changes: 0,

        // Deductions
        absence_deduction: 0,
        late_deduction: 0,
        early_departure_deduction: 0,
        credit_deduction: 0,
        decrease_deduction: 0,

        // Totals
        total_deductions: 0,
        gross_salary: 0,
        net_salary: 0,

        // Validation context
        validation_status: validationMetadata.is_validated ? 'Validated' : 'Calculated',
        validated_at: validationMetadata.validated_at,
        validated_by_user_id: validationMetadata.validated_by_user_id,

        // Method indicator
        calculation_method: 'worked_days',

        // Special flag
        zero_worked_days: true
      };
    }

    // Calculate salary: Full days at full rate + Half days at half rate
    // Formula: (workedDays - halfDays) * dailyRate + halfDays * 0.5 * dailyRate
    // Simplified: workedDays * dailyRate - halfDays * 0.5 * dailyRate
    const halfDayDeduction = halfDays * 0.5 * dailyRate;
    const workedDaysSalary = workedDays * dailyRate - halfDayDeduction;

    // Calculate overtime amount
    const overtimeAmount = overtimeHours * overtimeHourRate;

    // Calculate late deduction
    const lateDeduction = lateHours * overtimeHourRate;

    // Calculate early departure deduction
    const earlyDepartureDeduction = earlyHours * overtimeHourRate;

    // Wage changes (already from calculateAttendanceDataFromRaw)
    const wageChangesNet = wageChanges;

    // Apply worked days salary formula:
    // Total Salary (DA) = (Worked Days × Daily Rate) + (Overtime × Rate) + WageChanges
    //                   - (LateHours × Rate) - (EarlyHours × Rate)

    const totalSalary = workedDaysSalary + overtimeAmount + wageChangesNet
      - lateDeduction - earlyDepartureDeduction;

    // Ensure non-negative salary
    const netSalary = Math.max(0, totalSalary);

    return {
      employee_id: employeeId,
      employee_name: `${employee.first_name} ${employee.last_name}`,
      position: employee.position_name,
      department_name: employee.department_name,
      month,
      year,
      currency: 'DA',

      // Base components
      base_salary: baseSalary,
      daily_rate: dailyRate,
      hourly_rate: hourlyRate,
      overtime_hour_rate: overtimeHourRate,

      // Attendance data (calculated from raw punches)
      worked_days: workedDays,
      absent_days: absenceDays,
      half_days: halfDays,
      full_days: fullDays,
      late_days: undefined,
      total_scheduled_days: undefined,

      // Time calculations
      overtime_hours: overtimeHours,
      late_hours: lateHours,
      early_departure_hours: earlyHours,

      // Positive amounts
      worked_days_salary: workedDaysSalary, // NEW: salary from worked days only (with half-day deduction applied)
      overtime_amount: overtimeAmount,
      raise_amount: 0,
      wage_changes: wageChangesNet,

      // Deductions (no absence deduction in worked days method)
      absence_deduction: 0, // NEW: no absence deduction
      half_day_deduction: halfDayDeduction, // Deduction for half days (0.5 * daily rate per half day)
      late_deduction: lateDeduction,
      early_departure_deduction: earlyDepartureDeduction,
      credit_deduction: 0,
      decrease_deduction: 0,

      // Totals
      total_deductions: lateDeduction + earlyDepartureDeduction,
      gross_salary: workedDaysSalary + overtimeAmount + wageChangesNet,
      net_salary: netSalary,

      // Validation context
      validation_status: validationMetadata.is_validated ? 'Validated' : 'Calculated',
      validated_at: validationMetadata.validated_at,
      validated_by_user_id: validationMetadata.validated_by_user_id,

      // Method indicator
      calculation_method: 'worked_days',

      // Special flag
      zero_worked_days: false
    };
  } catch (error) {
    // Don't log expected validation errors (employee not found, attendance not validated)
    // These are handled gracefully by the calling code
    if (!error.message.includes('Employee not found') && !error.message.includes('not validated')) {
      console.error('Error calculating worked days salary:', error);
    }
    throw error;
  }
};

/**
 * Calculate attendance data from raw punches using EXACT same logic as attendance page
 * 
 * This function replicates the attendance validation logic to ensure salary calculations
 * use the same data as what's displayed on the attendance page.
 * 
 * @param {Pool} pool - Database connection pool
 * @param {string} employeeId - Employee UUID
 * @param {number} month - Month number (1-12)
 * @param {number} year - Year number
 * @returns {Object} Attendance data: workedDays, halfDays, absenceDays, lateHours, earlyHours, overtimeHours, wageChanges
 */
const calculateAttendanceDataFromRaw = async (pool, employeeId, month, year) => {
  try {
    // Get employee info for name matching with raw_punches
    const employeeResult = await pool.query('SELECT first_name, last_name FROM employees WHERE id = $1', [employeeId]);
    if (employeeResult.rows.length === 0) throw new Error('Employee not found');
    const employee = employeeResult.rows[0];

    // Get grace period settings from attendance_settings table
    const settingsResult = await pool.query(`
      SELECT grace_period_lateness_minutes, grace_period_early_departure_minutes
      FROM attendance_settings WHERE scope = 'global' ORDER BY created_at DESC LIMIT 1
    `);
    const settings = settingsResult.rows[0] || { grace_period_lateness_minutes: 15, grace_period_early_departure_minutes: 15 };
    const latenessGrace = settings.grace_period_lateness_minutes || 15;
    const earlyGrace = settings.grace_period_early_departure_minutes || 15;

    // Calculate late/early minutes from daily records
    const dailyQuery = `
      WITH month_days AS (
        SELECT generate_series(
          date_trunc('month', make_date($2::integer, $3::integer, 1))::date,
          (date_trunc('month', make_date($2::integer, $3::integer, 1)) + interval '1 month - 1 day')::date,
          '1 day'::interval
        )::date AS date
      ),
      scheduled_intervals AS (
        SELECT d.date, jsonb_agg(
          jsonb_build_object('start_time', ti.start_time::text, 'end_time', ti.end_time::text, 'break_minutes', ti.break_minutes)
          ORDER BY ti.start_time
        ) AS intervals
        FROM month_days d
        JOIN employee_timetables et ON et.employee_id = $1
          AND d.date BETWEEN COALESCE(et.effective_from, '1900-01-01') AND COALESCE(et.effective_to, '2100-12-31')
        JOIN timetable_intervals ti ON ti.timetable_id = et.timetable_id
          AND (EXTRACT(ISODOW FROM d.date) = ti.weekday OR (ti.weekday = 0 AND EXTRACT(ISODOW FROM d.date) = 7))
        GROUP BY d.date
      ),
      daily_punches AS (
        SELECT rp.punch_time::date AS date,
          COUNT(*) AS punch_count,
          CASE WHEN COUNT(*) = 1 THEN
            CASE WHEN EXTRACT(HOUR FROM MIN(rp.punch_time)) < 12 THEN MIN(rp.punch_time)::time ELSE NULL END
          ELSE MIN(rp.punch_time)::time END AS entry_time_ts,
          CASE WHEN COUNT(*) = 1 THEN
            CASE WHEN EXTRACT(HOUR FROM MIN(rp.punch_time)) >= 12 THEN MIN(rp.punch_time)::time ELSE NULL END
          ELSE MAX(rp.punch_time)::time END AS exit_time_ts
        FROM raw_punches rp
        WHERE lower(TRIM(BOTH FROM replace(rp.employee_name, ' ', ''))) IN (
          lower(TRIM(BOTH FROM replace($4 || ' ' || $5, ' ', ''))),
          lower(TRIM(BOTH FROM replace($5 || ' ' || $4, ' ', ''))),
          lower(TRIM(BOTH FROM replace($4 || $5, ' ', ''))),
          lower(TRIM(BOTH FROM replace($5 || $4, ' ', '')))
        ) AND EXTRACT(YEAR FROM rp.punch_time) = $2 AND EXTRACT(MONTH FROM rp.punch_time) = $3
        GROUP BY rp.punch_time::date
      )
      SELECT md.date, ao.override_type, COALESCE(dp.punch_count, 0) AS punch_count, si.intervals,
        CASE WHEN ao.override_type IS NOT NULL THEN 0
        WHEN dp.entry_time_ts IS NOT NULL AND si.intervals IS NOT NULL AND jsonb_array_length(si.intervals) > 0 THEN
          GREATEST(0, EXTRACT(EPOCH FROM ((dp.entry_time_ts - (si.intervals->0->>'start_time')::time)))/60 - ${latenessGrace})::integer
        ELSE 0 END AS late_minutes,
        CASE WHEN ao.override_type IS NOT NULL THEN 0
        WHEN dp.exit_time_ts IS NOT NULL AND si.intervals IS NOT NULL AND jsonb_array_length(si.intervals) > 0 THEN
          GREATEST(0, EXTRACT(EPOCH FROM (((si.intervals->-1->>'end_time')::time - dp.exit_time_ts)))/60 - ${earlyGrace})::integer
        ELSE 0 END AS early_minutes
      FROM month_days md
      LEFT JOIN scheduled_intervals si ON si.date = md.date
      LEFT JOIN daily_punches dp ON md.date = dp.date
      LEFT JOIN attendance_overrides ao ON ao.employee_id = $1 AND ao.date = md.date
      ORDER BY md.date
    `;
    const dailyResult = await pool.query(dailyQuery, [employeeId, parseInt(year), parseInt(month), employee.first_name, employee.last_name]);

    let totalLateMinutes = 0, totalEarlyMinutes = 0;
    dailyResult.rows.forEach(r => {
      if (!r.override_type && (r.punch_count || 0) >= 1) {
        totalLateMinutes += r.late_minutes || 0;
        totalEarlyMinutes += r.early_minutes || 0;
      }
    });

    // Calculate worked/absence/half days using EXACT same SQL logic as attendance validation
    // This ensures salary calculations match what's shown on the attendance page
    const countsQuery = `
      WITH employee_info AS (SELECT first_name, last_name FROM employees WHERE id = $1)
      SELECT
        (SELECT COUNT(*) FROM (
          SELECT d.date, CASE
            WHEN ao.override_type = 'status_override' AND ao.details->>'pending_treatment' = 'full_day' THEN 'Present'
            WHEN ao.override_type = 'status_override' AND ao.details->>'pending_treatment' = 'half_day' THEN 'Present'
            WHEN ao.override_type = 'status_override' AND ao.details->>'pending_treatment' = 'refuse' THEN 'Absent'
            WHEN dp.punch_count = 1 AND (ao.override_type IS NULL OR (ao.override_type = 'status_override' AND ao.details->>'pending_treatment' IS NULL)) THEN 'Pending'
            WHEN ao.override_type IS NOT NULL THEN 'Present'
            WHEN dp.punch_count >= 2 THEN 'Present'
            ELSE 'Absent'
          END AS status
          FROM generate_series(
            date_trunc('month', make_date($2::integer, $3::integer, 1))::date,
            (date_trunc('month', make_date($2::integer, $3::integer, 1)) + interval '1 month - 1 day')::date,
            '1 day'::interval
          ) AS d(date)
          LEFT JOIN (
            SELECT rp.punch_time::date AS date, COUNT(*) AS punch_count
            FROM raw_punches rp, employee_info ei
            WHERE lower(TRIM(BOTH FROM replace(rp.employee_name, ' ', ''))) IN (
              lower(TRIM(BOTH FROM replace(ei.first_name || ' ' || ei.last_name, ' ', ''))),
              lower(TRIM(BOTH FROM replace(ei.last_name || ' ' || ei.first_name, ' ', ''))),
              lower(TRIM(BOTH FROM replace(ei.first_name || ei.last_name, ' ', ''))),
              lower(TRIM(BOTH FROM replace(ei.last_name || ei.first_name, ' ', '')))
            ) AND EXTRACT(YEAR FROM rp.punch_time) = $2 AND EXTRACT(MONTH FROM rp.punch_time) = $3
            GROUP BY rp.punch_time::date
          ) dp ON d.date = dp.date
          LEFT JOIN attendance_overrides ao ON ao.employee_id = $1 AND ao.date = d.date
          WHERE EXISTS (SELECT 1 FROM timetable_intervals ti JOIN employee_timetables et ON ti.timetable_id = et.timetable_id
            WHERE et.employee_id = $1 AND (EXTRACT(ISODOW FROM d.date) = ti.weekday OR (ti.weekday = 0 AND EXTRACT(ISODOW FROM d.date) = 7))
            AND d.date BETWEEN COALESCE(et.effective_from, '1900-01-01') AND COALESCE(et.effective_to, '2100-12-31'))
        ) daily_records WHERE status = 'Present'
        ) AS worked_days,
        (SELECT COUNT(*) FROM (
          SELECT d.date FROM generate_series(
            date_trunc('month', make_date($2::integer, $3::integer, 1))::date,
            (date_trunc('month', make_date($2::integer, $3::integer, 1)) + interval '1 month - 1 day')::date,
            '1 day'::interval
          ) AS d(date)
          LEFT JOIN attendance_overrides ao ON ao.employee_id = $1 AND ao.date = d.date
          WHERE EXISTS (SELECT 1 FROM timetable_intervals ti JOIN employee_timetables et ON ti.timetable_id = et.timetable_id
            WHERE et.employee_id = $1 AND (EXTRACT(ISODOW FROM d.date) = ti.weekday OR (ti.weekday = 0 AND EXTRACT(ISODOW FROM d.date) = 7))
            AND d.date BETWEEN COALESCE(et.effective_from, '1900-01-01') AND COALESCE(et.effective_to, '2100-12-31'))
          AND ao.override_type = 'status_override' AND ao.details->>'pending_treatment' = 'half_day'
        ) half_day_records) AS half_days,
        (SELECT COUNT(*) FROM (
          SELECT d.date, CASE
            WHEN ao.override_type = 'status_override' AND ao.details->>'pending_treatment' = 'full_day' THEN 'Present'
            WHEN ao.override_type = 'status_override' AND ao.details->>'pending_treatment' = 'half_day' THEN 'Present'
            WHEN ao.override_type = 'status_override' AND ao.details->>'pending_treatment' = 'refuse' THEN 'Absent'
            WHEN dp.punch_count = 1 AND (ao.override_type IS NULL OR (ao.override_type = 'status_override' AND ao.details->>'pending_treatment' IS NULL)) THEN 'Pending'
            WHEN ao.override_type IS NOT NULL THEN 'Present'
            WHEN dp.punch_count >= 2 THEN 'Present'
            ELSE 'Absent'
          END AS status
          FROM generate_series(
            date_trunc('month', make_date($2::integer, $3::integer, 1))::date,
            (date_trunc('month', make_date($2::integer, $3::integer, 1)) + interval '1 month - 1 day')::date,
            '1 day'::interval
          ) AS d(date)
          LEFT JOIN (
            SELECT rp.punch_time::date AS date, COUNT(*) AS punch_count
            FROM raw_punches rp, employee_info ei
            WHERE lower(TRIM(BOTH FROM replace(rp.employee_name, ' ', ''))) IN (
              lower(TRIM(BOTH FROM replace(ei.first_name || ' ' || ei.last_name, ' ', ''))),
              lower(TRIM(BOTH FROM replace(ei.last_name || ' ' || ei.first_name, ' ', ''))),
              lower(TRIM(BOTH FROM replace(ei.first_name || ei.last_name, ' ', ''))),
              lower(TRIM(BOTH FROM replace(ei.last_name || ei.first_name, ' ', '')))
            ) AND EXTRACT(YEAR FROM rp.punch_time) = $2 AND EXTRACT(MONTH FROM rp.punch_time) = $3
            GROUP BY rp.punch_time::date
          ) dp ON d.date = dp.date
          LEFT JOIN attendance_overrides ao ON ao.employee_id = $1 AND ao.date = d.date
          WHERE EXISTS (SELECT 1 FROM timetable_intervals ti JOIN employee_timetables et ON ti.timetable_id = et.timetable_id
            WHERE et.employee_id = $1 AND (EXTRACT(ISODOW FROM d.date) = ti.weekday OR (ti.weekday = 0 AND EXTRACT(ISODOW FROM d.date) = 7))
            AND d.date BETWEEN COALESCE(et.effective_from, '1900-01-01') AND COALESCE(et.effective_to, '2100-12-31'))
        ) daily_records WHERE status = 'Absent'
        ) AS absence_days
    `;
    const countsRes = await pool.query(countsQuery, [employeeId, parseInt(year), parseInt(month)]);

    const workedDays = parseFloat(countsRes.rows[0]?.worked_days) || 0;
    const halfDays = parseFloat(countsRes.rows[0]?.half_days) || 0;
    const absenceDays = parseFloat(countsRes.rows[0]?.absence_days) || 0;
    const lateHours = totalLateMinutes / 60.0;
    const earlyHours = totalEarlyMinutes / 60.0;

    // Get overtime and wage changes
    const monthWindowQuery = `
      WITH month_window AS (SELECT make_date($2, $3, 1)::date AS start_date, (make_date($2, $3, 1) + interval '1 month - 1 day')::date AS end_date)
      SELECT
        (SELECT COALESCE(SUM(hours), 0) FROM employee_overtime_hours eoh, month_window mw
          WHERE eoh.employee_id = $1 AND eoh.date BETWEEN mw.start_date AND mw.end_date) AS overtime_hours,
        (SELECT COALESCE(SUM(CASE
          WHEN adjustment_type = 'decrease' THEN -amount WHEN adjustment_type = 'credit' THEN -amount
          WHEN adjustment_type = 'raise' THEN amount ELSE amount END), 0)
          FROM employee_salary_adjustments esa
          WHERE esa.employee_id = $1 AND EXTRACT(YEAR FROM esa.effective_date) = $2 AND EXTRACT(MONTH FROM esa.effective_date) = $3
        ) AS wage_changes
    `;
    const monthWindowRes = await pool.query(monthWindowQuery, [employeeId, parseInt(year), parseInt(month)]);
    const overtimeHours = parseFloat(monthWindowRes.rows[0]?.overtime_hours) || 0;
    const wageChanges = parseFloat(monthWindowRes.rows[0]?.wage_changes) || 0;

    return { workedDays, halfDays, absenceDays, lateHours, earlyHours, overtimeHours, wageChanges };
  } catch (error) {
    console.error('Error calculating attendance from raw punches:', error);
    throw error;
  }
};

// Main salary calculation function using Algerian formula
const calculateSalaryAlgerian = async (pool, employeeId, month, year) => {
  try {
    // Get salary parameters
    const params = await getSalaryParameters(pool);

    // Get employee and position details with latest salary info
    const employeeQuery = `
      WITH comp AS (
        SELECT escv.employee_id, escv.base_salary, escv.hourly_rate, escv.overtime_rate
        FROM employee_salary_calculation_view escv WHERE escv.employee_id = $1
      )
      SELECT e.id, e.first_name, e.last_name, p.name as position_name,
        COALESCE(comp.base_salary, ps.base_salary) AS base_salary,
        COALESCE(comp.hourly_rate, ps.hourly_rate) AS hourly_rate,
        COALESCE(comp.overtime_rate, ps.overtime_rate) AS overtime_rate,
        d.name as department_name
      FROM employees e
      JOIN positions p ON e.position_id = p.id
      LEFT JOIN comp ON comp.employee_id = e.id
      LEFT JOIN position_salaries ps ON p.id = ps.position_id AND ps.effective_date <= $2
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      WHERE e.id = $1 ORDER BY ps.effective_date DESC NULLS LAST LIMIT 1
    `;
    const employeeResult = await pool.query(employeeQuery, [employeeId, `${year}-${month.toString().padStart(2, '0')}-01`]);
    if (employeeResult.rows.length === 0) throw new Error('Employee not found');
    const employee = employeeResult.rows[0];

    // Check if validated and get validation metadata (don't use attendance data from this table)
    const validationCheck = await pool.query(`
      SELECT is_validated, validated_at, validated_by_user_id FROM employee_monthly_summaries 
      WHERE employee_id = $1 AND month = $2 AND year = $3
    `, [employeeId, month, year]);

    if (!validationCheck.rows[0] || validationCheck.rows[0].is_validated !== true) {
      throw new Error('Monthly attendance not validated. Please validate first.');
    }

    const validationMetadata = validationCheck.rows[0];

    // CALCULATE ATTENDANCE DATA FROM RAW PUNCHES (SAME AS ATTENDANCE PAGE)
    const attendanceData = await calculateAttendanceDataFromRaw(pool, employeeId, month, year);
    const workedDays = attendanceData.workedDays;
    const halfDays = attendanceData.halfDays;
    const absenceDays = attendanceData.absenceDays;
    const lateHours = attendanceData.lateHours;
    const earlyHours = attendanceData.earlyHours;
    const overtimeHours = attendanceData.overtimeHours;
    const wageChanges = attendanceData.wageChanges;

    // Calculate base salary components
    const baseSalary = parseFloat(employee.base_salary) || 0;

    // Calculate daily rate: Base Salary ÷ 22 (standard working days per month)
    const dailyRate = baseSalary / params.working_days_per_month;

    // Calculate hourly and overtime rates
    // If provided in database, use them; otherwise calculate from base salary
    const standardHoursPerDay = 8; // Standard working hours per day
    const monthlyHours = params.working_days_per_month * standardHoursPerDay; // 22 * 8 = 176 hours

    let hourlyRate = parseFloat(employee.hourly_rate);
    if (!hourlyRate || hourlyRate === 0) {
      // Calculate hourly rate from base salary: Base ÷ (22 days × 8 hours)
      hourlyRate = baseSalary / monthlyHours;
    }

    let overtimeRate = parseFloat(employee.overtime_rate);
    if (!overtimeRate || overtimeRate === 0) {
      // Calculate overtime rate: Hourly Rate × Overtime Multiplier (default 1.5)
      overtimeRate = hourlyRate * params.overtime_multiplier;
    }

    // Use overtime_rate for overtime calculations, hourly_rate for late/early deductions
    const overtimeHourRate = overtimeRate;

    // Use data from calculateAttendanceDataFromRaw (already calculated above)
    const fullDays = workedDays - halfDays;

    // SPECIAL CASE: If employee worked 0 days, salary is 0 regardless of other factors
    if (workedDays === 0) {
      return {
        employee_id: employeeId,
        employee_name: `${employee.first_name} ${employee.last_name}`,
        position: employee.position_name,
        department_name: employee.department_name,
        month,
        year,
        currency: 'DA',

        // Base components
        base_salary: baseSalary,
        daily_rate: dailyRate,
        hourly_rate: hourlyRate,
        overtime_hour_rate: overtimeHourRate,

        // Attendance data
        worked_days: 0,
        absent_days: 0,
        half_days: 0,
        full_days: 0,

        // Time calculations
        overtime_hours: 0,
        late_hours: 0,
        early_departure_hours: 0,

        // All amounts are 0
        overtime_amount: 0,
        raise_amount: 0,
        wage_changes: 0,

        // Deductions
        absence_deduction: 0,
        half_day_deduction: 0,
        late_deduction: 0,
        early_departure_deduction: 0,
        credit_deduction: 0,
        decrease_deduction: 0,

        // Totals
        total_deductions: 0,
        gross_salary: 0,
        net_salary: 0,

        // Validation context
        validation_status: validationMetadata.is_validated ? 'Validated' : 'Calculated',
        validated_at: validationMetadata.validated_at,
        validated_by_user_id: validationMetadata.validated_by_user_id,

        // Method indicator
        calculation_method: 'algerian',

        // Special flag
        zero_worked_days: true
      };
    }

    // Calculate overtime amount
    const overtimeAmount = overtimeHours * overtimeHourRate;

    // Calculate late deduction
    const lateDeduction = lateHours * overtimeHourRate;

    // Calculate early departure deduction
    const earlyDepartureDeduction = earlyHours * overtimeHourRate;

    // Calculate absence deduction
    const absenceDeduction = absenceDays * dailyRate;

    // Calculate half-day deduction (0.5 * daily rate per half day)
    const halfDayDeduction = halfDays * 0.5 * dailyRate;

    // Wage changes (already from calculateAttendanceDataFromRaw)
    const wageChangesNet = wageChanges;

    // Apply Algerian salary formula:
    // Total Salary (DA) = Base Salary + (Overtime × Rate) + WageChanges
    //                   - (AbsentDays × DailyRate) - (HalfDays × 0.5 × DailyRate)
    //                   - (LateHours × Rate) - (EarlyHours × Rate)

    const totalSalary = baseSalary + overtimeAmount + wageChangesNet
      - absenceDeduction - halfDayDeduction - lateDeduction - earlyDepartureDeduction;

    // Ensure non-negative salary
    const netSalary = Math.max(0, totalSalary);

    return {
      employee_id: employeeId,
      employee_name: `${employee.first_name} ${employee.last_name}`,
      position: employee.position_name,
      department_name: employee.department_name,
      month,
      year,
      currency: 'DA', // Algerian Dinar

      // Base components
      base_salary: baseSalary,
      daily_rate: dailyRate,
      hourly_rate: hourlyRate,
      overtime_hour_rate: overtimeHourRate,

      // Attendance data (calculated from raw punches)
      worked_days: workedDays,
      absent_days: absenceDays,
      half_days: halfDays,
      full_days: fullDays,
      late_days: undefined,
      total_scheduled_days: undefined,

      // Time calculations
      overtime_hours: overtimeHours,
      late_hours: lateHours,
      early_departure_hours: earlyHours,

      // Positive amounts
      overtime_amount: overtimeAmount,
      raise_amount: 0,
      wage_changes: wageChangesNet,

      // Deductions
      absence_deduction: absenceDeduction,
      half_day_deduction: halfDayDeduction,
      late_deduction: lateDeduction,
      early_departure_deduction: earlyDepartureDeduction,
      credit_deduction: 0,
      decrease_deduction: 0,

      // Totals
      total_deductions: absenceDeduction + halfDayDeduction + lateDeduction + earlyDepartureDeduction,
      gross_salary: baseSalary + overtimeAmount + wageChangesNet,
      net_salary: netSalary,

      // Validation context
      validation_status: validationMetadata.is_validated ? 'Validated' : 'Calculated',
      validated_at: validationMetadata.validated_at,
      validated_by_user_id: validationMetadata.validated_by_user_id,

      // Method indicator
      calculation_method: 'algerian',

      // Special flag
      zero_worked_days: false
    };
  } catch (error) {
    // Don't log expected validation errors (employee not found, attendance not validated)
    // These are handled gracefully by the calling code
    if (!error.message.includes('Employee not found') && !error.message.includes('not validated')) {
      console.error('Error calculating Algerian salary:', error);
    }
    throw error;
  }
};

module.exports = {
  calculateSalaryAlgerian,
  calculateSalaryWorkedDays,
  calculateAttendanceDataFromRaw,
  getSalaryParameters
};

