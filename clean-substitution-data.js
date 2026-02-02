/**
 * Script to clean up substitution data for testing
 * This will delete all substitution invitations, requests, and history
 * 
 * Usage: node clean-substitution-data.js
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

async function cleanSubstitutionData() {
  const client = await pool.connect();
  
  try {
    console.log('🧹 Cleaning up substitution data for testing...\n');
    
    // Get counts before deletion
    const historyCount = await client.query('SELECT COUNT(*) as count FROM substitution_history');
    const invitationsCount = await client.query('SELECT COUNT(*) as count FROM substitution_invitations');
    const requestsCount = await client.query('SELECT COUNT(*) as count FROM substitution_requests');
    
    console.log('📊 Current data:');
    console.log(`   History records: ${historyCount.rows[0].count}`);
    console.log(`   Invitations: ${invitationsCount.rows[0].count}`);
    console.log(`   Requests: ${requestsCount.rows[0].count}\n`);
    
    // Delete in correct order to respect foreign key constraints
    console.log('🗑️  Deleting substitution history...');
    const historyResult = await client.query('DELETE FROM substitution_history');
    console.log(`   ✅ Deleted ${historyResult.rowCount} history records`);
    
    console.log('🗑️  Deleting substitution invitations...');
    const invitationsResult = await client.query('DELETE FROM substitution_invitations');
    console.log(`   ✅ Deleted ${invitationsResult.rowCount} invitations`);
    
    console.log('🗑️  Deleting substitution requests...');
    const requestsResult = await client.query('DELETE FROM substitution_requests');
    console.log(`   ✅ Deleted ${requestsResult.rowCount} requests`);
    
    // Verify deletion
    const finalHistoryCount = await client.query('SELECT COUNT(*) as count FROM substitution_history');
    const finalInvitationsCount = await client.query('SELECT COUNT(*) as count FROM substitution_invitations');
    const finalRequestsCount = await client.query('SELECT COUNT(*) as count FROM substitution_requests');
    
    console.log('\n📊 Final data:');
    console.log(`   History records: ${finalHistoryCount.rows[0].count}`);
    console.log(`   Invitations: ${finalInvitationsCount.rows[0].count}`);
    console.log(`   Requests: ${finalRequestsCount.rows[0].count}`);
    
    console.log('\n✅ All substitution data cleaned successfully!');
    console.log('🎯 You can now test the enhanced substitution system with fresh data.');
    
  } catch (error) {
    console.error('❌ Error cleaning data:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

// Run the cleanup
cleanSubstitutionData()
  .then(() => {
    console.log('\n✅ Cleanup completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Cleanup failed:', error.message);
    process.exit(1);
  });
