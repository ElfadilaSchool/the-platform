-- ==========================================
-- CREATE TEST LEAVE REQUEST AND AUTO-APPROVE
-- This will trigger auto-substitution
-- ==========================================

-- Step 1: Get a teacher to create leave for
DO $$
DECLARE
    v_teacher_id UUID;
    v_teacher_name TEXT;
    v_user_id UUID;
    v_exception_id UUID;
    v_leave_date DATE := CURRENT_DATE + 1; -- Tomorrow
BEGIN
    -- Find a teacher with a timetable
    SELECT e.id, e.first_name || ' ' || e.last_name, e.user_id
    INTO v_teacher_id, v_teacher_name, v_user_id
    FROM employees e
    JOIN positions p ON e.position_id = p.id
    LEFT JOIN employee_timetables et ON e.id = et.employee_id
        AND et.effective_from <= CURRENT_DATE
        AND (et.effective_to IS NULL OR et.effective_to >= CURRENT_DATE)
    WHERE p.name ILIKE '%teacher%'
        AND et.id IS NOT NULL
    LIMIT 1;

    IF v_teacher_id IS NULL THEN
        RAISE NOTICE '❌ No teachers with timetables found! Cannot create test leave request.';
        RAISE NOTICE 'Please assign timetables to teachers first.';
        RETURN;
    END IF;

    RAISE NOTICE '✓ Found teacher: % (ID: %)', v_teacher_name, v_teacher_id;
    RAISE NOTICE '  Creating leave request for date: %', v_leave_date;

    -- Create a leave request exception
    INSERT INTO attendance_exceptions (
        employee_id,
        type,
        date,
        end_date,
        payload,
        submitted_by_user_id,
        status,
        created_at
    ) VALUES (
        v_teacher_id,
        'LeaveRequest',
        v_leave_date,
        v_leave_date,
        '{"leave_type": "annual", "reason": "Test leave for auto-substitution system"}',
        v_user_id,
        'Pending',
        CURRENT_TIMESTAMP
    )
    RETURNING id INTO v_exception_id;

    RAISE NOTICE '✓ Created exception ID: %', v_exception_id;
    RAISE NOTICE '';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'TEST LEAVE REQUEST CREATED!';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Exception ID: %', v_exception_id;
    RAISE NOTICE 'Teacher: %', v_teacher_name;
    RAISE NOTICE 'Date: %', v_leave_date;
    RAISE NOTICE 'Status: Pending';
    RAISE NOTICE '';
    RAISE NOTICE 'NEXT STEP:';
    RAISE NOTICE '1. Start your attendance-server if not running';
    RAISE NOTICE '2. Go to Exceptions page in the UI';
    RAISE NOTICE '3. Approve this exception';
    RAISE NOTICE '4. Watch console for "Successfully created X invitations"';
    RAISE NOTICE '5. Check substitution_invitations table';
    RAISE NOTICE '';
    RAISE NOTICE 'OR run: SELECT * FROM attendance_exceptions WHERE id = ''%'';', v_exception_id;
    RAISE NOTICE '================================================';

END $$;

-- Show the created exception
SELECT 
    ae.id,
    ae.type,
    ae.status,
    ae.date,
    e.first_name || ' ' || e.last_name as teacher,
    ae.created_at
FROM attendance_exceptions ae
JOIN employees e ON ae.employee_id = e.id
WHERE ae.type = 'LeaveRequest'
    AND ae.status = 'Pending'
ORDER BY ae.created_at DESC
LIMIT 1;

