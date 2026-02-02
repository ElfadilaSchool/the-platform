// Test script to verify pending status functionality
// Run this with: node test_pending_status.js

const { Pool } = require('pg');

async function testPendingStatus() {
    console.log('🔍 Testing Pending Status Implementation...\n');
    
    // Database connection (adjust these settings for your database)
    const pool = new Pool({
        user: 'postgres',
        host: 'localhost',
        database: 'hr_operations',
        password: 'your_password', // Update this
        port: 5432,
    });

    try {
        // Test 1: Check if pending_status column exists
        console.log('1. Checking if pending_status column exists...');
        const columnCheck = await pool.query(`
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'attendance_overrides' 
            AND column_name = 'pending_status'
        `);
        
        if (columnCheck.rows.length > 0) {
            console.log('✅ pending_status column exists');
            console.log(`   Type: ${columnCheck.rows[0].data_type}\n`);
        } else {
            console.log('❌ pending_status column does NOT exist');
            console.log('   You need to run the database migration first!\n');
            console.log('   Run this SQL file: database/APPLY_PENDING_STATUS_MIGRATION.sql\n');
            return;
        }

        // Test 2: Check if helper functions exist
        console.log('2. Checking if helper functions exist...');
        const functionCheck = await pool.query(`
            SELECT routine_name 
            FROM information_schema.routines 
            WHERE routine_name IN ('get_employee_pending_count', 'can_validate_month')
            AND routine_schema = 'public'
        `);
        
        if (functionCheck.rows.length === 2) {
            console.log('✅ Helper functions exist');
            console.log('   - get_employee_pending_count()');
            console.log('   - can_validate_month()\n');
        } else {
            console.log('❌ Helper functions missing');
            console.log('   Run the database migration to create them\n');
        }

        // Test 3: Check for sample data
        console.log('3. Checking for sample attendance data...');
        const dataCheck = await pool.query(`
            SELECT COUNT(*) as total_employees FROM employees
        `);
        console.log(`   Total employees: ${dataCheck.rows[0].total_employees}`);

        const punchCheck = await pool.query(`
            SELECT COUNT(*) as total_punches FROM raw_punches
        `);
        console.log(`   Total punches: ${punchCheck.rows[0].total_punches}`);

        // Test 4: Look for single punch cases (potential pending cases)
        console.log('\n4. Looking for potential pending cases...');
        const pendingCheck = await pool.query(`
            SELECT 
                DATE(punch_time) as punch_date,
                employee_name,
                COUNT(*) as punch_count
            FROM raw_punches 
            WHERE punch_time >= CURRENT_DATE - INTERVAL '30 days'
            GROUP BY DATE(punch_time), employee_name
            HAVING COUNT(*) = 1
            ORDER BY punch_date DESC
            LIMIT 5
        `);

        if (pendingCheck.rows.length > 0) {
            console.log(`   Found ${pendingCheck.rows.length} potential pending cases (single punches):`);
            pendingCheck.rows.forEach(row => {
                console.log(`   - ${row.employee_name} on ${row.punch_date} (${row.punch_count} punch)`);
            });
        } else {
            console.log('   No single punch cases found in the last 30 days');
        }

        console.log('\n🎉 Database structure looks good!');
        console.log('\n📋 Next steps:');
        console.log('   1. Make sure your attendance service is running');
        console.log('   2. Open the attendance master page in your browser');
        console.log('   3. Look for the orange "Pending" column');
        console.log('   4. If you have single punch cases, they should show as pending');

    } catch (error) {
        console.error('❌ Database connection failed:', error.message);
        console.log('\n💡 Make sure:');
        console.log('   - PostgreSQL is running');
        console.log('   - Database credentials are correct');
        console.log('   - Database "hr_operations" exists');
    } finally {
        await pool.end();
    }
}

// Run the test
testPendingStatus().catch(console.error);