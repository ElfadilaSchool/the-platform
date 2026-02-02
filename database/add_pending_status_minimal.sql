-- Minimal Database Migration for Pending Status Support
-- This version focuses on core functionality without complex indexes

-- 1. Add pending_status column to track treatment of partial cases
ALTER TABLE attendance_overrides 
ADD COLUMN IF NOT EXISTS pending_status VARCHAR(20) DEFAULT NULL;

-- 2. Add basic index for performance (no function-based indexes)
CREATE INDEX IF NOT EXISTS idx_attendance_overrides_pending 
ON attendance_overrides(employee_id, date) 
WHERE pending_status IS NOT NULL;

-- 3. Simple function to get pending count for an employee
CREATE OR REPLACE FUNCTION get_employee_pending_count(
    p_employee_id UUID,
    p_year INTEGER,
    p_month INTEGER
) RETURNS INTEGER AS $$
DECLARE
    pending_count INTEGER := 0;
    rec RECORD;
BEGIN
    -- Count days where employee has exactly 1 punch and no pending treatment
    FOR rec IN 
        SELECT DATE(rp.punch_time) as punch_date, COUNT(*) as punch_count
        FROM raw_punches rp
        JOIN employees e ON e.id = p_employee_id
        WHERE (
            -- Simple name matching (case insensitive)
            UPPER(REPLACE(rp.employee_name, ' ', '')) = UPPER(REPLACE(e.first_name || ' ' || e.last_name, ' ', '')) OR
            UPPER(REPLACE(rp.employee_name, ' ', '')) = UPPER(REPLACE(e.last_name || ' ' || e.first_name, ' ', ''))
        )
        AND EXTRACT(YEAR FROM rp.punch_time) = p_year
        AND EXTRACT(MONTH FROM rp.punch_time) = p_month
        GROUP BY DATE(rp.punch_time)
        HAVING COUNT(*) = 1
    LOOP
        -- Check if this date has been treated
        IF NOT EXISTS (
            SELECT 1 FROM attendance_overrides ao 
            WHERE ao.employee_id = p_employee_id 
            AND ao.date = rec.punch_date
            AND ao.pending_status IN ('full_day', 'half_day', 'refused')
        ) THEN
            pending_count := pending_count + 1;
        END IF;
    END LOOP;
    
    RETURN pending_count;
END;
$$ LANGUAGE plpgsql;

-- 4. Function to check if month validation is allowed
CREATE OR REPLACE FUNCTION can_validate_month(
    p_year INTEGER,
    p_month INTEGER,
    p_department_id UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    employee_rec RECORD;
    pending_count INTEGER;
BEGIN
    -- Check each employee for pending cases
    FOR employee_rec IN 
        SELECT e.id 
        FROM employees e
        WHERE (p_department_id IS NULL OR e.department_id = p_department_id)
    LOOP
        pending_count := get_employee_pending_count(employee_rec.id, p_year, p_month);
        IF pending_count > 0 THEN
            RETURN FALSE;
        END IF;
    END LOOP;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 5. Add constraint for valid pending_status values
DO $$ 
BEGIN
    -- Check if constraint already exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'chk_pending_status' 
        AND table_name = 'attendance_overrides'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE attendance_overrides 
        ADD CONSTRAINT chk_pending_status 
        CHECK (pending_status IS NULL OR pending_status IN ('pending', 'full_day', 'half_day', 'refused'));
    END IF;
END $$;

-- 6. Add helpful comments
COMMENT ON COLUMN attendance_overrides.pending_status IS 'Status for partial attendance cases: pending, full_day, half_day, refused';
COMMENT ON FUNCTION get_employee_pending_count(UUID, INTEGER, INTEGER) IS 'Returns count of pending partial cases for an employee in a specific month';
COMMENT ON FUNCTION can_validate_month(INTEGER, INTEGER, UUID) IS 'Checks if month validation is allowed (returns false if any pending cases exist)';

-- Success message
SELECT 'Pending status support added successfully! No complex indexes used.' as result;
