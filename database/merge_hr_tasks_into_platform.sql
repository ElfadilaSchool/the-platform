-- Merge HR Tasks schema into Platform DB (idempotent)
-- Safe to run multiple times

-- Ensure uuid extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ==========================
-- Tasks table enhancements
-- ==========================
ALTER TABLE IF EXISTS public.tasks
  ADD COLUMN IF NOT EXISTS priority character varying(20) DEFAULT 'Low';

-- ==========================
-- Task assignments table
-- ==========================
CREATE TABLE IF NOT EXISTS public.task_assignments (
  task_id uuid NOT NULL,
  employee_id uuid NOT NULL,
  status character varying(20) DEFAULT 'Pending'::character varying NOT NULL,
  assigned_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  completed_at timestamp with time zone
);

-- PK and FKs (idempotent)
DO $$ BEGIN
  -- Add PK only if table has no primary key yet
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    WHERE c.conrelid = 'public.task_assignments'::regclass
      AND c.contype = 'p'
  ) THEN
    ALTER TABLE public.task_assignments
      ADD CONSTRAINT task_assignments_pkey PRIMARY KEY (task_id, employee_id);
  END IF;

  BEGIN
    ALTER TABLE public.task_assignments
      ADD CONSTRAINT task_assignments_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;
  EXCEPTION WHEN duplicate_object THEN NULL; END;

  BEGIN
    ALTER TABLE public.task_assignments
      ADD CONSTRAINT task_assignments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_task_assignments_task ON public.task_assignments (task_id);
CREATE INDEX IF NOT EXISTS idx_task_assignments_employee ON public.task_assignments (employee_id);
CREATE INDEX IF NOT EXISTS idx_task_assignments_status ON public.task_assignments (status);

-- ==========================
-- Task comments enhancements
-- ==========================
ALTER TABLE IF EXISTS public.task_comments
  ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone;

-- ==========================
-- Reports table (for task reports)
-- ==========================
CREATE TABLE IF NOT EXISTS public.reports (
  id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
  task_id uuid NOT NULL,
  employee_id uuid NOT NULL,
  description text,
  remarks text,
  pdf_url text,
  created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT reports_pkey PRIMARY KEY (id)
);

DO $$ BEGIN
  BEGIN
    ALTER TABLE public.reports
      ADD CONSTRAINT reports_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;
  EXCEPTION WHEN duplicate_object THEN NULL; END;

  BEGIN
    ALTER TABLE public.reports
      ADD CONSTRAINT reports_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

CREATE INDEX IF NOT EXISTS idx_reports_task ON public.reports (task_id);
CREATE INDEX IF NOT EXISTS idx_reports_employee ON public.reports (employee_id);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON public.reports (created_at);

-- ==========================
-- Notifications: align with HR Tasks expectations
-- ==========================
-- Relax NOT NULL on message if present
DO $$ BEGIN
  BEGIN
    ALTER TABLE public.notifications ALTER COLUMN message DROP NOT NULL;
  EXCEPTION WHEN undefined_column THEN NULL; WHEN others THEN NULL; END;
END $$;

ALTER TABLE IF EXISTS public.notifications
  ADD COLUMN IF NOT EXISTS user_id uuid,
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS body text,
  ADD COLUMN IF NOT EXISTS ref_type text,
  ADD COLUMN IF NOT EXISTS ref_id uuid;

-- Backfill minimal defaults to satisfy NOT NULL in app logic
UPDATE public.notifications SET title = COALESCE(title, '') WHERE title IS NULL;

-- Helpful indexes used by the service
CREATE INDEX IF NOT EXISTS idx_notifications_user_created 
  ON public.notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_read 
  ON public.notifications (user_id, is_read);

-- ==========================
-- Compatibility views (optional)
-- ==========================
-- None for now

-- ==========================
-- DATA MERGE PLACEHOLDER
-- ==========================
-- If you have HR Tasks seed/data to merge from hr_tasks/hr_tasks/data.sql,
-- load it into a temp schema then upsert. Example workflow:
--
--   -- 1) Create temp schema and load HR Tasks dump
--   CREATE SCHEMA IF NOT EXISTS hr_tasks_temp;
--   SET search_path TO hr_tasks_temp;
--   -- 
--   -- Load the hr_tasks data.sql here (outside this file), e.g.:
--   --   psql -d hr_operations_platform -f hr_tasks/hr_tasks/data.sql -v schema=hr_tasks_temp
--   -- Adjust the script to create objects in hr_tasks_temp.* instead of public.*
--
--   -- 2) Upsert missing reference data and rows (examples):
--   -- INSERT INTO public.departments(id, name, responsible_id)
--   -- SELECT d.id, d.name, d.responsible_id FROM hr_tasks_temp.departments d
--   -- ON CONFLICT (id) DO NOTHING;
--
--   -- INSERT INTO public.tasks(id, title, description, type, assigned_by, due_date, status, priority, created_at, updated_at)
--   -- SELECT t.id, t.title, t.description, t.type, t.assigned_by, t.due_date, t.status, COALESCE(t.priority, 'Low'), t.created_at, t.updated_at
--   -- FROM hr_tasks_temp.tasks t
--   -- ON CONFLICT (id) DO NOTHING;
--
--   -- INSERT INTO public.task_assignments(task_id, employee_id, status, assigned_at, completed_at)
--   -- SELECT ta.task_id, ta.employee_id, COALESCE(ta.status, 'Pending'), ta.assigned_at, ta.completed_at
--   -- FROM hr_tasks_temp.task_assignments ta
--   -- ON CONFLICT (task_id, employee_id) DO NOTHING;
--
--   -- INSERT INTO public.task_comments(id, task_id, employee_id, comment, created_at)
--   -- SELECT c.id, c.task_id, c.employee_id, c.comment, c.created_at
--   -- FROM hr_tasks_temp.task_comments c
--   -- ON CONFLICT (id) DO NOTHING;
--
--   -- INSERT INTO public.reports(id, task_id, employee_id, description, remarks, pdf_url, created_at)
--   -- SELECT r.id, r.task_id, r.employee_id, r.description, r.remarks, r.pdf_url, r.created_at
--   -- FROM hr_tasks_temp.reports r
--   -- ON CONFLICT (id) DO NOTHING;
--
--   -- 3) Drop temp schema when done:
--   -- DROP SCHEMA hr_tasks_temp CASCADE;


