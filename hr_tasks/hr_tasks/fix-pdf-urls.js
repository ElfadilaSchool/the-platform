const pool = require('./db');

async function fixPdfUrls() {
  try {
    console.log('🔧 Fixing PDF URLs in database...');
    
    // Update all PDF URLs from port 3004 to 3020
    const result = await pool.query(`
      UPDATE employee_reports
      SET pdf_url = REPLACE(pdf_url, 'localhost:3004', 'localhost:3020')
      WHERE pdf_url LIKE '%localhost:3004%'
      RETURNING id, pdf_url
    `);
    
    console.log(`✅ Updated ${result.rows.length} reports`);
    
    if (result.rows.length > 0) {
      console.log('\nSample updated URLs:');
      result.rows.slice(0, 5).forEach(row => {
        console.log(`  - ${row.id}: ${row.pdf_url}`);
      });
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error fixing PDF URLs:', error);
    process.exit(1);
  }
}

fixPdfUrls();
