const { Pool } = require('pg');

// Use the same database config as the attendance service
const pool = new Pool({
  user: 'postgres',
  host: 'localhost', 
  database: 'attendance_db',
  password: 'admin',
  port: 5432,
});

async function testTables() {
  try {
    console.log('Testing database connection...');
    
    // Test basic connection
    const result = await pool.query('SELECT NOW()');
    console.log('✓ Database connected:', result.rows[0].now);
    
    // Check if wage_changes table exists
    const wageChangesExists = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'wage_changes'
      );
    `);
    console.log('wage_changes table exists:', wageChangesExists.rows[0].exists);
    
    // Check if attendance_exceptions table exists
    const exceptionsExists = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'attendance_exceptions'
      );
    `);
    console.log('attendance_exceptions table exists:', exceptionsExists.rows[0].exists);
    
    // Check if employees table exists
    const employeesExists = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'employees'
      );
    `);
    console.log('employees table exists:', employeesExists.rows[0].exists);
    
    // Check if attendance_overrides table exists
    const overridesExists = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'attendance_overrides'
      );
    `);
    console.log('attendance_overrides table exists:', overridesExists.rows[0].exists);
    
    await pool.end();
    console.log('✓ Database test completed');
    
  } catch (error) {
    console.error('❌ Database test failed:', error.message);
    process.exit(1);
  }
}

testTables();
