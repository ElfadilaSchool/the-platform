-- Merge HR Tasks DATA into Platform DB
-- Prereq: HR Tasks dump loaded into schema hr_tasks_temp
-- Safe/idempotent upserts where possible

-- Ensure base FKs exist before inserting child rows
-- Employees (only if HR Tasks carries employees table)
DO $$ BEGIN
  IF to_regclass('hr_tasks_temp.employees') IS NOT NULL THEN
    INSERT INTO public.employees (id, user_id, position_id, institution, first_name, last_name, foreign_name, foreign_last_name, gender, birth_date, phone, email, nationality, address, foreign_address, join_date, marital_status, visible_to_parents_in_chat, profile_picture_url, cv_url, education_level, created_at, updated_at, emergency_contact_name, emergency_contact_phone, emergency_contact_relationship, language_preference, notification_preferences, theme_preference)
    SELECT e.id, e.user_id, e.position_id, e.institution, e.first_name, e.last_name, e.foreign_name, e.foreign_last_name, e.gender, e.birth_date, e.phone, e.email, e.nationality, e.address, e.foreign_address, e.join_date, e.marital_status, e.visible_to_parents_in_chat, e.profile_picture_url, e.cv_url, e.education_level, e.created_at, e.updated_at, e.emergency_contact_name, e.emergency_contact_phone, e.emergency_contact_relationship, COALESCE(e.language_preference, 'en'), COALESCE(e.notification_preferences, '{"sms": false, "push": true, "email": true}'::jsonb), COALESCE(e.theme_preference, 'light')
    FROM hr_tasks_temp.employees e
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- Departments
DO $$ BEGIN
  IF to_regclass('hr_tasks_temp.departments') IS NOT NULL THEN
    INSERT INTO public.departments (id, name, responsible_id, created_at, updated_at)
    SELECT d.id, d.name, d.responsible_id, d.created_at, d.updated_at
    FROM hr_tasks_temp.departments d
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- Employee departments
DO $$ BEGIN
  IF to_regclass('hr_tasks_temp.employee_departments') IS NOT NULL THEN
    INSERT INTO public.employee_departments (employee_id, department_id, created_at, updated_at)
    SELECT ed.employee_id, ed.department_id, ed.created_at, ed.updated_at
    FROM hr_tasks_temp.employee_departments ed
    ON CONFLICT (employee_id, department_id) DO NOTHING;
  END IF;
END $$;

-- Tasks
DO $$ BEGIN
  IF to_regclass('hr_tasks_temp.tasks') IS NOT NULL THEN
    INSERT INTO public.tasks (id, title, description, type, assigned_to, assigned_by, due_date, status, created_at, updated_at, priority)
    SELECT t.id, t.title, t.description, t.type, t.assigned_to, t.assigned_by, t.due_date, t.status, t.created_at, t.updated_at, COALESCE(t.priority, 'Low')
    FROM hr_tasks_temp.tasks t
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- Task assignments (if present)
DO $$ BEGIN
  IF to_regclass('hr_tasks_temp.task_assignments') IS NOT NULL THEN
    INSERT INTO public.task_assignments (task_id, employee_id, status, assigned_at, completed_at)
    SELECT ta.task_id, ta.employee_id, COALESCE(ta.status, 'Pending'), ta.assigned_at, ta.completed_at
    FROM hr_tasks_temp.task_assignments ta
    ON CONFLICT (task_id, employee_id) DO NOTHING;
  END IF;
END $$;

-- Task comments
DO $$ BEGIN
  IF to_regclass('hr_tasks_temp.task_comments') IS NOT NULL THEN
    INSERT INTO public.task_comments (id, task_id, employee_id, comment, created_at)
    SELECT c.id, c.task_id, c.employee_id, c.comment, c.created_at
    FROM hr_tasks_temp.task_comments c
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- Reports
DO $$ BEGIN
  IF to_regclass('hr_tasks_temp.reports') IS NOT NULL THEN
    INSERT INTO public.reports (id, task_id, employee_id, description, remarks, pdf_url, created_at)
    SELECT r.id, r.task_id, r.employee_id, r.description, r.remarks, r.pdf_url, r.created_at
    FROM hr_tasks_temp.reports r
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- Notifications (optional)
DO $$ BEGIN
  IF to_regclass('hr_tasks_temp.notifications') IS NOT NULL THEN
    INSERT INTO public.notifications (id, user_id, recipient_id, sender_id, title, body, type, ref_type, ref_id, is_read, created_at)
    SELECT n.id, n.user_id, n.recipient_id, n.sender_id, COALESCE(n.title, ''), n.body, n.type, n.ref_type, n.ref_id, COALESCE(n.is_read, false), n.created_at
    FROM hr_tasks_temp.notifications n
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- Users (normalize roles from HR Tasks into platform roles)
DO $$ BEGIN
  IF to_regclass('hr_tasks_temp.users') IS NOT NULL THEN
    INSERT INTO public.users (id, username, password_hash, role, created_at, updated_at)
    SELECT u.id,
           COALESCE(u.username, u.email, 'user_'||left(u.id::text,8)),
           COALESCE(u.password_hash, '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'),
           CASE
             WHEN lower(u.role) IN ('director','hr_manager','hrmanager','hr_manager') THEN 'HR_Manager'
             WHEN lower(u.role) IN ('department_responsible','responsible','manager') THEN 'Department_Responsible'
             WHEN lower(u.role) IN ('employee','staff','user') THEN 'Employee'
             ELSE 'Employee'
           END,
           COALESCE(u.created_at, NOW()),
           COALESCE(u.updated_at, NOW())
    FROM hr_tasks_temp.users u
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- Positions (optional)
DO $$ BEGIN
  IF to_regclass('hr_tasks_temp.positions') IS NOT NULL THEN
    INSERT INTO public.positions (id, name, created_at, updated_at)
    SELECT p.id, p.name, COALESCE(p.created_at, NOW()), COALESCE(p.updated_at, NOW())
    FROM hr_tasks_temp.positions p
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- Attendance (optional)
DO $$ BEGIN
  IF to_regclass('hr_tasks_temp.attendance') IS NOT NULL THEN
    INSERT INTO public.attendance_punches (id, employee_id, punch_time, source, device_id, upload_id, raw_employee_name, is_duplicate, created_at)
    SELECT a.id, a.employee_id, a.punch_time, COALESCE(a.source,'upload'), a.device_id, NULL, a.employee_name, false, COALESCE(a.created_at, NOW())
    FROM hr_tasks_temp.attendance a
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- Employee_reports (optional) into reports table if compatible
DO $$ BEGIN
  IF to_regclass('hr_tasks_temp.employee_reports') IS NOT NULL THEN
    INSERT INTO public.reports (id, task_id, employee_id, description, remarks, pdf_url, created_at)
    SELECT er.id,
           NULL, -- no task linkage in HR tasks employee_reports
           er.employee_id,
           er.subject,
           er.content,
           er.pdf_url,
           COALESCE(er.created_at, NOW())
    FROM hr_tasks_temp.employee_reports er
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- Instruction tables (optional)
DO $$ BEGIN
  IF to_regclass('hr_tasks_temp.instructions') IS NOT NULL THEN
    -- Create compatible shadow tables if needed or skip when platform lacks these
    -- Here we skip to avoid breaking platform constraints
    NULL;
  END IF;
END $$;


