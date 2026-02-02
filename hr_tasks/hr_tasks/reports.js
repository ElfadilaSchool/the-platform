const express = require('express');
const router = express.Router();
const pool = require('./db');   // ✅ importe pool depuis db.js

// 📊 Récupérer les données des rapports
router.get('/data', async (req, res) => {
  try {
    const tasksResult = await pool.query(`
      SELECT 
        t.*,
        json_agg(
          json_build_object(
            'id', ta.employee_id,
            'first_name', e.first_name,
            'last_name', e.last_name,
            'status', ta.status,
            'assigned_at', ta.assigned_at,
            'completed_at', ta.completed_at
          )
        ) as assignees
      FROM tasks t
      LEFT JOIN task_assignments ta ON t.id = ta.task_id
      LEFT JOIN employees e ON ta.employee_id = e.id
      GROUP BY t.id
      ORDER BY t.created_at DESC
    `);

    const employeesResult = await pool.query(`
      SELECT id, first_name, last_name, 
             CONCAT(first_name, ' ', last_name) as name
      FROM employees 
      ORDER BY first_name, last_name
    `);

    const tasks = tasksResult.rows.map(row => {
      const assignees = row.assignees.filter(a => a.id !== null);
      return { ...row, assignees };
    });

    res.json({
      success: true,
      tasks,
      employees: employeesResult.rows
    });
  } catch (error) {
    console.error("❌ Erreur dans /data :", error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch report data'
    });
  }
});


// 📊 Statistiques par employé
router.get('/employee-stats', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        e.id,
        e.first_name,
        e.last_name,
        COUNT(ta.task_id) as total_tasks,
        COUNT(CASE WHEN ta.status = 'Completed' THEN 1 END) as completed_tasks,
        COUNT(CASE WHEN ta.status IN ('In Progress', 'Pending') THEN 1 END) as in_progress_tasks,
        COUNT(CASE WHEN ta.status != 'Completed' AND t.due_date < NOW() THEN 1 END) as overdue_tasks
      FROM employees e
      LEFT JOIN task_assignments ta ON e.id = ta.employee_id
      LEFT JOIN tasks t ON ta.task_id = t.id
      GROUP BY e.id
      ORDER BY e.first_name, e.last_name
    `);

    res.json({
      success: true,
      stats: result.rows
    });
  } catch (error) {
    console.error("❌ Erreur dans /employee-stats :", error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch employee statistics'
    });
  }
});
// 🔹 Récupérer tous les responsables (via departments.responsible_id)
router.get('/responsibles', async (req, res) => {
  try {
    // Responsables = employés référencés par departments.responsible_id
    // et dont l'utilisateur lié a le rôle Department_Responsible
    const result = await pool.query(`
      SELECT DISTINCT
        e.id,
        e.first_name,
        e.last_name
      FROM departments d
      JOIN employees e ON e.id = d.responsible_id
      LEFT JOIN users u ON u.id = e.user_id
      WHERE u.role = 'Department_Responsible'
      ORDER BY e.first_name, e.last_name
    `);

    res.json(result.rows);
  } catch (err) {
    console.error('Erreur /api/reports/responsibles:', err);
    res.status(500).json({ error: 'Failed to fetch responsibles' });
  }
});

// 🔹 Récupérer les tâches par responsable
router.get('/by-responsible/:id', async (req, res) => {
  try {
    const responsibleId = req.params.id;
    const result = await pool.query(
      "SELECT * FROM tasks WHERE responsible_id = $1 ORDER BY created_at DESC",
      [responsibleId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).send("Erreur serveur");
  }
});


module.exports = router;
