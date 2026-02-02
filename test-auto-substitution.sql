-- ===============================================
-- TEST SCRIPT: Verify Auto-Substitution Setup
-- ===============================================
-- Run this in your PostgreSQL database to check prerequisites

-- 1. Check if you have teachers in the system
SELECT 
    e.id,
    e.first_name || ' ' || e.last_name AS teacher_name,
    p.name AS position, 
    e.institution,
    e.education_level,
    e.status
FROM employees e
LEFT JOIN positions p ON e.position_id = p.id
WHERE p.name ILIKE '%teacher%'
ORDER BY e.first_name
LIMIT 10;

-- Expected: Should show at least 2-3 teachers with institution and education_level filled

-- 2. Check if teachers have timetables assigned
SELECT 
    e.first_name || ' ' || e.last_name AS teacher_name,
    t.name AS timetable_name,
    t.type,
    et.effective_from,
    et.effective_to,
    COUNT(ti.id) AS interval_count
FROM employees e
JOIN positions p ON e.position_id = p.id
LEFT JOIN employee_timetables et ON e.id = et.employee_id 
    AND et.effective_from <= CURRENT_DATE
    AND (et.effective_to IS NULL OR et.effective_to >= CURRENT_DATE)
LEFT JOIN timetables t ON et.timetable_id = t.id
LEFT JOIN timetable_intervals ti ON t.id = ti.timetable_id
WHERE p.name ILIKE '%teacher%'
GROUP BY e.id, e.first_name, e.last_name, t.name, t.type, et.effective_from, et.effective_to
ORDER BY e.first_name
LIMIT 10;

-- Expected: Teachers should have timetables with intervals

-- 3. Check substitution tables exist
SELECT COUNT(*) as request_count FROM substitution_requests;
SELECT COUNT(*) as invitation_count FROM substitution_invitations;
SELECT COUNT(*) as overtime_request_count FROM overtime_requests;

-- Expected: Tables exist (even if count is 0)

-- 4. Check for any existing exceptions from teachers
SELECT 
    ae.id,
    ae.type,
    ae.status,
    ae.date,
    e.first_name || ' ' || e.last_name AS teacher_name,
    p.name AS position
FROM attendance_exceptions ae
JOIN employees e ON ae.employee_id = e.id
LEFT JOIN positions p ON e.position_id = p.id
WHERE ae.type IN ('LeaveRequest', 'HolidayAssignment')
    AND ae.status = 'Pending'
ORDER BY ae.created_at DESC
LIMIT 5;

-- Expected: Shows any pending leave/holiday requests from teachers

-- ===============================================
-- READY TO TEST WHEN:
-- - At least 2 teachers exist
-- - Teachers have institution and education_level
-- - Teachers have timetables with intervals
-- - All tables exist
-- ===============================================

