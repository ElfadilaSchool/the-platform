const multer = require('multer');
const mime = require('mime-types');
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const moment = require('moment-timezone');

module.exports = function registerPayslipRoutes(app, pool, verifyToken, requireRole) {
  // Storage dir
  const PAYSLIPS_DIR = path.join(__dirname, 'uploads', 'payslips');
  if (!fs.existsSync(PAYSLIPS_DIR)) {
    fs.mkdirSync(PAYSLIPS_DIR, { recursive: true });
  }

  // Multer config
  const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, PAYSLIPS_DIR),
    filename: (req, file, cb) => {
      const safeName = file.originalname.replace(/[^A-Za-z0-9_.-]/g, '_');
      const timestamp = Date.now();
      cb(null, `${timestamp}-${safeName}`);
    }
  });

  const upload = multer({
    storage,
    limits: { files: 2000, fileSize: 25 * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
      const mimeType = file.mimetype || mime.lookup(file.originalname) || '';
      if (mimeType === 'application/pdf' || file.originalname.toLowerCase().endsWith('.pdf')) cb(null, true);
      else cb(new Error('Only PDF files are allowed'));
    }
  });

  // Helpers
  const normalize = (str) => (str || '')
    .toLowerCase()
    .normalize('NFD').replace(/\p{Diacritic}/gu, '')
    .replace(/[^a-z0-9]+/g, '')
    .trim();

  const extractNameTokensFromFilename = (filename) => {
    const base = path.parse(filename).name;
    const cleaned = base.replace(/\b(20\d{2}|19\d{2})\b/g, '').replace(/\b(0?[1-9]|1[0-2])\b/g, '');
    const tokens = cleaned.split(/[^A-Za-z]+/).filter(Boolean);
    return tokens.map(t => normalize(t));
  };

  const buildCandidateKeys = (firstName, lastName, foreignFirst, foreignLast) => {
    const keys = new Set();
    const f = normalize(firstName);
    const l = normalize(lastName);
    const ff = normalize(foreignFirst);
    const fl = normalize(foreignLast);
    [f + l, l + f, `${f}${l}`, `${l}${f}`].forEach(c => c && keys.add(c));
    if (ff || fl) { const ffc = ff + fl; const flc = fl + ff; if (ffc) keys.add(ffc); if (flc) keys.add(flc); }
    return keys;
  };

  async function insertUploadRecord(client, fileInfo, userId) {
    const id = uuidv4();
    const query = `
      INSERT INTO uploads (id, file_name, original_name, mime_type, file_size, storage_path, storage_type, uploader_user_id)
      VALUES ($1, $2, $3, $4, $5, $6, 'file', $7)
      RETURNING *
    `;
    const params = [
      id,
      path.basename(fileInfo.filename),
      fileInfo.originalname,
      'application/pdf',
      fileInfo.size,
      path.relative(process.cwd(), fileInfo.path).replace(/\\/g, '/'),
      userId
    ];
    const result = await client.query(query, params);
    return result.rows[0];
  }

  // Upload batch
  app.post('/payslips/upload-batch', verifyToken, requireRole(['HR_Manager', 'Director']), upload.array('files', 2000), async (req, res) => {
    const client = await pool.connect();
    try {
      const { month, year } = req.body;
      const parsedMonth = parseInt(month, 10);
      const parsedYear = parseInt(year, 10);
      if (!parsedMonth || !parsedYear) return res.status(400).json({ error: 'month and year are required' });
      if (!req.files || req.files.length === 0) return res.status(400).json({ error: 'No files uploaded' });

      await client.query('BEGIN');
      const batchId = uuidv4();
      await client.query(`
        INSERT INTO payslip_batches (id, month, year, uploaded_by_user_id, total_files)
        VALUES ($1, $2, $3, $4, $5)
      `, [batchId, parsedMonth, parsedYear, req.user.userId, req.files.length]);

      const empRes = await client.query(`
        SELECT e.id, e.first_name, e.last_name, e.foreign_name, e.foreign_last_name
        FROM employees e
      `);
      const employees = empRes.rows.map(e => ({ ...e, keys: buildCandidateKeys(e.first_name, e.last_name, e.foreign_name, e.foreign_last_name) }));

      const results = [];
      for (const file of req.files) {
        const uploadRow = await insertUploadRecord(client, file, req.user.userId);
        const tokens = extractNameTokensFromFilename(file.originalname);
        const tokenKey = tokens.join('');
        let matched = null; let confidence = 0;
        for (const emp of employees) {
          for (const key of emp.keys) {
            if (!key) continue;
            if (tokenKey.includes(key) || key.includes(tokenKey)) { matched = emp; confidence = Math.max(confidence, 0.9); break; }
            const overlap = Math.min(key.length, tokenKey.length);
            if (overlap >= 4 && (tokenKey.startsWith(key) || tokenKey.endsWith(key))) { matched = emp; confidence = Math.max(confidence, 0.7); }
          }
          if (matched) break;
        }

        const payslipId = uuidv4();
        if (matched) {
          await client.query(`
            INSERT INTO payslips (id, employee_id, month, year, upload_id, status, matched_confidence, batch_id)
            VALUES ($1, $2, $3, $4, $5, 'uploaded', $6, $7)
            ON CONFLICT (employee_id, month, year)
            DO UPDATE SET upload_id = EXCLUDED.upload_id, status = 'uploaded', matched_confidence = EXCLUDED.matched_confidence, batch_id = EXCLUDED.batch_id, updated_at = CURRENT_TIMESTAMP
          `, [payslipId, matched.id, parsedMonth, parsedYear, uploadRow.id, confidence, batchId]);
          results.push({ original_name: file.originalname, employee_id: matched.id, status: 'uploaded', confidence });
        } else {
          await client.query(`
            INSERT INTO payslips (id, employee_id, month, year, upload_id, status, matched_confidence, batch_id)
            VALUES ($1, NULL, $2, $3, $4, 'unmatched', 0, $5)
          `, [payslipId, parsedMonth, parsedYear, uploadRow.id, batchId]);
          results.push({ original_name: file.originalname, employee_id: null, status: 'unmatched', confidence: 0 });
        }
      }

      await client.query('COMMIT');
      res.json({ success: true, batch_id: batchId, uploaded: req.files.length, results });
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('Error uploading payslips batch:', error);
      res.status(500).json({ error: 'Failed to upload payslips', details: error.message });
    } finally { client.release(); }
  });

  // Admin list
  app.get('/payslips/admin', verifyToken, requireRole(['HR_Manager', 'Director']), async (req, res) => {
    try {
      const month = parseInt(req.query.month || (moment().month() + 1), 10);
      const year = parseInt(req.query.year || moment().year(), 10);
      const { employee, department, page = 1, limit = 50 } = req.query;
      const offset = (page - 1) * limit;
      const params = [month, year];
      let idx = params.length + 1;
      let base = `
        SELECT 
          e.id as employee_id,
          e.first_name || ' ' || e.last_name AS employee_name,
          d.name AS department_name,
          psl.id AS payslip_id,
          psl.status,
          upl.storage_path,
          upl.original_name
        FROM employees e
        LEFT JOIN employee_departments ed ON e.id = ed.employee_id
        LEFT JOIN departments d ON ed.department_id = d.id
        LEFT JOIN payslips psl ON psl.employee_id = e.id AND psl.month = $1 AND psl.year = $2
        LEFT JOIN uploads upl ON psl.upload_id = upl.id
        WHERE 1=1
      `;
      if (employee) { base += ` AND e.id = $${idx++}`; params.push(employee); }
      if (department) { base += ` AND d.id = $${idx++}`; params.push(department); }
      base += ` ORDER BY e.first_name, e.last_name LIMIT $${idx++} OFFSET $${idx}`;
      params.push(limit, offset);
      const rows = await pool.query(base, params);
      res.json({ success: true, month, year, items: rows.rows });
    } catch (error) {
      console.error('Error listing payslips for admin:', error);
      res.status(500).json({ error: 'Failed to list payslips' });
    }
  });

  // Admin employee detail
  app.get('/payslips/admin/:employeeId', verifyToken, requireRole(['HR_Manager', 'Director']), async (req, res) => {
    try {
      const { employeeId } = req.params;
      const { start_month, start_year } = req.query;
      const empRes = await pool.query(`SELECT join_date FROM employees WHERE id = $1`, [employeeId]);
      if (empRes.rows.length === 0) return res.status(404).json({ error: 'Employee not found' });
      const joinDate = empRes.rows[0].join_date ? new Date(empRes.rows[0].join_date) : new Date('2020-01-01');
      let from = joinDate;
      if (start_year && start_month) {
        from = new Date(parseInt(start_year, 10), parseInt(start_month, 10) - 1, 1);
      } else if (start_year && !start_month) {
        from = new Date(parseInt(start_year, 10), 0, 1);
      } else if (!start_year && start_month) {
        from = new Date(joinDate.getFullYear(), parseInt(start_month, 10) - 1, 1);
      }
      const to = new Date();
      const items = [];
      let cursor = new Date(from.getFullYear(), from.getMonth(), 1);
      while (cursor <= to) {
        const m = cursor.getMonth() + 1; const y = cursor.getFullYear();
        const row = await pool.query(`
          SELECT p.id as payslip_id, p.status, u.storage_path, u.original_name
          FROM payslips p
          LEFT JOIN uploads u ON p.upload_id = u.id
          WHERE p.employee_id = $1 AND p.month = $2 AND p.year = $3
        `, [employeeId, m, y]);
        items.push({ month: m, year: y, file: row.rows[0]?.storage_path || null, payslip_id: row.rows[0]?.payslip_id || null, status: row.rows[0]?.status || 'not_uploaded' });
        cursor.setMonth(cursor.getMonth() + 1);
      }
      res.json({ success: true, items });
    } catch (error) {
      console.error('Error listing employee payslips detail:', error);
      res.status(500).json({ error: 'Failed to list employee payslips' });
    }
  });

  // Employee self list
  app.get('/payslips/me', verifyToken, requireRole(['Employee', 'Department_Responsible', 'HR_Manager']), async (req, res) => {
    try {
      const userId = req.user.userId;
      const empRes = await pool.query(`SELECT id, join_date FROM employees WHERE user_id = $1`, [userId]);
      if (empRes.rows.length === 0) return res.status(404).json({ error: 'Employee record not found' });
      const employeeId = empRes.rows[0].id;
      const joinDate = empRes.rows[0].join_date ? new Date(empRes.rows[0].join_date) : new Date('2020-01-01');
      const to = new Date();
      const { year, month } = req.query;
      const items = [];
      let cursor = new Date(joinDate.getFullYear(), joinDate.getMonth(), 1);
      while (cursor <= to) {
        const m = cursor.getMonth() + 1; const y = cursor.getFullYear();
        if (!year || parseInt(year, 10) === y) {
          if (!month || parseInt(month, 10) === m) {
            const row = await pool.query(`
              SELECT p.id as payslip_id, p.status, u.storage_path, u.original_name
              FROM payslips p
              LEFT JOIN uploads u ON p.upload_id = u.id
              WHERE p.employee_id = $1 AND p.month = $2 AND p.year = $3
            `, [employeeId, m, y]);
            items.push({ month: m, year: y, file: row.rows[0]?.storage_path || null, payslip_id: row.rows[0]?.payslip_id || null, status: row.rows[0]?.status || 'not_uploaded' });
          }
        }
        cursor.setMonth(cursor.getMonth() + 1);
      }
      res.json({ success: true, items });
    } catch (error) {
      console.error('Error listing my payslips:', error);
      res.status(500).json({ error: 'Failed to list payslips' });
    }
  });

  // Download
  app.get('/payslips/download/:payslipId', verifyToken, async (req, res) => {
    try {
      const { payslipId } = req.params;
      const row = await pool.query(`
        SELECT p.employee_id, u.storage_path, u.original_name
        FROM payslips p
        JOIN uploads u ON p.upload_id = u.id
        WHERE p.id = $1
      `, [payslipId]);
      if (row.rows.length === 0) return res.status(404).json({ error: 'Not found' });
      const rec = row.rows[0];
      const isAdmin = req.user?.role === 'HR_Manager' || req.user?.role === 'Director' || req.user?.role === 'Department_Responsible';
      let isOwner = false;
      if (!isAdmin) {
        const owner = await pool.query(`SELECT id FROM employees WHERE user_id = $1`, [req.user.userId]);
        isOwner = owner.rows[0]?.id === rec.employee_id;
      }
      if (!isAdmin && !isOwner) return res.status(403).json({ error: 'Forbidden' });
      const absPath = path.isAbsolute(rec.storage_path) ? rec.storage_path : path.join(process.cwd(), rec.storage_path);
      if (!fs.existsSync(absPath)) return res.status(404).json({ error: 'File missing' });
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename="${rec.original_name || 'payslip.pdf'}"`);
      fs.createReadStream(absPath).pipe(res);
    } catch (error) {
      console.error('Error downloading payslip:', error);
      res.status(500).json({ error: 'Failed to download' });
    }
  });
};


