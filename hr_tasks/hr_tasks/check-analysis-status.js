const pool = require('./db');

async function checkStatus() {
  try {
    const result = await pool.query(`
      SELECT 
        COUNT(*) as total,
        COUNT(CASE WHEN analysis IS NOT NULL THEN 1 END) as with_analysis,
        COUNT(CASE WHEN analysis IS NULL THEN 1 END) as without_analysis,
        COUNT(CASE WHEN (analysis->'severity'->>'score')::int > 0 THEN 1 END) as with_scores
      FROM employee_reports
    `);
    
    console.log('📊 Report Analysis Status:');
    console.log(`  Total reports: ${result.rows[0].total}`);
    console.log(`  With analysis: ${result.rows[0].with_analysis}`);
    console.log(`  Without analysis: ${result.rows[0].without_analysis}`);
    console.log(`  With scores > 0: ${result.rows[0].with_scores}`);
    
    // Show sample of recent reports
    const samples = await pool.query(`
      SELECT title, 
             (analysis->'severity'->>'score')::int as severity_score,
             (analysis->'urgency'->>'score')::int as urgency_score
      FROM employee_reports
      ORDER BY created_at DESC
      LIMIT 5
    `);
    
    console.log('\n📝 Recent reports:');
    samples.rows.forEach(r => {
      console.log(`  - ${r.title.substring(0, 40)}: Severity=${r.severity_score || 0}, Urgency=${r.urgency_score || 0}`);
    });
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkStatus();
