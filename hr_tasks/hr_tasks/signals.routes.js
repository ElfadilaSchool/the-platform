const express = require('express');
const pool = require('./db');
const path = require('path');
const fs = require('fs');
let multer;
try { multer = require('multer'); } catch (_) { /* multer optional */ }
if (!multer) {
  console.warn('[signals] multer not installed; photo uploads & multipart fields will be ignored');
}

const router = express.Router();
const complaintsRouter = express.Router();
const suggestionsRouter = express.Router();
const directorRouter = express.Router();

function buildSignalFilters(query = {}) {
  const { from, to, typeId, priority, status } = query;
  const clauses = [];
  const values = [];
  let idx = 1;

  if (from) {
    clauses.push(`s.created_at >= $${idx++}`);
    values.push(from);
  }
  if (to) {
    clauses.push(`s.created_at <= $${idx++}`);
    values.push(to);
  }
  if (typeId) {
    clauses.push(`s.type_id = $${idx++}`);
    values.push(typeId);
  }
  if (priority) {
    clauses.push(`s.priority = $${idx++}`);
    values.push(priority);
  }
  if (status === 'pending') {
    clauses.push(`s.is_treated = false`);
  } else if (status === 'treated') {
    clauses.push(`s.is_treated = true`);
  }

  const whereClause = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
  return { whereClause, values };
}

function buildSuggestionFilters(query = {}) {
  const { from, to, departmentId, status } = query;
  const clauses = [];
  const values = [];
  let idx = 1;

  if (from) {
    clauses.push(`s.created_at >= $${idx++}`);
    values.push(from);
  }
  if (to) {
    clauses.push(`s.created_at <= $${idx++}`);
    values.push(to);
  }
  if (departmentId) {
    clauses.push(`s.department_id = $${idx++}`);
    values.push(departmentId);
  }
  if (status) {
    clauses.push(`s.status = $${idx++}`);
    values.push(status);
  }

  const whereClause = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
  return { whereClause, values };
}

const uploadDir = path.join(__dirname, 'public', 'uploads', 'signalisations');
const complaintsUploadDir = path.join(__dirname, 'public', 'uploads', 'complaints');
const suggestionsUploadDir = path.join(__dirname, 'public', 'uploads', 'suggestions');
try { if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true }); } catch (_) { }
try { if (!fs.existsSync(complaintsUploadDir)) fs.mkdirSync(complaintsUploadDir, { recursive: true }); } catch (_) { }
try { if (!fs.existsSync(suggestionsUploadDir)) fs.mkdirSync(suggestionsUploadDir, { recursive: true }); } catch (_) { }

let upload = (req, res, next) => next();
let attachmentUpload = (req, res, next) => next();
let multiAttachmentUpload = (req, res, next) => next();
let suggestionAttachmentUpload = (req, res, next) => next();
if (multer) {
  const storage = multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, uploadDir),
    filename: (_req, file, cb) => {
      const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
      const ext = path.extname(file.originalname || '').toLowerCase();
      cb(null, unique + ext);
    }
  });
  upload = multer({ storage }).single('photo');

  const complaintStorage = multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, complaintsUploadDir),
    filename: (_req, file, cb) => {
      const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
      const ext = path.extname(file.originalname || '').toLowerCase();
      cb(null, unique + ext);
    }
  });
  attachmentUpload = multer({ storage: complaintStorage }).single('attachment');
  multiAttachmentUpload = multer({ storage: complaintStorage }).array('attachments', 5);

  const suggestionStorage = multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, suggestionsUploadDir),
    filename: (_req, file, cb) => {
      const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
      const ext = path.extname(file.originalname || '').toLowerCase();
      cb(null, unique + ext);
    }
  });
  suggestionAttachmentUpload = multer({ storage: suggestionStorage }).array('attachments', 5);
}

async function ensureSignalsSchema() {
  await pool.query(`
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

    CREATE TABLE IF NOT EXISTS public.signal_types (
      id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
      code text UNIQUE NOT NULL,
      name text NOT NULL,
      created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    -- Localisations master data
    CREATE TABLE IF NOT EXISTS public.localisations
    (
      id uuid NOT NULL DEFAULT uuid_generate_v4(),
      code_emplacement text NOT NULL,
      batiment text NOT NULL,
      etage text NOT NULL,
      description_fr text,
      description_ar text,
      type_local text,
      type_local_custom text,
      created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT localisations_pkey PRIMARY KEY (id),
      CONSTRAINT localisations_code_emplacement_key UNIQUE (code_emplacement),
      CONSTRAINT localisations_type_local_check CHECK (type_local = ANY (ARRAY['salle','bureau','sanitaire','laboratoire','salle_informatique','atelier','restaurant','stockage','autre']))
    );
    CREATE INDEX IF NOT EXISTS idx_localisations_batiment
      ON public.localisations(batiment ASC NULLS LAST, etage ASC NULLS LAST);
    CREATE INDEX IF NOT EXISTS idx_localisations_code
      ON public.localisations(code_emplacement ASC NULLS LAST);

    CREATE TABLE IF NOT EXISTS public.signal_type_responsibles (
      type_id uuid NOT NULL REFERENCES public.signal_types(id) ON DELETE CASCADE,
      employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
      assigned_by uuid REFERENCES public.employees(id) ON DELETE SET NULL,
      assigned_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (type_id, employee_id)
    );
    CREATE INDEX IF NOT EXISTS idx_signal_type_responsibles_employee
      ON public.signal_type_responsibles(employee_id);

    CREATE TABLE IF NOT EXISTS public.signalisations (
      id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
      type_id uuid NOT NULL REFERENCES public.signal_types(id) ON DELETE RESTRICT,
      created_by uuid NOT NULL REFERENCES public.employees(id) ON DELETE RESTRICT,
      title text NOT NULL,
      description text,
      location text,
      localisation_id uuid NULL,
      photo_path text,
      is_viewed boolean NOT NULL DEFAULT false,
      is_treated boolean NOT NULL DEFAULT false,
      treated_by uuid REFERENCES public.employees(id) ON DELETE SET NULL,
      treated_at timestamp,
      created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    -- Ensure new column and FK exist in case table pre-existed
    DO $$ BEGIN
      BEGIN
        -- Backward compatibility: some databases may miss 'location' text column
        ALTER TABLE public.signalisations
          ADD COLUMN IF NOT EXISTS location text;
      EXCEPTION WHEN duplicate_column THEN NULL; END;
      BEGIN
        ALTER TABLE public.signalisations
          ADD COLUMN localisation_id uuid NULL;
      EXCEPTION WHEN duplicate_column THEN NULL; END;
      BEGIN
        ALTER TABLE public.signalisations
          ADD CONSTRAINT signalisations_localisation_id_fkey
          FOREIGN KEY (localisation_id) REFERENCES public.localisations(id) ON DELETE SET NULL;
      EXCEPTION WHEN duplicate_object THEN NULL; END;
      BEGIN
        ALTER TABLE public.signalisations
          ADD COLUMN IF NOT EXISTS priority text NOT NULL DEFAULT 'medium'
            CHECK (priority = ANY (ARRAY['low','medium','high']));
      EXCEPTION WHEN duplicate_column THEN NULL; END;
      BEGIN
        ALTER TABLE public.signalisations
          ADD COLUMN IF NOT EXISTS satisfaction_rating integer
            CHECK (satisfaction_rating BETWEEN 1 AND 5);
      EXCEPTION WHEN duplicate_column THEN NULL; END;
      BEGIN
        ALTER TABLE public.signalisations
          ADD COLUMN IF NOT EXISTS feedback text;
      EXCEPTION WHEN duplicate_column THEN NULL; END;
      BEGIN
        -- Ensure optional custom type column exists
        ALTER TABLE public.localisations
          ADD COLUMN IF NOT EXISTS type_local_custom text;
      EXCEPTION WHEN duplicate_column THEN NULL; END;
    END $$;

    CREATE INDEX IF NOT EXISTS idx_signalisations_type_created ON public.signalisations(type_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_signalisations_created_by ON public.signalisations(created_by, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_signalisations_status ON public.signalisations(is_treated, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_signalisations_localisation_id ON public.signalisations(localisation_id);

    CREATE TABLE IF NOT EXISTS public.signalisations_views (
      signalisation_id uuid NOT NULL REFERENCES public.signalisations(id) ON DELETE CASCADE,
      viewer_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
      viewed_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (signalisation_id, viewer_id)
    );
    CREATE INDEX IF NOT EXISTS idx_signalisations_views_viewer ON public.signalisations_views(viewer_id);
    CREATE TABLE IF NOT EXISTS public.signalisations_status_history (
      id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
      signalisation_id uuid NOT NULL REFERENCES public.signalisations(id) ON DELETE CASCADE,
      status text NOT NULL,
      changed_by uuid REFERENCES public.employees(id),
      note text,
      changed_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    INSERT INTO public.signal_types (code, name) VALUES
      ('FURNITURE', 'الاثاث و التجهيزات'),
      ('ELECTRICITY_SIGNAL', 'الكهرباء و الاشارة'),
      ('TECH_IT', 'الاجهزة التقنية و الاعلام الالي'),
      ('WATER', 'الماء'),
      ('CLEANLINESS', 'النظافة مشاكل او اقتراحات')
    ON CONFLICT (code) DO NOTHING;

    CREATE TABLE IF NOT EXISTS public.complaint_types (
      id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
      code text UNIQUE NOT NULL,
      name text NOT NULL,
      created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS public.complaints (
      id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
      employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
      type_id uuid NOT NULL REFERENCES public.complaint_types(id) ON DELETE RESTRICT,
      title text NOT NULL,
      description text,
      priority text NOT NULL DEFAULT 'medium' CHECK (priority = ANY(ARRAY['low','medium','high'])),
      is_anonymous boolean NOT NULL DEFAULT false,
      status text NOT NULL DEFAULT 'pending' CHECK (status = ANY(ARRAY['pending','completed'])),
      manager_comment text,
      handled_by uuid REFERENCES public.employees(id),
      department_id uuid REFERENCES public.departments(id),
      due_date timestamp,
      is_overdue boolean GENERATED ALWAYS AS (
        CASE WHEN status = 'pending' AND due_date IS NOT NULL AND due_date < CURRENT_TIMESTAMP THEN true ELSE false END
      ) STORED,
      satisfaction_rating integer CHECK (satisfaction_rating BETWEEN 1 AND 5),
      feedback text,
      resolved_at timestamp,
      created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
      completed_at timestamp
    );
    DO $$ BEGIN
      BEGIN
        ALTER TABLE public.complaints
          ADD COLUMN IF NOT EXISTS due_date timestamp;
      EXCEPTION WHEN duplicate_column THEN NULL; END;
      BEGIN
        ALTER TABLE public.complaints
          ADD COLUMN IF NOT EXISTS resolved_at timestamp;
      EXCEPTION WHEN duplicate_column THEN NULL; END;
      BEGIN
        ALTER TABLE public.complaints
          ADD COLUMN IF NOT EXISTS satisfaction_rating integer;
      EXCEPTION WHEN duplicate_column THEN NULL; END;
      BEGIN
        ALTER TABLE public.complaints
          ADD COLUMN IF NOT EXISTS feedback text;
      EXCEPTION WHEN duplicate_column THEN NULL; END;
      BEGIN
        ALTER TABLE public.complaints
          ADD COLUMN IF NOT EXISTS department_id uuid REFERENCES public.departments(id);
      EXCEPTION WHEN duplicate_column THEN NULL; END;
    END $$;
    UPDATE public.complaints
      SET due_date = CASE
        WHEN priority = 'high' THEN created_at + INTERVAL '24 hours'
        WHEN priority = 'low' THEN created_at + INTERVAL '168 hours'
        ELSE created_at + INTERVAL '72 hours'
      END
    WHERE due_date IS NULL;
    CREATE INDEX IF NOT EXISTS idx_complaints_employee ON public.complaints(employee_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_complaints_status ON public.complaints(status, created_at DESC);

    CREATE TABLE IF NOT EXISTS public.complaint_messages (
      id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
      complaint_id uuid NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
      sender_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
      sender_role text NOT NULL CHECK (sender_role = ANY(ARRAY['employee','director'])),
      body text NOT NULL,
      created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX IF NOT EXISTS idx_complaint_messages_complaint ON public.complaint_messages(complaint_id, created_at ASC);

    CREATE TABLE IF NOT EXISTS public.complaint_history (
      id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
      complaint_id uuid NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
      changed_by uuid NOT NULL REFERENCES public.employees(id),
      old_status text,
      new_status text,
      comment text,
      created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX IF NOT EXISTS idx_complaint_history_complaint ON public.complaint_history(complaint_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS public.complaint_notifications (
      id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
      complaint_id uuid NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
      recipient_id uuid REFERENCES public.employees(id),
      recipient_user_id uuid REFERENCES public.users(id),
      message text NOT NULL,
      title text,
      is_read boolean NOT NULL DEFAULT false,
      created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    DO $$ BEGIN
      BEGIN
        ALTER TABLE public.complaint_notifications
          ADD COLUMN IF NOT EXISTS title text;
      EXCEPTION WHEN duplicate_column THEN NULL; END;
      BEGIN
        ALTER TABLE public.complaint_notifications
          ADD COLUMN IF NOT EXISTS recipient_user_id uuid REFERENCES public.users(id);
      EXCEPTION WHEN duplicate_column THEN NULL; END;
      BEGIN
        ALTER TABLE public.complaint_notifications
          ALTER COLUMN recipient_id DROP NOT NULL;
      EXCEPTION WHEN undefined_column THEN NULL;
        WHEN others THEN NULL;
      END;
    END $$;
    CREATE INDEX IF NOT EXISTS idx_complaint_notifications_recipient
      ON public.complaint_notifications(recipient_id, is_read, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_complaint_notifications_user
      ON public.complaint_notifications(recipient_user_id, is_read, created_at DESC);

    CREATE TABLE IF NOT EXISTS public.complaint_attachments (
      id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
      complaint_id uuid NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
      file_path text NOT NULL,
      file_name text,
      uploaded_by uuid REFERENCES public.employees(id),
      created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX IF NOT EXISTS idx_complaint_attachments_complaint ON public.complaint_attachments(complaint_id, created_at DESC);

    INSERT INTO public.complaint_types (code, name) VALUES
      ('EDUCATIONAL', 'شكاوي تربوية'),
      ('TRANSPORT', 'شكاوي النقل المدرسي'),
      ('BEHAVIOR', 'شكاوي سلوكية'),
      ('ADMIN', 'شكاوي ادارية'),
      ('TECH', 'شكاوي تقنية'),
      ('FINANCE', 'شكاوي مالية'),
      ('ACTIVITIES', 'شكاوي الانشطة و الرحلات'),
      ('FOOD', 'شكاوي متعلقة بالاطعام'),
      ('SAFETY', 'شكاوي النظافة و الامن و السلامة'),
      ('GENERAL', 'شكاوي عامة')
    ON CONFLICT (code) DO NOTHING;

    -- Suggestions (اقتراحات) Schema
    CREATE TABLE IF NOT EXISTS public.suggestion_types (
      id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
      code text UNIQUE NOT NULL,
      name text NOT NULL,
      created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS public.suggestions (
      id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
      employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
      type_id uuid REFERENCES public.suggestion_types(id) ON DELETE SET NULL,
      title text NOT NULL,
      description text,
      category text,
      department_id uuid REFERENCES public.departments(id),
      status text NOT NULL DEFAULT 'under_review' CHECK (status = ANY(ARRAY['under_review','accepted','rejected'])),
      director_comment text,
      handled_by uuid REFERENCES public.employees(id),
      redirected_to uuid REFERENCES public.departments(id),
      created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
      reviewed_at timestamp,
      decision_at timestamp
    );
    CREATE INDEX IF NOT EXISTS idx_suggestions_employee ON public.suggestions(employee_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_suggestions_status ON public.suggestions(status, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_suggestions_department ON public.suggestions(department_id);

    CREATE TABLE IF NOT EXISTS public.suggestion_attachments (
      id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
      suggestion_id uuid NOT NULL REFERENCES public.suggestions(id) ON DELETE CASCADE,
      file_path text NOT NULL,
      file_name text,
      uploaded_by uuid REFERENCES public.employees(id),
      created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX IF NOT EXISTS idx_suggestion_attachments_suggestion ON public.suggestion_attachments(suggestion_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS public.suggestion_messages (
      id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
      suggestion_id uuid NOT NULL REFERENCES public.suggestions(id) ON DELETE CASCADE,
      sender_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
      sender_role text NOT NULL CHECK (sender_role = ANY(ARRAY['employee','director'])),
      body text NOT NULL,
      created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX IF NOT EXISTS idx_suggestion_messages_suggestion ON public.suggestion_messages(suggestion_id, created_at ASC);

    CREATE TABLE IF NOT EXISTS public.suggestion_history (
      id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
      suggestion_id uuid NOT NULL REFERENCES public.suggestions(id) ON DELETE CASCADE,
      changed_by uuid NOT NULL REFERENCES public.employees(id),
      old_status text,
      new_status text,
      comment text,
      created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX IF NOT EXISTS idx_suggestion_history_suggestion ON public.suggestion_history(suggestion_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS public.suggestion_notifications (
      id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
      suggestion_id uuid NOT NULL REFERENCES public.suggestions(id) ON DELETE CASCADE,
      recipient_id uuid REFERENCES public.employees(id),
      recipient_user_id uuid REFERENCES public.users(id),
      message text NOT NULL,
      title text,
      is_read boolean NOT NULL DEFAULT false,
      created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX IF NOT EXISTS idx_suggestion_notifications_recipient
      ON public.suggestion_notifications(recipient_id, is_read, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_suggestion_notifications_user
      ON public.suggestion_notifications(recipient_user_id, is_read, created_at DESC);

    INSERT INTO public.suggestion_types (code, name) VALUES
      ('IMPROVEMENT', 'تحسينات'),
      ('PROCESS', 'عمليات'),
      ('TRAINING', 'تدريب'),
      ('TECHNOLOGY', 'تقنية'),
      ('COMMUNICATION', 'تواصل'),
      ('FACILITIES', 'مرافق'),
      ('POLICY', 'سياسات'),
      ('GENERAL', 'عامة')
    ON CONFLICT (code) DO NOTHING;
  `);
}

async function createNotificationDirect({ recipientId, senderId, title, body, refType, refId }) {
  try {
    await pool.query(
      `INSERT INTO notifications (recipient_id, sender_id, type, message, is_read, user_id, title, body, ref_type, ref_id)
       VALUES ($1,$2,$3,$4,false,$1,$5,$6,$7,$8)`,
      [recipientId, senderId || null, 'SIGNALISATION', body || '', title || '', body || '', refType || 'SIGNALISATION', refId || null]
    );
  } catch (_) { }
}

async function getMaintenanceResponsibleIds() {
  const result = await pool.query(`
    SELECT DISTINCT d.responsible_id AS id
    FROM departments d
    WHERE d.responsible_id IS NOT NULL
      AND (d.name ILIKE '%maintenance%' OR d.name ILIKE '%maintennace%' OR d.name LIKE '%صيانة%')
  `);
  return result.rows.map(r => r.id);
}

async function isMaintenanceResponsible(responsibleId) {
  const ids = await getMaintenanceResponsibleIds();
  return ids.some(id => String(id) === String(responsibleId));
}

async function isMaintenanceEmployee(employeeId) {
  const result = await pool.query(`
    SELECT 1
    FROM employee_departments ed
    JOIN departments d ON d.id = ed.department_id
    WHERE ed.employee_id = $1
      AND (d.name ILIKE '%maintenance%' OR d.name ILIKE '%maintennace%' OR d.name LIKE '%صيانة%')
    LIMIT 1
  `, [employeeId]);
  return result.rowCount > 0;
}

async function isDirectorAccount(identifier) {
  if (!identifier) return false;
  try {
    const directorViaEmployee = await pool.query(
      `SELECT 1
       FROM employees e
       JOIN users u ON u.id = e.user_id
       WHERE (e.id = $1 OR e.user_id = $1)
         AND LOWER(u.role) IN ('director', 'department_responsible')
       LIMIT 1`,
      [identifier]
    );
    if (directorViaEmployee.rowCount > 0) return true;

    const directorViaUser = await pool.query(
      `SELECT 1 FROM users WHERE id = $1 AND LOWER(role) IN ('director', 'department_responsible') LIMIT 1`,
      [identifier]
    );
    return directorViaUser.rowCount > 0;
  } catch (e) {
    console.error('isDirectorAccount error', e);
    return false;
  }
}

function mapComplaint(row, { viewer } = {}) {
  const showIdentity = !row.is_anonymous || viewer === 'owner';
  const attachments = Array.isArray(row.attachments) ? row.attachments : [];
  const attachmentPath = row.attachment_path || row.latest_file_path || (attachments[0]?.file_path ?? null);
  const employee = showIdentity
    ? {
      id: row.employee_id,
      first_name: row.employee_first_name,
      last_name: row.employee_last_name
    }
    : { id: null, first_name: 'مجهول', last_name: '' };
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    type_id: row.type_id,
    type_name: row.type_name,
    is_anonymous: row.is_anonymous,
    attachment_path: attachmentPath,
    attachments,
    created_at: row.created_at,
    completed_at: row.completed_at,
    manager_comment: row.manager_comment,
    due_date: row.due_date,
    is_overdue: row.is_overdue,
    satisfaction_rating: row.satisfaction_rating,
    feedback: row.feedback,
    employee
  };
}

const handleComplaintUpload = (req, res, next) => attachmentUpload(req, res, next);

function calculateDueDate(priority) {
  const hours = priority === 'high' ? 24 : priority === 'low' ? 168 : 72;
  const due = new Date();
  due.setHours(due.getHours() + hours);
  return due;
}

async function recordComplaintHistory(complaintId, changedBy, oldStatus, newStatus, comment) {
  try {
    await pool.query(
      `INSERT INTO complaint_history (complaint_id, changed_by, old_status, new_status, comment)
       VALUES ($1,$2,$3,$4,$5)`,
      [complaintId, changedBy, oldStatus, newStatus, comment || null]
    );
  } catch (e) {
    console.error('record history error', e);
  }
}

async function getUserIdByEmployeeId(employeeId) {
  if (!employeeId) return null;
  try {
    const { rows } = await pool.query(
      `SELECT user_id FROM employees WHERE id = $1`,
      [employeeId]
    );
    return rows[0]?.user_id || null;
  } catch (e) {
    console.error('get user by employee error', e);
    return null;
  }
}

async function getEmployeeIdByUserId(userId) {
  if (!userId) return null;
  try {
    const { rows } = await pool.query(
      `SELECT id FROM employees WHERE user_id = $1`,
      [userId]
    );
    return rows[0]?.id || null;
  } catch (e) {
    console.error('get employee by user error', e);
    return null;
  }
}

async function createComplaintNotification({ complaintId, recipientId, recipientUserId, message, title }) {
  if (!recipientId && !recipientUserId) return;
  try {
    let employeeId = recipientId || null;
    let userId = recipientUserId || null;
    if (!userId && employeeId) {
      userId = await getUserIdByEmployeeId(employeeId);
    }
    if (!employeeId && userId) {
      employeeId = await getEmployeeIdByUserId(userId);
    }
    if (!employeeId && !userId) {
      console.warn('[notifications] no valid recipient for notification');
      return;
    }
    console.log('[notifications] creating', { complaintId, employeeId, userId, message });
    await pool.query(
      `INSERT INTO complaint_notifications (complaint_id, recipient_id, recipient_user_id, message, title)
       VALUES ($1,$2,$3,$4,$5)`,
      [complaintId, employeeId, userId, message || 'تنبيه جديد', title || null]
    );
  } catch (e) {
    console.error('create complaint notification', e);
  }
}

async function getDepartmentResponsibles(employeeId) {
  try {
    const { rows } = await pool.query(
      `SELECT DISTINCT d.responsible_id AS id
       FROM employee_departments ed
       JOIN departments d ON d.id = ed.department_id
       WHERE ed.employee_id = $1
         AND d.responsible_id IS NOT NULL`,
      [employeeId]
    );
    return rows.map(r => r.id);
  } catch (e) {
    console.error('get department responsibles error', e);
    return [];
  }
}

async function notifyDepartmentResponsibles({ complaintId, employeeId, message }) {
  if (!complaintId || !employeeId) return;
  const responsibles = await getDepartmentResponsibles(employeeId);
  if (!responsibles.length) return;
  await Promise.all(responsibles.map(id =>
    createComplaintNotification({
      complaintId,
      recipientId: id,
      message: message || 'تم تسجيل شكوى جديدة'
    })
  ));
}

async function getDirectorUserIds() {
  try {
    const { rows } = await pool.query(
      `SELECT id FROM users WHERE role = 'Director'`
    );
    return rows.map(r => r.id);
  } catch (e) {
    console.error('get directors error', e);
    return [];
  }
}

async function notifyGlobalDirectors({ complaintId, message, title }) {
  const directorIds = await getDirectorUserIds();
  if (!directorIds.length) return;
  await Promise.all(directorIds.map(userId =>
    createComplaintNotification({
      complaintId,
      recipientUserId: userId,
      message,
      title
    })
  ));
}

async function getComplaintTitle(complaintId) {
  try {
    const { rows } = await pool.query(
      `SELECT title FROM complaints WHERE id = $1`,
      [complaintId]
    );
    return rows[0]?.title || '';
  } catch (e) {
    console.error('getComplaintTitle error', e);
    return '';
  }
}

async function listComplaintNotifications(req, res) {
  try {
    const { userId } = req.params;
    res.set({
      'Cache-Control': 'no-store, no-cache, must-revalidate',
      Pragma: 'no-cache',
      Expires: '0'
    });
    const { rows } = await pool.query(
      `SELECT id, complaint_id, message, title, is_read, created_at
       FROM complaint_notifications
       WHERE (recipient_id = $1 OR recipient_user_id = $1)
       ORDER BY created_at DESC
       LIMIT 50`,
      [userId]
    );
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function complaintUnreadCount(req, res) {
  try {
    const { userId } = req.params;
    res.set({
      'Cache-Control': 'no-store, no-cache, must-revalidate',
      Pragma: 'no-cache',
      Expires: '0'
    });
    const { rows } = await pool.query(
      `SELECT COUNT(*)::int AS count FROM complaint_notifications
       WHERE (recipient_id = $1 OR recipient_user_id = $1) AND is_read = false`,
      [userId]
    );
    res.json({ count: rows[0]?.count || 0 });
  } catch (e) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function markComplaintNotificationRead(req, res) {
  try {
    const { notificationId } = req.params;
    await pool.query(`UPDATE complaint_notifications SET is_read = true WHERE id = $1`, [notificationId]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function listComplaintTypes(_req, res) {
  try {
    const { rows } = await pool.query('SELECT id, code, name FROM complaint_types ORDER BY name');
    res.json(rows);
  } catch (e) { res.status(500).json({ error: 'Erreur serveur' }); }
}

async function createComplaint(req, res) {
  try {
    const { employeeId } = req.params;
    const { typeId, title, description, priority, isAnonymous, departmentId } = req.body || {};
    if (!typeId || !title) {
      return res.status(400).json({ error: 'النوع و العنوان مطلوبان' });
    }
    const priorities = ['low', 'medium', 'high'];
    const finalPriority = priorities.includes(String(priority)) ? priority : 'medium';
    const dueDate = calculateDueDate(finalPriority);
    const insert = await pool.query(
      `INSERT INTO complaints (employee_id, type_id, title, description, priority, is_anonymous, attachment_path, due_date)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       RETURNING id`,
      [
        employeeId,
        typeId,
        title,
        description || null,
        finalPriority,
        String(isAnonymous) === 'true',
        req.file ? `/uploads/complaints/${req.file.filename}` : null,
        dueDate
      ]
    );
    await recordComplaintHistory(insert.rows[0].id, employeeId, null, 'pending', 'تم إنشاء الشكوى');
    await notifyDepartmentResponsibles({
      complaintId: insert.rows[0].id,
      employeeId,
      message: `تم تسجيل شكوى جديدة في قسمك: ${title}`
    });
    await notifyGlobalDirectors({
      complaintId: insert.rows[0].id,
      message: `📥 شكوى جديدة: ${title}`,
      title
    });
    res.status(201).json({ id: insert.rows[0].id });
  } catch (e) {
    console.error('create complaint error', e);
    res.status(500).json({ error: e?.message || 'Erreur serveur' });
  }
}

async function listEmployeeComplaints(req, res) {
  try {
    const { employeeId } = req.params;
    const { rows } = await pool.query(
      `SELECT c.*, ct.name AS type_name,
              e.first_name AS employee_first_name, e.last_name AS employee_last_name,
              att.attachments, att.latest_file_path
       FROM complaints c
       JOIN complaint_types ct ON ct.id = c.type_id
       JOIN employees e ON e.id = c.employee_id
       LEFT JOIN LATERAL (
         SELECT
           json_agg(
             json_build_object(
               'id', ca.id,
               'file_path', ca.file_path,
               'file_name', ca.file_name,
               'created_at', ca.created_at
             )
             ORDER BY ca.created_at DESC
           ) AS attachments,
           (ARRAY_AGG(ca.file_path ORDER BY ca.created_at DESC))[1] AS latest_file_path
         FROM complaint_attachments ca
         WHERE ca.complaint_id = c.id
       ) att ON true
       WHERE c.employee_id = $1
       ORDER BY c.created_at DESC`,
      [employeeId]
    );
    const data = rows.map(r => mapComplaint(r, { viewer: 'owner' }));
    const responses = data.filter(c => c.manager_comment || c.status === 'completed');
    res.json({ data, responses });
  } catch (e) {
    console.error('list employee complaints error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function listDirectorComplaints(req, res) {
  try {
    const { status, typeId, priority, q } = req.query;
    const filters = [];
    const params = [];
    let idx = 1;
    if (status) {
      filters.push(`c.status = $${idx++}`);
      params.push(status);
    }
    if (typeId) {
      filters.push(`c.type_id = $${idx++}`);
      params.push(typeId);
    }
    if (priority) {
      filters.push(`c.priority = $${idx++}`);
      params.push(priority);
    }
    if (q) {
      filters.push(`(c.title ILIKE $${idx} OR c.description ILIKE $${idx})`);
      params.push(`%${q}%`);
      idx++;
    }
    const where = filters.length ? 'WHERE ' + filters.join(' AND ') : '';
    const { rows } = await pool.query(
      `SELECT c.*, ct.name AS type_name,
              e.first_name AS employee_first_name, e.last_name AS employee_last_name,
              att.attachments, att.latest_file_path
       FROM complaints c
       JOIN complaint_types ct ON ct.id = c.type_id
       JOIN employees e ON e.id = c.employee_id
       LEFT JOIN LATERAL (
         SELECT
           json_agg(
             json_build_object(
               'id', ca.id,
               'file_path', ca.file_path,
               'file_name', ca.file_name,
               'created_at', ca.created_at
             )
             ORDER BY ca.created_at DESC
           ) AS attachments,
           (ARRAY_AGG(ca.file_path ORDER BY ca.created_at DESC))[1] AS latest_file_path
         FROM complaint_attachments ca
         WHERE ca.complaint_id = c.id
       ) att ON true
       ${where}
       ORDER BY c.created_at DESC
       LIMIT 200`,
      params
    );
    res.json(rows.map(r => mapComplaint(r, { viewer: 'director' })));
  } catch (e) {
    console.error('list director complaints error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function listOverdueComplaints(_req, res) {
  try {
    const { rows } = await pool.query(
      `SELECT c.*, ct.name AS type_name,
              e.first_name AS employee_first_name, e.last_name AS employee_last_name
       FROM complaints c
       JOIN complaint_types ct ON ct.id = c.type_id
       JOIN employees e ON e.id = c.employee_id
       WHERE c.status = 'pending'
         AND c.due_date IS NOT NULL
         AND c.due_date < CURRENT_TIMESTAMP
       ORDER BY c.due_date ASC`
    );
    res.json(rows.map(r => mapComplaint(r, { viewer: 'director' })));
  } catch (e) {
    console.error('list overdue error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function escalateComplaint(req, res) {
  try {
    const { complaintId } = req.body || {};
    if (!complaintId) return res.status(400).json({ error: 'complaintId مطلوب' });
    const info = await pool.query(`SELECT employee_id, title FROM complaints WHERE id = $1`, [complaintId]);
    if (!info.rows.length) return res.status(404).json({ error: 'الشكوى غير موجودة' });
    await recordComplaintHistory(complaintId, info.rows[0].employee_id, 'pending', 'pending', 'تم رفع الشكوى للإداره');
    await createComplaintNotification({
      complaintId,
      recipientId: info.rows[0].employee_id,
      message: `تم رفع الشكوى للمتابعة: ${info.rows[0].title || ''}`,
      title: info.rows[0].title || null
    });
    await notifyGlobalDirectors({
      complaintId,
      message: `⚠️ تم تصعيد الشكوى: ${info.rows[0].title || ''}`,
      title: info.rows[0].title || null
    });
    res.json({ ok: true });
  } catch (e) {
    console.error('escalate complaint error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function complaintAnalytics(req, res) {
  try {
    const { from, to } = req.query;
    const filters = [];
    const params = [];
    let idx = 1;
    if (from) { filters.push(`created_at >= $${idx++}`); params.push(from); }
    if (to) { filters.push(`created_at <= $${idx++}`); params.push(to); }
    const where = filters.length ? 'WHERE ' + filters.join(' AND ') : '';
    const overview = await pool.query(`SELECT COUNT(*)::int total,
      COUNT(*) FILTER (WHERE status='completed')::int completed,
      AVG(EXTRACT(EPOCH FROM (resolved_at - created_at))/3600) AS avg_response_time
      FROM complaints ${where}`, params);
    const byType = await pool.query(`SELECT ct.name, COUNT(*)::int count
      FROM complaints c JOIN complaint_types ct ON ct.id = c.type_id
      ${where} GROUP BY ct.name ORDER BY count DESC`, params);
    const byPriority = await pool.query(`SELECT priority, COUNT(*)::int count
      FROM complaints ${where} GROUP BY priority`, params);
    res.json({
      total: overview.rows[0]?.total || 0,
      completed: overview.rows[0]?.completed || 0,
      avgResponseTime: Number(overview.rows[0]?.avg_response_time || 0),
      byType: byType.rows,
      byPriority: byPriority.rows
    });
  } catch (e) {
    console.error('analytics error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function exportComplaints(req, res) {
  try {
    const { filters } = req.body || {};
    const params = [];
    const clauses = [];
    let idx = 1;
    if (filters?.status) { clauses.push(`status = $${idx++}`); params.push(filters.status); }
    const where = clauses.length ? 'WHERE ' + clauses.join(' AND ') : '';
    const rows = await pool.query(
      `SELECT title, priority, status, created_at FROM complaints ${where} ORDER BY created_at DESC`,
      params
    );
    const header = 'العنوان,الأولوية,الحالة,التاريخ\n';
    const csv = header + rows.rows.map(r =>
      [r.title, r.priority, r.status, r.created_at.toISOString()].join(',')
    ).join('\n');
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', 'attachment; filename="complaints_export.csv"');
    res.send(csv);
  } catch (e) {
    console.error('export complaints error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function searchComplaints(req, res) {
  try {
    const { types, statuses, priorities, dateFrom, dateTo, overdue } = req.query;
    const params = [];
    const filters = [];
    let idx = 1;
    if (types) { filters.push(`c.type_id = ANY($${idx++}::uuid[])`); params.push(types.split(',')); }
    if (statuses) { filters.push(`c.status = ANY($${idx++}::text[])`); params.push(statuses.split(',')); }
    if (priorities) { filters.push(`c.priority = ANY($${idx++}::text[])`); params.push(priorities.split(',')); }
    if (dateFrom) { filters.push(`c.created_at >= $${idx++}`); params.push(dateFrom); }
    if (dateTo) { filters.push(`c.created_at <= $${idx++}`); params.push(dateTo); }
    if (overdue !== undefined) {
      filters.push(`c.is_overdue = $${idx++}`);
      params.push(overdue === 'true');
    }
    const where = filters.length ? 'WHERE ' + filters.join(' AND ') : '';
    const { rows } = await pool.query(
      `SELECT c.*, ct.name AS type_name,
              e.first_name AS employee_first_name, e.last_name AS employee_last_name
       FROM complaints c
       JOIN complaint_types ct ON ct.id = c.type_id
       JOIN employees e ON e.id = c.employee_id
       ${where}
       ORDER BY c.created_at DESC
       LIMIT 200`,
      params
    );
    res.json(rows.map(r => mapComplaint(r, { viewer: 'director' })));
  } catch (e) {
    console.error('search complaints error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function submitFeedback(req, res) {
  try {
    const { complaintId } = req.params;
    const { rating, comment } = req.body || {};
    if (!rating || rating < 1 || rating > 5) return res.status(400).json({ error: 'تقييم غير صالح' });
    const result = await pool.query(
      `UPDATE complaints
       SET satisfaction_rating = $1, feedback = $2
       WHERE id = $3
       RETURNING handled_by, title`,
      [rating, comment || null, complaintId]
    );
    const handledBy = result.rows[0]?.handled_by;
    if (handledBy) {
      await createComplaintNotification({
        complaintId,
        recipientId: handledBy,
        message: `⭐ تقييم جديد (${rating}/5) على: ${result.rows[0]?.title || ''}`,
        title: result.rows[0]?.title || null
      });
    }
    await notifyGlobalDirectors({
      complaintId,
      message: `⭐ تقييم جديد (${rating}/5) على: ${result.rows[0]?.title || ''}`,
      title: result.rows[0]?.title || null
    });
    res.json({ ok: true });
  } catch (e) {
    console.error('feedback error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
}
async function updateComplaintComment(req, res) {
  try {
    const { complaintId } = req.params;
    const { comment, status, managerId } = req.body || {};
    const current = await pool.query(`SELECT status, employee_id, handled_by FROM complaints WHERE id = $1`, [complaintId]);
    if (!current.rows.length) {
      return res.status(404).json({ error: 'الشكوى غير موجودة' });
    }
    const existing = current.rows[0];
    const fields = [];
    const params = [];
    let idx = 1;
    if (comment !== undefined) {
      fields.push(`manager_comment = $${idx++}`);
      params.push(comment || null);
    }
    if (status && ['pending', 'completed'].includes(status)) {
      fields.push(`status = $${idx}`);
      params.push(status);
      idx++;
      if (status === 'completed') {
        fields.push(`completed_at = CURRENT_TIMESTAMP`);
        fields.push(`resolved_at = CURRENT_TIMESTAMP`);
      }
    }
    if (managerId) {
      fields.push(`handled_by = $${idx++}`);
      params.push(managerId);
    }
    if (!fields.length) {
      return res.status(400).json({ error: 'لا يوجد تحديث' });
    }
    params.push(complaintId);
    await pool.query(
      `UPDATE complaints SET ${fields.join(', ')} WHERE id = $${idx}`,
      params
    );
    const info = await pool.query(
      `SELECT c.*, ct.name AS type_name,
              e.first_name AS employee_first_name, e.last_name AS employee_last_name
       FROM complaints c
       JOIN complaint_types ct ON ct.id = c.type_id
       JOIN employees e ON e.id = c.employee_id
       WHERE c.id = $1`,
      [complaintId]
    );
    if (status && status !== existing.status) {
      await recordComplaintHistory(
        complaintId,
        managerId || existing.handled_by || existing.employee_id,
        existing.status,
        status,
        comment
      );
      await createComplaintNotification({
        complaintId,
        recipientId: existing.employee_id,
        message: status === 'completed'
          ? `تم إغلاق شكواك: ${info.rows[0]?.title || ''}`
          : `تم تحديث حالة الشكوى: ${info.rows[0]?.title || ''}`,
        title: info.rows[0]?.title || null
      });
      await notifyGlobalDirectors({
        complaintId,
        message: status === 'completed'
          ? `✅ تم إغلاق شكوى: ${info.rows[0]?.title || ''}`
          : `🔄 تحديث حالة الشكوى: ${info.rows[0]?.title || ''}`,
        title: info.rows[0]?.title || null
      });
    } else if (comment) {
      await recordComplaintHistory(
        complaintId,
        managerId || existing.handled_by || existing.employee_id,
        existing.status,
        existing.status,
        comment
      );
      await notifyGlobalDirectors({
        complaintId,
        message: `📝 تعليق جديد على الشكوى: ${info.rows[0]?.title || ''}`,
        title: info.rows[0]?.title || null
      });
    }
    res.json(mapComplaint(info.rows[0], { viewer: 'director' }));
  } catch (e) {
    console.error('update complaint error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

// Public check: is employee in maintenance department
router.get('/maintenance/is-employee/:employeeId', async (req, res) => {
  try {
    const ok = await isMaintenanceEmployee(req.params.employeeId);
    res.json({ isMaintenance: ok });
  } catch (e) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Public check: is employee the maintenance responsible
router.get('/maintenance/is-responsible/:employeeId', async (req, res) => {
  try {
    const ok = await isMaintenanceResponsible(req.params.employeeId);
    res.json({ isResponsible: ok });
  } catch (e) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Generic helper: employees under any department managed by this responsible
async function getEmployeesUnderResponsible(responsibleId) {
  // Directors can see all employees; department responsibles are scoped to their departments
  const isDirector = await isDirectorAccount(responsibleId);
  const query = isDirector
    ? `
      SELECT DISTINCT e.id, e.first_name, e.last_name
      FROM employees e
      ORDER BY e.first_name, e.last_name
    `
    : `
      SELECT DISTINCT e.id, e.first_name, e.last_name
      FROM employees e
      JOIN employee_departments ed ON ed.employee_id = e.id
      JOIN departments d ON d.id = ed.department_id
      WHERE d.responsible_id = $1
      ORDER BY e.first_name, e.last_name
    `;
  const params = isDirector ? [] : [responsibleId];
  const result = await pool.query(query, params);
  return result.rows;
}

// List all signal types
router.get('/types', async (_req, res) => {
  try {
    const { rows } = await pool.query('SELECT id, code, name FROM signal_types ORDER BY name');
    res.json(rows);
  } catch (e) { res.status(500).json({ error: 'Erreur serveur' }); }
});

router.get('/complaints/types', listComplaintTypes);
router.get('/complaints/statistics/overview', complaintsStatisticsOverviewHandler);
router.get('/complaints/statistics/monthly', complaintsStatisticsMonthlyHandler);
router.get('/complaints/overdue', listOverdueComplaints);
router.post('/complaints/escalate', escalateComplaint);
router.get('/complaints/analytics', complaintAnalytics);
router.post('/complaints/export', exportComplaints);
router.get('/complaints/search', searchComplaints);
router.get('/complaints/:complaintId/messages', listComplaintMessages);
router.post('/complaints/:complaintId/messages', createComplaintMessage);
router.get('/complaints/:complaintId/history', listComplaintHistory);
router.get('/complaints/notifications/:userId', listComplaintNotifications);
router.get('/complaints/notifications/:userId/unread-count', complaintUnreadCount);
router.post('/complaints/notifications/:notificationId/read', markComplaintNotificationRead);
complaintsRouter.get('/types', listComplaintTypes);
complaintsRouter.get('/statistics/overview', complaintsStatisticsOverviewHandler);
complaintsRouter.get('/statistics/monthly', complaintsStatisticsMonthlyHandler);
complaintsRouter.get('/overdue', listOverdueComplaints);
complaintsRouter.post('/escalate', escalateComplaint);
complaintsRouter.get('/analytics', complaintAnalytics);
complaintsRouter.post('/export', exportComplaints);
complaintsRouter.get('/search', searchComplaints);
complaintsRouter.get('/director', listDirectorComplaints);

async function listComplaintMessages(req, res) {
  try {
    const { complaintId } = req.params;
    const viewer = req.query.viewer === 'director' ? 'director' : 'owner';
    const { rows } = await pool.query(
      `SELECT m.id, m.body, m.created_at, m.sender_role,
              c.is_anonymous,
              e.first_name, e.last_name,
              m.sender_id
       FROM complaint_messages m
       JOIN complaints c ON c.id = m.complaint_id
       JOIN employees e ON e.id = m.sender_id
       WHERE m.complaint_id = $1
       ORDER BY m.created_at ASC`,
      [complaintId]
    );
    const messages = rows.map(r => {
      const hideEmployeeName = r.is_anonymous && viewer === 'director' && r.sender_role === 'employee';
      const senderName = hideEmployeeName
        ? 'مجهول'
        : `${r.first_name || ''} ${r.last_name || ''}`.trim() || 'غير معروف';
      return {
        id: r.id,
        body: r.body,
        created_at: r.created_at,
        sender_role: r.sender_role,
        sender_id: r.sender_id,
        sender_name: senderName
      };
    });
    res.json(messages);
  } catch (e) {
    console.error('list complaint messages error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function createComplaintMessage(req, res) {
  try {
    const { complaintId } = req.params;
    const { senderId, senderRole, body } = req.body || {};
    if (!senderId || !body || !senderRole || !['employee', 'director'].includes(senderRole)) {
      return res.status(400).json({ error: 'بيانات غير مكتملة' });
    }
    // Ensure complaint exists
    const info = await pool.query(`SELECT id, employee_id, handled_by FROM complaints WHERE id = $1`, [complaintId]);
    if (!info.rows.length) return res.status(404).json({ error: 'الشكوى غير موجودة' });

    const insert = await pool.query(
      `INSERT INTO complaint_messages (complaint_id, sender_id, sender_role, body)
       VALUES ($1,$2,$3,$4)
       RETURNING id, complaint_id, sender_id, sender_role, body, created_at`,
      [complaintId, senderId, senderRole, body]
    );

    const title = await getComplaintTitle(complaintId);
    if (senderRole === 'director') {
      await createComplaintNotification({
        complaintId,
        recipientId: info.rows[0].employee_id,
        message: `رد جديد من المدير على: ${title || ''}`,
        title
      });
      await notifyGlobalDirectors({
        complaintId,
        message: `💬 المدير أضاف رداً على: ${title || ''}`,
        title
      });
    } else if (senderRole === 'employee' && info.rows[0].handled_by) {
      await createComplaintNotification({
        complaintId,
        recipientId: info.rows[0].handled_by,
        message: `رد جديد من الموظف على: ${title || ''}`,
        title
      });
      await notifyGlobalDirectors({
        complaintId,
        message: `💬 الموظف أضاف رداً على: ${title || ''}`,
        title
      });
    }

    res.status(201).json(insert.rows[0]);
  } catch (e) {
    console.error('create complaint message error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function listComplaintHistory(req, res) {
  try {
    const { complaintId } = req.params;
    const { rows } = await pool.query(
      `SELECT h.*, e.first_name, e.last_name
       FROM complaint_history h
       JOIN employees e ON e.id = h.changed_by
       WHERE h.complaint_id = $1
       ORDER BY h.created_at DESC`,
      [complaintId]
    );
    res.json(rows.map(r => ({
      id: r.id,
      complaint_id: r.complaint_id,
      old_status: r.old_status,
      new_status: r.new_status,
      comment: r.comment,
      created_at: r.created_at,
      user: { id: r.changed_by, first_name: r.first_name, last_name: r.last_name }
    })));
  } catch (e) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

complaintsRouter.get('/:complaintId/messages', listComplaintMessages);
complaintsRouter.post('/:complaintId/messages', createComplaintMessage);
complaintsRouter.get('/:complaintId/history', listComplaintHistory);
complaintsRouter.get('/notifications/:userId', listComplaintNotifications);
complaintsRouter.get('/notifications/:userId/unread-count', complaintUnreadCount);
complaintsRouter.post('/notifications/:notificationId/read', markComplaintNotificationRead);
complaintsRouter.post('/:complaintId/attachments', (req, res, next) => multiAttachmentUpload(req, res, next), async (req, res) => {
  try {
    const { complaintId } = req.params;
    if (!req.files || !req.files.length) {
      return res.status(400).json({ error: 'لا توجد مرفقات' });
    }
    const rows = await Promise.all(req.files.map(file => pool.query(
      `INSERT INTO complaint_attachments (complaint_id, file_path, file_name, uploaded_by)
       VALUES ($1,$2,$3,$4)
       RETURNING id, file_path, file_name, created_at`,
      [complaintId, `/uploads/complaints/${file.filename}`, file.originalname || null, req.body.uploadedBy || null]
    )));
    res.json(rows.map(r => r.rows[0]));
  } catch (e) {
    console.error('upload attachments error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});
complaintsRouter.get('/:complaintId/attachments', async (req, res) => {
  try {
    const { complaintId } = req.params;
    const { rows } = await pool.query(
      `SELECT id, file_path, file_name, created_at FROM complaint_attachments
       WHERE complaint_id = $1
       ORDER BY created_at DESC`,
      [complaintId]
    );
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});
complaintsRouter.post('/:complaintId/feedback', submitFeedback);

router.post('/maintenance/:responsibleId/types', async (req, res) => {
  try {
    const { responsibleId } = req.params;
    const { name, code, employeeId } = req.body || {};
    const isMaint = await isMaintenanceResponsible(responsibleId);
    const isDirector = await isDirectorAccount(responsibleId);
    if (!isMaint && !isDirector) return res.status(403).json({ error: 'Accès refusé' });

    if (!name || !String(name).trim()) {
      return res.status(400).json({ error: 'الاسم مطلوب' });
    }
    let finalCode = (code || '').trim();
    if (!finalCode) {
      finalCode = String(name).trim().toUpperCase()
        .replace(/[^\w]+/g, '_')
        .replace(/__+/g, '_')
        .replace(/^_+|_+$/g, '')
        || `TYPE_${Date.now()}`;
    }

    const insert = await pool.query(
      `INSERT INTO signal_types (code, name)
       VALUES ($1, $2)
       RETURNING id, code, name`,
      [finalCode, name.trim()]
    );

    let assigned = false;
    if (employeeId) {
      const managedEmployees = await getEmployeesUnderResponsible(responsibleId);
      const isManaged = managedEmployees.some(e => String(e.id) === String(employeeId));
      if (!isManaged) {
        return res.status(403).json({ error: 'الموظف خارج نطاق مسؤوليتك' });
      }
      await pool.query(
        `INSERT INTO signal_type_responsibles (type_id, employee_id, assigned_by)
         VALUES ($1,$2,$3)
         ON CONFLICT DO NOTHING`,
        [insert.rows[0].id, employeeId, responsibleId]
      );
      assigned = true;
    }

    res.status(201).json({ ...insert.rows[0], assigned });
  } catch (e) {
    if (e.code === '23505') {
      return res.status(409).json({ error: 'Code النوع مستخدم مسبقاً' });
    }
    console.error('create type error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

router.post('/complaints/employee/:employeeId', handleComplaintUpload, createComplaint);
router.get('/complaints/employee/:employeeId', listEmployeeComplaints);
router.get('/complaints/director', listDirectorComplaints);
router.get('/complaints/:complaintId/messages', listComplaintMessages);
router.post('/complaints/:complaintId/messages', createComplaintMessage);
router.get('/complaints/:complaintId/history', listComplaintHistory);
router.post('/complaints/:complaintId/attachments', (req, res, next) => multiAttachmentUpload(req, res, next), async (req, res) => {
  try {
    const { complaintId } = req.params;
    if (!req.files || !req.files.length) {
      return res.status(400).json({ error: 'لا توجد مرفقات' });
    }
    const rows = await Promise.all(req.files.map(file => pool.query(
      `INSERT INTO complaint_attachments (complaint_id, file_path, file_name, uploaded_by)
       VALUES ($1,$2,$3,$4)
       RETURNING id, file_path, file_name, created_at`,
      [complaintId, `/uploads/complaints/${file.filename}`, file.originalname || null, req.body.uploadedBy || null]
    )));
    res.json(rows.map(r => r.rows[0]));
  } catch (e) {
    console.error('upload attachments error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});
router.get('/complaints/:complaintId/attachments', async (req, res) => {
  try {
    const { complaintId } = req.params;
    const { rows } = await pool.query(
      `SELECT id, file_path, file_name, created_at FROM complaint_attachments
       WHERE complaint_id = $1
       ORDER BY created_at DESC`,
      [complaintId]
    );
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});
router.post('/complaints/:complaintId/comment', updateComplaintComment);
router.get('/complaints/notifications/:userId', listComplaintNotifications);
router.get('/complaints/notifications/:userId/unread-count', complaintUnreadCount);
router.post('/complaints/notifications/:notificationId/read', markComplaintNotificationRead);
router.post('/complaints/:complaintId/feedback', submitFeedback);

// =========================
// DIRECTOR DASHBOARD ROUTES
// =========================

// Ces routes s'appuient sur les vues SQL suivantes (à créer côté base) :
// - director_dashboard
// - department_performance_detail
// - trend_analysis
// - top_contributors
// - critical_alerts

directorRouter.get('/dashboard', async (_req, res) => {
  try {
    const { rows } = await pool.query('SELECT * FROM director_dashboard');
    res.json(rows[0] || {});
  } catch (e) {
    console.error('director dashboard error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

directorRouter.get('/departments', async (_req, res) => {
  try {
    const { rows } = await pool.query('SELECT * FROM department_performance_detail ORDER BY total_suggestions DESC');
    res.json(rows);
  } catch (e) {
    console.error('director departments stats error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

directorRouter.get('/trends', async (_req, res) => {
  try {
    const { rows } = await pool.query('SELECT month, type, count FROM trend_analysis ORDER BY month ASC, type ASC');
    res.json(rows);
  } catch (e) {
    console.error('director trends error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

directorRouter.get('/top-contributors', async (_req, res) => {
  try {
    const { rows } = await pool.query('SELECT * FROM top_contributors ORDER BY suggestion_rank ASC');
    res.json(rows);
  } catch (e) {
    console.error('director top contributors error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

directorRouter.get('/critical-alerts', async (_req, res) => {
  try {
    const { rows } = await pool.query('SELECT * FROM critical_alerts ORDER BY days_pending DESC');
    res.json(rows);
  } catch (e) {
    console.error('director critical alerts error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

directorRouter.get('/signals-stats', async (req, res) => {
  try {
    const { whereClause, values } = buildSignalFilters(req.query);

    const overview = await pool.query(
      `SELECT 
        COUNT(*)::int as total,
        COUNT(*) FILTER (WHERE s.is_treated = false)::int as pending,
        COUNT(*) FILTER (WHERE s.is_treated = true)::int as treated,
        COUNT(*) FILTER (WHERE s.priority = 'high')::int as high_priority,
        COUNT(*) FILTER (WHERE s.priority = 'medium')::int as medium_priority,
        COUNT(*) FILTER (WHERE s.priority = 'low')::int as low_priority
       FROM signalisations s ${whereClause}`,
      values
    );

    const byType = await pool.query(
      `SELECT COALESCE(st.name, 'غير محدد') AS type_name,
              COUNT(*)::int AS total,
              COUNT(*) FILTER (WHERE s.is_treated = false)::int as pending,
              COUNT(*) FILTER (WHERE s.is_treated = true)::int as treated
       FROM signalisations s
       LEFT JOIN signal_types st ON st.id = s.type_id
       ${whereClause}
       GROUP BY st.name
       ORDER BY total DESC`,
      values
    );

    const byPriority = await pool.query(
      `SELECT s.priority,
              COUNT(*)::int AS total
       FROM signalisations s
       ${whereClause}
       GROUP BY s.priority
       ORDER BY total DESC`,
      values
    );

    const byStatus = await pool.query(
      `SELECT CASE WHEN s.is_treated THEN 'treated' ELSE 'pending' END AS status,
              COUNT(*)::int AS total
       FROM signalisations s
       ${whereClause}
       GROUP BY status
       ORDER BY status`,
      values
    );

    const timeline = await pool.query(
      `SELECT DATE_TRUNC('day', s.created_at) AS day,
              COUNT(*)::int AS total
       FROM signalisations s
       ${whereClause}
       GROUP BY day
       ORDER BY day`,
      values
    );

    const satisfactionWhere = whereClause
      ? `${whereClause} AND s.satisfaction_rating IS NOT NULL`
      : 'WHERE s.satisfaction_rating IS NOT NULL';
    const satisfaction = await pool.query(
      `SELECT s.satisfaction_rating AS rating,
              COUNT(*)::int AS total
       FROM signalisations s
       ${satisfactionWhere}
       GROUP BY s.satisfaction_rating
       ORDER BY rating`,
      values
    );

    res.json({
      overview: overview.rows[0] || {
        total: 0,
        pending: 0,
        treated: 0,
        high_priority: 0,
        medium_priority: 0,
        low_priority: 0
      },
      byType: byType.rows,
      byPriority: byPriority.rows,
      byStatus: byStatus.rows,
      timeline: timeline.rows,
      satisfaction: satisfaction.rows
    });
  } catch (e) {
    console.error('director signals-stats error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

directorRouter.get('/complaints-stats', async (req, res) => {
  try {
    const { whereClause, values } = buildSignalFilters(req.query);

    const byType = await pool.query(
      `SELECT COALESCE(st.name, 'غير محدد') AS type_name,
              COUNT(*)::int AS total
       FROM signalisations s
       LEFT JOIN signal_types st ON st.id = s.type_id
       ${whereClause}
       GROUP BY st.name
       ORDER BY total DESC`,
      values
    );

    const byPriority = await pool.query(
      `SELECT s.priority,
              COUNT(*)::int AS total
       FROM signalisations s
       ${whereClause}
       GROUP BY s.priority
       ORDER BY total DESC`,
      values
    );

    const byStatus = await pool.query(
      `SELECT CASE WHEN s.is_treated THEN 'treated' ELSE 'pending' END AS status,
              COUNT(*)::int AS total
       FROM signalisations s
       ${whereClause}
       GROUP BY status
       ORDER BY status`,
      values
    );

    const timeline = await pool.query(
      `SELECT DATE_TRUNC('day', s.created_at) AS day,
              COUNT(*)::int AS total
       FROM signalisations s
       ${whereClause}
       GROUP BY day
       ORDER BY day`,
      values
    );

    const satisfactionWhere = whereClause
      ? `${whereClause} AND s.satisfaction_rating IS NOT NULL`
      : 'WHERE s.satisfaction_rating IS NOT NULL';
    const satisfaction = await pool.query(
      `SELECT s.satisfaction_rating AS rating,
              COUNT(*)::int AS total
       FROM signalisations s
       ${satisfactionWhere}
       GROUP BY s.satisfaction_rating
       ORDER BY rating`,
      values
    );

    res.json({
      byType: byType.rows,
      byPriority: byPriority.rows,
      byStatus: byStatus.rows,
      timeline: timeline.rows,
      satisfaction: satisfaction.rows
    });
  } catch (e) {
    console.error('director complaints-stats error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Director: Get comprehensive complaints statistics
directorRouter.get('/complaints-statistics', async (req, res) => {
  try {
    const { from, to } = req.query;
    const filters = [];
    const params = [];
    let idx = 1;

    if (from) {
      filters.push(`c.created_at >= $${idx++}`);
      params.push(from);
    }
    if (to) {
      filters.push(`c.created_at <= $${idx++}`);
      params.push(to);
    }

    const whereClause = filters.length ? 'WHERE ' + filters.join(' AND ') : '';

    const overview = await pool.query(
      `SELECT 
        COUNT(*)::int as total,
        COUNT(*) FILTER (WHERE c.status = 'pending')::int as pending,
        COUNT(*) FILTER (WHERE c.status = 'completed')::int as completed,
        COUNT(*) FILTER (WHERE c.priority = 'high')::int as high_priority,
        COUNT(*) FILTER (WHERE c.priority = 'medium')::int as medium_priority,
        COUNT(*) FILTER (WHERE c.priority = 'low')::int as low_priority,
        COUNT(*) FILTER (
          WHERE c.status = 'pending'
            AND c.due_date IS NOT NULL
            AND c.due_date < CURRENT_TIMESTAMP
        )::int as overdue
       FROM complaints c ${whereClause}`,
      params
    );

    const byType = await pool.query(
      `SELECT ct.name as type_name,
              COUNT(*)::int as total,
              COUNT(*) FILTER (WHERE c.status = 'pending')::int as pending,
              COUNT(*) FILTER (WHERE c.status = 'completed')::int as completed
       FROM complaints c
       JOIN complaint_types ct ON ct.id = c.type_id
       ${whereClause}
       GROUP BY ct.name
       ORDER BY total DESC`,
      params
    );

    res.json({
      overview: overview.rows[0] || {
        total: 0,
        pending: 0,
        completed: 0,
        high_priority: 0,
        medium_priority: 0,
        low_priority: 0,
        overdue: 0
      },
      byType: byType.rows || []
    });
  } catch (e) {
    console.error('Director complaints statistics error:', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

directorRouter.get('/suggestions-stats', async (req, res) => {
  try {
    const { whereClause, values } = buildSuggestionFilters(req.query);

    const byDepartment = await pool.query(
      `SELECT COALESCE(d.name, 'غير محدد') AS department_name,
              COUNT(*)::int AS total,
              COUNT(*) FILTER (WHERE s.status = 'under_review')::int AS pending,
              COUNT(*) FILTER (WHERE s.status = 'accepted')::int AS accepted,
              COUNT(*) FILTER (WHERE s.status = 'rejected')::int AS rejected
       FROM suggestions s
       LEFT JOIN departments d ON d.id = s.department_id
       ${whereClause}
       GROUP BY d.name
       ORDER BY total DESC`,
      values
    );

    const byStatus = await pool.query(
      `SELECT s.status,
              COUNT(*)::int AS total
       FROM suggestions s
       ${whereClause}
       GROUP BY s.status
       ORDER BY total DESC`,
      values
    );

    const timeline = await pool.query(
      `SELECT DATE_TRUNC('day', s.created_at) AS day,
              COUNT(*)::int AS total
       FROM suggestions s
       ${whereClause}
       GROUP BY day
       ORDER BY day`,
      values
    );

    res.json({
      byDepartment: byDepartment.rows,
      byStatus: byStatus.rows,
      timeline: timeline.rows
    });
  } catch (e) {
    console.error('director suggestions-stats error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

complaintsRouter.get('/employee/:employeeId/statistics', async (req, res) => {
  const { employeeId } = req.params;
  const { from, to } = req.query;
  try {
    const filters = ['c.employee_id = $1'];
    const params = [employeeId];
    let idx = 2;

    if (from) {
      filters.push(`c.created_at >= $${idx++}`);
      params.push(from);
    }
    if (to) {
      filters.push(`c.created_at <= $${idx++}`);
      params.push(to);
    }

    const whereClause = 'WHERE ' + filters.join(' AND ');

    const overview = await pool.query(
      `SELECT 
        COUNT(*)::int as total,
        COUNT(*) FILTER (WHERE c.status = 'pending')::int as pending,
        COUNT(*) FILTER (WHERE c.status = 'completed')::int as completed,
        COUNT(*) FILTER (WHERE c.priority = 'high')::int as high_priority,
        COUNT(*) FILTER (WHERE c.priority = 'medium')::int as medium_priority,
        COUNT(*) FILTER (WHERE c.priority = 'low')::int as low_priority,
        COUNT(*) FILTER (
          WHERE c.status = 'pending'
            AND c.due_date IS NOT NULL
            AND c.due_date < CURRENT_TIMESTAMP
        )::int as overdue
       FROM complaints c ${whereClause}`,
      params
    );

    const byType = await pool.query(
      `SELECT ct.name as type_name,
              COUNT(*)::int as total,
              COUNT(*) FILTER (WHERE c.status = 'pending')::int as pending,
              COUNT(*) FILTER (WHERE c.status = 'completed')::int as completed
       FROM complaints c
       JOIN complaint_types ct ON ct.id = c.type_id
       ${whereClause}
       GROUP BY ct.name
       ORDER BY total DESC`,
      params
    );

    res.json({
      overview: overview.rows[0] || {
        total: 0,
        pending: 0,
        completed: 0,
        high_priority: 0,
        medium_priority: 0,
        low_priority: 0,
        overdue: 0
      },
      byType: byType.rows || []
    });
  } catch (e) {
    console.error('Employee complaints statistics error:', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});
complaintsRouter.post('/employee/:employeeId', handleComplaintUpload, createComplaint);
complaintsRouter.get('/employee/:employeeId', listEmployeeComplaints);
complaintsRouter.get('/director', listDirectorComplaints);
complaintsRouter.post('/:complaintId/comment', updateComplaintComment);

// List all localisations for selection
router.get('/localisations', async (_req, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT id, code_emplacement, description_ar, batiment, etage
      FROM localisations
      ORDER BY batiment, etage, code_emplacement
    `);
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Distinct buildings and floors helpers
router.get('/localisations/distincts', async (_req, res) => {
  try {
    const bats = await pool.query(`SELECT DISTINCT batiment FROM localisations WHERE batiment IS NOT NULL AND batiment <> '' ORDER BY batiment`);
    const etages = await pool.query(`SELECT DISTINCT etage FROM localisations WHERE etage IS NOT NULL AND etage <> '' ORDER BY etage`);
    res.json({ batiments: bats.rows.map(r => r.batiment), etages: etages.rows.map(r => r.etage) });
  } catch (e) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Maintenance responsible can create a localisation
router.post('/maintenance/:responsibleId/localisations', async (req, res) => {
  try {
    const { responsibleId } = req.params;
    const isMaint = await isMaintenanceResponsible(responsibleId);
    const isDirector = await isDirectorAccount(responsibleId);
    if (!isMaint && !isDirector) return res.status(403).json({ error: 'Accès refusé' });

    const {
      code_emplacement,
      batiment,
      etage,
      description_ar,
      description_fr,
      type_local,
      type_local_custom
    } = req.body || {};

    if (!code_emplacement || !(batiment && etage)) {
      return res.status(400).json({ error: 'code_emplacement, batiment et etage requis' });
    }

    // Validate type_local if provided
    const allowed = ['salle', 'bureau', 'sanitaire', 'laboratoire', 'salle_informatique', 'atelier', 'restaurant', 'stockage', 'autre'];
    const hasCustom = type_local_custom && String(type_local_custom).trim().length > 0;
    const finalType = hasCustom ? 'autre' : (type_local && allowed.includes(type_local) ? type_local : null);
    const finalCustom = hasCustom ? String(type_local_custom).trim() : null;

    // Ensure unique code
    const exists = await pool.query(`SELECT 1 FROM localisations WHERE code_emplacement = $1`, [code_emplacement]);
    if (exists.rowCount > 0) {
      return res.status(409).json({ error: 'code_emplacement déjà utilisé' });
    }

    const ins = await pool.query(
      `INSERT INTO localisations (code_emplacement, batiment, etage, description_fr, description_ar, type_local, type_local_custom)
       VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [code_emplacement, batiment, etage, description_fr || null, description_ar || null, finalType, finalCustom]
    );

    res.status(201).json(ins.rows[0]);
  } catch (e) {
    console.error('create localisation error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Maintenance Responsible: Get types with responsibles count
router.get('/maintenance/:responsibleId/types-with-responsibles', async (req, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT st.id, st.code, st.name, COUNT(r.employee_id)::int as responsibles_count
      FROM signal_types st
      LEFT JOIN signal_type_responsibles r ON r.type_id = st.id
      GROUP BY st.id ORDER BY st.name
    `);
    res.json(rows);
  } catch (e) { res.status(500).json({ error: 'Erreur serveur' }); }
});

// Maintenance Responsible: Get maintenance employees
router.get('/maintenance/:responsibleId/employees', async (req, res) => {
  try {
    const { responsibleId } = req.params;
    const employees = await getEmployeesUnderResponsible(responsibleId);
    res.json(employees);
  } catch (e) { res.status(500).json({ error: 'Erreur serveur' }); }
});

// Maintenance Responsible: Get responsibles for a type
router.get('/maintenance/:responsibleId/types/:typeId/responsibles', async (req, res) => {
  try {
    const { responsibleId, typeId } = req.params;
    const { rows } = await pool.query(`
      SELECT r.employee_id as id, e.first_name, e.last_name
      FROM signal_type_responsibles r
      JOIN employees e ON e.id = r.employee_id
      WHERE r.type_id = $1
      ORDER BY e.first_name, e.last_name
    `, [typeId]);
    res.json(rows);
  } catch (e) { res.status(500).json({ error: 'Erreur serveur' }); }
});

// Maintenance Responsible: Assign employee to type
router.post('/maintenance/:responsibleId/types/:typeId/responsibles', async (req, res) => {
  try {
    const { responsibleId, typeId } = req.params;
    const { employeeId } = req.body || {};
    if (!employeeId) return res.status(400).json({ error: 'employeeId requis' });

    const isDirector = await isDirectorAccount(responsibleId);
    const managedEmployees = await getEmployeesUnderResponsible(responsibleId);
    const isManaged = managedEmployees.some(e => String(e.id) === String(employeeId));
    if (!isDirector && !isManaged) return res.status(403).json({ error: 'Employé hors de votre département' });

    await pool.query(
      `INSERT INTO signal_type_responsibles (type_id, employee_id, assigned_by)
       VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`,
      [typeId, employeeId, responsibleId]
    );
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: 'Erreur serveur' }); }
});

// Maintenance Responsible: Remove employee from type
router.delete('/maintenance/:responsibleId/types/:typeId/responsibles/:employeeId', async (req, res) => {
  try {
    const { responsibleId, typeId, employeeId } = req.params;
    const isDirector = await isDirectorAccount(responsibleId);
    const managedEmployees = await getEmployeesUnderResponsible(responsibleId);
    const isManaged = managedEmployees.some(e => String(e.id) === String(employeeId));
    if (!isDirector && !isManaged) return res.status(403).json({ error: 'Employé hors de votre département' });

    await pool.query(`DELETE FROM signal_type_responsibles WHERE type_id = $1 AND employee_id = $2`, [typeId, employeeId]);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: 'Erreur serveur' }); }
});

// Employee: Create signalisation
router.post('/employee/:employeeId/signalisations', (req, res, next) => upload(req, res, next), async (req, res) => {
  const { employeeId } = req.params;
  const body = req.body || {};
  const typeId = body.typeId || body.type_id || body.type;
  const title = body.title || body.name;
  const description = body.description;
  const location = body.location;
  const localisationId = body.localisationId || body.localisation_id;
  const localisation_id = body.localisation_id; // keep original alias
  const photoPath = req.file ? '/uploads/signalisations/' + req.file.filename : null;
  if (!typeId || !title) return res.status(400).json({ error: 'typeId et title requis' });
  // prefer localisation_id if provided
  const finalLocalisationId = localisationId || localisation_id || null;
  const finalLocation = finalLocalisationId ? null : (location || null);

  try {
    const insert = await pool.query(
      `INSERT INTO signalisations (type_id, created_by, title, description, location, localisation_id, photo_path)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id, created_at`,
      [typeId, employeeId, title, description || null, finalLocation, finalLocalisationId, photoPath]
    );
    const signalisationId = insert.rows[0].id;

    // 1. Notify maintenance department responsible(s)
    const maintenanceIds = await getMaintenanceResponsibleIds();
    await Promise.all(maintenanceIds.map(id => createNotificationDirect({
      recipientId: id,
      senderId: employeeId,
      title: 'Nouvelle signalisation',
      body: title,
      refType: 'SIGNALISATION',
      refId: signalisationId
    })));

    // 2. Notify employees assigned to this signal type
    const assignedEmployees = await pool.query(
      `SELECT employee_id FROM signal_type_responsibles WHERE type_id = $1`,
      [typeId]
    );
    await Promise.all(assignedEmployees.rows.map(r => createNotificationDirect({
      recipientId: r.employee_id,
      senderId: employeeId,
      title: 'Nouvelle signalisation (Type assigné)',
      body: title,
      refType: 'SIGNALISATION',
      refId: signalisationId
    })));

    res.json({ id: signalisationId, created_at: insert.rows[0].created_at });
  } catch (e) {
    console.error('Erreur création:', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Employee: Update own signalisation (basic fields)
router.put('/employee/:employeeId/signalisations/:signalId', async (req, res) => {
  const { employeeId, signalId } = req.params;
  const { typeId, title, description } = req.body || {};

  if (!typeId || !title) {
    return res.status(400).json({ error: 'typeId و العنوان مطلوبان' });
  }

  try {
    const current = await pool.query(
      `SELECT id, created_by, is_treated FROM signalisations WHERE id = $1`,
      [signalId]
    );
    if (!current.rows.length) {
      return res.status(404).json({ error: 'الإشارة غير موجودة' });
    }
    const row = current.rows[0];
    if (String(row.created_by) !== String(employeeId)) {
      return res.status(403).json({ error: 'غير مسموح بتعديل هذه الإشارة' });
    }
    if (row.is_treated) {
      return res.status(400).json({ error: 'لا يمكن تعديل إشارة تمت معالجتها' });
    }

    const update = await pool.query(
      `UPDATE signalisations
       SET type_id = $1,
           title = $2,
           description = $3
       WHERE id = $4
       RETURNING *`,
      [typeId, title, description || null, signalId]
    );

    res.json(update.rows[0]);
  } catch (e) {
    console.error('update signalisation error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Employee: Delete own signalisation
router.delete('/employee/:employeeId/signalisations/:signalId', async (req, res) => {
  const { employeeId, signalId } = req.params;
  try {
    const current = await pool.query(
      `SELECT id, created_by, is_treated FROM signalisations WHERE id = $1`,
      [signalId]
    );
    if (!current.rows.length) {
      return res.status(404).json({ error: 'الإشارة غير موجودة' });
    }
    const row = current.rows[0];
    if (String(row.created_by) !== String(employeeId)) {
      return res.status(403).json({ error: 'غير مسموح بحذف هذه الإشارة' });
    }
    if (row.is_treated) {
      return res.status(400).json({ error: 'لا يمكن حذف إشارة تمت معالجتها' });
    }

    await pool.query(`DELETE FROM signalisations WHERE id = $1`, [signalId]);
    res.json({ ok: true });
  } catch (e) {
    console.error('delete signalisation error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Employee: Get statistics for own signalisations (MUST come before /signalisations to avoid route conflicts)
router.get('/employee/:employeeId/statistics', async (req, res) => {
  const { employeeId } = req.params;
  const { from, to } = req.query;
  try {
    const filters = ['s.created_by = $1'];
    const params = [employeeId];
    let idx = 2;

    if (from) {
      filters.push(`s.created_at >= $${idx++}`);
      params.push(from);
    }
    if (to) {
      filters.push(`s.created_at <= $${idx++}`);
      params.push(to);
    }

    const whereClause = 'WHERE ' + filters.join(' AND ');

    const overview = await pool.query(
      `SELECT 
        COUNT(*)::int as total,
        COUNT(*) FILTER (WHERE s.is_treated = false)::int as pending,
        COUNT(*) FILTER (WHERE s.is_treated = true)::int as treated,
        COUNT(*) FILTER (WHERE s.priority = 'high')::int as high_priority,
        COUNT(*) FILTER (WHERE s.priority = 'medium')::int as medium_priority,
        COUNT(*) FILTER (WHERE s.priority = 'low')::int as low_priority
       FROM signalisations s ${whereClause}`,
      params
    );

    const byType = await pool.query(
      `SELECT st.name as type_name,
              COUNT(*)::int as total,
              COUNT(*) FILTER (WHERE s.is_treated = false)::int as pending,
              COUNT(*) FILTER (WHERE s.is_treated = true)::int as treated
       FROM signalisations s
       JOIN signal_types st ON st.id = s.type_id
       ${whereClause}
       GROUP BY st.name
       ORDER BY total DESC`,
      params
    );

    res.json({
      overview: overview.rows[0] || {
        total: 0,
        pending: 0,
        treated: 0,
        high_priority: 0,
        medium_priority: 0,
        low_priority: 0
      },
      byType: byType.rows || []
    });
  } catch (e) {
    console.error('Employee signals statistics error:', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Employee: List own signalisations
router.get('/employee/:employeeId/signalisations', async (req, res) => {
  const { employeeId } = req.params;
  try {
    const { rows } = await pool.query(
      `SELECT s.*, st.name as type_name,
              CASE WHEN s.localisation_id IS NOT NULL
                   THEN (l.code_emplacement || ' (' || COALESCE(l.description_ar,'') || ')')
                   ELSE s.location
              END AS location
       FROM signalisations s
       JOIN signal_types st ON st.id = s.type_id
       LEFT JOIN localisations l ON l.id = s.localisation_id
       WHERE s.created_by = $1
       ORDER BY s.created_at DESC`,
      [employeeId]
    );
    res.json(rows);
  } catch (e) { res.status(500).json({ error: 'Erreur serveur' }); }
});


// Assigned employee: List signalisations for types assigned to this employee
router.get('/assigned/:employeeId/signalisations', async (req, res) => {
  const { employeeId } = req.params;
  const { q, typeId, status, from, to } = req.query;
  try {
    // Fetch assigned types first
    const assignedTypes = await pool.query(
      `SELECT type_id FROM signal_type_responsibles WHERE employee_id = $1`,
      [employeeId]
    );

    if (assignedTypes.rowCount === 0) {
      return res.json({ data: [], stats: { total: 0, pending: 0, treated: 0 } });
    }

    const typeIds = assignedTypes.rows.map(r => r.type_id);

    const filters = [`s.type_id = ANY($1::uuid[])`];
    const params = [typeIds];
    let idx = 2;

    if (typeId) { filters.push(`s.type_id = $${idx++}`); params.push(typeId); }
    if (status === 'treated') filters.push(`s.is_treated = true`);
    if (status === 'pending') filters.push(`s.is_treated = false`);
    if (from) { filters.push(`s.created_at >= $${idx++}`); params.push(from); }
    if (to) { filters.push(`s.created_at <= $${idx++}`); params.push(to); }
    if (q) { filters.push(`(s.title ILIKE $${idx} OR s.description ILIKE $${idx})`); params.push(`%${q}%`); idx++; }

    const where = 'WHERE ' + filters.join(' AND ');

    const list = await pool.query(
      `SELECT s.*, st.name as type_name, e.first_name || ' ' || e.last_name as employee_name,
              CASE WHEN s.localisation_id IS NOT NULL
                   THEN (l.code_emplacement || ' (' || COALESCE(l.description_ar,'') || ')')
                   ELSE s.location
              END AS location
       FROM signalisations s
       JOIN signal_types st ON st.id = s.type_id
       JOIN employees e ON e.id = s.created_by
       LEFT JOIN localisations l ON l.id = s.localisation_id
       ${where}
       ORDER BY s.created_at DESC LIMIT 200`,
      params
    );

    const stats = await pool.query(
      `SELECT COUNT(*)::int as total,
              COUNT(*) FILTER (WHERE is_treated = false)::int as pending,
              COUNT(*) FILTER (WHERE is_treated = true)::int as treated
       FROM signalisations s ${where}`,
      params
    );

    res.json({ data: list.rows, stats: stats.rows[0] });
  } catch (e) {
    console.error('Erreur list assigned:', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Assigned employee: list assigned type IDs
router.get('/assigned/:employeeId/types', async (req, res) => {
  const { employeeId } = req.params;
  try {
    const assignedTypes = await pool.query(
      `SELECT DISTINCT type_id FROM signal_type_responsibles WHERE employee_id = $1`,
      [employeeId]
    );
    res.json({ typeIds: assignedTypes.rows.map(r => r.type_id) });
  } catch (e) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Responsible: List signalisations (maintenance resp OR assigned employee)
router.get('/responsible/:responsibleId/signalisations', async (req, res) => {
  const { responsibleId } = req.params;
  const { q, typeId, status, from, to } = req.query;

  try {
    const isMaint = await isMaintenanceResponsible(responsibleId);
    const isDirector = await isDirectorAccount(responsibleId);
    const assignedTypes = await pool.query(
      `SELECT type_id FROM signal_type_responsibles WHERE employee_id = $1`,
      [responsibleId]
    );

    if (!isMaint && !isDirector && assignedTypes.rowCount === 0) {
      return res.status(403).json({ error: 'Accès refusé' });
    }

    const filters = [];
    const params = [];
    let idx = 1;

    if (!isMaint && !isDirector) {
      const typeIds = assignedTypes.rows.map(r => r.type_id);
      filters.push(`s.type_id = ANY($${idx++}::uuid[])`);
      params.push(typeIds);
    }

    if (typeId) { filters.push(`s.type_id = $${idx++}`); params.push(typeId); }
    if (status === 'treated') filters.push(`s.is_treated = true`);
    if (status === 'pending') filters.push(`s.is_treated = false`);
    if (from) { filters.push(`s.created_at >= $${idx++}`); params.push(from); }
    if (to) { filters.push(`s.created_at <= $${idx++}`); params.push(to); }
    if (q) {
      filters.push(`(s.title ILIKE $${idx} OR s.description ILIKE $${idx})`);
      params.push(`%${q}%`);
      idx++;
    }

    const where = filters.length ? 'WHERE ' + filters.join(' AND ') : '';

    const list = await pool.query(
      `SELECT s.*, st.name as type_name, e.first_name || ' ' || e.last_name as employee_name,
              CASE WHEN s.localisation_id IS NOT NULL
                   THEN (l.code_emplacement || ' (' || COALESCE(l.description_ar,'') || ')')
                   ELSE s.location
              END AS location
       FROM signalisations s
       JOIN signal_types st ON st.id = s.type_id
       JOIN employees e ON e.id = s.created_by
       LEFT JOIN localisations l ON l.id = s.localisation_id
       ${where}
       ORDER BY s.created_at DESC LIMIT 200`,
      params
    );

    const stats = await pool.query(
      `SELECT COUNT(*)::int as total,
              COUNT(*) FILTER (WHERE is_treated = false)::int as pending,
              COUNT(*) FILTER (WHERE is_treated = true)::int as treated
       FROM signalisations s ${where}`,
      params
    );

    res.json({ data: list.rows, stats: stats.rows[0] });
  } catch (e) {
    console.error('Erreur list:', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Responsible: Mark viewed
router.post('/responsible/:responsibleId/signalisations/:id/mark-viewed', async (req, res) => {
  const { responsibleId, id } = req.params;
  try {
    const isMaint = await isMaintenanceResponsible(responsibleId);
    const isDirector = await isDirectorAccount(responsibleId);
    const hasAccess = await pool.query(
      `SELECT 1 FROM signalisations s WHERE s.id = $1 
       AND EXISTS (SELECT 1 FROM signal_type_responsibles r WHERE r.type_id = s.type_id AND r.employee_id = $2)`,
      [id, responsibleId]
    );

    if (!isMaint && !isDirector && hasAccess.rowCount === 0) {
      return res.status(403).json({ error: 'Non autorisé' });
    }

    // Mark viewed on the main record as well
    await pool.query(`UPDATE signalisations SET is_viewed = true WHERE id = $1`, [id]);
    await pool.query(`INSERT INTO signalisations_views (signalisation_id, viewer_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`, [id, responsibleId]);
    await pool.query(`INSERT INTO signalisations_status_history (signalisation_id, status, changed_by, note) VALUES ($1,'VIEWED',$2,$3)`, [id, responsibleId, 'Vu']);

    // Notify creator that their signalisation was viewed by name
    const details = await pool.query(
      `SELECT s.created_by, s.title, (e.first_name || ' ' || e.last_name) AS viewer_name
       FROM signalisations s
       JOIN employees e ON e.id = $1
       WHERE s.id = $2`,
      [responsibleId, id]
    );
    if (details.rowCount > 0) {
      const d = details.rows[0];
      await createNotificationDirect({
        recipientId: d.created_by,
        senderId: responsibleId,
        title: 'تم الاطلاع على الإشارة',
        body: `${d.viewer_name || ''} - ${d.title || ''}`.trim(),
        refType: 'SIGNALISATION',
        refId: id
      });
    }
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: 'Erreur serveur' }); }
});

// Responsible: Mark treated
router.post('/responsible/:responsibleId/signalisations/:id/mark-treated', async (req, res) => {
  const { responsibleId, id } = req.params;
  try {
    const isMaint = await isMaintenanceResponsible(responsibleId);
    const isDirector = await isDirectorAccount(responsibleId);
    const signalCheck = await pool.query(`SELECT s.created_by, s.type_id FROM signalisations s WHERE s.id = $1`, [id]);

    if (signalCheck.rowCount === 0) {
      return res.status(404).json({ error: 'Introuvable' });
    }

    const hasAccess = await pool.query(
      `SELECT 1 FROM signal_type_responsibles WHERE type_id = $1 AND employee_id = $2`,
      [signalCheck.rows[0].type_id, responsibleId]
    );

    if (!isMaint && !isDirector && hasAccess.rowCount === 0) {
      return res.status(403).json({ error: 'Non autorisé' });
    }

    const up = await pool.query(
      `UPDATE signalisations SET is_treated = true, treated_by = $1, treated_at = CURRENT_TIMESTAMP 
       WHERE id = $2 AND is_treated = false RETURNING id, created_by, title`,
      [responsibleId, id]
    );

    if (up.rowCount === 0) {
      return res.status(404).json({ error: 'Déjà traité' });
    }

    const row = up.rows[0];
    await createNotificationDirect({
      recipientId: row.created_by,
      senderId: responsibleId,
      title: 'Signalisation traitée',
      body: row.title,
      refType: 'SIGNALISATION',
      refId: row.id
    });
    await pool.query(`INSERT INTO signalisations_status_history (signalisation_id, status, changed_by, note) VALUES ($1,'TREATED',$2,$3)`, [id, responsibleId, 'Traitée']);
    res.json({ id, is_treated: true });
  } catch (e) { res.status(500).json({ error: 'Erreur serveur' }); }
});
// Add this endpoint to your signals.js router

// Responsible: Get comprehensive statistics
router.get('/responsible/:responsibleId/statistics', async (req, res) => {
  const { responsibleId } = req.params;
  const { from, to } = req.query;

  try {
    const isMaint = await isMaintenanceResponsible(responsibleId);
    const isDirector = await isDirectorAccount(responsibleId);
    const assignedTypes = await pool.query(
      `SELECT type_id FROM signal_type_responsibles WHERE employee_id = $1`,
      [responsibleId]
    );

    if (!isMaint && !isDirector && assignedTypes.rowCount === 0) {
      return res.status(403).json({ error: 'Accès refusé' });
    }

    const filters = [];
    const params = [];
    let idx = 1;

    if (!isMaint && !isDirector) {
      const typeIds = assignedTypes.rows.map(r => r.type_id);
      filters.push(`s.type_id = ANY($${idx++}::uuid[])`);
      params.push(typeIds);
    }

    if (from) { filters.push(`s.created_at >= $${idx++}`); params.push(from); }
    if (to) { filters.push(`s.created_at <= $${idx++}`); params.push(to); }

    const where = filters.length ? 'WHERE ' + filters.join(' AND ') : '';

    // Overview stats
    const overview = await pool.query(
      `SELECT 
        COUNT(*)::int as total,
        COUNT(*) FILTER (WHERE is_treated = false)::int as pending,
        COUNT(*) FILTER (WHERE is_treated = true)::int as treated,
        ROUND(AVG(EXTRACT(EPOCH FROM (treated_at - created_at)) / 3600)::numeric, 1) as avg_treatment_time
       FROM signalisations s ${where}`,
      params
    );

    // By type
    const byType = await pool.query(
      `SELECT st.name, COUNT(s.id)::int as count
       FROM signalisations s
       JOIN signal_types st ON st.id = s.type_id
       ${where}
       GROUP BY st.name
       ORDER BY count DESC`,
      params
    );

    // Daily trend (last 30 days or date range)
    const dailyTrend = await pool.query(
      `SELECT 
        TO_CHAR(s.created_at, 'YYYY-MM-DD') as date,
        COUNT(*)::int as count
       FROM signalisations s
       ${where}
       GROUP BY TO_CHAR(s.created_at, 'YYYY-MM-DD')
       ORDER BY date DESC
       LIMIT 30`,
      params
    );

    // Top locations
    const topLocations = await pool.query(
      `SELECT 
        COALESCE(l.code_emplacement, s.location, 'غير محدد') as location,
        l.batiment,
        l.etage,
        COUNT(s.id)::int as count
       FROM signalisations s
       LEFT JOIN localisations l ON l.id = s.localisation_id
       ${where}
       GROUP BY l.code_emplacement, s.location, l.batiment, l.etage
       ORDER BY count DESC
       LIMIT 10`,
      params
    );

    // Treated signals
    const treatedSignals = await pool.query(
      `SELECT s.title, st.name as type_name, s.treated_at,
              CASE WHEN s.localisation_id IS NOT NULL
                   THEN (l.code_emplacement || ' (' || COALESCE(l.description_ar,'') || ')')
                   ELSE s.location
              END AS location
       FROM signalisations s
       JOIN signal_types st ON st.id = s.type_id
       LEFT JOIN localisations l ON l.id = s.localisation_id
       ${where.replace('WHERE', 'WHERE s.is_treated = true AND')}
       ORDER BY s.treated_at DESC
       LIMIT 20`,
      filters.length ? [...params] : []
    );

    // Pending signals
    const pendingSignals = await pool.query(
      `SELECT s.title, st.name as type_name, s.created_at,
              CASE WHEN s.localisation_id IS NOT NULL
                   THEN (l.code_emplacement || ' (' || COALESCE(l.description_ar,'') || ')')
                   ELSE s.location
              END AS location
       FROM signalisations s
       JOIN signal_types st ON st.id = s.type_id
       LEFT JOIN localisations l ON l.id = s.localisation_id
       ${where.replace('WHERE', 'WHERE s.is_treated = false AND')}
       ORDER BY s.created_at DESC
       LIMIT 20`,
      filters.length ? [...params] : []
    );

    res.json({
      overview: overview.rows[0],
      byType: byType.rows,
      dailyTrend: dailyTrend.rows.reverse(),
      topLocations: topLocations.rows,
      treatedSignals: treatedSignals.rows,
      pendingSignals: pendingSignals.rows
    });
  } catch (e) {
    console.error('Erreur statistiques:', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});
// Responsible: Get comprehensive statistics
router.get('/responsible/:responsibleId/statistics', async (req, res) => {
  const { responsibleId } = req.params;
  const { from, to } = req.query;

  try {
    const isMaint = await isMaintenanceResponsible(responsibleId);
    const isDirector = await isDirectorAccount(responsibleId);
    const assignedTypes = await pool.query(
      `SELECT type_id FROM signal_type_responsibles WHERE employee_id = $1`,
      [responsibleId]
    );

    if (!isMaint && !isDirector && assignedTypes.rowCount === 0) {
      return res.status(403).json({ error: 'Accès refusé' });
    }

    const filters = [];
    const params = [];
    let idx = 1;

    if (!isMaint && !isDirector) {
      const typeIds = assignedTypes.rows.map(r => r.type_id);
      filters.push(`s.type_id = ANY($${idx++}::uuid[])`);
      params.push(typeIds);
    }

    if (from) { filters.push(`s.created_at >= $${idx++}`); params.push(from); }
    if (to) { filters.push(`s.created_at <= $${idx++}`); params.push(to); }

    const where = filters.length ? 'WHERE ' + filters.join(' AND ') : '';

    // Overview stats
    const overview = await pool.query(
      `SELECT 
        COUNT(*)::int as total,
        COUNT(*) FILTER (WHERE is_treated = false)::int as pending,
        COUNT(*) FILTER (WHERE is_treated = true)::int as treated,
        ROUND(AVG(EXTRACT(EPOCH FROM (treated_at - created_at)) / 3600)::numeric, 1) as avg_treatment_time
       FROM signalisations s ${where}`,
      params
    );

    // By type
    const byType = await pool.query(
      `SELECT st.name, COUNT(s.id)::int as count
       FROM signalisations s
       JOIN signal_types st ON st.id = s.type_id
       ${where}
       GROUP BY st.name
       ORDER BY count DESC`,
      params
    );

    // Daily trend (last 30 days or date range)
    const dailyTrend = await pool.query(
      `SELECT 
        TO_CHAR(s.created_at, 'YYYY-MM-DD') as date,
        COUNT(*)::int as count
       FROM signalisations s
       ${where}
       GROUP BY TO_CHAR(s.created_at, 'YYYY-MM-DD')
       ORDER BY date DESC
       LIMIT 30`,
      params
    );

    // Top locations
    const topLocations = await pool.query(
      `SELECT 
        COALESCE(l.code_emplacement, s.location, 'غير محدد') as location,
        l.batiment,
        l.etage,
        COUNT(s.id)::int as count
       FROM signalisations s
       LEFT JOIN localisations l ON l.id = s.localisation_id
       ${where}
       GROUP BY l.code_emplacement, s.location, l.batiment, l.etage
       ORDER BY count DESC
       LIMIT 10`,
      params
    );

    // Treated signals
    const treatedWhere = where ? where.replace('WHERE', 'WHERE s.is_treated = true AND') : 'WHERE s.is_treated = true';
    const treatedSignals = await pool.query(
      `SELECT s.title, st.name as type_name, s.treated_at,
              CASE WHEN s.localisation_id IS NOT NULL
                   THEN (l.code_emplacement || ' (' || COALESCE(l.description_ar,'') || ')')
                   ELSE s.location
              END AS location
       FROM signalisations s
       JOIN signal_types st ON st.id = s.type_id
       LEFT JOIN localisations l ON l.id = s.localisation_id
       ${treatedWhere}
       ORDER BY s.treated_at DESC
       LIMIT 20`,
      params
    );

    // Pending signals
    const pendingWhere = where ? where.replace('WHERE', 'WHERE s.is_treated = false AND') : 'WHERE s.is_treated = false';
    const pendingSignals = await pool.query(
      `SELECT s.title, st.name as type_name, s.created_at,
              CASE WHEN s.localisation_id IS NOT NULL
                   THEN (l.code_emplacement || ' (' || COALESCE(l.description_ar,'') || ')')
                   ELSE s.location
              END AS location
       FROM signalisations s
       JOIN signal_types st ON st.id = s.type_id
       LEFT JOIN localisations l ON l.id = s.localisation_id
       ${pendingWhere}
       ORDER BY s.created_at DESC
       LIMIT 20`,
      params
    );

    res.json({
      overview: overview.rows[0],
      byType: byType.rows,
      dailyTrend: dailyTrend.rows.reverse(),
      topLocations: topLocations.rows,
      treatedSignals: treatedSignals.rows,
      pendingSignals: pendingSignals.rows
    });
  } catch (e) {
    console.error('Erreur statistiques:', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});
// Ajouter ces endpoints dans signals.js après les autres endpoints complaints

// Statistics Overview
async function complaintsStatisticsOverviewHandler(req, res) {
  try {
    const { from, to } = req.query;
    const filters = [];
    const params = [];
    let idx = 1;

    if (from) {
      filters.push(`c.created_at >= $${idx++}`);
      params.push(from);
    }
    if (to) {
      filters.push(`c.created_at <= $${idx++}`);
      params.push(to);
    }

    const filterExpression = filters.join(' AND ');
    const whereClause = filterExpression ? `WHERE ${filterExpression}` : '';
    const resolutionWhere = whereClause
      ? `${whereClause} AND c.status = 'completed' AND c.resolved_at IS NOT NULL`
      : `WHERE c.status = 'completed' AND c.resolved_at IS NOT NULL`;
    const satisfactionWhere = whereClause
      ? `${whereClause} AND c.satisfaction_rating IS NOT NULL`
      : `WHERE c.satisfaction_rating IS NOT NULL`;

    const overview = await pool.query(
      `SELECT 
        COUNT(*)::int as total,
        COUNT(*) FILTER (WHERE c.status = 'pending')::int as pending,
        COUNT(*) FILTER (WHERE c.status = 'completed')::int as completed,
        ROUND(COALESCE(AVG(CASE 
          WHEN c.status = 'completed' AND c.resolved_at IS NOT NULL 
          THEN EXTRACT(EPOCH FROM (c.resolved_at - c.created_at)) / 3600 
        END), 0)::numeric, 2) as avg_resolution_hours,
        COUNT(*) FILTER (
          WHERE c.status = 'pending'
            AND c.due_date IS NOT NULL
            AND c.due_date < CURRENT_TIMESTAMP
        )::int as overdue,
        ROUND(COALESCE(AVG(c.satisfaction_rating), 0)::numeric, 2) as avg_satisfaction
       FROM complaints c ${whereClause}`,
      params
    );

    const byType = await pool.query(
      `SELECT ct.name, ct.code,
              COUNT(c.id)::int as total,
              COUNT(*) FILTER (WHERE c.status = 'pending')::int as pending,
              COUNT(*) FILTER (WHERE c.status = 'completed')::int as completed
       FROM complaints c
       JOIN complaint_types ct ON ct.id = c.type_id
       ${whereClause}
       GROUP BY ct.id, ct.name, ct.code
       ORDER BY total DESC`,
      params
    );

    const byPriority = await pool.query(
      `SELECT c.priority,
              COUNT(*)::int as total,
              COUNT(*) FILTER (WHERE c.status = 'pending')::int as pending,
              COUNT(*) FILTER (WHERE c.status = 'completed')::int as completed,
              ROUND(COALESCE(AVG(CASE 
                WHEN c.status = 'completed' AND c.resolved_at IS NOT NULL 
                THEN EXTRACT(EPOCH FROM (c.resolved_at - c.created_at)) / 3600 
              END), 0)::numeric, 2) as avg_hours
       FROM complaints c ${whereClause}
       GROUP BY c.priority
       ORDER BY 
         CASE c.priority 
           WHEN 'high' THEN 1 
           WHEN 'medium' THEN 2 
           WHEN 'low' THEN 3 
         END`,
      params
    );

    const dailyParams = [];
    let dailyIdx = 1;
    let dailyWhere = `WHERE c.created_at >= CURRENT_DATE - INTERVAL '30 days'`;
    if (from) {
      dailyWhere += ` AND c.created_at >= $${dailyIdx++}`;
      dailyParams.push(from);
    }
    if (to) {
      dailyWhere += ` AND c.created_at <= $${dailyIdx++}`;
      dailyParams.push(to);
    }

    const dailyTrend = await pool.query(
      `SELECT 
        DATE(c.created_at) as date,
        COUNT(*)::int as count,
        COUNT(*) FILTER (WHERE c.status = 'completed')::int as completed
       FROM complaints c
       ${dailyWhere}
       GROUP BY DATE(c.created_at)
       ORDER BY date ASC`,
      dailyParams
    );

    const topEmployees = await pool.query(
      `SELECT 
        CASE WHEN c.is_anonymous THEN 'مجهول' 
             ELSE COALESCE(e.first_name || ' ' || e.last_name, 'غير معروف')
        END as employee_name,
        COUNT(c.id)::int as complaint_count
       FROM complaints c
       LEFT JOIN employees e ON e.id = c.employee_id
       ${whereClause}
       GROUP BY 
         CASE WHEN c.is_anonymous THEN 'مجهول' 
              ELSE COALESCE(e.first_name || ' ' || e.last_name, 'غير معروف')
         END
       ORDER BY complaint_count DESC
       LIMIT 10`,
      params
    );

    const resolutionDistribution = await pool.query(
      `SELECT time_range, COUNT(*)::int AS count
       FROM (
         SELECT 
           CASE 
             WHEN EXTRACT(EPOCH FROM (c.resolved_at - c.created_at)) / 3600 <= 24 THEN '0-24 ساعة'
             WHEN EXTRACT(EPOCH FROM (c.resolved_at - c.created_at)) / 3600 <= 72 THEN '24-72 ساعة'
             WHEN EXTRACT(EPOCH FROM (c.resolved_at - c.created_at)) / 3600 <= 168 THEN '3-7 أيام'
             ELSE 'أكثر من 7 أيام'
           END as time_range
         FROM complaints c
         ${resolutionWhere}
       ) buckets
       GROUP BY time_range
       ORDER BY array_position(
         ARRAY['0-24 ساعة','24-72 ساعة','3-7 أيام','أكثر من 7 أيام'],
         time_range
       )`,
      params
    );

    const satisfactionDistribution = await pool.query(
      `SELECT 
        c.satisfaction_rating as rating,
        COUNT(*)::int as count
       FROM complaints c
       ${satisfactionWhere}
       GROUP BY c.satisfaction_rating
       ORDER BY c.satisfaction_rating DESC`,
      params
    );

    const priorityStatusMatrix = await pool.query(
      `SELECT 
         c.priority,
         c.status,
         COUNT(*)::int as total,
         COUNT(*) FILTER (
           WHERE c.status = 'pending'
             AND c.due_date IS NOT NULL
             AND c.due_date < CURRENT_TIMESTAMP
         )::int as overdue,
         ROUND(COALESCE(AVG(CASE 
           WHEN c.status = 'completed' AND c.resolved_at IS NOT NULL
             THEN EXTRACT(EPOCH FROM (c.resolved_at - c.created_at)) / 3600
         END), 0)::numeric, 2) as avg_resolution_hours
       FROM complaints c
       ${whereClause}
       GROUP BY c.priority, c.status
       ORDER BY c.priority, c.status`,
      params
    );

    const departmentDistribution = await pool.query(
      `SELECT 
         COALESCE(d.name, 'غير محدد') AS department_name,
         COUNT(*)::int as total,
         COUNT(*) FILTER (WHERE c.status = 'pending')::int as pending,
         COUNT(*) FILTER (WHERE c.status = 'completed')::int as completed
       FROM complaints c
       LEFT JOIN departments d ON d.id = c.department_id
       ${whereClause}
       GROUP BY department_name
       ORDER BY total DESC
       LIMIT 12`,
      params
    );

    res.json({
      overview: overview.rows[0] || {
        total: 0,
        pending: 0,
        completed: 0,
        avg_resolution_hours: 0,
        overdue: 0,
        avg_satisfaction: 0
      },
      byType: byType.rows || [],
      byPriority: byPriority.rows || [],
      dailyTrend: dailyTrend.rows || [],
      topEmployees: topEmployees.rows || [],
      resolutionDistribution: resolutionDistribution.rows || [],
      satisfactionDistribution: satisfactionDistribution.rows || [],
      priorityStatusMatrix: priorityStatusMatrix.rows || [],
      departmentDistribution: departmentDistribution.rows || []
    });
  } catch (e) {
    console.error('Statistics error:', e);
    res.status(500).json({ error: 'Erreur serveur: ' + e.message });
  }
}

async function complaintsStatisticsMonthlyHandler(_req, res) {
  try {
    const result = await pool.query(`
      SELECT 
        TO_CHAR(c.created_at, 'YYYY-MM') as month,
        COUNT(*)::int as total,
        COUNT(*) FILTER (WHERE c.status = 'completed')::int as completed,
        ROUND(COALESCE(AVG(CASE 
          WHEN c.status = 'completed' AND c.resolved_at IS NOT NULL 
          THEN EXTRACT(EPOCH FROM (c.resolved_at - c.created_at)) / 3600 
        END), 0)::numeric, 2) as avg_hours
      FROM complaints c
      WHERE c.created_at >= CURRENT_DATE - INTERVAL '12 months'
      GROUP BY TO_CHAR(c.created_at, 'YYYY-MM')
      ORDER BY month DESC
      LIMIT 12
    `);
    res.json(result.rows.reverse());
  } catch (e) {
    console.error('Monthly stats error:', e);
    res.status(500).json({ error: 'Erreur serveur: ' + e.message });
  }
}
// Responsible: Mark in progress
router.post('/responsible/:responsibleId/signalisations/:id/mark-in-progress', async (req, res) => {
  const { responsibleId, id } = req.params;
  try {
    const isMaint = await isMaintenanceResponsible(responsibleId);
    const isDirector = await isDirectorAccount(responsibleId);
    const signalCheck = await pool.query(`SELECT s.created_by, s.type_id, s.title FROM signalisations s WHERE s.id = $1`, [id]);

    if (signalCheck.rowCount === 0) {
      return res.status(404).json({ error: 'Introuvable' });
    }

    const hasAccess = await pool.query(
      `SELECT 1 FROM signal_type_responsibles WHERE type_id = $1 AND employee_id = $2`,
      [signalCheck.rows[0].type_id, responsibleId]
    );

    if (!isMaint && !isDirector && hasAccess.rowCount === 0) {
      return res.status(403).json({ error: 'Non autorisé' });
    }

    await pool.query(`INSERT INTO signalisations_status_history (signalisation_id, status, changed_by, note) VALUES ($1,'IN_PROGRESS',$2,$3)`, [id, responsibleId, 'En cours']);

    await createNotificationDirect({
      recipientId: signalCheck.rows[0].created_by,
      senderId: responsibleId,
      title: 'الإشارة قيد المعالجة',
      body: signalCheck.rows[0].title || '',
      refType: 'SIGNALISATION',
      refId: id
    });

    res.json({ id, status: 'IN_PROGRESS' });
  } catch (e) { res.status(500).json({ error: 'Erreur serveur' }); }
});
// =====================
// SUGGESTIONS FUNCTIONS
// =====================

function mapSuggestion(row, { viewer } = {}) {
  const attachments = Array.isArray(row.attachments) ? row.attachments : [];
  const attachmentPath = row.latest_file_path || (attachments[0]?.file_path ?? null);
  const employee = {
    id: row.employee_id,
    first_name: row.employee_first_name,
    last_name: row.employee_last_name
  };
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    category: row.category,
    status: row.status,
    type_id: row.type_id,
    type_name: row.type_name || null,
    department_id: row.department_id,
    department_name: row.department_name || null,
    director_comment: row.director_comment,
    handled_by: row.handled_by,
    redirected_to: row.redirected_to,
    created_at: row.created_at,
    reviewed_at: row.reviewed_at,
    decision_at: row.decision_at,
    employee,
    attachments,
    attachment_path: attachmentPath
  };
}

async function recordSuggestionHistory(suggestionId, changedBy, oldStatus, newStatus, comment) {
  try {
    await pool.query(
      `INSERT INTO suggestion_history (suggestion_id, changed_by, old_status, new_status, comment)
       VALUES ($1,$2,$3,$4,$5)`,
      [suggestionId, changedBy, oldStatus, newStatus, comment || null]
    );
  } catch (e) {
    console.error('record suggestion history error', e);
  }
}

async function notifySuggestionDirectors({ suggestionId, employeeId, message, title }) {
  try {
    const directorIds = await pool.query(`
      SELECT DISTINCT u.id
      FROM users u
      JOIN employees e ON e.user_id = u.id
      WHERE u.role = 'director' OR e.id IN (SELECT responsible_id FROM departments WHERE responsible_id IS NOT NULL)
    `);
    const userId = await getUserIdByEmployeeId(employeeId);
    for (const dir of directorIds.rows) {
      await pool.query(
        `INSERT INTO suggestion_notifications (suggestion_id, recipient_user_id, message, title, is_read)
         VALUES ($1,$2,$3,$4,false)`,
        [suggestionId, dir.id, message, title || 'اقتراح جديد']
      );
    }
    if (userId) {
      await pool.query(
        `INSERT INTO suggestion_notifications (suggestion_id, recipient_id, message, title, is_read)
         VALUES ($1,$2,$3,$4,false)`,
        [suggestionId, employeeId, `تم إرسال اقتراحك: ${title}`, title || 'اقتراح جديد']
      );
    }
  } catch (e) {
    console.error('notify suggestion directors error', e);
  }
}

async function listSuggestionTypes(_req, res) {
  try {
    const { rows } = await pool.query(`SELECT id, code, name FROM suggestion_types ORDER BY name`);
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function createSuggestion(req, res) {
  try {
    const { employeeId } = req.params;
    const { typeId, title, description, category, departmentId } = req.body || {};
    if (!title) {
      return res.status(400).json({ error: 'العنوان مطلوب' });
    }
    const insert = await pool.query(
      `INSERT INTO suggestions (employee_id, type_id, title, description, category, department_id)
       VALUES ($1,$2,$3,$4,$5,$6)
       RETURNING id`,
      [
        employeeId,
        typeId || null,
        title,
        description || null,
        category || null,
        departmentId || null
      ]
    );
    await recordSuggestionHistory(insert.rows[0].id, employeeId, null, 'under_review', 'تم إنشاء الاقتراح');
    await notifySuggestionDirectors({
      suggestionId: insert.rows[0].id,
      employeeId,
      message: `تم تسجيل اقتراح جديد: ${title}`,
      title
    });
    res.status(201).json({ id: insert.rows[0].id });
  } catch (e) {
    console.error('create suggestion error', e);
    res.status(500).json({ error: e?.message || 'Erreur serveur' });
  }
}

async function listEmployeeSuggestions(req, res) {
  try {
    const { employeeId } = req.params;
    const { rows } = await pool.query(
      `SELECT s.*, st.name AS type_name, d.name AS department_name,
              e.first_name AS employee_first_name, e.last_name AS employee_last_name,
              att.attachments, att.latest_file_path
       FROM suggestions s
       LEFT JOIN suggestion_types st ON st.id = s.type_id
       LEFT JOIN departments d ON d.id = s.department_id
       JOIN employees e ON e.id = s.employee_id
       LEFT JOIN LATERAL (
         SELECT
           json_agg(
             json_build_object(
               'id', sa.id,
               'file_path', sa.file_path,
               'file_name', sa.file_name,
               'created_at', sa.created_at
             )
             ORDER BY sa.created_at DESC
           ) AS attachments,
           (ARRAY_AGG(sa.file_path ORDER BY sa.created_at DESC))[1] AS latest_file_path
         FROM suggestion_attachments sa
         WHERE sa.suggestion_id = s.id
       ) att ON true
       WHERE s.employee_id = $1
       ORDER BY s.created_at DESC`,
      [employeeId]
    );
    res.json({ data: rows.map(r => mapSuggestion(r, { viewer: 'owner' })) });
  } catch (e) {
    console.error('list employee suggestions error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function listDirectorSuggestions(req, res) {
  try {
    const { status, typeId, departmentId, employeeId, q, responsibleId } = req.query;
    const filters = [];
    const params = [];
    let idx = 1;
    if (status) {
      filters.push(`s.status = $${idx++}`);
      params.push(status);
    }
    if (typeId) {
      filters.push(`s.type_id = $${idx++}`);
      params.push(typeId);
    }
    if (departmentId) {
      filters.push(`s.department_id = $${idx++}`);
      params.push(departmentId);
    }
    if (employeeId) {
      filters.push(`s.employee_id = $${idx++}`);
      params.push(employeeId);
    }
    if (q) {
      filters.push(`(s.title ILIKE $${idx} OR s.description ILIKE $${idx})`);
      params.push(`%${q}%`);
      idx++;
    }
    if (responsibleId) {
      const deptParamIdx = idx++;
      params.push(responsibleId);
      const redirectParamIdx = idx++;
      params.push(responsibleId);
      const handlerParamIdx = idx++;
      params.push(responsibleId);
      filters.push(`(
        s.department_id IN (SELECT id FROM departments WHERE responsible_id = $${deptParamIdx})
        OR (s.redirected_to IS NOT NULL AND s.redirected_to IN (SELECT id FROM departments WHERE responsible_id = $${redirectParamIdx}))
        OR s.handled_by = $${handlerParamIdx}
      )`);
    }
    const where = filters.length ? 'WHERE ' + filters.join(' AND ') : '';
    const { rows } = await pool.query(
      `SELECT s.*, st.name AS type_name, d.name AS department_name,
              e.first_name AS employee_first_name, e.last_name AS employee_last_name,
              att.attachments, att.latest_file_path
       FROM suggestions s
       LEFT JOIN suggestion_types st ON st.id = s.type_id
       LEFT JOIN departments d ON d.id = s.department_id
       JOIN employees e ON e.id = s.employee_id
       LEFT JOIN LATERAL (
         SELECT
           json_agg(
             json_build_object(
               'id', sa.id,
               'file_path', sa.file_path,
               'file_name', sa.file_name,
               'created_at', sa.created_at
             )
             ORDER BY sa.created_at DESC
           ) AS attachments,
           (ARRAY_AGG(sa.file_path ORDER BY sa.created_at DESC))[1] AS latest_file_path
         FROM suggestion_attachments sa
         WHERE sa.suggestion_id = s.id
       ) att ON true
       ${where}
       ORDER BY s.created_at DESC
       LIMIT 200`,
      params
    );
    res.json(rows.map(r => mapSuggestion(r, { viewer: 'director' })));
  } catch (e) {
    console.error('list director suggestions error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function updateSuggestionStatus(req, res) {
  try {
    const { suggestionId } = req.params;
    const { status, comment, managerId, redirectedTo, redirected_to } = req.body || {};
    const finalRedirectedTo = redirectedTo || redirected_to;
    if (!status || !['under_review', 'accepted', 'rejected'].includes(status)) {
      return res.status(400).json({ error: 'حالة غير صحيحة' });
    }
    const current = await pool.query(`SELECT status, employee_id FROM suggestions WHERE id = $1`, [suggestionId]);
    if (!current.rows.length) {
      return res.status(404).json({ error: 'الاقتراح غير موجود' });
    }
    const existing = current.rows[0];
    const fields = [`status = $1`];
    const params = [status];
    let idx = 2;
    if (comment !== undefined) {
      fields.push(`director_comment = $${idx++}`);
      params.push(comment || null);
    }
    if (managerId) {
      fields.push(`handled_by = $${idx++}`);
      params.push(managerId);
    }
    if (finalRedirectedTo) {
      fields.push(`redirected_to = $${idx++}`);
      params.push(finalRedirectedTo);
    }
    if (status === 'accepted' || status === 'rejected') {
      fields.push(`decision_at = CURRENT_TIMESTAMP`);
    }
    if (status !== 'under_review') {
      fields.push(`reviewed_at = CURRENT_TIMESTAMP`);
    }
    params.push(suggestionId);
    await pool.query(
      `UPDATE suggestions SET ${fields.join(', ')} WHERE id = $${idx}`,
      params
    );
    if (status !== existing.status) {
      await recordSuggestionHistory(suggestionId, managerId || existing.employee_id, existing.status, status, comment);
      await pool.query(
        `INSERT INTO suggestion_notifications (suggestion_id, recipient_id, message, title, is_read)
         VALUES ($1,$2,$3,$4,false)`,
        [suggestionId, existing.employee_id, `تم تحديث حالة اقتراحك: ${status === 'accepted' ? 'مقبول' : status === 'rejected' ? 'مرفوض' : 'قيد الدراسة'}`, 'تحديث الاقتراح']
      );
    }
    res.json({ id: suggestionId, status });
  } catch (e) {
    console.error('update suggestion status error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function listSuggestionMessages(req, res) {
  try {
    const { suggestionId } = req.params;
    const { rows } = await pool.query(
      `SELECT m.*, e.first_name, e.last_name
       FROM suggestion_messages m
       JOIN employees e ON e.id = m.sender_id
       WHERE m.suggestion_id = $1
       ORDER BY m.created_at ASC`,
      [suggestionId]
    );
    res.json(rows.map(r => ({
      id: r.id,
      suggestion_id: r.suggestion_id,
      sender_id: r.sender_id,
      sender_name: `${r.first_name} ${r.last_name}`,
      sender_role: r.sender_role,
      body: r.body,
      created_at: r.created_at
    })));
  } catch (e) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

async function createSuggestionMessage(req, res) {
  try {
    const { suggestionId } = req.params;
    const { senderId, senderRole, body } = req.body || {};
    if (!senderId || !senderRole || !body) {
      return res.status(400).json({ error: 'البيانات مطلوبة' });
    }
    const insert = await pool.query(
      `INSERT INTO suggestion_messages (suggestion_id, sender_id, sender_role, body)
       VALUES ($1,$2,$3,$4)
       RETURNING id, created_at`,
      [suggestionId, senderId, senderRole, body]
    );
    res.json(insert.rows[0]);
  } catch (e) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

// Suggestions Routes
suggestionsRouter.get('/types', listSuggestionTypes);
suggestionsRouter.post('/employee/:employeeId', createSuggestion);
suggestionsRouter.get('/employee/:employeeId', listEmployeeSuggestions);
suggestionsRouter.get('/director', listDirectorSuggestions);
suggestionsRouter.post('/:suggestionId/status', updateSuggestionStatus);
suggestionsRouter.get('/:suggestionId/messages', listSuggestionMessages);
suggestionsRouter.post('/:suggestionId/messages', createSuggestionMessage);
suggestionsRouter.post('/:suggestionId/attachments', (req, res, next) => suggestionAttachmentUpload(req, res, next), async (req, res) => {
  try {
    const { suggestionId } = req.params;
    if (!req.files || !req.files.length) {
      return res.status(400).json({ error: 'لا توجد مرفقات' });
    }
    const rows = await Promise.all(req.files.map(file => pool.query(
      `INSERT INTO suggestion_attachments (suggestion_id, file_path, file_name, uploaded_by)
       VALUES ($1,$2,$3,$4)
       RETURNING id, file_path, file_name, created_at`,
      [suggestionId, `/uploads/suggestions/${file.filename}`, file.originalname || null, req.body.uploadedBy || null]
    )));
    res.json(rows.map(r => r.rows[0]));
  } catch (e) {
    console.error('upload suggestion attachments error', e);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});


module.exports = { router, complaintsRouter, suggestionsRouter, directorRouter, ensureSignalsSchema };