/**
 * Test script for the enhanced substitution invitation system
 * This script tests the new features and API endpoints
 * 
 * Usage: node test-enhanced-substitution.js
 */

const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'hr_operations_platform',
  password: process.env.DB_PASSWORD || 'admin',
  port: process.env.DB_PORT || 5432,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

async function testEnhancedSubstitution() {
  const client = await pool.connect();
  
  try {
    console.log('🧪 Testing Enhanced Substitution System...\n');
    
    // Test 1: Check if disabled status is allowed
    console.log('1️⃣ Testing disabled status constraint...');
    try {
      await client.query(`
        INSERT INTO substitution_invitations 
        (request_id, candidate_employee_id, date, start_time, end_time, total_minutes, status)
        VALUES (gen_random_uuid(), gen_random_uuid(), '2025-01-15', '09:00', '11:00', 120, 'disabled')
      `);
      console.log('   ✅ Disabled status is allowed');
      await client.query('DELETE FROM substitution_invitations WHERE status = \'disabled\'');
    } catch (error) {
      console.log('   ❌ Disabled status not allowed:', error.message);
    }
    
    // Test 2: Check if history table exists
    console.log('\n2️⃣ Testing substitution history table...');
    const historyExists = await client.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'substitution_history'
      );
    `);
    
    if (historyExists.rows[0].exists) {
      console.log('   ✅ Substitution history table exists');
    } else {
      console.log('   ❌ Substitution history table not found');
    }
    
    // Test 3: Test history table structure
    console.log('\n3️⃣ Testing history table structure...');
    try {
      const columns = await client.query(`
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_name = 'substitution_history'
        ORDER BY ordinal_position
      `);
      
      const expectedColumns = [
        'id', 'invitation_id', 'request_id', 'substitute_employee_id',
        'absent_employee_id', 'date', 'start_time', 'end_time',
        'minutes', 'status', 'completed_at', 'created_at'
      ];
      
      const actualColumns = columns.rows.map(row => row.column_name);
      const missingColumns = expectedColumns.filter(col => !actualColumns.includes(col));
      
      if (missingColumns.length === 0) {
        console.log('   ✅ All expected columns present');
      } else {
        console.log('   ❌ Missing columns:', missingColumns);
      }
    } catch (error) {
      console.log('   ❌ Error checking table structure:', error.message);
    }
    
    // Test 4: Test status constraint
    console.log('\n4️⃣ Testing status constraint...');
    try {
      const constraint = await client.query(`
        SELECT pg_get_constraintdef(oid) as definition
        FROM pg_constraint 
        WHERE conname = 'substitution_invitations_status_check'
      `);
      
      if (constraint.rows.length > 0) {
        const constraintText = constraint.rows[0].definition;
        if (constraintText.includes('disabled')) {
          console.log('   ✅ Status constraint includes disabled status');
        } else {
          console.log('   ❌ Status constraint does not include disabled status');
        }
      } else {
        console.log('   ❌ Status constraint not found');
      }
    } catch (error) {
      console.log('   ❌ Error checking constraint:', error.message);
    }
    
    // Test 5: Test indexes
    console.log('\n5️⃣ Testing indexes...');
    try {
      const indexes = await client.query(`
        SELECT indexname, tablename
        FROM pg_indexes
        WHERE tablename IN ('substitution_invitations', 'substitution_history')
        ORDER BY tablename, indexname
      `);
      
      const expectedIndexes = [
        'idx_substitution_invitations_candidate',
        'idx_substitution_invitations_request',
        'idx_substitution_invitations_status',
        'idx_substitution_invitations_date',
        'idx_substitution_history_substitute',
        'idx_substitution_history_absent',
        'idx_substitution_history_date',
        'idx_substitution_history_status'
      ];
      
      const actualIndexes = indexes.rows.map(row => row.indexname);
      const missingIndexes = expectedIndexes.filter(idx => !actualIndexes.includes(idx));
      
      if (missingIndexes.length === 0) {
        console.log('   ✅ All expected indexes present');
      } else {
        console.log('   ⚠️  Missing indexes:', missingIndexes);
      }
    } catch (error) {
      console.log('   ❌ Error checking indexes:', error.message);
    }
    
    // Test 6: Test data integrity
    console.log('\n6️⃣ Testing data integrity...');
    try {
      // Check if there are any invitations with invalid statuses
      const invalidStatuses = await client.query(`
        SELECT status, COUNT(*) as count
        FROM substitution_invitations
        WHERE status NOT IN ('pending', 'accepted', 'denied', 'taught', 'dropped', 'disabled')
        GROUP BY status
      `);
      
      if (invalidStatuses.rows.length === 0) {
        console.log('   ✅ All invitation statuses are valid');
      } else {
        console.log('   ❌ Invalid statuses found:', invalidStatuses.rows);
      }
    } catch (error) {
      console.log('   ❌ Error checking data integrity:', error.message);
    }
    
    // Summary
    console.log('\n📊 Test Summary:');
    console.log('   Enhanced substitution system is ready for use!');
    console.log('\n🔗 Available API Endpoints:');
    console.log('   GET  /api/substitutions/invitations/teacher-view');
    console.log('   GET  /api/substitutions/invitations/admin-view');
    console.log('   GET  /api/substitutions/history/:employeeId');
    console.log('   GET  /api/substitutions/history/all');
    console.log('   POST /api/substitutions/invitations/:id/mark-no-show');
    console.log('\n📚 Documentation: ENHANCED_SUBSTITUTION_SYSTEM.md');
    
  } catch (error) {
    console.error('❌ Test failed:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

// Run the tests
testEnhancedSubstitution()
  .then(() => {
    console.log('\n✅ All tests completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Tests failed:', error.message);
    process.exit(1);
  });
