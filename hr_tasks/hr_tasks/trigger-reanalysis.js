const pool = require('./db');
const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));

async function triggerReanalysis() {
  try {
    // Get the 3 test reports
    const result = await pool.query(`
      SELECT id, title
      FROM employee_reports
      WHERE title IN ('fgfgfgh', 'kjhjkh', 'dsdsd')
    `);
    
    console.log(`🔄 Triggering re-analysis for ${result.rows.length} test reports...\n`);
    
    for (const report of result.rows) {
      console.log(`Triggering: ${report.title}`);
      
      const response = await fetch(`http://localhost:3020/api/rapportemp/${report.id}/reanalyze`, {
        method: 'POST'
      });
      
      const data = await response.json();
      console.log(`  ✅ ${data.message}\n`);
      
      // Wait 2 seconds between requests
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
    
    console.log('✅ All re-analysis requests sent!');
    console.log('⏳ Check the server logs for progress...');
    console.log('📊 Reports will be updated in a few seconds.\n');
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

triggerReanalysis();
