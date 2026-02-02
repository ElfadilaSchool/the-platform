const pool = require('./db');

async function reanalyzeTestReports() {
  try {
    console.log('🔄 Re-analyzing test reports with gibberish content...\n');
    
    // Get reports with 0 scores
    const result = await pool.query(`
      SELECT id, title
      FROM employee_reports
      WHERE (analysis->'severity'->>'score')::int = 0
      ORDER BY created_at DESC
    `);
    
    console.log(`Found ${result.rows.length} reports with 0 scores\n`);
    
    for (const report of result.rows) {
      console.log(`Re-analyzing: ${report.title}`);
      
      // Reset analysis to null to trigger re-analysis
      await pool.query(
        'UPDATE employee_reports SET analysis = NULL WHERE id = $1',
        [report.id]
      );
      
      console.log(`  ✅ Reset - will be re-analyzed on next view\n`);
    }
    
    console.log('✅ Done! The reports will be re-analyzed when you view them.');
    console.log('Note: Reports with gibberish content (fgfgfgh, etc.) will still get 0/10 scores');
    console.log('because they have no meaningful content to analyze.\n');
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

reanalyzeTestReports();
