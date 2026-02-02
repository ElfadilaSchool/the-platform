const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
require('dotenv').config();
const pool = require('./db'); 
const app = express();
const PORT = process.env.TASK_SERVICE_PORT || 3020;

// Middlewares
app.use(
  helmet.contentSecurityPolicy({
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'", "https://cdnjs.cloudflare.com", "https://gc.kis.v2.scr.kaspersky-labs.com"],
      scriptSrcAttr: ["'unsafe-inline'"], // ← CETTE LIGNE RÉSOUT LE PROBLÈME
      imgSrc: ["'self'", "data:", "https://via.placeholder.com", "https:"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://cdnjs.cloudflare.com"],
      fontSrc: ["'self'", "https://cdnjs.cloudflare.com"],
      connectSrc: ["'self'", `http://localhost:${PORT}`, `ws://localhost:${PORT}`, "https://gc.kis.v2.scr.kaspersky-labs.com", "wss://gc.kis.v2.scr.kaspersky-labs.com"]
    },
  })
);

app.use(cors());
app.use(morgan('dev'));
app.use(express.json());

// Servir les fichiers statiques (frontend)
app.use(express.static(path.join(__dirname, 'public')));

// Importer tes routes
const reportDataRoutes = require('./reports');   // 📊 data + stats
const reportGenRoutes = require('./generer');    // 📝 ajout + PDF
const rapportempRoutes = require('./rapportemp'); // 📝 interface rapports employé

// Monter les routes
app.use('/api/reports', reportDataRoutes);  // => /api/reports/data , /api/reports/employee-stats
app.use('/api/reports', reportGenRoutes);   // => /api/reports (POST), /api/reports/:id/pdf
app.use('/api/rapportemp', rapportempRoutes); // => /api/rapportemp/employee/:id/reports

// Route pour tester le backend
app.get('/health', (req, res) => {
  res.json({ status: 'OK', service: 'Task Service' });
});

// =====================
// Departments Endpoints
// =====================
app.get('/departments', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT id, name, responsible_id
      FROM departments
      ORDER BY name
    `);
    res.json(result.rows);
  } catch (error) {
    console.error('Erreur liste départements:', error);
    res.status(500).json({ error: 'Impossible de récupérer les départements' });
  }
});

app.get('/departments/:id/employees', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(`
      SELECT e.id, e.first_name, e.last_name, e.phone, e.email, e.profile_picture_url, e.nationality, e.join_date, e.address
      FROM employees e
      INNER JOIN employee_departments ed ON ed.employee_id = e.id
      WHERE ed.department_id = $1
      ORDER BY e.first_name, e.last_name
    `, [id]);
    res.json(result.rows);
  } catch (error) {
    console.error('Erreur employés par département:', error);
    res.status(500).json({ error: 'Impossible de récupérer les employés du département' });
  }
});

// Route principale pour le frontend
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'tasks.html'));
});

// Démarrer serveur
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Task Service running on port ${PORT}`);
});

// Get all employees
app.get('/employees', async (req, res) => {
  try {
    const { responsible_id } = req.query;

    if (responsible_id && responsible_id !== 'null' && responsible_id !== 'undefined') {
      console.log('[EMPLOYEES] Filter by responsible_id =', responsible_id);
      // Filtrer les employés par département dont "responsible_id" est le responsable
      const result = await pool.query(`
        SELECT DISTINCT e.id, e.first_name, e.last_name
        FROM employees e
        INNER JOIN employee_departments ed ON ed.employee_id = e.id
        INNER JOIN departments d ON d.id = ed.department_id
        WHERE d.responsible_id = $1
        ORDER BY e.first_name, e.last_name
      `, [responsible_id]);
      console.log('[EMPLOYEES] Found', result.rows.length, 'employees for responsible');
      return res.json(result.rows);
    }

    // Sinon: renvoyer tous les employés
    const result = await pool.query(`
      SELECT id, first_name, last_name
      FROM employees
      ORDER BY first_name, last_name
    `);
    return res.json(result.rows);
  } catch (error) {
    console.error('Erreur récupération employés:', error);
    res.status(500).json({ error: 'Impossible de récupérer les employés' });
  }
});

// Retourner les départements d'un responsable (par nom)
app.get('/responsibles/:id/departments', async (req, res) => {
  try {
    const { id } = req.params;
    if (!id || id === 'null' || id === 'undefined') {
      return res.json({ departments: [] });
    }
    const result = await pool.query(`
      SELECT d.id, d.name
      FROM departments d
      WHERE d.responsible_id = $1
      ORDER BY d.name
    `, [id]);
    res.json({ departments: result.rows });
  } catch (error) {
    console.error('Erreur récupération départements responsable:', error);
    res.status(500).json({ error: 'Impossible de récupérer les départements' });
  }
});
app.get('/employees/:id', async (req, res) => {
  try {
    const { id } = req.params;
    console.log('GET /employees/:id (minimal) ID:', id);

    const result = await pool.query(
      `SELECT id, first_name, last_name, phone FROM employees WHERE id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'Employee not found',
        details: `Aucun employé trouvé avec l'ID: ${id}`
      });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('GET /employees/:id error (minimal):', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get all tasks with filters
// Get all tasks with multiple assignees
app.get('/tasks', async (req, res) => {
  try {
    const { status, type, priority, assigned_to } = req.query;
    
    let query = `
      SELECT 
        t.*,
        assigned_by_emp.first_name as assigned_by_first_name,
        assigned_by_emp.last_name as assigned_by_last_name,
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
      LEFT JOIN employees assigned_by_emp ON t.assigned_by = assigned_by_emp.id
      LEFT JOIN task_assignments ta ON t.id = ta.task_id
      LEFT JOIN employees e ON ta.employee_id = e.id
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;

    if (status) {
      query += ` AND t.status = $${paramCount}`;
      params.push(status);
      paramCount++;
    }

    if (type) {
      query += ` AND t.type = $${paramCount}`;
      params.push(type);
      paramCount++;
    }

    if (priority) {
      query += ` AND t.priority = $${paramCount}`;
      params.push(priority);
      paramCount++;
    }

    query += ' GROUP BY t.id, assigned_by_emp.first_name, assigned_by_emp.last_name ORDER BY t.created_at DESC';

    const result = await pool.query(query, params);

    // Transformer les résultats pour regrouper les assignés
    const tasks = result.rows.map(row => {
      const assignees = (row.assignees || []).filter(a => a && a.id !== null);
      return { ...row, assignees };
    });

    // Récupérer commentaires et rapports pour toutes les tâches en une fois
    const taskIds = tasks.map(t => t.id);
    if (taskIds.length > 0) {
      // Comments
      const commentsQuery = `
        SELECT 
          tc.task_id,
          tc.id,
          tc.comment AS text,
          tc.created_at,
          e.first_name || ' ' || e.last_name AS author_name,
          e.id AS employee_id
        FROM task_comments tc
        JOIN employees e ON e.id = tc.employee_id
        WHERE tc.task_id = ANY($1::uuid[])
        ORDER BY tc.created_at DESC
      `;
      const commentsRes = await pool.query(commentsQuery, [taskIds]);
      const taskIdToComments = new Map();
      (commentsRes.rows || []).forEach(c => {
        const key = String(c.task_id);
        if (!taskIdToComments.has(key)) taskIdToComments.set(key, []);
        taskIdToComments.get(key).push({
          id: c.id,
          text: c.text,
          created_at: c.created_at,
          author_name: c.author_name,
          employee_id: c.employee_id
        });
      });

      // Reports
      const reportsQuery = `
        SELECT 
          r.task_id,
          r.id,
          r.description AS content,
          r.remarks,
          r.created_at,
          r.pdf_url,
          e.first_name || ' ' || e.last_name AS author_name,
          e.id AS employee_id
        FROM reports r
        JOIN employees e ON e.id = r.employee_id
        WHERE r.task_id = ANY($1::uuid[])
        ORDER BY r.created_at DESC
      `;
      const reportsRes = await pool.query(reportsQuery, [taskIds]);
      const taskIdToReports = new Map();
      (reportsRes.rows || []).forEach(r => {
        const key = String(r.task_id);
        if (!taskIdToReports.has(key)) taskIdToReports.set(key, []);
        taskIdToReports.get(key).push({
          id: r.id,
          content: r.content,
          remarks: r.remarks,
          created_at: r.created_at,
          pdf_url: r.pdf_url,
          author_name: r.author_name,
          employee_id: r.employee_id
        });
      });

      // Attacher aux tâches
      tasks.forEach(t => {
        const key = String(t.id);
        t.comments = taskIdToComments.get(key) || [];
        t.reports = taskIdToReports.get(key) || [];
      });
    }

    res.json(tasks);
  } catch (error) {
    console.error('Get tasks error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create new task with multiple assignees
app.post('/tasks', async (req, res) => {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    const { title, description, type, assigned_to, due_date, priority, assigned_by } = req.body;

    console.log('=== BACKEND DEBUGGING ===');
    console.log('Received assigned_by:', assigned_by);
    console.log('Full request body:', req.body);

    const assignees = Array.isArray(assigned_to) ? assigned_to.filter(Boolean) : [assigned_to].filter(Boolean);
    if (!title || !type || assignees.length === 0) {
      return res.status(400).json({ 
        error: 'Champs requis manquants: title, type, et au moins un employé assigné'
      });
    }

    // ❌ SUPPRIMER CETTE PARTIE QUI CAUSE LE PROBLÈME :
    /*
    const assignedByResult = await client.query(
      'SELECT id FROM employees ORDER BY created_at ASC LIMIT 1'
    );
    const assigned_by = assignedByResult.rows[0].id;
    */

    // ✅ NOUVELLE LOGIQUE : Utiliser seulement assigned_by du frontend
    if (!assigned_by) {
      return res.status(400).json({ 
        error: 'assigned_by is required. Cannot identify current user.',
        received_data: { assigned_by, title, type }
      });
    }

    // Vérifier que l'assigned_by existe dans la base
    const assignedByCheck = await client.query(
      'SELECT id, first_name, last_name FROM employees WHERE id = $1', 
      [assigned_by]
    );
    
    if (assignedByCheck.rows.length === 0) {
      return res.status(400).json({ 
        error: `L'utilisateur avec l'ID ${assigned_by} n'existe pas dans la base de données` 
      });
    }

    console.log('✅ Found assigned_by user:', assignedByCheck.rows[0]);

    // Insertion de la tâche avec le bon assigned_by
    const taskResult = await client.query(`
      INSERT INTO tasks (title, description, type, assigned_by, due_date, priority)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `, [
      title,
      description || null,
      type,
      assigned_by, // ✅ Utiliser la valeur du frontend
      due_date || null,
      priority || 'Low'
    ]);

    const task = taskResult.rows[0];
    console.log('✅ Task created with assigned_by:', task.assigned_by);
    
    // Assigner la tâche à chaque employé sélectionné
    for (const employeeId of assignees) {
      const employeeCheck = await client.query(
        'SELECT id FROM employees WHERE id = $1', 
        [employeeId]
      );
      
      if (employeeCheck.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: `L'employé avec l'ID ${employeeId} n'existe pas` });
      }
      
      await client.query(`
        INSERT INTO task_assignments (task_id, employee_id)
        VALUES ($1, $2)
      `, [task.id, employeeId]);
    }

    await client.query('COMMIT');
    
    // Récupérer la tâche complète
    const completeTaskResult = await pool.query(`
      SELECT 
        t.*,
        assigned_by_emp.first_name as assigned_by_first_name,
        assigned_by_emp.last_name as assigned_by_last_name,
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
      LEFT JOIN employees assigned_by_emp ON t.assigned_by = assigned_by_emp.id
      LEFT JOIN task_assignments ta ON t.id = ta.task_id
      LEFT JOIN employees e ON ta.employee_id = e.id
      WHERE t.id = $1
      GROUP BY t.id, assigned_by_emp.first_name, assigned_by_emp.last_name
    `, [task.id]);

    console.log('✅ Complete task result:', completeTaskResult.rows[0]);

    res.status(201).json({
      message: 'Task created successfully',
      task: completeTaskResult.rows[0]
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Error creating task:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  } finally {
    client.release();
  }
});

// Update task status for a specific assignee
// Mettre à jour le statut d'un assigné et vérifier si la tâche est complète
// Update task status for a specific assignee - VERSION CORRIGÉE
// Update task status for a specific assignee - VERSION CORRIGÉE
// Version ultra-simplifiée (comme votre requête manuelle)
// Version ultra-simplifiée (comme votre requête manuelle)
// Version ultra-simple qui devrait marcher
app.put('/tasks/:taskId/assignees/:employeeId/status', async (req, res) => {
  try {
    const { taskId, employeeId } = req.params;
    const { status } = req.body;

    // Utilisez directement les valeurs sans paramètre pour le status
    const result = await pool.query(`
      UPDATE task_assignments 
      SET status = '${status}', 
          completed_at = CASE WHEN '${status}' = 'Completed' THEN CURRENT_TIMESTAMP ELSE completed_at END
      WHERE task_id = $1 
      AND employee_id = $2
      RETURNING *
    `, [taskId, employeeId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Assignment not found' });
    }

    res.json({
      success: true,
      message: 'Status updated successfully',
      data: result.rows[0]
    });

  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ error: error.message });
  }
});
// Get task by ID with comments
app.get('/tasks/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await pool.query(`
      SELECT 
        t.*,
        assigned_by_emp.first_name as assigned_by_first_name,
        assigned_by_emp.last_name as assigned_by_last_name,
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
      LEFT JOIN employees assigned_by_emp ON t.assigned_by = assigned_by_emp.id
      LEFT JOIN task_assignments ta ON t.id = ta.task_id
      LEFT JOIN employees e ON ta.employee_id = e.id
      WHERE t.id = $1
      GROUP BY t.id, assigned_by_emp.first_name, assigned_by_emp.last_name
    `, [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    // Filtrer les assignés nulls
    const task = result.rows[0];
    task.assignees = (task.assignees || []).filter(a => a && a.id !== null);

    // Attacher les commentaires
    const commentsRes = await pool.query(`
      SELECT 
        tc.id,
        tc.comment AS text,
        tc.created_at,
        e.first_name || ' ' || e.last_name AS author_name,
        e.id AS employee_id
      FROM task_comments tc
      JOIN employees e ON e.id = tc.employee_id
      WHERE tc.task_id = $1
      ORDER BY tc.created_at DESC
    `, [id]);
    task.comments = commentsRes.rows || [];

    // Attacher les rapports
    const reportsRes = await pool.query(`
      SELECT 
        r.id,
        r.description AS content,
        r.remarks,
        r.created_at,
        r.pdf_url,
        e.first_name || ' ' || e.last_name AS author_name,
        e.id AS employee_id
      FROM reports r
      JOIN employees e ON e.id = r.employee_id
      WHERE r.task_id = $1
      ORDER BY r.created_at DESC
    `, [id]);
    task.reports = reportsRes.rows || [];

    res.json(task);
  } catch (error) {
    console.error('Get task by ID error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create new task - version sans utilisateur connecté
// Create new task



// Update task - version simplifiée sans authentification
app.put('/tasks/:id', async (req, res) => {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    const { id } = req.params;
    const { title, description, type, priority, due_date, assigned_to } = req.body;
    
    // Vérifier que la tâche existe
    const currentTask = await client.query('SELECT * FROM tasks WHERE id = $1', [id]);
    if (currentTask.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Task not found' });
    }

    // Mettre à jour la table tasks
    const updateFields = [];
    const values = [];
    let paramCount = 1;

    if (title !== undefined) {
      updateFields.push(`title = $${paramCount}`);
      values.push(title);
      paramCount++;
    }

    if (description !== undefined) {
      updateFields.push(`description = $${paramCount}`);
      values.push(description);
      paramCount++;
    }

    if (type !== undefined) {
      updateFields.push(`type = $${paramCount}`);
      values.push(type);
      paramCount++;
    }

    if (priority !== undefined) {
      updateFields.push(`priority = $${paramCount}`);
      values.push(priority);
      paramCount++;
    }

    if (due_date !== undefined) {
      updateFields.push(`due_date = $${paramCount}`);
      values.push(due_date || null);
      paramCount++;
    }

    if (updateFields.length > 0) {
      updateFields.push(`updated_at = CURRENT_TIMESTAMP`);
      values.push(id);
      const query = `UPDATE tasks SET ${updateFields.join(', ')} WHERE id = $${paramCount} RETURNING *`;
      
      const result = await client.query(query, values);
    }

    // Si assigned_to est fourni, mettre à jour les assignations
    if (assigned_to && Array.isArray(assigned_to)) {
      // Supprimer toutes les assignations existantes
      await client.query('DELETE FROM task_assignments WHERE task_id = $1', [id]);
      
      // Ajouter les nouvelles assignations
      for (const employeeId of assigned_to) {
        // Vérifier que l'employé existe
        const employeeCheck = await client.query(
          'SELECT id FROM employees WHERE id = $1', 
          [employeeId]
        );
        
        if (employeeCheck.rows.length === 0) {
          await client.query('ROLLBACK');
          return res.status(400).json({ error: `Employee with ID ${employeeId} does not exist` });
        }
        
        await client.query(`
          INSERT INTO task_assignments (task_id, employee_id, status)
          VALUES ($1, $2, 'Pending')
        `, [id, employeeId]);
      }
    }

    await client.query('COMMIT');

    // Récupérer la tâche mise à jour avec ses assignés
    const updatedTaskResult = await pool.query(`
      SELECT 
        t.*,
        assigned_by_emp.first_name as assigned_by_first_name,
        assigned_by_emp.last_name as assigned_by_last_name,
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
      LEFT JOIN employees assigned_by_emp ON t.assigned_by = assigned_by_emp.id
      LEFT JOIN task_assignments ta ON t.id = ta.task_id
      LEFT JOIN employees e ON ta.employee_id = e.id
      WHERE t.id = $1
      GROUP BY t.id, assigned_by_emp.first_name, assigned_by_emp.last_name
    `, [id]);

    res.json({
      message: 'Task updated successfully',
      task: updatedTaskResult.rows[0]
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Update task error:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  } finally {
    client.release();
  }
});

// Delete task - version simplifiée sans authentification
app.delete('/tasks/:id', async (req, res) => {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    const { id } = req.params;
    
    // Vérifier que la tâche existe
    const currentTask = await client.query('SELECT * FROM tasks WHERE id = $1', [id]);
    if (currentTask.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Task not found' });
    }

    // Supprimer les commentaires associés
    await client.query('DELETE FROM task_comments WHERE task_id = $1', [id]);
    
    // Supprimer les assignations (déjà configuré en CASCADE dans la BD)
    await client.query('DELETE FROM task_assignments WHERE task_id = $1', [id]);
    
    // Supprimer la tâche
    const deleteResult = await client.query('DELETE FROM tasks WHERE id = $1 RETURNING *', [id]);
    
    await client.query('COMMIT');

    res.json({ 
      message: 'Task deleted successfully',
      deleted_task: deleteResult.rows[0]
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Delete task error:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  } finally {
    client.release();
  }
});

// Add comment to task - version simplifiée sans authentification
app.post('/tasks/:taskId/comments', async (req, res) => {
  try {
    const { taskId } = req.params;
    // Accept both employee_id and employeeId for compatibility
    const { comment, employee_id, employeeId } = req.body;
    const finalEmployeeId = employee_id || employeeId;

    if (!comment || !finalEmployeeId) {
      return res.status(400).json({
        success: false,
        error: 'Comment and employee ID are required',
        received: { comment: !!comment, employee_id: !!employee_id, employeeId: !!employeeId }
      });
    }

    // Verify task exists
    const taskCheck = await pool.query('SELECT id FROM tasks WHERE id = $1', [taskId]);
    if (taskCheck.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Task not found'
      });
    }

    // Verify employee exists
    const employeeCheck = await pool.query('SELECT id FROM employees WHERE id = $1', [finalEmployeeId]);
    if (employeeCheck.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Employee not found'
      });
    }

    // Insert comment
    const result = await pool.query(`
      INSERT INTO task_comments (task_id, employee_id, comment)
      VALUES ($1, $2, $3)
      RETURNING *
    `, [taskId, finalEmployeeId, comment]);

    // Get complete comment details
    const commentWithDetails = await pool.query(`
      SELECT 
        tc.id,
        tc.comment,
        tc.created_at,
        e.id as employee_id,
        e.first_name,
        e.last_name
      FROM task_comments tc
      JOIN employees e ON tc.employee_id = e.id
      WHERE tc.id = $1
    `, [result.rows[0].id]);

    res.status(201).json({
      success: true,
      comment: commentWithDetails.rows[0],
      message: 'Comment added successfully'
    });
  } catch (error) {
    console.error('Error adding comment:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to add comment',
      details: error.message
    });
  }
});

// Get task statistics for dashboard
app.get('/tasks/stats/dashboard', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        status,
        COUNT(*) as count
      FROM tasks
      GROUP BY status
    `);

    const stats = {
      pending: 0,
      in_progress: 0,
      completed: 0,
      not_done: 0
    };

    result.rows.forEach(row => {
      const status = row.status.toLowerCase().replace(' ', '_');
      stats[status] = parseInt(row.count);
    });

    res.json(stats);
  } catch (error) {
    console.error('Get task stats error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Route pour générer un UUID (optionnel)
app.get('/generate-uuid', (req, res) => {
  res.json({ uuid: uuidv4() });
});

// Error handling middleware
// Middleware de logging
// Middleware de logging - VERSION CORRIGÉE
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  
  // Vérifier que req.body existe avant d'utiliser Object.keys()
  if (req.body && Object.keys(req.body).length > 0) {
    console.log('Body:', req.body);
  }
  
  // Vérifier que req.params existe avant d'utiliser Object.keys()
  if (req.params && Object.keys(req.params).length > 0) {
    console.log('Params:', req.params);
  }
  
  next();
});
// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Task Service running on port ${PORT}`);
});
app.get('/tasks/:taskId/comments', async (req, res) => {
  try {
    const { taskId } = req.params;
    
    // Vérifier que la tâche existe
    const taskCheck = await pool.query('SELECT id FROM tasks WHERE id = $1', [taskId]);
    if (taskCheck.rows.length === 0) {
      return res.status(404).json({ 
        success: false, 
        error: 'Task not found' 
      });
    }

    // Récupérer les commentaires
    const result = await pool.query(`
      SELECT 
        tc.id,
        tc.comment,
        tc.created_at,
        e.id as employee_id,
        e.first_name,
        e.last_name
      FROM task_comments tc
      JOIN employees e ON tc.employee_id = e.id
      WHERE tc.task_id = $1
      ORDER BY tc.created_at DESC
    `, [taskId]);

    // CORRECTION : Vérifier si result.rows existe avant de l'utiliser
    const comments = result.rows || [];
    
    res.json({
      success: true,
      comments: comments // Utiliser la variable vérifiée
    });
  } catch (error) {
    console.error('Error fetching comments:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch comments'
    });
  }
});

// 2. Route POST pour ajouter un commentaire
app.post('/tasks/:taskId/comments', async (req, res) => {
  try {
    const { taskId } = req.params;
    const { comment, employeeId } = req.body;

    if (!comment || !employeeId) {
      return res.status(400).json({
        success: false,
        error: 'Comment and employee ID are required'
      });
    }

    // Vérifier si la tâche existe
    const taskCheck = await pool.query('SELECT id FROM tasks WHERE id = $1', [taskId]);
    if (taskCheck.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Task not found'
      });
    }

    // Vérifier si l'employé existe
    const employeeCheck = await pool.query('SELECT id FROM employees WHERE id = $1', [employeeId]);
    if (employeeCheck.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Employee not found'
      });
    }

    // Insérer le commentaire
    const result = await pool.query(`
      INSERT INTO task_comments (task_id, employee_id, comment)
      VALUES ($1, $2, $3)
      RETURNING *
    `, [taskId, employeeId, comment]);

    // Récupérer les informations complètes du commentaire
    const commentWithDetails = await pool.query(`
      SELECT 
        tc.id,
        tc.comment,
        tc.created_at,
        e.id as employee_id,
        e.first_name,
        e.last_name
      FROM task_comments tc
      JOIN employees e ON tc.employee_id = e.id
      WHERE tc.id = $1
    `, [result.rows[0].id]);

    res.status(201).json({
      success: true,
      comment: commentWithDetails.rows[0],
      message: 'Comment added successfully'
    });
  } catch (error) {
    console.error('Error adding comment:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to add comment'
    });
  }
});

// PUT /api/comments/:commentId - Modifier un commentaire
// PUT /api/comments/:commentId - Modifier un commentaire
// PUT /comments/:commentId - Modifier un commentaire (CORRIGÉ)
app.put('/comments/:commentId', async (req, res) => {
  try {
    const { commentId } = req.params;
    const { comment, employee_id, employeeId } = req.body;
    const finalEmployeeId = employee_id || employeeId;

    if (!comment) {
      return res.status(400).json({
        success: false,
        error: 'Comment is required'
      });
    }

    // Vérifier si le commentaire existe et appartient à l'employé
    const commentCheck = await pool.query(
      'SELECT * FROM task_comments WHERE id = $1 AND employee_id = $2',
      [commentId, finalEmployeeId]
    );

    if (commentCheck.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Comment not found or unauthorized'
      });
    }

    // Mettre à jour le commentaire
    const result = await pool.query(`
      UPDATE task_comments 
      SET comment = $1, updated_at = CURRENT_TIMESTAMP
      WHERE id = $2
      RETURNING *
    `, [comment, commentId]);

    // Récupérer les détails complets du commentaire mis à jour
    const updatedComment = await pool.query(`
      SELECT 
        tc.id,
        tc.comment,
        tc.created_at,
        tc.updated_at,
        e.id as employee_id,
        e.first_name,
        e.last_name
      FROM task_comments tc
      JOIN employees e ON tc.employee_id = e.id
      WHERE tc.id = $1
    `, [commentId]);

    res.json({
      success: true,
      comment: updatedComment.rows[0],
      message: 'Comment updated successfully'
    });
  } catch (error) {
    console.error('Error updating comment:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update comment: ' + error.message
    });
  }
});

// DELETE /comments/:commentId - Supprimer un commentaire (CORRIGÉ)
app.delete('/comments/:commentId', async (req, res) => {
  try {
    const { commentId } = req.params;
    const { employee_id, employeeId } = req.body;
    const finalEmployeeId = employee_id || employeeId;

    if (!finalEmployeeId) {
      return res.status(400).json({
        success: false,
        error: 'Employee ID is required'
      });
    }

    // Vérifier si le commentaire existe et appartient à l'employé
    const commentCheck = await pool.query(
      'SELECT * FROM task_comments WHERE id = $1 AND employee_id = $2',
      [commentId, finalEmployeeId]
    );

    if (commentCheck.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Comment not found or unauthorized'
      });
    }

    // Supprimer le commentaire
    await pool.query(
      'DELETE FROM task_comments WHERE id = $1',
      [commentId]
    );

    res.json({
      success: true,
      message: 'Comment deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting comment:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete comment: ' + error.message
    });
  }
});
app.get('/director/overview', async (req, res) => {
  try {
    // Récupérer les statistiques globales
    const employeeCount = await pool.query('SELECT COUNT(*) FROM employees');
    const taskStats = await pool.query(`
      SELECT status, COUNT(*) 
      FROM tasks 
      GROUP BY status
    `);
    const departmentStats = await pool.query(`
      SELECT d.name, COUNT(e.id) as employee_count
      FROM departments d
      LEFT JOIN employee_departments ed ON d.id = ed.department_id
      LEFT JOIN employees e ON ed.employee_id = e.id
      GROUP BY d.id, d.name
    `);
    
    res.json({
      employeeCount: employeeCount.rows[0].count,
      taskStats: taskStats.rows,
      departmentStats: departmentStats.rows
    });
  } catch (error) {
    console.error('Error fetching director overview:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});
app.get('/director/department-performance', async (req, res) => {
  try {
    const performanceData = await pool.query(`
      SELECT d.name, 
             COUNT(DISTINCT e.id) as employee_count,
             AVG(CASE WHEN ta.status = 'Completed' THEN 1 ELSE 0 END) * 100 as completion_rate
      FROM departments d
      LEFT JOIN employee_departments ed ON d.id = ed.department_id
      LEFT JOIN employees e ON ed.employee_id = e.id
      LEFT JOIN task_assignments ta ON e.id = ta.employee_id
      GROUP BY d.id, d.name
      ORDER BY completion_rate DESC
    `);
    
    res.json(performanceData.rows);
  } catch (error) {
    console.error('Error fetching department performance:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});


module.exports = app;