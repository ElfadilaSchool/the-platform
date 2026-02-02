const pool = require('./db');

async function testDB() {
  try {
    console.log('🔍 Test de la base de données...');
    
    // Vérifier la structure des tables
    const employees = await pool.query('SELECT COUNT(*) as count FROM employees');
    console.log('📊 Nombre d\'employés:', employees.rows[0].count);
    
    const departments = await pool.query('SELECT id, name, responsible_id FROM departments ORDER BY name');
    console.log('📊 Départements:');
    departments.rows.forEach(dept => {
      console.log(`  - ${dept.name} (ID: ${dept.id}, Responsable: ${dept.responsible_id || 'AUCUN'})`);
    });
    
    // Vérifier les responsables
    const responsibles = await pool.query(`
      SELECT e.id, e.first_name, e.last_name, d.name as department_name
      FROM employees e
      INNER JOIN departments d ON d.responsible_id = e.id
      ORDER BY e.first_name
    `);
    console.log('📊 Responsables trouvés:', responsibles.rows.length);
    responsibles.rows.forEach(resp => {
      console.log(`  - ${resp.first_name} ${resp.last_name} (${resp.department_name})`);
    });
    
    // Test avec LEFT JOIN
    const responsiblesLeft = await pool.query(`
      SELECT e.id, e.first_name, e.last_name, d.name as department_name
      FROM employees e
      LEFT JOIN departments d ON d.responsible_id = e.id
      WHERE EXISTS (SELECT 1 FROM departments d2 WHERE d2.responsible_id = e.id)
      ORDER BY e.first_name
    `);
    console.log('📊 Responsables avec LEFT JOIN:', responsiblesLeft.rows.length);
    responsiblesLeft.rows.forEach(resp => {
      console.log(`  - ${resp.first_name} ${resp.last_name} (${resp.department_name || 'Sans département'})`);
    });
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur:', error);
    process.exit(1);
  }
}

testDB();
