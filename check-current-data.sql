-- Check what data we currently have

-- 1. How many teachers?
SELECT 
    'Teachers in system' as check_type,
    COUNT(*) as count
FROM employees e
JOIN positions p ON e.position_id = p.id
WHERE p.name ILIKE '%teacher%';

-- 2. Teachers with timetables?
SELECT 
    'Teachers with timetables' as check_type,
    COUNT(DISTINCT e.id) as count
FROM employees e
JOIN positions p ON e.position_id = p.id
LEFT JOIN employee_timetables et ON e.id = et.employee_id 
    AND et.effective_from <= CURRENT_DATE
    AND (et.effective_to IS NULL OR et.effective_to >= CURRENT_DATE)
WHERE p.name ILIKE '%teacher%'
    AND et.id IS NOT NULL;

-- 3. Any pending leave requests from teachers?
SELECT 
    'Pending teacher leave requests' as check_type,
    COUNT(*) as count
FROM attendance_exceptions ae
JOIN employees e ON ae.employee_id = e.id
JOIN positions p ON e.position_id = p.id
WHERE ae.type IN ('LeaveRequest', 'HolidayAssignment')
    AND ae.status = 'Pending'
    AND p.name ILIKE '%teacher%';

-- 4. Any APPROVED leave requests from teachers?
SELECT 
    'Approved teacher leave requests' as check_type,
    COUNT(*) as count
FROM attendance_exceptions ae
JOIN employees e ON ae.employee_id = e.id
JOIN positions p ON e.position_id = p.id
WHERE ae.type IN ('LeaveRequest', 'HolidayAssignment')
    AND ae.status = 'Approved'
    AND p.name ILIKE '%teacher%';

-- 5. Current state of substitution tables
SELECT 'Substitution requests' as check_type, COUNT(*) as count FROM substitution_requests
UNION ALL
SELECT 'Substitution invitations' as check_type, COUNT(*) as count FROM substitution_invitations;

-- 6. Show any approved teacher exceptions (these should have triggered substitution)
SELECT 
    ae.id,
    ae.type,
    ae.status,
    ae.date,
    e.first_name || ' ' || e.last_name as teacher_name,
    ae.created_at,
    ae.reviewed_at
FROM attendance_exceptions ae
JOIN employees e ON ae.employee_id = e.id
JOIN positions p ON e.position_id = p.id
WHERE ae.type IN ('LeaveRequest', 'HolidayAssignment')
    AND ae.status = 'Approved'
    AND p.name ILIKE '%teacher%'
ORDER BY ae.reviewed_at DESC
LIMIT 5;

