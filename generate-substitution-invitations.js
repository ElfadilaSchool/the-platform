/**
 * Utility script to generate substitution invitations from existing requests
 * Run this to automatically create invitations for all substitution requests
 * that don't have invitations yet.
 * 
 * Usage: node generate-substitution-invitations.js
 */

const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/hr_operations'
});

async function generateInvitations() {
  const client = await pool.connect();
  
  try {
    console.log('🔍 Checking for substitution requests without invitations...\n');
    
    // Get all substitution requests
    const requestsResult = await client.query(`
      SELECT sr.id, sr.absent_employee_id, sr.date, sr.start_time, sr.end_time, sr.total_minutes, sr.status,
             e.first_name || ' ' || e.last_name AS employee_name,
             ed.department_id,
             COUNT(si.id) AS existing_invitations
      FROM substitution_requests sr
      LEFT JOIN employees e ON sr.absent_employee_id = e.id
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN substitution_invitations si ON sr.id = si.request_id
      GROUP BY sr.id, sr.absent_employee_id, sr.date, sr.start_time, sr.end_time, sr.total_minutes, sr.status,
               e.first_name, e.last_name, ed.department_id
      ORDER BY sr.date DESC, sr.start_time DESC
    `);

    if (requestsResult.rows.length === 0) {
      console.log('❌ No substitution requests found in the database.');
      return;
    }

    console.log(`📊 Found ${requestsResult.rows.length} substitution request(s)\n`);

    let totalCreated = 0;

    for (const request of requestsResult.rows) {
      console.log(`\n📅 Request: ${request.employee_name} - ${request.date} (${request.start_time}-${request.end_time})`);
      console.log(`   Existing invitations: ${request.existing_invitations}`);

      if (parseInt(request.existing_invitations) > 0) {
        console.log('   ✓ Already has invitations, skipping...');
        continue;
      }

      // Find all employees in the same department (excluding the requester)
      const candidatesResult = await client.query(
        `SELECT DISTINCT e.id, e.first_name || ' ' || e.last_name AS name
         FROM employees e
         LEFT JOIN employee_departments ed ON e.id = ed.employee_id
         WHERE ed.department_id = $1 
           AND e.id != $2
           AND (e.status = 'active' OR e.status IS NULL)
         ORDER BY e.first_name, e.last_name`,
        [request.department_id, request.employee_id]
      );

      if (candidatesResult.rows.length === 0) {
        console.log('   ⚠️  No available employees found in department');
        continue;
      }

      console.log(`   👥 Found ${candidatesResult.rows.length} potential substitute(s):`);

      // Create invitations for all candidates
      let created = 0;
      for (const candidate of candidatesResult.rows) {
        try {
          await client.query(
            `INSERT INTO substitution_invitations 
             (request_id, candidate_employee_id, date, start_time, end_time, minutes, status)
             VALUES ($1, $2, $3, $4, $5, $6, 'pending')`,
            [request.id, candidate.id, request.date, request.start_time, request.end_time, request.minutes]
          );
          created++;
          console.log(`      ✓ ${candidate.name}`);
        } catch (err) {
          console.log(`      ✗ ${candidate.name} (${err.message})`);
        }
      }

      console.log(`   ✅ Created ${created} invitation(s) for this request`);
      totalCreated += created;
    }

    console.log(`\n\n🎉 Total invitations created: ${totalCreated}`);
    console.log('\n✅ Done! Employees can now see these invitations in the "Pending Extra Hours" tab.');

  } catch (error) {
    console.error('❌ Error generating invitations:', error.message);
    console.error(error.stack);
  } finally {
    client.release();
    await pool.end();
  }
}

// Run the script
console.log('🚀 Substitution Invitations Generator\n');
console.log('=' .repeat(60));
generateInvitations()
  .then(() => {
    console.log('=' .repeat(60));
    process.exit(0);
  })
  .catch((err) => {
    console.error('Fatal error:', err);
    process.exit(1);
  });

