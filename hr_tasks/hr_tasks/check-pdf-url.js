const pool = require('./db');

async function checkUrl() {
  try {
    const result = await pool.query(
      'SELECT pdf_url FROM employee_reports WHERE id = $1',
      ['0107bc3d-260b-4e7c-a286-1b39eab7171f']
    );
    
    if (result.rows.length > 0) {
      console.log('PDF URL:', result.rows[0].pdf_url);
    } else {
      console.log('Report not found');
    }
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkUrl();
