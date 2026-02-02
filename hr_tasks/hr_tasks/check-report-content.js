const pool = require('./db');

async function checkReport() {
  try {
    const result = await pool.query(`
      SELECT title, subject, content, analysis
      FROM employee_reports
      WHERE title = 'fgfgfgh'
      LIMIT 1
    `);
    
    if (result.rows.length > 0) {
      const report = result.rows[0];
      console.log('📄 Report:', report.title);
      console.log('Subject:', report.subject);
      console.log('Content:', report.content);
      console.log('\nAnalysis:', JSON.stringify(report.analysis, null, 2));
    }
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkReport();
