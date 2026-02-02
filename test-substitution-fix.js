/**
 * Test script to verify the substitution system fixes
 * Tests the scenario: Admin User leave Oct 16-25, with teachers having partial schedules
 */

const { Pool } = require('pg');
const moment = require('moment-timezone');

// Database connection
const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'hr_operations',
  password: 'admin',
  port: 5432,
});

async function testSubstitutionFix() {
  console.log('🧪 Testing Substitution System Fixes\n');
  
  try {
    // 1. Check if we have the test data
    console.log('1️⃣ Checking test data...');
    
    // Check for Admin User
    const adminResult = await pool.query(`
      SELECT e.id, e.first_name, e.last_name, e.institution, e.education_level,
             p.name AS position_name
      FROM employees e
      LEFT JOIN positions p ON e.position_id = p.id
      WHERE e.first_name ILIKE '%admin%' AND e.last_name ILIKE '%user%'
    `);
    
    if (adminResult.rows.length === 0) {
      console.log('❌ Admin User not found. Please create test data first.');
      return;
    }
    
    const adminUser = adminResult.rows[0];
    console.log(`✅ Found Admin User: ${adminUser.first_name} ${adminUser.last_name}`);
    console.log(`   Position: ${adminUser.position_name}`);
    console.log(`   Institution: ${adminUser.institution}`);
    console.log(`   Level: ${adminUser.education_level}`);
    
    // Check for test teachers
    const teachersResult = await pool.query(`
      SELECT e.id, e.first_name, e.last_name, e.institution, e.education_level,
             p.name AS position_name
      FROM employees e
      LEFT JOIN positions p ON e.position_id = p.id
      WHERE (e.first_name ILIKE '%achouak%' OR e.first_name ILIKE '%asma%')
        AND p.name ILIKE '%teacher%'
    `);
    
    console.log(`✅ Found ${teachersResult.rows.length} test teachers:`);
    teachersResult.rows.forEach(teacher => {
      console.log(`   - ${teacher.first_name} ${teacher.last_name} (${teacher.institution}, ${teacher.education_level})`);
    });
    
    // 2. Check for existing leave request
    console.log('\n2️⃣ Checking for existing leave request...');
    
    const leaveResult = await pool.query(`
      SELECT id, employee_id, date, end_date, type, status, reason
      FROM attendance_exceptions
      WHERE employee_id = $1 
        AND type = 'LeaveRequest'
        AND date = '2025-10-16'
        AND end_date = '2025-10-25'
        AND status = 'approved'
      ORDER BY created_at DESC
      LIMIT 1
    `, [adminUser.id]);
    
    if (leaveResult.rows.length === 0) {
      console.log('❌ No approved leave request found for Oct 16-25, 2025');
      console.log('   Please create and approve a leave request first.');
      return;
    }
    
    const leaveRequest = leaveResult.rows[0];
    console.log(`✅ Found approved leave request: ${leaveRequest.id}`);
    console.log(`   Period: ${leaveRequest.date} to ${leaveRequest.end_date}`);
    console.log(`   Reason: ${leaveRequest.reason}`);
    
    // 3. Check existing substitution invitations
    console.log('\n3️⃣ Checking existing substitution invitations...');
    
    const invitationsResult = await pool.query(`
      SELECT si.id, si.date, si.start_time, si.end_time, si.total_minutes, si.status,
             e.first_name, e.last_name
      FROM substitution_invitations si
      JOIN employees e ON si.candidate_employee_id = e.id
      JOIN substitution_requests sr ON si.request_id = sr.id
      WHERE sr.absent_employee_id = $1
        AND si.date BETWEEN '2025-10-16' AND '2025-10-25'
      ORDER BY si.date, si.start_time
    `, [adminUser.id]);
    
    console.log(`Found ${invitationsResult.rows.length} existing invitations:`);
    invitationsResult.rows.forEach(inv => {
      console.log(`   📅 ${inv.date} ${inv.start_time}-${inv.end_time} → ${inv.first_name} ${inv.last_name} (${inv.status})`);
    });
    
    // 4. Test the auto-substitution matcher
    console.log('\n4️⃣ Testing auto-substitution matcher...');
    
    const AutoSubstitutionMatcher = require('./attendance-service/auto-substitution-matcher');
    const matcher = new AutoSubstitutionMatcher(pool);
    
    console.log('🔄 Triggering auto-substitution for the leave request...');
    const result = await matcher.generateSubstitutionInvitations(leaveRequest.id, leaveRequest);
    
    console.log('\n📊 Results:');
    console.log(`   Success: ${result.success}`);
    console.log(`   Message: ${result.message}`);
    if (result.invitationsCreated) {
      console.log(`   Invitations Created: ${result.invitationsCreated}`);
    }
    if (result.candidatesFound) {
      console.log(`   Candidates Found: ${result.candidatesFound}`);
    }
    
    // 5. Check updated invitations
    console.log('\n5️⃣ Checking updated invitations...');
    
    const updatedInvitationsResult = await pool.query(`
      SELECT si.id, si.date, si.start_time, si.end_time, si.total_minutes, si.status,
             e.first_name, e.last_name
      FROM substitution_invitations si
      JOIN employees e ON si.candidate_employee_id = e.id
      JOIN substitution_requests sr ON si.request_id = sr.id
      WHERE sr.absent_employee_id = $1
        AND si.date BETWEEN '2025-10-16' AND '2025-10-25'
      ORDER BY si.date, si.start_time
    `, [adminUser.id]);
    
    console.log(`Found ${updatedInvitationsResult.rows.length} total invitations:`);
    updatedInvitationsResult.rows.forEach(inv => {
      console.log(`   📅 ${inv.date} ${inv.start_time}-${inv.end_time} → ${inv.first_name} ${inv.last_name} (${inv.status})`);
    });
    
    // 6. Analyze the results
    console.log('\n6️⃣ Analysis:');
    
    const oct16Invitations = updatedInvitationsResult.rows.filter(inv => inv.date === '2025-10-16');
    const oct17Invitations = updatedInvitationsResult.rows.filter(inv => inv.date === '2025-10-17');
    const oct18Invitations = updatedInvitationsResult.rows.filter(inv => inv.date === '2025-10-18');
    const oct19Invitations = updatedInvitationsResult.rows.filter(inv => inv.date === '2025-10-19');
    const oct20Invitations = updatedInvitationsResult.rows.filter(inv => inv.date === '2025-10-20');
    
    console.log(`   Oct 16 invitations: ${oct16Invitations.length}`);
    console.log(`   Oct 17 invitations: ${oct17Invitations.length}`);
    console.log(`   Oct 18 invitations: ${oct18Invitations.length}`);
    console.log(`   Oct 19 invitations: ${oct19Invitations.length}`);
    console.log(`   Oct 20 invitations: ${oct20Invitations.length}`);
    
    // Check if we have invitations for the correct dates
    const hasCorrectDates = oct16Invitations.length > 0 || oct17Invitations.length > 0 || 
                           oct18Invitations.length > 0 || oct19Invitations.length > 0 || 
                           oct20Invitations.length > 0;
    
    if (hasCorrectDates) {
      console.log('✅ SUCCESS: Invitations are being created for the correct leave dates!');
    } else {
      console.log('❌ ISSUE: No invitations found for the leave period dates.');
    }
    
    // Check for partial coverage
    const partialCoverage = updatedInvitationsResult.rows.some(inv => {
      // Check if this is a partial slot (less than 8 hours)
      const hours = inv.total_minutes / 60;
      return hours < 8 && hours > 0;
    });
    
    if (partialCoverage) {
      console.log('✅ SUCCESS: Partial coverage is working - teachers with free intervals are being invited!');
    } else {
      console.log('ℹ️  INFO: No partial coverage detected (all slots are full day or no coverage)');
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error);
  } finally {
    await pool.end();
  }
}

// Run the test
testSubstitutionFix();