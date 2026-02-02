const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const pool = require('./db');

// Simple UUID validator (PostgreSQL uuid format)
function isUuid(value) {
  return typeof value === 'string' && /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$/.test(value);
}

// Dans instructions.js, correction de la création de notification
router.post('/', async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const {
      body,
      priority,
      due_at,
      created_by_user_id,
      created_by_employee_id,
      recipients
    } = req.body || {};

    if (!body || typeof body !== 'string' || !body.trim()) {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, error: 'body is required' });
    }

    const safePriority = ['low','normal','high','urgent'].includes(String(priority).toLowerCase())
      ? String(priority).toLowerCase()
      : 'normal';

    const instructionId = uuidv4();

    // Normalize creator identifiers so we never violate FK constraints
    let creatorEmployeeId = null;
    let creatorUserId = null;

    if (created_by_user_id && isUuid(created_by_user_id)) {
      creatorUserId = created_by_user_id;
    }

    if (created_by_employee_id && isUuid(created_by_employee_id)) {
      const empCheck = await client.query(
        'SELECT id FROM employees WHERE id = $1 LIMIT 1',
        [created_by_employee_id]
      );
      if (empCheck.rows.length > 0) {
        creatorEmployeeId = created_by_employee_id;
      } else {
        console.warn('[instructions] Provided created_by_employee_id not found, will try resolving via user_id', {
          created_by_employee_id
        });
      }
    }

    if (!creatorEmployeeId && creatorUserId) {
      try {
        const resolveCreator = await client.query(
          'SELECT id FROM employees WHERE user_id = $1 LIMIT 1',
          [creatorUserId]
        );
        if (resolveCreator.rows.length > 0) {
          creatorEmployeeId = resolveCreator.rows[0].id;
        }
      } catch (resolveErr) {
        console.warn('[instructions] Failed to resolve creator employee from user_id', resolveErr.message);
      }
    }

    const insertInstruction = await client.query(`
      INSERT INTO instructions (id, body, priority, due_at, created_by_user_id, created_by_employee_id)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `, [
      instructionId,
      body,
      safePriority,
      due_at || null,
      creatorUserId,
      creatorEmployeeId
    ]);

    const instruction = insertInstruction.rows[0];

    const recipientIds = Array.isArray(recipients) ? recipients : [];
    console.log('📨 Creating instruction with recipients:', recipientIds);

    if (recipientIds.length > 0) {
      for (const rawId of recipientIds) {
        try {
          let employeeIdToUse = null;

          // Case A: rawId looks like a UUID. It could be employees.id or users.id
          if (isUuid(rawId)) {
            // Try as employees.id first
            const empCheck = await client.query(`SELECT id FROM employees WHERE id = $1 LIMIT 1`, [rawId]);
            if (empCheck.rows.length > 0) {
              employeeIdToUse = empCheck.rows[0].id;
            } else {
              // Try resolving as users.id -> employees.id
              const byUser = await client.query(`SELECT id FROM employees WHERE user_id = $1 LIMIT 1`, [rawId]);
              if (byUser.rows.length > 0) {
                employeeIdToUse = byUser.rows[0].id;
              }
            }
          } else if (rawId && typeof rawId === 'string') {
            // Case B: Non-UUID string → treat as users.id and resolve to employees.id
            const byUser = await client.query(`SELECT id FROM employees WHERE user_id = $1 LIMIT 1`, [rawId]);
            if (byUser.rows.length > 0) {
              employeeIdToUse = byUser.rows[0].id;
            }
          }

          if (!employeeIdToUse) {
            console.warn('[instructions] Invalid recipient identifier. Skipping.', {
              instructionId,
              providedRecipient: rawId
            });
            continue;
          }

          // Ajouter le destinataire
          await client.query(`
            INSERT INTO instruction_recipients (instruction_id, employee_id)
            VALUES ($1, $2)
            ON CONFLICT (instruction_id, employee_id) DO NOTHING
          `, [instructionId, employeeIdToUse]);

          console.log('✅ Added instruction recipient:', employeeIdToUse);

          // CORRECTION: Créer la notification avec le bon format
          try {
            const notificationId = uuidv4();
            const notificationResult = await client.query(`
              INSERT INTO notifications(id, user_id, title, body, type, ref_type, ref_id, created_at, is_read)
              VALUES($1, $2, $3, $4, $5, $6, $7, NOW(), FALSE)
              RETURNING *
            `, [
              notificationId,
              employeeIdToUse, // user_id doit être l'employee_id
              'Nouvelle instruction',
              String(body).slice(0, 140),
              'instruction_created',
              'instruction',
              instructionId
            ]);

            console.log('✅ Created notification for recipient:', employeeIdToUse, notificationResult.rows[0]);

            // IMPORTANT: Émettre la notification en temps réel via Socket.IO
            try {
              const { Server } = require('socket.io');
              const io = req.app.get('io'); // Récupérer l'instance Socket.IO
              if (io) {
                const room = `user:${employeeIdToUse}`;
                io.to(room).emit('notification:new', notificationResult.rows[0]);
                console.log('🔊 Emitted real-time notification to room:', room);
              }
            } catch (socketError) {
              console.warn('Socket.IO emission failed:', socketError.message);
            }

          } catch (e) {
            console.error('[instructions] Failed to create notification for recipient', employeeIdToUse, e);
          }
        } catch (e) {
          console.warn('Skipping invalid recipient for instruction', instructionId, rawId, e.message);
        }
      }
    }

    await client.query('COMMIT');
    console.log('🎉 Instruction created successfully:', instructionId);
    
    res.status(201).json({ success: true, instruction_id: instructionId, instruction });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Error creating instruction:', error);
    res.status(500).json({ success: false, error: 'Failed to create instruction', details: error.message });
  } finally {
    client.release();
  }
});

// Get assigned instructions for an employee (employee or responsible)
// Dans instructions.js, amélioration de l'endpoint GET /employee/:employeeId
router.get('/employee/:employeeId', async (req, res) => {
  try {
    let { employeeId } = req.params;
    console.log('📋 Loading instructions for employee:', employeeId);

    // Step 1: normalize to an employees.id if possible
    if (!isUuid(employeeId)) {
      try {
        const resolveRes = await pool.query(
          `SELECT e.id FROM employees e WHERE e.user_id = $1 LIMIT 1`,
          [employeeId]
        );
        if (resolveRes.rows.length === 0) {
          console.warn('❌ Employee not found with user_id:', employeeId);
          return res.status(400).json({ success: false, error: 'Invalid employeeId' });
        }
        employeeId = resolveRes.rows[0].id;
        console.log('✅ Resolved user_id to employee_id:', employeeId);
      } catch (e) {
        console.error('❌ Error resolving user_id:', e);
        return res.status(400).json({ success: false, error: 'Invalid employeeId' });
      }
    }

    // Step 2: Query instructions assigned to this employee, aggregate all recipients (with names)
    let result = await pool.query(`
      SELECT 
        i.id,
        i.body,
        i.priority,
        i.due_at,
        i.status,
        i.created_by_user_id,
        i.created_by_employee_id,
        i.created_at,
        i.updated_at,
        creator.first_name as created_by_first_name,
        creator.last_name as created_by_last_name,
        COALESCE(json_agg(DISTINCT jsonb_build_object(
          'employee_id', ir_all.employee_id,
          'first_name', rec.first_name,
          'last_name', rec.last_name
        )) FILTER (WHERE ir_all.employee_id IS NOT NULL), '[]'::json) AS recipients
      FROM instruction_recipients ir
      JOIN instructions i ON i.id = ir.instruction_id
      LEFT JOIN employees creator ON i.created_by_employee_id = creator.id
      LEFT JOIN instruction_recipients ir_all ON ir_all.instruction_id = i.id
      LEFT JOIN employees rec ON rec.id = ir_all.employee_id
      WHERE ir.employee_id = $1
      AND i.status = 'active'
      GROUP BY i.id, creator.first_name, creator.last_name
      ORDER BY 
        CASE WHEN i.due_at IS NOT NULL THEN i.due_at ELSE i.created_at END DESC, 
        i.created_at DESC
    `, [employeeId]);

    console.log('📊 Found', result.rows.length, 'instructions for employee:', employeeId);

    // Step 3: Si aucune instruction trouvée et que le paramètre original était un UUID,
    // essayer de le traiter comme users.id
    if ((result.rows || []).length === 0 && isUuid(req.params.employeeId)) {
      try {
        const byUser = await pool.query(
          `SELECT e.id FROM employees e WHERE e.user_id = $1 LIMIT 1`,
          [req.params.employeeId]
        );
        if (byUser.rows.length > 0) {
          const empId = byUser.rows[0].id;
          console.log('🔄 Retry with resolved employee_id:', empId);
          
          result = await pool.query(`
            SELECT 
              i.id,
              i.body,
              i.priority,
              i.due_at,
              i.status,
              i.created_by_user_id,
              i.created_by_employee_id,
              i.created_at,
              i.updated_at,
              creator.first_name as created_by_first_name,
              creator.last_name as created_by_last_name,
              COALESCE(json_agg(DISTINCT jsonb_build_object(
                'employee_id', ir_all.employee_id,
                'first_name', rec.first_name,
                'last_name', rec.last_name
              )) FILTER (WHERE ir_all.employee_id IS NOT NULL), '[]'::json) AS recipients
            FROM instruction_recipients ir
            JOIN instructions i ON i.id = ir.instruction_id
            LEFT JOIN employees creator ON i.created_by_employee_id = creator.id
            LEFT JOIN instruction_recipients ir_all ON ir_all.instruction_id = i.id
            LEFT JOIN employees rec ON rec.id = ir_all.employee_id
            WHERE ir.employee_id = $1
            AND i.status = 'active'
            GROUP BY i.id, creator.first_name, creator.last_name
            ORDER BY 
              CASE WHEN i.due_at IS NOT NULL THEN i.due_at ELSE i.created_at END DESC, 
              i.created_at DESC
          `, [empId]);
          
          console.log('📊 Retry found', result.rows.length, 'instructions');
        }
      } catch (e) {
        console.warn('🔄 Retry failed:', e.message);
      }
    }

    res.json({ success: true, instructions: result.rows });
  } catch (error) {
    console.error('❌ Error fetching instructions for employee:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch instructions', 
      details: error.message 
    });
  }
});

// Acknowledge an instruction assignment
router.put('/:instructionId/acknowledge', async (req, res) => {
  try {
    const { instructionId } = req.params;
    const { employee_id } = req.body || {};

    if (!isUuid(instructionId) || !isUuid(employee_id)) {
      return res.status(400).json({ success: false, error: 'Invalid ids' });
    }

    const r = await pool.query(`
      UPDATE instruction_recipients
      SET acknowledged = true, acknowledged_at = NOW()
      WHERE instruction_id = $1 AND employee_id = $2
      RETURNING *
    `, [instructionId, employee_id]);

    if (r.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Assignment not found' });
    }

    res.json({ success: true, assignment: r.rows[0] });
  } catch (error) {
    console.error('Error acknowledging instruction:', error);
    res.status(500).json({ success: false, error: 'Failed to acknowledge instruction', details: error.message });
  }
});

// Mark an instruction assignment as completed
router.put('/:instructionId/complete', async (req, res) => {
  try {
    const { instructionId } = req.params;
    const { employee_id, completed } = req.body || {};

    if (!isUuid(instructionId) || !isUuid(employee_id)) {
      return res.status(400).json({ success: false, error: 'Invalid ids' });
    }

    const setCompleted = String(completed) === 'false' ? false : true;

    const r = await pool.query(`
      UPDATE instruction_recipients
      SET completed = $3, completed_at = CASE WHEN $3 THEN NOW() ELSE NULL END
      WHERE instruction_id = $1 AND employee_id = $2
      RETURNING *
    `, [instructionId, employee_id, setCompleted]);

    if (r.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Assignment not found' });
    }

    res.json({ success: true, assignment: r.rows[0] });
  } catch (error) {
    console.error('Error completing instruction:', error);
    res.status(500).json({ success: false, error: 'Failed to complete instruction', details: error.message });
  }
});

// Optional: archive/cancel an instruction (director/admin)
router.put('/:instructionId/status', async (req, res) => {
  try {
    const { instructionId } = req.params;
    const { status } = req.body || {};

    const allowed = ['active','archived','cancelled'];
    if (!isUuid(instructionId) || !allowed.includes(String(status).toLowerCase())) {
      return res.status(400).json({ success: false, error: 'Invalid parameters' });
    }

    const r = await pool.query(`
      UPDATE instructions SET status = $2, updated_at = NOW() WHERE id = $1 RETURNING *
    `, [instructionId, String(status).toLowerCase()]);

    if (!r.rows.length) {
      return res.status(404).json({ success: false, error: 'Instruction not found' });
    }

    res.json({ success: true, instruction: r.rows[0] });
  } catch (error) {
    console.error('Error updating instruction status:', error);
    res.status(500).json({ success: false, error: 'Failed to update instruction status', details: error.message });
  }
});

// List instructions created by a given director/creator
// Accepts either employees.id or users.id in :id
router.get('/created-by/:id', async (req, res) => {
  try {
    let { id } = req.params;
    let employeeId = null;
    let userId = null;

    // If it's a UUID, it could be either users.id or employees.id. Try resolving both.
    if (isUuid(id)) {
      // First assume employees.id
      const empCheck = await pool.query(`SELECT id, user_id FROM employees WHERE id = $1 LIMIT 1`, [id]);
      if (empCheck.rows.length > 0) {
        employeeId = empCheck.rows[0].id;
        userId = empCheck.rows[0].user_id || null;
      } else {
        // Otherwise treat it as users.id and resolve to employees.id
        const byUser = await pool.query(`SELECT id FROM employees WHERE user_id = $1 LIMIT 1`, [id]);
        if (byUser.rows.length > 0) {
          employeeId = byUser.rows[0].id;
          userId = id;
        } else {
          // Still return empty list gracefully
          return res.json({ success: true, instructions: [] });
        }
      }
    } else {
      // Non-UUID → treat as users.id string
      const byUser = await pool.query(`SELECT id FROM employees WHERE user_id = $1 LIMIT 1`, [id]);
      if (byUser.rows.length > 0) {
        employeeId = byUser.rows[0].id;
        userId = id;
      } else {
        return res.json({ success: true, instructions: [] });
      }
    }

    const result = await pool.query(`
      SELECT 
        i.id,
        i.body,
        i.priority,
        i.due_at,
        i.status,
        i.created_by_user_id,
        i.created_by_employee_id,
        i.created_at,
        i.updated_at,
        COALESCE(json_agg(
          DISTINCT jsonb_build_object(
            'employee_id', ir.employee_id,
            'assigned_at', ir.assigned_at,
            'acknowledged', ir.acknowledged,
            'acknowledged_at', ir.acknowledged_at,
            'completed', ir.completed,
            'completed_at', ir.completed_at
          )
        ) FILTER (WHERE ir.employee_id IS NOT NULL), '[]'::json) AS recipients
      FROM instructions i
      LEFT JOIN instruction_recipients ir ON ir.instruction_id = i.id
      WHERE (i.created_by_employee_id = $1) OR (i.created_by_user_id = $2)
      GROUP BY i.id
      ORDER BY COALESCE(i.due_at, i.created_at) DESC, i.created_at DESC
    `, [employeeId, userId]);

    res.json({ success: true, instructions: result.rows });
  } catch (error) {
    console.error('Error fetching created instructions:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch created instructions', details: error.message });
  }
});

module.exports = router;


