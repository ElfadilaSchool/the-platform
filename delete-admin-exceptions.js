/**
 * Script to delete admin user exceptions
 * This will help identify and delete exceptions created by admin users
 * 
 * Usage: node delete-admin-exceptions.js
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

async function deleteAdminExceptions() {
  const client = await pool.connect();
  
  try {
    console.log('🔍 Analyzing admin user exceptions...\n');
    
    // First, show current exceptions by role
    const roleStats = await client.query(`
      SELECT u.role, COUNT(ae.id) as exception_count
      FROM attendance_exceptions ae
      JOIN users u ON ae.submitted_by_user_id = u.id
      GROUP BY u.role
      ORDER BY u.role
    `);
    
    console.log('📊 Current exceptions by role:');
    roleStats.rows.forEach(row => {
      console.log(`   ${row.role}: ${row.exception_count} exceptions`);
    });
    
    // Show admin users and their exceptions
    const adminUsers = await client.query(`
      SELECT u.id, u.username, u.role, COUNT(ae.id) as exception_count
      FROM users u
      LEFT JOIN attendance_exceptions ae ON u.id = ae.submitted_by_user_id
      WHERE u.role IN ('HR_Manager', 'Department_Responsible')
      GROUP BY u.id, u.username, u.role
      ORDER BY u.role, u.username
    `);
    
    console.log('\n👥 Admin users and their exceptions:');
    adminUsers.rows.forEach(row => {
      console.log(`   ${row.username} (${row.role}): ${row.exception_count} exceptions`);
    });
    
    // Get total count of admin exceptions
    const totalAdminExceptions = await client.query(`
      SELECT COUNT(ae.id) as total_count
      FROM attendance_exceptions ae
      JOIN users u ON ae.submitted_by_user_id = u.id
      WHERE u.role IN ('HR_Manager', 'Department_Responsible')
    `);
    
    const totalCount = totalAdminExceptions.rows[0].total_count;
    
    if (totalCount === 0) {
      console.log('\n✅ No admin exceptions found to delete.');
      return;
    }
    
    console.log(`\n🗑️  Found ${totalCount} admin exceptions to delete.`);
    console.log('\n⚠️  This will permanently delete all exceptions created by HR_Manager and Department_Responsible users.');
    
    // Uncomment the next section to actually perform the deletion
    /*
    console.log('\n🗑️  Deleting admin exceptions...');
    const deleteResult = await client.query(`
      DELETE FROM attendance_exceptions 
      WHERE submitted_by_user_id IN (
        SELECT id FROM users 
        WHERE role IN ('HR_Manager', 'Department_Responsible')
      )
    `);
    
    console.log(`✅ Deleted ${deleteResult.rowCount} admin exceptions successfully!`);
    */
    
    console.log('\n💡 To actually delete the exceptions, uncomment the deletion code in this script.');
    console.log('🔍 SQL query to run manually:');
    console.log(`
DELETE FROM attendance_exceptions 
WHERE submitted_by_user_id IN (
    SELECT id FROM users 
    WHERE role IN ('HR_Manager', 'Department_Responsible')
);`);
    
  } catch (error) {
    console.error('❌ Error:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

// Run the analysis
deleteAdminExceptions()
  .then(() => {
    console.log('\n✅ Analysis completed');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Analysis failed:', error.message);
    process.exit(1);
  });
