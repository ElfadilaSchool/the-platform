const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

// Database connection using same config as attendance service
const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'attendance_db',
  password: process.env.DB_PASSWORD || 'admin',
  port: process.env.DB_PORT || 5432,
});

async function applyFix() {
  try {
    console.log('Connecting to database...');

    // Read the SQL file
    const sqlPath = path.join(__dirname, 'fix_overtime_constraint.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('Executing SQL fix...');

    // Execute the SQL
    await pool.query(sql);

    console.log('✅ Unique constraint added successfully!');

    // Test the constraint by running a simple query to check for duplicates
    console.log('Testing the unique constraint...');
    const result = await pool.query(`
      SELECT employee_id, date, COUNT(*)
      FROM public.employee_overtime_hours
      GROUP BY employee_id, date
      HAVING COUNT(*) > 1
    `);

    if (result.rows.length === 0) {
      console.log('✅ No duplicate records found for employee_id and date.');
    } else {
      console.warn('⚠️ Duplicate records found for employee_id and date:', result.rows);
    }

  } catch (error) {
    console.error('❌ Error applying fix:', error);
  } finally {
    await pool.end();
    console.log('Database connection closed.');
  }
}

applyFix();
