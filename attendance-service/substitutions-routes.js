const express = require('express');

// JWT verification middleware (will be injected)
let verifyToken;

const setAuthMiddleware = (authMiddleware) => {
  verifyToken = authMiddleware;
};

const initializeRoutes = (dbPool) => {
  const router = express.Router();
  const pool = dbPool;

  // GET /api/substitutions/invitations/mine?status=pending|accepted
  router.get('/invitations/mine', verifyToken, async (req, res) => {
    try {
      const employeeId = req.user.employeeId;
      const status = (req.query.status || 'pending').toLowerCase();
      if (!employeeId) return res.status(401).json({ error: 'Unauthorized' });

      const allowed = ['pending', 'accepted', 'dropped'];
      const filter = allowed.includes(status) ? status : 'pending';

      const result = await pool.query(
        `SELECT si.id, si.request_id, si.candidate_employee_id, si.date::text AS date,
                to_char(si.start_time, 'HH24:MI') AS start_time,
                to_char(si.end_time, 'HH24:MI') AS end_time,
                si.total_minutes, si.status, si.responded_at,
                si.grade_level, e.education_level
           FROM substitution_invitations si
           JOIN substitution_requests sr ON si.request_id = sr.id
           JOIN employees e ON sr.absent_employee_id = e.id
          WHERE si.candidate_employee_id = $1 AND si.status = $2
          ORDER BY si.date DESC, si.start_time DESC
          LIMIT 200`,
        [employeeId, filter]
      );
      res.json(result.rows);
    } catch (e) {
      console.error('Load invitations error', e);
      res.status(500).json({ error: 'Failed to load invitations', details: e.message });
    }
  });

  // POST /api/substitutions/invitations/:id/respond { action }
  // Actions: accept, deny, drop, taught
  router.post('/invitations/:id/respond', verifyToken, async (req, res) => {
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');
      
      const invitationId = req.params.id;
      const action = (req.body && req.body.action) || '';
      const userId = req.user.userId;
      const employeeId = req.user.employeeId;
      
      if (!invitationId || !action) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Missing id or action' });
      }

      console.log(`\n🔄 [INVITATION-RESPOND] Action: ${action} by user ${userId} (employee ${employeeId})`);

      // Get the invitation details
      const invResult = await client.query(
        `SELECT * FROM substitution_invitations WHERE id = $1`,
        [invitationId]
      );

      if (invResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Invitation not found' });
      }

      const invitation = invResult.rows[0];
      console.log(`   Invitation: ${invitation.date} ${invitation.start_time}-${invitation.end_time} (${invitation.total_minutes} min)`);

      // Check if user is the invited candidate
      if (invitation.candidate_employee_id !== employeeId) {
        await client.query('ROLLBACK');
        return res.status(403).json({ error: 'Not authorized to respond to this invitation' });
      }

      let message = '';
      let newStatus = invitation.status;

      switch (action) {
        case 'accept':
          if (invitation.status !== 'pending') {
            await client.query('ROLLBACK');
            return res.status(400).json({ error: 'Can only accept pending invitations' });
          }
          
          // Check if this specific time slot is already accepted by another teacher
          const existingAccepted = await client.query(
            `SELECT id FROM substitution_invitations 
             WHERE request_id = $1 AND date = $2 AND start_time = $3 AND end_time = $4 
             AND status = 'accepted' AND id != $5`,
            [invitation.request_id, invitation.date, invitation.start_time, invitation.end_time, invitationId]
          );
          
          if (existingAccepted.rows.length > 0) {
            await client.query('ROLLBACK');
            return res.status(400).json({ error: 'This specific time slot has already been accepted by another teacher' });
          }
          
          // Mark this invitation as accepted
          await client.query(
            `UPDATE substitution_invitations 
             SET status = 'accepted', responded_at = CURRENT_TIMESTAMP 
             WHERE id = $1`,
            [invitationId]
          );
          
          // Disable other invitations for the same time slot (same date, start_time, end_time)
          await client.query(
            `UPDATE substitution_invitations 
             SET status = 'disabled', responded_at = CURRENT_TIMESTAMP 
             WHERE request_id = $1 AND date = $2 AND start_time = $3 AND end_time = $4 
             AND status = 'pending' AND id != $5`,
            [invitation.request_id, invitation.date, invitation.start_time, invitation.end_time, invitationId]
          );
          
          // Note: Teachers can still accept other different time slots
          
          newStatus = 'accepted';
          message = 'Invitation accepted successfully. You can accept other available time slots.';
          console.log(`✓ [INVITATION-RESPOND] Invitation accepted for specific time slot`);
          break;

        case 'deny':
          if (invitation.status !== 'pending') {
            await client.query('ROLLBACK');
            return res.status(400).json({ error: 'Can only deny pending invitations' });
          }
          
          // Mark invitation as denied
          await client.query(
            `UPDATE substitution_invitations 
             SET status = 'denied', responded_at = CURRENT_TIMESTAMP 
             WHERE id = $1`,
            [invitationId]
          );
          
          newStatus = 'denied';
          message = 'Invitation denied';
          console.log(`✓ [INVITATION-RESPOND] Invitation denied`);
          break;

        case 'drop':
          if (invitation.status !== 'accepted') {
            await client.query('ROLLBACK');
            return res.status(400).json({ error: 'Can only drop accepted invitations' });
          }
          
          // Mark this invitation as dropped
          await client.query(
            `UPDATE substitution_invitations 
             SET status = 'dropped', responded_at = CURRENT_TIMESTAMP 
             WHERE id = $1`,
            [invitationId]
          );
          
          // Reactivate other disabled invitations for the same time slot
          const reactivateResult = await client.query(
            `UPDATE substitution_invitations 
             SET status = 'pending', responded_at = NULL 
             WHERE request_id = $1 AND date = $2 AND start_time = $3 AND end_time = $4 
             AND status = 'disabled' AND id != $5
             RETURNING id, candidate_employee_id`,
            [invitation.request_id, invitation.date, invitation.start_time, invitation.end_time, invitationId]
          );
          
          console.log(`✓ [INVITATION-RESPOND] Reactivated ${reactivateResult.rows.length} invitation(s) for the same time slot`);
          reactivateResult.rows.forEach(row => {
            console.log(`   - Reactivated invitation ${row.id} for teacher ${row.candidate_employee_id}`);
          });
          
          newStatus = 'dropped';
          message = 'Invitation dropped. Other teachers can now accept this slot again.';
          console.log(`✓ [INVITATION-RESPOND] Invitation dropped, others reactivated`);
          break;

        case 'taught':
          if (invitation.status !== 'accepted') {
            await client.query('ROLLBACK');
            return res.status(400).json({ error: 'Can only mark accepted invitations as taught' });
          }
          
          // Get the absent employee information
          const requestResult = await client.query(
            `SELECT sr.absent_employee_id as absent_employee_id, e.first_name, e.last_name
             FROM substitution_requests sr
             JOIN employees e ON sr.absent_employee_id = e.id
             WHERE sr.id = $1`,
            [invitation.request_id]
          );
          
          if (requestResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Substitution request not found' });
          }
          
          const absentEmployee = requestResult.rows[0];
          
          // Mark invitation as completed
          await client.query(
            `UPDATE substitution_invitations 
             SET status = 'taught', completed_at = CURRENT_TIMESTAMP 
             WHERE id = $1`,
            [invitationId]
          );
          
          // Add to substitution history
          await client.query(`
            INSERT INTO substitution_history
            (invitation_id, request_id, substitute_employee_id, absent_employee_id, 
             date, start_time, end_time, minutes, status, completed_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'completed', CURRENT_TIMESTAMP)
          `, [
            invitationId,
            invitation.request_id,
            employeeId,
            absentEmployee.absent_employee_id,
            invitation.date,
            invitation.start_time,
            invitation.end_time,
            invitation.total_minutes
          ]);
          
          // Calculate hours from minutes
          const hours = (invitation.total_minutes / 60).toFixed(2);
          
          // Create overtime request (auto-approved since work is already done)
          const overtimeResult = await client.query(`
            INSERT INTO overtime_requests
            (employee_id, date, requested_hours, description, submitted_by_user_id, 
             status, reviewed_by_user_id, reviewed_at, created_at)
            VALUES ($1, $2, $3, $4, $5, 'Approved', $5, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id
          `, [
            employeeId,
            invitation.date,
            hours,
            `Substitution coverage for ${absentEmployee.first_name} ${absentEmployee.last_name}: ${invitation.date} ${invitation.start_time}-${invitation.end_time}`,
            userId
          ]);

          // Add to employee_overtime_hours
          await client.query(`
            INSERT INTO employee_overtime_hours
            (employee_id, date, hours, description, created_by_user_id, created_at)
            VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)
            ON CONFLICT (employee_id, date)
            DO UPDATE SET
              hours = employee_overtime_hours.hours + EXCLUDED.hours,
              updated_at = CURRENT_TIMESTAMP
          `, [
            employeeId,
            invitation.date,
            hours,
            `Substitution for ${absentEmployee.first_name} ${absentEmployee.last_name}: ${invitation.start_time}-${invitation.end_time}`,
            userId
          ]);

          // Update monthly summary
          const dateStr = invitation.date instanceof Date ? invitation.date.toISOString().split('T')[0] : String(invitation.date);
          const [year, month] = dateStr.split('-').map(Number);
          const overtimeSummary = await client.query(`
            SELECT COALESCE(SUM(hours), 0) AS total_hours
            FROM employee_overtime_hours
            WHERE employee_id = $1 
              AND EXTRACT(YEAR FROM date) = $2 
              AND EXTRACT(MONTH FROM date) = $3
          `, [employeeId, year, month]);

          const totalHours = parseFloat(overtimeSummary.rows[0].total_hours);
          
          await client.query(`
            UPDATE employee_monthly_summaries
            SET total_overtime_hours = $1, updated_at = CURRENT_TIMESTAMP
            WHERE employee_id = $2 AND year = $3 AND month = $4
          `, [totalHours, employeeId, year, month]);

          newStatus = 'taught';
          message = `Marked as taught! ${hours} hours added to your overtime. This substitution is now in your history.`;
          console.log(`✓ [INVITATION-RESPOND] Marked as taught, ${hours} hours added to overtime and history`);
          break;

        default:
          await client.query('ROLLBACK');
          return res.status(400).json({ error: 'Invalid action. Use: accept, deny, drop, or taught' });
      }

      await client.query('COMMIT');

      res.json({
        success: true,
        message,
        invitation: {
          id: invitation.id,
          status: newStatus,
          date: invitation.date,
          start_time: invitation.start_time,
          end_time: invitation.end_time,
          total_minutes: invitation.total_minutes
        }
      });

    } catch (e) {
      await client.query('ROLLBACK');
      console.error('❌ [INVITATION-RESPOND] Error:', e);
      res.status(500).json({ error: 'Failed to respond to invitation', details: e.message });
    } finally {
      client.release();
    }
  });

  // GET /api/substitutions/requests - Get all substitution requests
  router.get('/requests', verifyToken, async (req, res) => {
    try {
      const { status } = req.query;
      let query = `
        SELECT sr.*, 
               e.first_name || ' ' || e.last_name AS employee_name,
               COUNT(si.id) AS invitations_count
        FROM substitution_requests sr
        LEFT JOIN employees e ON sr.absent_employee_id = e.id
        LEFT JOIN substitution_invitations si ON sr.id = si.request_id
      `;
      const params = [];
      if (status) {
        query += ` WHERE sr.status = $1`;
        params.push(status);
      }
      query += ` GROUP BY sr.id, e.first_name, e.last_name ORDER BY sr.date DESC, sr.start_time DESC LIMIT 200`;
      
      const result = await pool.query(query, params);
      res.json({ success: true, data: result.rows });
    } catch (e) {
      console.error('Get substitution requests error', e);
      res.status(500).json({ error: 'Failed to load requests', details: e.message });
    }
  });

  // POST /api/substitutions/requests/:requestId/create-invitations
  // Create invitations from a substitution request to candidate employees
  router.post('/requests/:requestId/create-invitations', verifyToken, async (req, res) => {
    try {
      const { requestId } = req.params;
      const { candidate_employee_ids } = req.body; // Array of employee IDs to invite
      
      if (!candidate_employee_ids || !Array.isArray(candidate_employee_ids) || candidate_employee_ids.length === 0) {
        return res.status(400).json({ error: 'Please provide candidate_employee_ids array' });
      }

      // Get the request details with grade level information
      const requestResult = await pool.query(
        `SELECT sr.id, sr.absent_employee_id, sr.date, sr.start_time, sr.end_time, sr.total_minutes, sr.status,
                sr.grade_level, e.education_level
         FROM substitution_requests sr
         JOIN employees e ON sr.absent_employee_id = e.id
         WHERE sr.id = $1`,
        [requestId]
      );

      if (requestResult.rows.length === 0) {
        return res.status(404).json({ error: 'Substitution request not found' });
      }

      const request = requestResult.rows[0];

      // Create invitations for each candidate
      const invitations = [];
      for (const candidateId of candidate_employee_ids) {
        // Check if invitation already exists
        const existing = await pool.query(
          `SELECT id FROM substitution_invitations 
           WHERE request_id = $1 AND candidate_employee_id = $2`,
          [requestId, candidateId]
        );

        if (existing.rows.length === 0) {
          const invResult = await pool.query(
            `INSERT INTO substitution_invitations 
             (request_id, candidate_employee_id, date, start_time, end_time, total_minutes, grade_level, status)
             VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending')
             RETURNING *`,
            [requestId, candidateId, request.date, request.start_time, request.end_time, request.total_minutes, request.grade_level]
          );
          invitations.push(invResult.rows[0]);
        }
      }

      res.json({
        success: true,
        message: `Created ${invitations.length} invitation(s)`,
        invitations
      });
    } catch (e) {
      console.error('Create invitations error', e);
      res.status(500).json({ error: 'Failed to create invitations', details: e.message });
    }
  });

  // POST /api/substitutions/requests/:requestId/auto-invite
  // Automatically invite all available employees in the same department
  router.post('/requests/:requestId/auto-invite', verifyToken, async (req, res) => {
    try {
      const { requestId } = req.params;

      // Get the request details and requester's department
      const requestResult = await pool.query(
        `SELECT sr.*, ed.department_id
         FROM substitution_requests sr
         LEFT JOIN employees e ON sr.absent_employee_id = e.id
         LEFT JOIN employee_departments ed ON e.id = ed.employee_id
         WHERE sr.id = $1`,
        [requestId]
      );

      if (requestResult.rows.length === 0) {
        return res.status(404).json({ error: 'Substitution request not found' });
      }

      const request = requestResult.rows[0];

      // Find all employees in the same department (excluding the requester)
      const candidatesResult = await pool.query(
        `SELECT DISTINCT e.id
         FROM employees e
         LEFT JOIN employee_departments ed ON e.id = ed.employee_id
         WHERE ed.department_id = $1 
           AND e.id != $2
           AND e.status = 'active'`,
        [request.department_id, request.absent_employee_id]
      );

      if (candidatesResult.rows.length === 0) {
        return res.status(404).json({ error: 'No available employees found in department' });
      }

      // Create invitations for all candidates
      const invitations = [];
      for (const candidate of candidatesResult.rows) {
        // Check if invitation already exists
        const existing = await pool.query(
          `SELECT id FROM substitution_invitations 
           WHERE request_id = $1 AND candidate_employee_id = $2`,
          [requestId, candidate.id]
        );

        if (existing.rows.length === 0) {
          const invResult = await pool.query(
            `INSERT INTO substitution_invitations 
             (request_id, candidate_employee_id, date, start_time, end_time, total_minutes, status)
             VALUES ($1, $2, $3, $4, $5, $6, 'pending')
             RETURNING *`,
            [requestId, candidate.id, request.date, request.start_time, request.end_time, request.total_minutes]
          );
          invitations.push(invResult.rows[0]);
        }
      }

      res.json({
        success: true,
        message: `Created ${invitations.length} invitation(s) to department colleagues`,
        invitations
      });
    } catch (e) {
      console.error('Auto-invite error', e);
      res.status(500).json({ error: 'Failed to auto-invite', details: e.message });
    }
  });

  // GET /api/substitutions/invitations/all - Get all invitations for admin management
  router.get('/invitations/all', verifyToken, async (req, res) => {
    try {
      const { status, date, teacher_id, page = 1, limit = 50 } = req.query;
      const offset = (page - 1) * limit;
      
      let whereConditions = [];
      let params = [];
      let paramIndex = 1;

      // Build WHERE clause based on filters
      if (status) {
        whereConditions.push(`si.status = $${paramIndex}`);
        params.push(status);
        paramIndex++;
      }
      
      if (date) {
        whereConditions.push(`si.date = $${paramIndex}`);
        params.push(date);
        paramIndex++;
      }
      
      if (teacher_id) {
        whereConditions.push(`si.candidate_employee_id = $${paramIndex}`);
        params.push(teacher_id);
        paramIndex++;
      }

      const whereClause = whereConditions.length > 0 ? `WHERE ${whereConditions.join(' AND ')}` : '';

      const query = `
        SELECT 
          si.id,
          si.request_id,
          si.candidate_employee_id,
          si.date::text AS date,
          to_char(si.start_time, 'HH24:MI') AS start_time,
          to_char(si.end_time, 'HH24:MI') AS end_time,
          si.total_minutes,
          si.status,
          si.responded_at,
          si.completed_at,
          si.created_at,
          si.grade_level,
          absent_emp.education_level,
          -- Absent teacher info
          absent_emp.first_name || ' ' || absent_emp.last_name AS absent_teacher_name,
          absent_emp.institution AS absent_teacher_institution,
          -- Invited teacher info
          candidate_emp.first_name || ' ' || candidate_emp.last_name AS candidate_teacher_name,
          candidate_emp.institution AS candidate_teacher_institution,
          -- Request info
          sr.absent_employee_id AS absent_employee_id
        FROM substitution_invitations si
        JOIN substitution_requests sr ON si.request_id = sr.id
        JOIN employees absent_emp ON sr.absent_employee_id = absent_emp.id
        JOIN employees candidate_emp ON si.candidate_employee_id = candidate_emp.id
        ${whereClause}
        ORDER BY si.created_at DESC
        LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
      `;

      params.push(parseInt(limit), offset);

      const result = await pool.query(query, params);

      // Get total count for pagination
      const countQuery = `
        SELECT COUNT(*) as total
        FROM substitution_invitations si
        JOIN substitution_requests sr ON si.request_id = sr.id
        JOIN employees absent_emp ON sr.absent_employee_id = absent_emp.id
        JOIN employees candidate_emp ON si.candidate_employee_id = candidate_emp.id
        ${whereClause}
      `;

      const countResult = await pool.query(countQuery, params.slice(0, -2)); // Remove limit and offset params
      const total = parseInt(countResult.rows[0].total);

      res.json({
        success: true,
        data: result.rows,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / limit)
        }
      });

    } catch (e) {
      console.error('Get all invitations error', e);
      res.status(500).json({ error: 'Failed to load invitations', details: e.message });
    }
  });

  // DELETE /api/substitutions/invitations/:id - Delete an invitation
  router.delete('/invitations/:id', verifyToken, async (req, res) => {
    try {
      const { id } = req.params;
      
      // Check if invitation exists
      const checkResult = await pool.query(
        'SELECT id, status FROM substitution_invitations WHERE id = $1',
        [id]
      );

      if (checkResult.rows.length === 0) {
        return res.status(404).json({ error: 'Invitation not found' });
      }

      const invitation = checkResult.rows[0];

      // Don't allow deleting accepted or taught invitations
      if (invitation.status === 'accepted' || invitation.status === 'taught') {
        return res.status(400).json({ 
          error: 'Cannot delete accepted or taught invitations',
          details: 'Only pending, denied, or dropped invitations can be deleted'
        });
      }

      // Delete the invitation
      await pool.query(
        'DELETE FROM substitution_invitations WHERE id = $1',
        [id]
      );

      res.json({
        success: true,
        message: 'Invitation deleted successfully'
      });

    } catch (e) {
      console.error('Delete invitation error', e);
      res.status(500).json({ error: 'Failed to delete invitation', details: e.message });
    }
  });

  // GET /api/substitutions/invitations/stats - Get invitation statistics
  router.get('/invitations/stats', verifyToken, async (req, res) => {
    try {
      const result = await pool.query(`
        SELECT 
          status,
          COUNT(*) as count
        FROM substitution_invitations
        GROUP BY status
        ORDER BY status
      `);

      const stats = {
        pending: 0,
        accepted: 0,
        taught: 0,
        denied: 0,
        dropped: 0
      };

      result.rows.forEach(row => {
        if (stats.hasOwnProperty(row.status)) {
          stats[row.status] = parseInt(row.count);
        }
      });

      res.json({
        success: true,
        data: stats
      });

    } catch (e) {
      console.error('Get invitation stats error', e);
      res.status(500).json({ error: 'Failed to load statistics', details: e.message });
    }
  });

  // GET /api/substitutions/invitations/teacher-view - Get invitations filtered for teacher view
  router.get('/invitations/teacher-view', verifyToken, async (req, res) => {
    try {
      const employeeId = req.user.employeeId;
      const { status } = req.query;
      
      if (!employeeId) return res.status(401).json({ error: 'Unauthorized' });

      // Teachers only see pending, accepted, and dropped invitations
      // They don't see disabled, denied, or taught invitations
      const allowedStatuses = ['pending', 'accepted', 'dropped'];
      const filterStatus = allowedStatuses.includes(status) ? status : 'pending';

      const result = await pool.query(
        `SELECT si.id, si.request_id, si.candidate_employee_id, si.date::text AS date,
                to_char(si.start_time, 'HH24:MI') AS start_time,
                to_char(si.end_time, 'HH24:MI') AS end_time,
                si.total_minutes, si.status, si.responded_at,
                si.grade_level, e.education_level,
                e.first_name || ' ' || e.last_name AS absent_employee_name
         FROM substitution_invitations si
         JOIN substitution_requests sr ON si.request_id = sr.id
         JOIN employees e ON sr.absent_employee_id = e.id
         WHERE si.candidate_employee_id = $1 AND si.status = $2
         ORDER BY si.date DESC, si.start_time DESC
         LIMIT 200`,
        [employeeId, filterStatus]
      );
      
      res.json(result.rows);
    } catch (e) {
      console.error('Load teacher invitations error', e);
      res.status(500).json({ error: 'Failed to load invitations', details: e.message });
    }
  });

  // GET /api/substitutions/invitations/admin-view - Get all invitations for admin view
  router.get('/invitations/admin-view', verifyToken, async (req, res) => {
    try {
      const { status, request_id } = req.query;
      
      let query = `
        SELECT si.id, si.request_id, si.candidate_employee_id, si.date::text AS date,
               to_char(si.start_time, 'HH24:MI') AS start_time,
               to_char(si.end_time, 'HH24:MI') AS end_time,
               si.total_minutes, si.status, si.responded_at, si.completed_at,
               si.grade_level, absent_e.education_level,
               e.first_name || ' ' || e.last_name AS candidate_name,
               absent_e.first_name || ' ' || absent_e.last_name AS absent_employee_name
        FROM substitution_invitations si
        JOIN employees e ON si.candidate_employee_id = e.id
        JOIN substitution_requests sr ON si.request_id = sr.id
        JOIN employees absent_e ON sr.absent_employee_id = absent_e.id
      `;
      
      const params = [];
      let paramCount = 0;
      
      if (status) {
        paramCount++;
        query += ` WHERE si.status = $${paramCount}`;
        params.push(status);
      }
      
      if (request_id) {
        paramCount++;
        query += paramCount === 1 ? ' WHERE' : ' AND';
        query += ` si.request_id = $${paramCount}`;
        params.push(request_id);
      }
      
      query += ` ORDER BY si.date DESC, si.start_time DESC, si.created_at DESC LIMIT 500`;
      
      const result = await pool.query(query, params);
      res.json(result.rows);
    } catch (e) {
      console.error('Load admin invitations error', e);
      res.status(500).json({ error: 'Failed to load invitations', details: e.message });
    }
  });

  // GET /api/substitutions/history/:employeeId - Get substitution history for an employee
  router.get('/history/:employeeId', verifyToken, async (req, res) => {
    try {
      const { employeeId } = req.params;
      const { status, start_date, end_date } = req.query;
      
      let query = `
        SELECT sh.id, sh.invitation_id, sh.request_id, sh.date::text AS date,
               to_char(sh.start_time, 'HH24:MI') AS start_time,
               to_char(sh.end_time, 'HH24:MI') AS end_time,
               sh.minutes, sh.status, sh.completed_at,
               e.first_name || ' ' || e.last_name AS substitute_name,
               absent_e.first_name || ' ' || absent_e.last_name AS absent_employee_name
        FROM substitution_history sh
        JOIN employees e ON sh.substitute_employee_id = e.id
        JOIN employees absent_e ON sh.absent_employee_id = absent_e.id
        WHERE sh.substitute_employee_id = $1
      `;
      
      const params = [employeeId];
      let paramCount = 1;
      
      if (status) {
        paramCount++;
        query += ` AND sh.status = $${paramCount}`;
        params.push(status);
      }
      
      if (start_date) {
        paramCount++;
        query += ` AND sh.date >= $${paramCount}`;
        params.push(start_date);
      }
      
      if (end_date) {
        paramCount++;
        query += ` AND sh.date <= $${paramCount}`;
        params.push(end_date);
      }
      
      query += ` ORDER BY sh.date DESC, sh.start_time DESC LIMIT 200`;
      
      const result = await pool.query(query, params);
      res.json(result.rows);
    } catch (e) {
      console.error('Load substitution history error', e);
      res.status(500).json({ error: 'Failed to load substitution history', details: e.message });
    }
  });

  // GET /api/substitutions/history/all - Get all substitution history (admin view)
  router.get('/history/all', verifyToken, async (req, res) => {
    try {
      const { status, start_date, end_date, employee_id } = req.query;
      
      let query = `
        SELECT sh.id, sh.invitation_id, sh.request_id, sh.date::text AS date,
               to_char(sh.start_time, 'HH24:MI') AS start_time,
               to_char(sh.end_time, 'HH24:MI') AS end_time,
               sh.minutes, sh.status, sh.completed_at,
               e.first_name || ' ' || e.last_name AS substitute_name,
               absent_e.first_name || ' ' || absent_e.last_name AS absent_employee_name
        FROM substitution_history sh
        JOIN employees e ON sh.substitute_employee_id = e.id
        JOIN employees absent_e ON sh.absent_employee_id = absent_e.id
        WHERE 1=1
      `;
      
      const params = [];
      let paramCount = 0;
      
      if (status) {
        paramCount++;
        query += ` AND sh.status = $${paramCount}`;
        params.push(status);
      }
      
      if (start_date) {
        paramCount++;
        query += ` AND sh.date >= $${paramCount}`;
        params.push(start_date);
      }
      
      if (end_date) {
        paramCount++;
        query += ` AND sh.date <= $${paramCount}`;
        params.push(end_date);
      }
      
      if (employee_id) {
        paramCount++;
        query += ` AND sh.substitute_employee_id = $${paramCount}`;
        params.push(employee_id);
      }
      
      query += ` ORDER BY sh.date DESC, sh.start_time DESC LIMIT 500`;
      
      const result = await pool.query(query, params);
      res.json(result.rows);
    } catch (e) {
      console.error('Load all substitution history error', e);
      res.status(500).json({ error: 'Failed to load substitution history', details: e.message });
    }
  });

  // POST /api/substitutions/invitations/:id/mark-no-show - Mark accepted invitation as no-show
  router.post('/invitations/:id/mark-no-show', verifyToken, async (req, res) => {
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');
      
      const invitationId = req.params.id;
      const userId = req.user.userId;
      const employeeId = req.user.employeeId;
      
      // Get the invitation details
      const invResult = await client.query(
        `SELECT * FROM substitution_invitations WHERE id = $1`,
        [invitationId]
      );

      if (invResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Invitation not found' });
      }

      const invitation = invResult.rows[0];
      
      if (invitation.status !== 'accepted') {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Can only mark accepted invitations as no-show' });
      }
      
      // Get the absent employee information
      const requestResult = await client.query(
        `SELECT sr.absent_employee_id as absent_employee_id, e.first_name, e.last_name
         FROM substitution_requests sr
         JOIN employees e ON sr.absent_employee_id = e.id
         WHERE sr.id = $1`,
        [invitation.request_id]
      );
      
      if (requestResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Substitution request not found' });
      }
      
      const absentEmployee = requestResult.rows[0];
      
      // Mark invitation as dropped
      await client.query(
        `UPDATE substitution_invitations 
         SET status = 'dropped', responded_at = CURRENT_TIMESTAMP 
         WHERE id = $1`,
        [invitationId]
      );
      
      // Add to substitution history as no-show
      await client.query(`
        INSERT INTO substitution_history
        (invitation_id, request_id, substitute_employee_id, absent_employee_id, 
         date, start_time, end_time, minutes, status, completed_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'no_show', CURRENT_TIMESTAMP)
      `, [
        invitationId,
        invitation.request_id,
        employeeId,
        absentEmployee.absent_employee_id,
        invitation.date,
        invitation.start_time,
        invitation.end_time,
        invitation.total_minutes
      ]);
      
      // Reactivate other disabled invitations for the same request
      await client.query(
        `UPDATE substitution_invitations 
         SET status = 'pending', responded_at = NULL 
         WHERE request_id = $1 AND status = 'disabled' AND id != $2`,
        [invitation.request_id, invitationId]
      );
      
      await client.query('COMMIT');
      
      res.json({
        success: true,
        message: 'Marked as no-show. Other teachers can now accept this slot again.',
        invitation: {
          id: invitation.id,
          status: 'dropped',
          date: invitation.date,
          start_time: invitation.start_time,
          end_time: invitation.end_time,
          total_minutes: invitation.total_minutes
        }
      });
      
    } catch (e) {
      await client.query('ROLLBACK');
      console.error('❌ [MARK-NO-SHOW] Error:', e);
      res.status(500).json({ error: 'Failed to mark as no-show', details: e.message });
    } finally {
      client.release();
    }
  });

  return router;
};

module.exports = { initializeRoutes, setAuthMiddleware };


