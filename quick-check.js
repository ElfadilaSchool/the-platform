/**
 * Quick System Check - Run this to verify everything is ready
 */
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/hr_operations'
});

async function quickCheck() {
  console.log('\n🔍 CHECKING AUTO-SUBSTITUTION SYSTEM\n');
  console.log('='.repeat(60));

  try {
    // 1. Check teachers
    const teachersResult = await pool.query(`
      SELECT COUNT(*) as count
      FROM employees e
      JOIN positions p ON e.position_id = p.id
      WHERE p.name ILIKE '%teacher%'
    `);
    const teacherCount = parseInt(teachersResult.rows[0].count);
    console.log(`\n1. Teachers in system: ${teacherCount}`);
    if (teacherCount === 0) {
      console.log('   ❌ NO TEACHERS FOUND! Add teachers first.');
    } else if (teacherCount < 2) {
      console.log('   ⚠️  Only 1 teacher. Need at least 2 for substitution.');
    } else {
      console.log('   ✅ Good! Have multiple teachers.');
    }

    // 2. Check teachers with timetables
    const timetableResult = await pool.query(`
      SELECT 
        e.id,
        e.first_name || ' ' || e.last_name AS name,
        e.institution,
        e.education_level,
        t.name AS timetable,
        COUNT(ti.id) AS intervals
      FROM employees e
      JOIN positions p ON e.position_id = p.id
      LEFT JOIN employee_timetables et ON e.id = et.employee_id 
        AND et.effective_from <= CURRENT_DATE
        AND (et.effective_to IS NULL OR et.effective_to >= CURRENT_DATE)
      LEFT JOIN timetables t ON et.timetable_id = t.id
      LEFT JOIN timetable_intervals ti ON t.id = ti.timetable_id
      WHERE p.name ILIKE '%teacher%'
      GROUP BY e.id, e.first_name, e.last_name, e.institution, e.education_level, t.name
      LIMIT 5
    `);

    console.log(`\n2. Teachers with timetables:`);
    if (timetableResult.rows.length === 0) {
      console.log('   ❌ NO TIMETABLES ASSIGNED! Assign timetables first.');
    } else {
      timetableResult.rows.forEach(row => {
        const hasData = row.institution && row.education_level;
        const hasTimetable = row.timetable && parseInt(row.intervals) > 0;
        const status = hasData && hasTimetable ? '✅' : '⚠️';
        console.log(`   ${status} ${row.name}`);
        console.log(`      Institution: ${row.institution || 'MISSING'}`);
        console.log(`      Level: ${row.education_level || 'MISSING'}`);
        console.log(`      Timetable: ${row.timetable || 'NONE'} (${row.intervals} intervals)`);
      });
    }

    // 3. Check tables exist
    console.log(`\n3. Database tables:`);
    try {
      await pool.query('SELECT 1 FROM substitution_requests LIMIT 1');
      console.log('   ✅ substitution_requests exists');
    } catch (e) {
      console.log('   ❌ substitution_requests MISSING!');
    }

    try {
      await pool.query('SELECT 1 FROM substitution_invitations LIMIT 1');
      console.log('   ✅ substitution_invitations exists');
    } catch (e) {
      console.log('   ❌ substitution_invitations MISSING!');
    }

    try {
      await pool.query('SELECT 1 FROM overtime_requests LIMIT 1');
      console.log('   ✅ overtime_requests exists');
    } catch (e) {
      console.log('   ❌ overtime_requests MISSING!');
    }

    try {
      await pool.query('SELECT 1 FROM employee_overtime_hours LIMIT 1');
      console.log('   ✅ employee_overtime_hours exists');
    } catch (e) {
      console.log('   ❌ employee_overtime_hours MISSING!');
    }

    // 4. Check for any existing data
    const requestsResult = await pool.query('SELECT COUNT(*) as count FROM substitution_requests');
    const invitationsResult = await pool.query('SELECT COUNT(*) as count FROM substitution_invitations');
    
    console.log(`\n4. Existing data:`);
    console.log(`   Substitution Requests: ${requestsResult.rows[0].count}`);
    console.log(`   Invitations: ${invitationsResult.rows[0].count}`);

    // 5. Check pending exceptions
    const exceptionsResult = await pool.query(`
      SELECT 
        ae.id,
        ae.type,
        ae.status,
        ae.date,
        e.first_name || ' ' || e.last_name AS teacher,
        p.name AS position
      FROM attendance_exceptions ae
      JOIN employees e ON ae.employee_id = e.id
      LEFT JOIN positions p ON e.position_id = p.id
      WHERE ae.type IN ('LeaveRequest', 'HolidayAssignment')
        AND ae.status = 'Pending'
        AND p.name ILIKE '%teacher%'
      ORDER BY ae.created_at DESC
      LIMIT 3
    `);

    console.log(`\n5. Pending teacher leave/holiday requests: ${exceptionsResult.rows.length}`);
    if (exceptionsResult.rows.length > 0) {
      console.log('   💡 You can approve these to trigger auto-substitution:');
      exceptionsResult.rows.forEach(row => {
        console.log(`      - ${row.teacher}: ${row.type} on ${row.date}`);
      });
    }

    console.log('\n' + '='.repeat(60));
    console.log('\n📊 SYSTEM STATUS:\n');

    if (teacherCount < 2) {
      console.log('❌ NOT READY: Need at least 2 teachers');
    } else if (timetableResult.rows.filter(r => r.timetable).length === 0) {
      console.log('❌ NOT READY: Teachers need timetables assigned');
    } else if (timetableResult.rows.filter(r => !r.institution || !r.education_level).length > 0) {
      console.log('⚠️  PARTIALLY READY: Some teachers missing institution/level');
    } else {
      console.log('✅ READY TO TEST!');
      console.log('\nNext steps:');
      console.log('1. Create a leave request (or approve an existing one)');
      console.log('2. Watch logs: tail -f attendance-server.log | grep AUTO-SUB');
      console.log('3. Check for "Successfully created X invitation(s)"');
    }

    console.log('\n');

  } catch (error) {
    console.error('\n❌ ERROR:', error.message);
    console.error('\nCheck your database connection!');
  } finally {
    await pool.end();
  }
}

quickCheck();

