-- Database changes to support Pending status for partial attendance cases
-- This script adds minimal changes to support the new Pending functionality

-- 1. Add a pending_status column to track treatment of partial cases
-- We avoid changing the main status enum to minimize disruption
ALTER TABLE attendance_overrides 
ADD COLUMN IF NOT EXISTS pending_status VARCHAR(20) DEFAULT NULL;

-- Add check constraint for pending_status values
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'chk_pending_status' 
        AND table_name = 'attendance_overrides'
    ) THEN
        ALTER TABLE attendance_overrides 
        ADD CONSTRAINT chk_pending_status 
        CHECK (pending_status IS NULL OR pending_status IN ('pending', 'full_day', 'half_day', 'refused'));
    END IF;
END $$;

-- 2. Add index for performance on pending status queries
CREATE INDEX IF NOT EXISTS idx_attendance_overrides_pending_status 
ON attendance_overrides(employee_id, date, pending_status) 
WHERE pending_status IS NOT NULL;

-- 3. Create a view to help identify partial cases (employees with exactly 1 punch)
CREATE OR REPLACE VIEW partial_attendance_cases AS
SELECT 
    e.id as employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    rp.punch_date,
    rp.punch_count,
    CASE 
        WHEN ao.pending_status IS NOT NULL THEN ao.pending_status
        ELSE 'pending'
    END as current_status,
    ao.id as override_id
FROM employees e
JOIN (
    SELECT 
        lower(TRIM(BOTH FROM replace(employee_name, ' ', ''))) as normalized_name,
        DATE(punch_time) as punch_date,
        COUNT(*) as punch_count
    FROM raw_punches 
    GROUP BY lower(TRIM(BOTH FROM replace(employee_name, ' ', ''))), DATE(punch_time)
    HAVING COUNT(*) = 1  -- Only partial cases (single punch)
) rp ON (
    rp.normalized_name IN (
        lower(TRIM(BOTH FROM replace(e.first_name || ' ' || e.last_name, ' ', ''))),
        lower(TRIM(BOTH FROM replace(e.last_name || ' ' || e.first_name, ' ', ''))),
        lower(TRIM(BOTH FROM replace(e.first_name || e.last_name, ' ', ''))),
        lower(TRIM(BOTH FROM replace(e.last_name || e.first_name, ' ', '')))
    )
)
LEFT JOIN attendance_overrides ao ON ao.employee_id = e.id AND ao.date = rp.punch_date
WHERE 
    -- Only include cases that haven't been treated yet or are explicitly pending
    (ao.pending_status IS NULL OR ao.pending_status = 'pending')
    -- Exclude cases that already have other overrides (like justified absences)
    AND (ao.override_type IS NULL OR ao.override_type = 'pending_treatment');

-- 4. Add a function to get pending count for an employee in a specific month
CREATE OR REPLACE FUNCTION get_employee_pending_count(
    p_employee_id UUID,
    p_year INTEGER,
    p_month INTEGER
) RETURNS INTEGER AS $$
DECLARE
    pending_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO pending_count
    FROM partial_attendance_cases pac
    WHERE pac.employee_id = p_employee_id
    AND EXTRACT(YEAR FROM pac.punch_date) = p_year
    AND EXTRACT(MONTH FROM pac.punch_date) = p_month
    AND pac.current_status = 'pending';
    
    RETURN COALESCE(pending_count, 0);
END;
$$ LANGUAGE plpgsql;

-- 5. Add a function to check if month validation is allowed (no pending cases)
CREATE OR REPLACE FUNCTION can_validate_month(
    p_year INTEGER,
    p_month INTEGER,
    p_department_id UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    pending_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO pending_count
    FROM partial_attendance_cases pac
    JOIN employees e ON e.id = pac.employee_id
    WHERE EXTRACT(YEAR FROM pac.punch_date) = p_year
    AND EXTRACT(MONTH FROM pac.punch_date) = p_month
    AND pac.current_status = 'pending'
    AND (p_department_id IS NULL OR e.department_id = p_department_id);
    
    RETURN pending_count = 0;
END;
$$ LANGUAGE plpgsql;

-- 6. Create basic indexes for better performance (avoiding function-based indexes)
CREATE INDEX IF NOT EXISTS idx_raw_punches_employee_name 
ON raw_punches(employee_name);

CREATE INDEX IF NOT EXISTS idx_raw_punches_punch_time 
ON raw_punches(punch_time);

CREATE INDEX IF NOT EXISTS idx_employees_names 
ON employees(first_name, last_name);

-- 7. Add comments for documentation
COMMENT ON COLUMN attendance_overrides.pending_status IS 'Status for partial attendance cases: pending, full_day, half_day, refused';
COMMENT ON VIEW partial_attendance_cases IS 'View to identify employees with partial attendance (single punch) that need treatment';
COMMENT ON FUNCTION get_employee_pending_count IS 'Returns count of pending partial cases for an employee in a specific month';
COMMENT ON FUNCTION can_validate_month IS 'Checks if month validation is allowed (returns false if any pending cases exist)';

