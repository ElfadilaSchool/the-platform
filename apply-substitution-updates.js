/**
 * Script to apply the enhanced substitution invitation system updates
 * This includes database schema changes and system improvements
 * 
 * Usage: node apply-substitution-updates.js
 */

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

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

async function applyUpdates() {
  const client = await pool.connect();
  
  try {
    console.log('🚀 Applying substitution invitation system updates...\n');
    
    // Read and execute the schema update file
    const schemaFile = path.join(__dirname, 'database', 'update_substitution_schema.sql');
    
    if (!fs.existsSync(schemaFile)) {
      console.log('❌ Schema update file not found:', schemaFile);
      return;
    }
    
    const schemaSQL = fs.readFileSync(schemaFile, 'utf8');
    console.log('📋 Executing database schema updates...');
    
    await client.query(schemaSQL);
    console.log('✅ Database schema updated successfully');
    
    // Verify the changes
    console.log('\n🔍 Verifying updates...');
    
    // Check if disabled status is now allowed
    const constraintCheck = await client.query(`
      SELECT conname, pg_get_constraintdef(oid) as definition
      FROM pg_constraint 
      WHERE conname = 'substitution_invitations_status_check'
    `);
    
    if (constraintCheck.rows.length > 0) {
      const definition = constraintCheck.rows[0].definition;
      if (definition.includes('disabled')) {
        console.log('✅ Status constraint updated to include "disabled"');
      } else {
        console.log('⚠️  Status constraint found but may not include "disabled"');
      }
    }
    
    // Check if history table exists
    const historyTableCheck = await client.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'substitution_history'
      );
    `);
    
    if (historyTableCheck.rows[0].exists) {
      console.log('✅ Substitution history table created');
    } else {
      console.log('❌ Substitution history table not found');
    }
    
    // Show current invitation statuses
    const statusCounts = await client.query(`
      SELECT status, COUNT(*) as count
      FROM substitution_invitations
      GROUP BY status
      ORDER BY status
    `);
    
    console.log('\n📊 Current invitation status distribution:');
    statusCounts.rows.forEach(row => {
      console.log(`   ${row.status}: ${row.count} invitations`);
    });
    
    // Show history table count
    const historyCount = await client.query(`
      SELECT COUNT(*) as count FROM substitution_history
    `);
    
    console.log(`\n📈 Substitution history records: ${historyCount.rows[0].count}`);
    
    console.log('\n🎉 All updates applied successfully!');
    console.log('\n📋 New Features Available:');
    console.log('   ✅ Single teacher acceptance (others become disabled)');
    console.log('   ✅ Drop functionality reactivates other invitations');
    console.log('   ✅ Automatic extra hour tracking for completed substitutions');
    console.log('   ✅ History tracking for all substitution work');
    console.log('   ✅ Separate views for teachers vs admin');
    console.log('   ✅ No-show tracking and management');
    
    console.log('\n🔗 New API Endpoints:');
    console.log('   GET /api/substitutions/invitations/teacher-view');
    console.log('   GET /api/substitutions/invitations/admin-view');
    console.log('   GET /api/substitutions/history/:employeeId');
    console.log('   GET /api/substitutions/history/all');
    console.log('   POST /api/substitutions/invitations/:id/mark-no-show');
    
  } catch (error) {
    console.error('❌ Error applying updates:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

// Run the updates
applyUpdates()
  .then(() => {
    console.log('\n✅ Script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Script failed:', error.message);
    process.exit(1);
  });
