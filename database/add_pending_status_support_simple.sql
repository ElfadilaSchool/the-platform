-- Simple Database Migration for Pending Status Support
-- This version uses basic SQL syntax for maximum compatibility

-- 1. Add pending_status column
ALTER TABLE attendance_overrides 
ADD COLUMN IF NOT EXISTS pending_status VARCHAR(20) DEFAULT NULL;

-- 2. Add check constraint (using simpler approach)
ALTER TABLE attendance_overrides 
ADD CONSTRAINT chk_pending_status 
CHECK (pending_status IS NULL OR pending_status IN ('pending', 'full_day', 'half_day', 'refused'));

-- 3. Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_attendance_overrides_pending_status 
ON attendance_overrides(employee_id, date, pending_status);

CREATE INDEX IF NOT EXISTS idx_raw_punches_employee_name 
ON raw_punches(employee_name);

CREATE INDEX IF NOT EXISTS idx_raw_punches_punch_time 
ON raw_punches(punch_time);

CREATE INDEX IF NOT EXISTS idx_employees_names 
ON employees(first_name, last_name);

-- 4. Simple function to get pending count
CREATE OR REPLACE FUNCTION get_employee_pending_count(
    p_employee_id UUID,
    p_year INTEGER,
    p_month INTEGER
) RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM raw_punches rp
        JOIN employees e ON e.id = p_employee_id
        WHERE (
            lower(TRIM(replace(rp.employee_name, ' ', ''))) = lower(TRIM(replace(e.first_name || ' ' || e.last_name, ' ', ''))) OR
            lower(TRIM(replace(rp.employee_name, ' ', ''))) = lower(TRIM(replace(e.last_name || ' ' || e.first_name, ' ', '')))
        )
        AND EXTRACT(YEAR FROM rp.punch_time) = p_year
        AND EXTRACT(MONTH FROM rp.punch_time) = p_month
        AND DATE(rp.punch_time) IN (
            SELECT DATE(punch_time) 
            FROM raw_punches rp2 
            WHERE lower(TRIM(replace(rp2.employee_name, ' ', ''))) = lower(TRIM(replace(rp.employee_name, ' ', '')))
            AND DATE(rp2.punch_time) = DATE(rp.punch_time)
            GROUP BY DATE(punch_time)
            HAVING COUNT(*) = 1
        )
        AND NOT EXISTS (
            SELECT 1 FROM attendance_overrides ao 
            WHERE ao.employee_id = p_employee_id 
            AND ao.date = DATE(rp.punch_time)
            AND ao.pending_status IN ('full_day', 'half_day', 'refused')
        )
    );
END;
$$ LANGUAGE plpgsql;

-- 5. Function to check if month validation is allowed
CREATE OR REPLACE FUNCTION can_validate_month(
    p_year INTEGER,
    p_month INTEGER,
    p_department_id UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        SELECT CASE 
            WHEN COUNT(*) = 0 THEN TRUE 
            ELSE FALSE 
        END
        FROM employees e
        WHERE (p_department_id IS NULL OR e.department_id = p_department_id)
        AND get_employee_pending_count(e.id, p_year, p_month) > 0
    );
END;
$$ LANGUAGE plpgsql;

-- 6. Add comments
COMMENT ON COLUMN attendance_overrides.pending_status IS 'Status for partial attendance cases: pending, full_day, half_day, refused';
COMMENT ON FUNCTION get_employee_pending_count IS 'Returns count of pending partial cases for an employee in a specific month';
COMMENT ON FUNCTION can_validate_month IS 'Checks if month validation is allowed (returns false if any pending cases exist)';

-- Success message
SELECT 'Pending status support added successfully!' as result;
