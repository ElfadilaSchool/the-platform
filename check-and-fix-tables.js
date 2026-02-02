/**
 * Check and fix substitution tables
 * This script checks if the substitution tables exist and creates them if needed
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

async function checkAndFixTables() {
  const client = await pool.connect();
  
  try {
    console.log('🔍 Checking substitution tables...');
    
    // Check if substitution_requests table exists
    const requestsCheck = await client.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'substitution_requests'
      );
    `);
    
    if (!requestsCheck.rows[0].exists) {
      console.log('❌ substitution_requests table does not exist. Creating...');
      
      await client.query(`
        CREATE TABLE substitution_requests (
          id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
          employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
          exception_id uuid REFERENCES attendance_exceptions(id) ON DELETE CASCADE,
          date date NOT NULL,
          start_time time NOT NULL,
          end_time time NOT NULL,
          minutes integer NOT NULL,
          status varchar(20) DEFAULT 'pending' NOT NULL,
          created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
          updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
          CONSTRAINT substitution_requests_status_check CHECK (status IN ('pending', 'approved', 'cancelled'))
        );
      `);
      
      console.log('✅ substitution_requests table created');
    } else {
      console.log('✅ substitution_requests table exists');
      
      // Check columns
      const columns = await client.query(`
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_name = 'substitution_requests'
        ORDER BY ordinal_position;
      `);
      
      console.log('   Columns:', columns.rows.map(r => r.column_name).join(', '));
    }
    
    // Check if substitution_invitations table exists
    const invitationsCheck = await client.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'substitution_invitations'
      );
    `);
    
    if (!invitationsCheck.rows[0].exists) {
      console.log('❌ substitution_invitations table does not exist. Creating...');
      
      await client.query(`
        CREATE TABLE substitution_invitations (
          id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
          request_id uuid NOT NULL REFERENCES substitution_requests(id) ON DELETE CASCADE,
          candidate_employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
          date date NOT NULL,
          start_time time NOT NULL,
          end_time time NOT NULL,
          minutes integer NOT NULL,
          status varchar(20) DEFAULT 'pending' NOT NULL,
          responded_at timestamp with time zone,
          completed_at timestamp with time zone,
          created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
          CONSTRAINT substitution_invitations_status_check CHECK (status IN ('pending', 'accepted', 'denied', 'taught', 'dropped')),
          CONSTRAINT substitution_invitations_unique UNIQUE (request_id, candidate_employee_id, date, start_time)
        );
      `);
      
      console.log('✅ substitution_invitations table created');
    } else {
      console.log('✅ substitution_invitations table exists');
    }
    
    // Create indexes
    console.log('🔧 Creating indexes...');
    
    try {
      await client.query('CREATE INDEX IF NOT EXISTS idx_substitution_requests_employee ON substitution_requests(absent_employee_id);');
      await client.query('CREATE INDEX IF NOT EXISTS idx_substitution_requests_date ON substitution_requests(date);');
      await client.query('CREATE INDEX IF NOT EXISTS idx_substitution_requests_status ON substitution_requests(status);');
      
      await client.query('CREATE INDEX IF NOT EXISTS idx_substitution_invitations_candidate ON substitution_invitations(candidate_employee_id);');
      await client.query('CREATE INDEX IF NOT EXISTS idx_substitution_invitations_request ON substitution_invitations(request_id);');
      await client.query('CREATE INDEX IF NOT EXISTS idx_substitution_invitations_status ON substitution_invitations(status);');
      await client.query('CREATE INDEX IF NOT EXISTS idx_substitution_invitations_date ON substitution_invitations(date);');
      
      console.log('✅ Indexes created');
    } catch (e) {
      console.log('⚠️  Some indexes may already exist:', e.message);
    }
    
    // Test the tables
    console.log('🧪 Testing tables...');
    
    const requestsCount = await client.query('SELECT COUNT(*) FROM substitution_requests');
    const invitationsCount = await client.query('SELECT COUNT(*) FROM substitution_invitations');
    
    console.log(`   substitution_requests: ${requestsCount.rows[0].count} records`);
    console.log(`   substitution_invitations: ${invitationsCount.rows[0].count} records`);
    
    console.log('\n✅ All tables are ready!');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    client.release();
    await pool.end();
  }
}

checkAndFixTables();
