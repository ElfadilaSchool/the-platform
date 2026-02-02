--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5
-- Dumped by pg_dump version 17.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: check_task_completion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_task_completion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    not_completed_count INTEGER;
BEGIN
    -- Si on essaie de mettre la tâche en "Completed"
    IF NEW.status = 'Completed' THEN
        -- Vérifier s'il existe encore des task_assignments non terminés
        SELECT COUNT(*) INTO not_completed_count
        FROM public.task_assignments
        WHERE task_id = NEW.id
          AND status <> 'Completed';

        IF not_completed_count > 0 THEN
            RAISE EXCEPTION 'Impossible de marquer la tâche % comme Completed : certains employés n''ont pas encore terminé.', NEW.id;
        END IF;

        -- Optionnel : mettre à jour la date de complétion
        NEW.completed_at := NOW();
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_task_completion() OWNER TO postgres;

--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_updated_at() OWNER TO postgres;

--
-- Name: update_task_status_on_completion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_task_status_on_completion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Vérifier si toutes les assignations de cette tâche sont complétées
    IF NOT EXISTS (
        SELECT 1 
        FROM public.task_assignments 
        WHERE task_id = NEW.task_id 
        AND status != 'Completed'
    ) THEN
        -- Mettre à jour le statut de la tâche principale
        UPDATE public.tasks 
        SET status = 'Completed', 
            completed_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.task_id;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_task_status_on_completion() OWNER TO postgres;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: attendance; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.attendance (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid,
    check_in_time timestamp without time zone NOT NULL,
    check_out_time timestamp without time zone,
    total_hours numeric(4,2),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    check_in timestamp without time zone,
    check_out timestamp without time zone
);


ALTER TABLE public.attendance OWNER TO postgres;

--
-- Name: departments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.departments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(255) NOT NULL,
    responsible_id uuid,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.departments OWNER TO postgres;

--
-- Name: employee_departments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employee_departments (
    employee_id uuid NOT NULL,
    department_id uuid NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.employee_departments OWNER TO postgres;

--
-- Name: employee_reports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employee_reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    employee_id uuid NOT NULL,
    title character varying(255) NOT NULL,
    subject text NOT NULL,
    content text NOT NULL,
    concerned_employees uuid[],
    status character varying(30) DEFAULT 'pending'::character varying,
    remarks text,
    pdf_url text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    recipients uuid[],
    include_director boolean DEFAULT true,
    analysis jsonb,
    analysis_embedding_json jsonb,
    CONSTRAINT employee_reports_status_check CHECK (((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('acknowledged'::character varying)::text]))),
    CONSTRAINT include_director_always_true CHECK ((include_director = true))
);


ALTER TABLE public.employee_reports OWNER TO postgres;

--
-- Name: employees; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employees (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    position_id uuid,
    institution character varying(255),
    first_name character varying(255) NOT NULL,
    last_name character varying(255) NOT NULL,
    foreign_name character varying(255),
    foreign_last_name character varying(255),
    gender character varying(20),
    birth_date date,
    phone character varying(20),
    email character varying(255),
    nationality character varying(100),
    address text,
    foreign_address text,
    join_date date,
    marital_status character varying(50),
    visible_to_parents_in_chat boolean DEFAULT false,
    profile_picture_url character varying(500),
    cv_url character varying(500),
    education_level character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    emergency_contact_name character varying(255),
    emergency_contact_phone character varying(20),
    emergency_contact_relationship character varying(100),
    language_preference character varying(10) DEFAULT 'en'::character varying,
    notification_preferences jsonb DEFAULT '{"sms": false, "push": true, "email": true}'::jsonb,
    theme_preference character varying(20) DEFAULT 'light'::character varying,
    CONSTRAINT employees_gender_check CHECK (((gender)::text = ANY (ARRAY[('Male'::character varying)::text, ('Female'::character varying)::text, ('Other'::character varying)::text]))),
    CONSTRAINT employees_marital_status_check CHECK (((marital_status)::text = ANY (ARRAY[('Single'::character varying)::text, ('Married'::character varying)::text, ('Divorced'::character varying)::text, ('Widowed'::character varying)::text])))
);


ALTER TABLE public.employees OWNER TO postgres;

--
-- Name: instruction_recipients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.instruction_recipients (
    instruction_id uuid NOT NULL,
    employee_id uuid NOT NULL,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL,
    acknowledged boolean DEFAULT false NOT NULL,
    acknowledged_at timestamp with time zone,
    completed boolean DEFAULT false NOT NULL,
    completed_at timestamp with time zone
);


ALTER TABLE public.instruction_recipients OWNER TO postgres;

--
-- Name: instructions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.instructions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    body text NOT NULL,
    priority text DEFAULT 'normal'::text NOT NULL,
    due_at timestamp with time zone,
    status text DEFAULT 'active'::text NOT NULL,
    created_by_user_id uuid,
    created_by_employee_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT instructions_priority_check CHECK ((priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text, 'urgent'::text]))),
    CONSTRAINT instructions_status_check CHECK ((status = ANY (ARRAY['active'::text, 'archived'::text, 'cancelled'::text])))
);


ALTER TABLE public.instructions OWNER TO postgres;

--
-- Name: meeting_attendees; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.meeting_attendees (
    meeting_id uuid NOT NULL,
    employee_id uuid NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.meeting_attendees OWNER TO postgres;

--
-- Name: meetings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.meetings (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    scheduled_by uuid,
    start_time timestamp without time zone NOT NULL,
    end_time timestamp without time zone NOT NULL,
    notes text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.meetings OWNER TO postgres;

--
-- Name: notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notifications (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    recipient_id uuid,
    sender_id uuid,
    type character varying(100) NOT NULL,
    message text,
    is_read boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    user_id uuid NOT NULL,
    title text NOT NULL,
    body text,
    ref_type text,
    ref_id uuid
);


ALTER TABLE public.notifications OWNER TO postgres;

--
-- Name: permission_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.permission_requests (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid,
    type character varying(50) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    reason text NOT NULL,
    document_url character varying(500),
    status character varying(20) DEFAULT 'Pending'::character varying NOT NULL,
    reviewed_by uuid,
    reviewed_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT permission_requests_status_check CHECK (((status)::text = ANY (ARRAY[('Pending'::character varying)::text, ('Accepted'::character varying)::text, ('Denied'::character varying)::text]))),
    CONSTRAINT permission_requests_type_check CHECK (((type)::text = ANY (ARRAY[('Vacation'::character varying)::text, ('Day Off'::character varying)::text, ('Absence Justification'::character varying)::text])))
);


ALTER TABLE public.permission_requests OWNER TO postgres;

--
-- Name: position_salaries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.position_salaries (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    position_id uuid,
    base_salary numeric(10,2),
    hourly_rate numeric(8,2),
    overtime_rate numeric(8,2),
    bonus_rate numeric(5,2),
    effective_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.position_salaries OWNER TO postgres;

--
-- Name: positions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.positions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.positions OWNER TO postgres;

--
-- Name: report_acknowledgements; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.report_acknowledgements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    report_id uuid NOT NULL,
    employee_id uuid NOT NULL,
    acknowledged boolean DEFAULT false,
    acknowledged_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.report_acknowledgements OWNER TO postgres;

--
-- Name: reports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reports (
    id uuid NOT NULL,
    task_id uuid NOT NULL,
    employee_id uuid NOT NULL,
    description text NOT NULL,
    remarks text,
    created_at timestamp without time zone DEFAULT now(),
    pdf_url text
);


ALTER TABLE public.reports OWNER TO postgres;

--
-- Name: salaries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.salaries (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid,
    position_id uuid,
    amount numeric(10,2) NOT NULL,
    currency character varying(10) DEFAULT 'DZD'::character varying,
    payment_frequency character varying(20) NOT NULL,
    effective_date date NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT salaries_payment_frequency_check CHECK (((payment_frequency)::text = ANY (ARRAY[('Monthly'::character varying)::text, ('Daily'::character varying)::text, ('Hourly'::character varying)::text])))
);


ALTER TABLE public.salaries OWNER TO postgres;

--
-- Name: salary_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.salary_history (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid,
    salary_id uuid,
    old_amount numeric(10,2),
    new_amount numeric(10,2),
    change_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.salary_history OWNER TO postgres;

--
-- Name: task_assignments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.task_assignments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    task_id uuid NOT NULL,
    employee_id uuid NOT NULL,
    assigned_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    completed_at timestamp without time zone,
    status character varying(20) DEFAULT 'Pending'::character varying NOT NULL,
    CONSTRAINT task_assignments_status_check CHECK (((status)::text = ANY (ARRAY[('Pending'::character varying)::text, ('In Progress'::character varying)::text, ('Completed'::character varying)::text])))
);


ALTER TABLE public.task_assignments OWNER TO postgres;

--
-- Name: task_comments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.task_comments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    task_id uuid,
    employee_id uuid,
    comment text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.task_comments OWNER TO postgres;

--
-- Name: tasks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tasks (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    type character varying(20) NOT NULL,
    assigned_by uuid,
    due_date date,
    status character varying(20) DEFAULT 'Pending'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    priority character varying(10) DEFAULT 'Low'::character varying NOT NULL,
    completed_at timestamp without time zone,
    CONSTRAINT tasks_priority_check CHECK (((priority)::text = ANY (ARRAY[('Low'::character varying)::text, ('Medium'::character varying)::text, ('High'::character varying)::text]))),
    CONSTRAINT tasks_status_check CHECK (((status)::text = ANY (ARRAY[('Pending'::character varying)::text, ('In Progress'::character varying)::text, ('Completed'::character varying)::text, ('Not Done'::character varying)::text]))),
    CONSTRAINT tasks_type_check CHECK (((type)::text = ANY (ARRAY[('Daily'::character varying)::text, ('Special'::character varying)::text])))
);


ALTER TABLE public.tasks OWNER TO postgres;

--
-- Name: user_sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_sessions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    token_hash character varying(255) NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    last_activity timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.user_sessions OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    username character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    role character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT users_role_check CHECK (((role)::text = ANY (ARRAY['HR_Manager'::text, 'Department_Responsible'::text, 'Employee'::text, 'Director'::text])))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: attendance attendance_records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_records_pkey PRIMARY KEY (id);


--
-- Name: departments departments_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_name_key UNIQUE (name);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: employee_departments employee_departments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_departments
    ADD CONSTRAINT employee_departments_pkey PRIMARY KEY (employee_id, department_id);


--
-- Name: employee_reports employee_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_reports
    ADD CONSTRAINT employee_reports_pkey PRIMARY KEY (id);


--
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);


--
-- Name: instruction_recipients instruction_recipients_instruction_id_employee_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruction_recipients
    ADD CONSTRAINT instruction_recipients_instruction_id_employee_id_key UNIQUE (instruction_id, employee_id);


--
-- Name: instructions instructions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instructions
    ADD CONSTRAINT instructions_pkey PRIMARY KEY (id);


--
-- Name: meeting_attendees meeting_attendees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meeting_attendees
    ADD CONSTRAINT meeting_attendees_pkey PRIMARY KEY (meeting_id, employee_id);


--
-- Name: meetings meetings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: permission_requests permission_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permission_requests
    ADD CONSTRAINT permission_requests_pkey PRIMARY KEY (id);


--
-- Name: position_salaries position_salaries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.position_salaries
    ADD CONSTRAINT position_salaries_pkey PRIMARY KEY (id);


--
-- Name: positions positions_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.positions
    ADD CONSTRAINT positions_name_key UNIQUE (name);


--
-- Name: positions positions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.positions
    ADD CONSTRAINT positions_pkey PRIMARY KEY (id);


--
-- Name: report_acknowledgements report_acknowledgements_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.report_acknowledgements
    ADD CONSTRAINT report_acknowledgements_pkey PRIMARY KEY (id);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: salaries salaries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salaries
    ADD CONSTRAINT salaries_pkey PRIMARY KEY (id);


--
-- Name: salary_history salary_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salary_history
    ADD CONSTRAINT salary_history_pkey PRIMARY KEY (id);


--
-- Name: task_assignments task_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_pkey PRIMARY KEY (id);


--
-- Name: task_comments task_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_comments
    ADD CONSTRAINT task_comments_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: report_acknowledgements unique_report_employee; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.report_acknowledgements
    ADD CONSTRAINT unique_report_employee UNIQUE (report_id, employee_id);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: idx_attendance_employee_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_attendance_employee_id ON public.attendance USING btree (employee_id);


--
-- Name: idx_employee_departments_department_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employee_departments_department_id ON public.employee_departments USING btree (department_id);


--
-- Name: idx_employee_departments_employee_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employee_departments_employee_id ON public.employee_departments USING btree (employee_id);


--
-- Name: idx_employee_reports_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employee_reports_created ON public.employee_reports USING btree (created_at);


--
-- Name: idx_employee_reports_employee; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employee_reports_employee ON public.employee_reports USING btree (employee_id);


--
-- Name: idx_employee_reports_recipient_ids; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employee_reports_recipient_ids ON public.employee_reports USING gin (recipients);


--
-- Name: idx_employee_reports_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employee_reports_status ON public.employee_reports USING btree (status);


--
-- Name: idx_employees_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employees_email ON public.employees USING btree (email);


--
-- Name: idx_employees_position_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employees_position_id ON public.employees USING btree (position_id);


--
-- Name: idx_employees_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employees_user_id ON public.employees USING btree (user_id);


--
-- Name: idx_instr_rec_acknowledged; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_instr_rec_acknowledged ON public.instruction_recipients USING btree (acknowledged);


--
-- Name: idx_instr_rec_completed; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_instr_rec_completed ON public.instruction_recipients USING btree (completed);


--
-- Name: idx_instr_rec_employee; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_instr_rec_employee ON public.instruction_recipients USING btree (employee_id);


--
-- Name: idx_instr_rec_instruction; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_instr_rec_instruction ON public.instruction_recipients USING btree (instruction_id);


--
-- Name: idx_instructions_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_instructions_created_at ON public.instructions USING btree (created_at DESC);


--
-- Name: idx_instructions_due_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_instructions_due_at ON public.instructions USING btree (due_at);


--
-- Name: idx_instructions_priority; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_instructions_priority ON public.instructions USING btree (priority);


--
-- Name: idx_instructions_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_instructions_status ON public.instructions USING btree (status);


--
-- Name: idx_meetings_scheduled_by; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_meetings_scheduled_by ON public.meetings USING btree (scheduled_by);


--
-- Name: idx_meetings_start_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_meetings_start_time ON public.meetings USING btree (start_time);


--
-- Name: idx_notifications_recipient_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_recipient_id ON public.notifications USING btree (recipient_id);


--
-- Name: idx_notifications_user_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_user_created ON public.notifications USING btree (user_id, created_at DESC);


--
-- Name: idx_notifications_user_read; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_user_read ON public.notifications USING btree (user_id, is_read);


--
-- Name: idx_permission_requests_employee_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_permission_requests_employee_id ON public.permission_requests USING btree (employee_id);


--
-- Name: idx_permission_requests_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_permission_requests_status ON public.permission_requests USING btree (status);


--
-- Name: idx_position_salaries_effective_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_position_salaries_effective_date ON public.position_salaries USING btree (effective_date);


--
-- Name: idx_position_salaries_position_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_position_salaries_position_id ON public.position_salaries USING btree (position_id);


--
-- Name: idx_report_acknowledgements_acknowledged; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_report_acknowledgements_acknowledged ON public.report_acknowledgements USING btree (acknowledged);


--
-- Name: idx_report_acknowledgements_employee_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_report_acknowledgements_employee_id ON public.report_acknowledgements USING btree (employee_id);


--
-- Name: idx_report_acknowledgements_report_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_report_acknowledgements_report_id ON public.report_acknowledgements USING btree (report_id);


--
-- Name: idx_reports_task_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reports_task_id ON public.reports USING btree (task_id);


--
-- Name: idx_task_assignments_employee_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_task_assignments_employee_id ON public.task_assignments USING btree (employee_id);


--
-- Name: idx_task_assignments_task_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_task_assignments_task_id ON public.task_assignments USING btree (task_id);


--
-- Name: idx_task_comments_task_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_task_comments_task_id ON public.task_comments USING btree (task_id);


--
-- Name: idx_tasks_assigned_by; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tasks_assigned_by ON public.tasks USING btree (assigned_by);


--
-- Name: idx_tasks_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tasks_status ON public.tasks USING btree (status);


--
-- Name: idx_user_sessions_token_hash; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_sessions_token_hash ON public.user_sessions USING btree (token_hash);


--
-- Name: idx_user_sessions_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_sessions_user_id ON public.user_sessions USING btree (user_id);


--
-- Name: idx_users_username; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_username ON public.users USING btree (username);


--
-- Name: tasks trg_check_task_completion; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_task_completion BEFORE UPDATE OF status ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.check_task_completion();


--
-- Name: instructions trg_instructions_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_instructions_updated_at BEFORE UPDATE ON public.instructions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: task_assignments trg_update_task_status; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_task_status AFTER UPDATE OF status ON public.task_assignments FOR EACH ROW WHEN (((new.status)::text = 'Completed'::text)) EXECUTE FUNCTION public.update_task_status_on_completion();


--
-- Name: attendance update_attendance_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_attendance_updated_at BEFORE UPDATE ON public.attendance FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: departments update_departments_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_departments_updated_at BEFORE UPDATE ON public.departments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: employees update_employees_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_employees_updated_at BEFORE UPDATE ON public.employees FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: meetings update_meetings_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_meetings_updated_at BEFORE UPDATE ON public.meetings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: permission_requests update_permission_requests_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_permission_requests_updated_at BEFORE UPDATE ON public.permission_requests FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: position_salaries update_position_salaries_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_position_salaries_updated_at BEFORE UPDATE ON public.position_salaries FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: salaries update_salaries_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_salaries_updated_at BEFORE UPDATE ON public.salaries FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: tasks update_tasks_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: user_sessions update_user_sessions_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_user_sessions_updated_at BEFORE UPDATE ON public.user_sessions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: users update_users_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: attendance attendance_records_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_records_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id);


--
-- Name: departments departments_responsible_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_responsible_id_fkey FOREIGN KEY (responsible_id) REFERENCES public.employees(id);


--
-- Name: employee_departments employee_departments_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_departments
    ADD CONSTRAINT employee_departments_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- Name: employee_departments employee_departments_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_departments
    ADD CONSTRAINT employee_departments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- Name: employee_reports employee_reports_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_reports
    ADD CONSTRAINT employee_reports_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- Name: employees employees_position_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_position_id_fkey FOREIGN KEY (position_id) REFERENCES public.positions(id);


--
-- Name: employees employees_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reports fk_employee; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT fk_employee FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- Name: report_acknowledgements fk_employee; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.report_acknowledgements
    ADD CONSTRAINT fk_employee FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- Name: report_acknowledgements fk_report; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.report_acknowledgements
    ADD CONSTRAINT fk_report FOREIGN KEY (report_id) REFERENCES public.employee_reports(id) ON DELETE CASCADE;


--
-- Name: reports fk_task; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT fk_task FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: instruction_recipients instruction_recipients_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruction_recipients
    ADD CONSTRAINT instruction_recipients_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- Name: instruction_recipients instruction_recipients_instruction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruction_recipients
    ADD CONSTRAINT instruction_recipients_instruction_id_fkey FOREIGN KEY (instruction_id) REFERENCES public.instructions(id) ON DELETE CASCADE;


--
-- Name: instructions instructions_created_by_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instructions
    ADD CONSTRAINT instructions_created_by_employee_id_fkey FOREIGN KEY (created_by_employee_id) REFERENCES public.employees(id) ON DELETE SET NULL;


--
-- Name: instructions instructions_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instructions
    ADD CONSTRAINT instructions_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: meeting_attendees meeting_attendees_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meeting_attendees
    ADD CONSTRAINT meeting_attendees_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- Name: meeting_attendees meeting_attendees_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meeting_attendees
    ADD CONSTRAINT meeting_attendees_meeting_id_fkey FOREIGN KEY (meeting_id) REFERENCES public.meetings(id) ON DELETE CASCADE;


--
-- Name: meetings meetings_scheduled_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_scheduled_by_fkey FOREIGN KEY (scheduled_by) REFERENCES public.employees(id);


--
-- Name: notifications notifications_recipient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES public.employees(id);


--
-- Name: notifications notifications_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.employees(id);


--
-- Name: permission_requests permission_requests_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permission_requests
    ADD CONSTRAINT permission_requests_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id);


--
-- Name: permission_requests permission_requests_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permission_requests
    ADD CONSTRAINT permission_requests_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.employees(id);


--
-- Name: position_salaries position_salaries_position_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.position_salaries
    ADD CONSTRAINT position_salaries_position_id_fkey FOREIGN KEY (position_id) REFERENCES public.positions(id) ON DELETE CASCADE;


--
-- Name: salaries salaries_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salaries
    ADD CONSTRAINT salaries_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id);


--
-- Name: salaries salaries_position_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salaries
    ADD CONSTRAINT salaries_position_id_fkey FOREIGN KEY (position_id) REFERENCES public.positions(id);


--
-- Name: salary_history salary_history_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salary_history
    ADD CONSTRAINT salary_history_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id);


--
-- Name: salary_history salary_history_salary_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salary_history
    ADD CONSTRAINT salary_history_salary_id_fkey FOREIGN KEY (salary_id) REFERENCES public.salaries(id);


--
-- Name: task_assignments task_assignments_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id);


--
-- Name: task_assignments task_assignments_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: task_comments task_comments_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_comments
    ADD CONSTRAINT task_comments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id);


--
-- Name: task_comments task_comments_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_comments
    ADD CONSTRAINT task_comments_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: tasks tasks_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.employees(id);


--
-- Name: user_sessions user_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

