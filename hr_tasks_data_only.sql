pg_restore: error: COPY failed for table "departments": ERROR:  duplicate key value violates unique constraint "departments_pkey"
DETAIL:  Key (id)=(4a950d19-299d-498a-b1b0-928626e137a8) already exists.
CONTEXT:  COPY departments, line 1
pg_restore: error: COPY failed for table "employee_reports": ERROR:  duplicate key value violates unique constraint "employee_reports_pkey"
DETAIL:  Key (id)=(183ecdf1-115f-474d-8ec2-fd5ce3bf2e65) already exists.
CONTEXT:  COPY employee_reports, line 1
pg_restore: error: COPY failed for table "employees": ERROR:  duplicate key value violates unique constraint "employees_pkey"
DETAIL:  Key (id)=(49459fe7-4d26-4199-a022-7cb8d906f20f) already exists.
CONTEXT:  COPY employees, line 2
pg_restore: error: COPY failed for table "instruction_recipients": ERROR:  duplicate key value violates unique constraint "instruction_recipients_instruction_id_employee_id_key"
DETAIL:  Key (instruction_id, employee_id)=(d4b52143-e255-4647-86f1-7e2bee5630fb, 49459fe7-4d26-4199-a022-7cb8d906f20f) already exists.
CONTEXT:  COPY instruction_recipients, line 1
pg_restore: error: COPY failed for table "instructions": ERROR:  duplicate key value violates unique constraint "instructions_pkey"
DETAIL:  Key (id)=(d4b52143-e255-4647-86f1-7e2bee5630fb) already exists.
CONTEXT:  COPY instructions, line 1
pg_restore: error: COPY failed for table "notifications": ERROR:  duplicate key value violates unique constraint "notifications_pkey"
DETAIL:  Key (id)=(4f026050-eea6-471b-bc03-a616e86d54a7) already exists.
CONTEXT:  COPY notifications, line 1
pg_restore: error: COPY failed for table "report_acknowledgements": ERROR:  duplicate key value violates unique constraint "report_acknowledgements_pkey"
DETAIL:  Key (id)=(ba2fb6a8-821b-4a28-8624-22a077aa66d7) already exists.
CONTEXT:  COPY report_acknowledgements, line 1
pg_restore: error: COPY failed for table "reports": ERROR:  duplicate key value violates unique constraint "reports_pkey"
DETAIL:  Key (id)=(59a1e993-d03a-445c-aa98-8282e77413c1) already exists.
CONTEXT:  COPY reports, line 1
pg_restore: error: COPY failed for table "task_assignments": ERROR:  duplicate key value violates unique constraint "task_assignments_pkey"
DETAIL:  Key (id)=(fef42a64-c9e5-4f7a-836d-553566ba4731) already exists.
CONTEXT:  COPY task_assignments, line 1
pg_restore: error: COPY failed for table "task_comments": ERROR:  duplicate key value violates unique constraint "task_comments_pkey"
DETAIL:  Key (id)=(8d4e6383-aabf-47c0-a919-e3bf0aaa16a2) already exists.
CONTEXT:  COPY task_comments, line 1
pg_restore: error: could not execute query: ERROR:  column "completed_at" of relation "tasks" does not exist
Command was: COPY public.tasks (id, title, description, type, assigned_by, due_date, status, created_at, updated_at, priority, completed_at) FROM stdin;
pg_restore: error: COPY failed for table "users": ERROR:  new row for relation "users" violates check constraint "users_role_check"
DETAIL:  Failing row contains (6d927a2a-83ba-4a6e-81d5-5d53d6457b43, directeur@entreprise.com, $2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi, Director, 2025-09-09 09:32:33.196958, 2025-09-09 09:32:33.196958).
CONTEXT:  COPY users, line 3: "6d927a2a-83ba-4a6e-81d5-5d53d6457b43	directeur@entreprise.com	$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro..."
pg_restore: warning: errors ignored on restore: 12
