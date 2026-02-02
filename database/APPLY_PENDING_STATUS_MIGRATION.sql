-- =====================================================
-- PENDING STATUS MIGRATION - APPLY THIS MANUALLY
-- =====================================================
-- This script adds the pending status functionality to your HR system
-- Run this in your PostgreSQL database to enable pending case management

-- 1. Add pending_status column to attendance_overrides table
DO $$ 
BEGIN
    -- Check if column already exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'attendance_overrides' 
        AND column_name = 'pending_status'
    ) THEN
        ALTER TABLE attendance_overrides 
        ADD COLUMN pending_status VARCHAR(20) DEFAULT NULL;
        
        RAISE NOTICE 'Added pending_status column to attendance_overrides table';
    ELSE
        RAISE NOTICE 'pending_status column already exists';
    END IF;
END $$;

-- 2. Add check constraint for valid pending_status values
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
        
        RAISE NOTICE 'Added check constraint for pending_status values';
    ELSE
        RAISE NOTICE 'pending_status check constraint already exists';
    END IF;
END $$;

-- 3. Add index for better performance
CREATE INDEX IF NOT EXISTS idx_attendance_overrides_pending 
ON attendance_overrides(employee_id, date) 
WHERE pending_status IS NOT NULL;

-- 4. Create helper function to get pending count for an employee
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

-- 5. Create helper function to check if month validation is allowed
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

-- 6. Add helpful comments
COMMENT ON COLUMN attendance_overrides.pending_status IS 'Status for partial attendance cases: pending, full_day, half_day, refused';
COMMENT ON FUNCTION get_employee_pending_count(UUID, INTEGER, INTEGER) IS 'Returns count of pending partial cases for an employee in a specific month';
COMMENT ON FUNCTION can_validate_month(INTEGER, INTEGER, UUID) IS 'Checks if month validation is allowed (returns false if any pending cases exist)';

-- 7. Test the migration
DO $$
DECLARE
    test_result BOOLEAN;
BEGIN
    -- Test if functions work
    SELECT can_validate_month(2024, 1) INTO test_result;
    RAISE NOTICE 'Migration completed successfully! Functions are working.';
    RAISE NOTICE 'You can now use the pending status functionality in your HR system.';
END $$;

-- Success message
SELECT 'PENDING STATUS MIGRATION COMPLETED SUCCESSFULLY!' as result;
SELECT 'Your HR system now supports pending case management.' as info;
SELECT 'Restart your attendance service to load the new functionality.' as next_step;
