const { Pool } = require('pg');

// Database connection
const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'hr_operations_platform',
  password: 'admin',
  port: 5432,
});

async function manualTriggerInvitations() {
  try {
    console.log('🔍 Checking substitution requests...');
    
    // Get substitution requests
    const requestsResult = await pool.query(`
      SELECT id, date, start_time, end_time, total_minutes, institution, education_level, absent_employee_id
      FROM substitution_requests 
      ORDER BY created_at DESC 
      LIMIT 5
    `);
    
    console.log(`Found ${requestsResult.rows.length} substitution requests`);
    
    if (requestsResult.rows.length === 0) {
      console.log('❌ No substitution requests found');
      return;
    }
    
    // Get teachers
    const teachersResult = await pool.query(`
      SELECT e.id, e.institution, e.education_level, p.name as position
      FROM employees e
      JOIN positions p ON e.position_id = p.id
      WHERE p.name ILIKE '%teacher%'
    `);
    
    console.log(`Found ${teachersResult.rows.length} teachers`);
    
    // For each substitution request, create invitations
    for (const request of requestsResult.rows) {
      console.log(`\n📅 Processing request for ${request.date} (${request.start_time} - ${request.end_time})`);
      console.log(`   Institution: ${request.institution}, Level: ${request.education_level}`);
      
      // Find matching teachers
      const matchingTeachers = teachersResult.rows.filter(teacher => {
        // Match institution
        const institutionMatch = teacher.institution === request.institution;
        
        // Match education level (with preschool/primary flexibility)
        const levelMatch = teacher.education_level === request.education_level ||
                          (teacher.education_level === 'preschool' && request.education_level === 'primary') ||
                          (teacher.education_level === 'primary' && request.education_level === 'preschool');
        
        // Don't match the absent teacher
        const notAbsent = teacher.id !== request.absent_employee_id;
        
        return institutionMatch && levelMatch && notAbsent;
      });
      
      console.log(`   Found ${matchingTeachers.length} matching teachers`);
      
      // Create invitations for matching teachers
      for (const teacher of matchingTeachers) {
        try {
          await pool.query(`
            INSERT INTO substitution_invitations (
              request_id,
              candidate_employee_id,
              date,
              start_time,
              end_time,
              minutes,
              status,
              created_at
            ) VALUES ($1, $2, $3, $4, $5, $6, 'pending', NOW())
          `, [
            request.id,
            teacher.id,
            request.date,
            request.start_time,
            request.end_time,
            request.total_minutes
          ]);
          
          console.log(`   ✅ Created invitation for teacher ${teacher.id}`);
        } catch (err) {
          if (err.code === '23505') { // Unique constraint violation
            console.log(`   ⚠️  Invitation already exists for teacher ${teacher.id}`);
          } else {
            console.log(`   ❌ Error creating invitation for teacher ${teacher.id}:`, err.message);
          }
        }
      }
    }
    
    // Check final count
    const finalCount = await pool.query('SELECT COUNT(*) FROM substitution_invitations');
    console.log(`\n🎉 Total invitations created: ${finalCount.rows[0].count}`);
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    await pool.end();
  }
}

manualTriggerInvitations();
