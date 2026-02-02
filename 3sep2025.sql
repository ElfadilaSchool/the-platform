--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5
-- Dumped by pg_dump version 17.5

-- Started on 2025-09-08 13:24:52

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
-- TOC entry 5 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- TOC entry 5321 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 260 (class 1255 OID 106741)
-- Name: get_employee_name_match_condition(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_employee_name_match_condition() RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN '(
        LOWER(TRIM(REPLACE(rp.employee_name, '' '', ''''))) = LOWER(TRIM(REPLACE(e.first_name || '' '' || e.last_name, '' '', ''''))) OR
        LOWER(TRIM(REPLACE(rp.employee_name, '' '', ''''))) = LOWER(TRIM(REPLACE(e.last_name || '' '' || e.first_name, '' '', ''''))) OR
        LOWER(TRIM(REPLACE(rp.employee_name, '' '', ''''))) = LOWER(TRIM(REPLACE(e.first_name || e.last_name, '' '', ''''))) OR
        LOWER(TRIM(REPLACE(rp.employee_name, '' '', ''''))) = LOWER(TRIM(REPLACE(e.last_name || e.first_name, '' '', '''')))
    )';
END;
$$;


ALTER FUNCTION public.get_employee_name_match_condition() OWNER TO postgres;

--
-- TOC entry 259 (class 1255 OID 66171)
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
-- TOC entry 238 (class 1259 OID 90376)
-- Name: attendance_exceptions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.attendance_exceptions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    type character varying(40) NOT NULL,
    status character varying(20) DEFAULT 'Pending'::character varying NOT NULL,
    date date NOT NULL,
    end_date date,
    payload jsonb NOT NULL,
    submitted_by_user_id uuid,
    reviewed_by_user_id uuid,
    reviewed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT attendance_exceptions_status_check CHECK (((status)::text = ANY ((ARRAY['Pending'::character varying, 'Approved'::character varying, 'Rejected'::character varying])::text[]))),
    CONSTRAINT attendance_exceptions_type_check CHECK (((type)::text = ANY ((ARRAY['MissingPunchFix'::character varying, 'LeaveRequest'::character varying, 'HolidayAssignment'::character varying])::text[])))
);


ALTER TABLE public.attendance_exceptions OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 90406)
-- Name: attendance_overrides; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.attendance_overrides (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    date date NOT NULL,
    override_type character varying(30) NOT NULL,
    details jsonb NOT NULL,
    exception_id uuid,
    created_by_user_id uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT attendance_overrides_override_type_check CHECK (((override_type)::text = ANY ((ARRAY['punch_add'::character varying, 'punch_remove'::character varying, 'status_override'::character varying, 'leave'::character varying, 'holiday'::character varying])::text[])))
);


ALTER TABLE public.attendance_overrides OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 90328)
-- Name: attendance_punches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.attendance_punches (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    punch_time timestamp with time zone NOT NULL,
    source character varying(50) DEFAULT 'upload'::character varying,
    device_id character varying(100),
    upload_id uuid,
    raw_employee_name text,
    is_duplicate boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    deleted_at timestamp with time zone
);


ALTER TABLE public.attendance_punches OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 90351)
-- Name: attendance_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.attendance_settings (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    scope character varying(20) NOT NULL,
    department_id uuid,
    timezone character varying(100) DEFAULT 'UTC'::character varying,
    grace_minutes integer DEFAULT 0,
    rounding_minutes integer DEFAULT 0,
    min_shift_minutes integer DEFAULT 0,
    cross_midnight_boundary time without time zone DEFAULT '05:00:00'::time without time zone,
    valid_window_start time without time zone,
    valid_window_end time without time zone,
    weekend_days smallint[] DEFAULT ARRAY[6, 0],
    holidays date[] DEFAULT ARRAY[]::date[],
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT attendance_settings_scope_check CHECK (((scope)::text = ANY ((ARRAY['global'::character varying, 'department'::character varying])::text[])))
);


ALTER TABLE public.attendance_settings OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 90432)
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    entity_type character varying(100) NOT NULL,
    entity_id uuid,
    action character varying(50) NOT NULL,
    actor_user_id uuid,
    data jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.audit_logs OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 41184)
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
-- TOC entry 222 (class 1259 OID 41199)
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
-- TOC entry 247 (class 1259 OID 106712)
-- Name: employee_salary_adjustments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employee_salary_adjustments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    adjustment_type character varying(20) NOT NULL,
    amount numeric(10,2) NOT NULL,
    description text,
    effective_date date NOT NULL,
    created_by_user_id uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT employee_salary_adjustments_adjustment_type_check CHECK (((adjustment_type)::text = ANY ((ARRAY['credit'::character varying, 'decrease'::character varying, 'raise'::character varying])::text[])))
);


ALTER TABLE public.employee_salary_adjustments OWNER TO postgres;

--
-- TOC entry 5322 (class 0 OID 0)
-- Dependencies: 247
-- Name: TABLE employee_salary_adjustments; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.employee_salary_adjustments IS 'Employee-specific salary adjustments (credit, decrease, raise)';


--
-- TOC entry 220 (class 1259 OID 41162)
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
    CONSTRAINT employees_gender_check CHECK (((gender)::text = ANY ((ARRAY['Male'::character varying, 'Female'::character varying, 'Other'::character varying])::text[]))),
    CONSTRAINT employees_marital_status_check CHECK (((marital_status)::text = ANY ((ARRAY['Single'::character varying, 'Married'::character varying, 'Divorced'::character varying, 'Widowed'::character varying])::text[])))
);


ALTER TABLE public.employees OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 41404)
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
-- TOC entry 219 (class 1259 OID 41152)
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
-- TOC entry 248 (class 1259 OID 106736)
-- Name: employee_salary_calculation_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.employee_salary_calculation_view AS
 SELECT e.id AS employee_id,
    (((e.first_name)::text || ' '::text) || (e.last_name)::text) AS employee_name,
    e.first_name,
    e.last_name,
    p.name AS position_name,
    ps.base_salary,
    ps.hourly_rate,
    ps.overtime_rate,
    d.name AS department_name
   FROM ((((public.employees e
     LEFT JOIN public.positions p ON ((e.position_id = p.id)))
     LEFT JOIN public.position_salaries ps ON ((p.id = ps.position_id)))
     LEFT JOIN public.employee_departments ed ON ((e.id = ed.employee_id)))
     LEFT JOIN public.departments d ON ((ed.department_id = d.id)))
  WHERE (ps.effective_date = ( SELECT max(ps2.effective_date) AS max
           FROM public.position_salaries ps2
          WHERE ((ps2.position_id = p.id) AND (ps2.effective_date <= CURRENT_DATE))));


ALTER VIEW public.employee_salary_calculation_view OWNER TO postgres;

--
-- TOC entry 5323 (class 0 OID 0)
-- Dependencies: 248
-- Name: VIEW employee_salary_calculation_view; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.employee_salary_calculation_view IS 'Consolidated view for employee salary calculation data';


--
-- TOC entry 234 (class 1259 OID 58158)
-- Name: employee_timetables; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employee_timetables (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    timetable_id uuid NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    priority integer DEFAULT 1,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.employee_timetables OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 41273)
-- Name: meeting_attendees; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.meeting_attendees (
    meeting_id uuid NOT NULL,
    employee_id uuid NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.meeting_attendees OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 41258)
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
-- TOC entry 228 (class 1259 OID 41327)
-- Name: notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notifications (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    recipient_id uuid,
    sender_id uuid,
    type character varying(100) NOT NULL,
    message text NOT NULL,
    is_read boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.notifications OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 41360)
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
    CONSTRAINT permission_requests_status_check CHECK (((status)::text = ANY ((ARRAY['Pending'::character varying, 'Accepted'::character varying, 'Denied'::character varying])::text[]))),
    CONSTRAINT permission_requests_type_check CHECK (((type)::text = ANY ((ARRAY['Vacation'::character varying, 'Day Off'::character varying, 'Absence Justification'::character varying])::text[])))
);


ALTER TABLE public.permission_requests OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 90495)
-- Name: punch_file_uploads; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.punch_file_uploads (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    filename character varying(255) NOT NULL,
    original_filename character varying(255) NOT NULL,
    file_path character varying(500) NOT NULL,
    file_size bigint NOT NULL,
    uploaded_by_user_id uuid NOT NULL,
    upload_date timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    processed_at timestamp with time zone,
    status character varying(20) DEFAULT 'uploaded'::character varying NOT NULL,
    total_records integer DEFAULT 0,
    processed_records integer DEFAULT 0,
    error_records integer DEFAULT 0,
    processing_errors jsonb DEFAULT '[]'::jsonb,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT punch_file_uploads_status_check CHECK (((status)::text = ANY ((ARRAY['uploaded'::character varying, 'processing'::character varying, 'completed'::character varying, 'failed'::character varying])::text[])))
);


ALTER TABLE public.punch_file_uploads OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 98513)
-- Name: raw_punches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.raw_punches (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_name text NOT NULL,
    punch_time timestamp with time zone NOT NULL,
    source character varying(50) DEFAULT 'file_upload'::character varying,
    uploaded_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    raw_data jsonb
);


ALTER TABLE public.raw_punches OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 41289)
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
    CONSTRAINT salaries_payment_frequency_check CHECK (((payment_frequency)::text = ANY ((ARRAY['Monthly'::character varying, 'Daily'::character varying, 'Hourly'::character varying])::text[])))
);


ALTER TABLE public.salaries OWNER TO postgres;

--
-- TOC entry 244 (class 1259 OID 90512)
-- Name: salary_calculations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.salary_calculations (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    calculation_period_start date NOT NULL,
    calculation_period_end date NOT NULL,
    base_salary numeric(10,2) DEFAULT 0 NOT NULL,
    worked_days integer DEFAULT 0 NOT NULL,
    total_absences integer DEFAULT 0 NOT NULL,
    overtime_hours numeric(5,2) DEFAULT 0 NOT NULL,
    deductions numeric(10,2) DEFAULT 0 NOT NULL,
    bonuses numeric(10,2) DEFAULT 0 NOT NULL,
    gross_salary numeric(10,2) DEFAULT 0 NOT NULL,
    net_salary numeric(10,2) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'calculated'::character varying NOT NULL,
    paid_at timestamp with time zone,
    calculated_by_user_id uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT salary_calculations_status_check CHECK (((status)::text = ANY ((ARRAY['calculated'::character varying, 'approved'::character varying, 'paid'::character varying])::text[])))
);


ALTER TABLE public.salary_calculations OWNER TO postgres;

--
-- TOC entry 246 (class 1259 OID 106700)
-- Name: salary_parameters; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.salary_parameters (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    parameter_name character varying(50) NOT NULL,
    parameter_value numeric(10,2) NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.salary_parameters OWNER TO postgres;

--
-- TOC entry 5324 (class 0 OID 0)
-- Dependencies: 246
-- Name: TABLE salary_parameters; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.salary_parameters IS 'Configurable parameters for salary calculations';


--
-- TOC entry 242 (class 1259 OID 90470)
-- Name: salary_payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.salary_payments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    month integer NOT NULL,
    year integer NOT NULL,
    status character varying(20) DEFAULT 'Paid'::character varying NOT NULL,
    paid_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    paid_by_user_id uuid,
    amount numeric(10,2),
    currency character varying(3) DEFAULT 'DA'::character varying,
    CONSTRAINT salary_payments_month_check CHECK (((month >= 1) AND (month <= 12))),
    CONSTRAINT salary_payments_status_check CHECK (((status)::text = ANY ((ARRAY['Paid'::character varying, 'Reversed'::character varying])::text[]))),
    CONSTRAINT salary_payments_year_check CHECK ((year >= 2000))
);


ALTER TABLE public.salary_payments OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 90448)
-- Name: salary_raises; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.salary_raises (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    raise_type character varying(20) NOT NULL,
    amount numeric(10,2) NOT NULL,
    effective_date date NOT NULL,
    reason text,
    created_by_user_id uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT salary_raises_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT salary_raises_raise_type_check CHECK (((raise_type)::text = ANY ((ARRAY['Fixed'::character varying, 'Percentage'::character varying])::text[])))
);


ALTER TABLE public.salary_raises OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 41239)
-- Name: task_comments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.task_comments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    task_id uuid,
    employee_id uuid,
    comment text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.task_comments OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 41216)
-- Name: tasks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tasks (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    type character varying(20) NOT NULL,
    assigned_to uuid,
    assigned_by uuid,
    due_date date,
    status character varying(20) DEFAULT 'Pending'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT tasks_status_check CHECK (((status)::text = ANY ((ARRAY['Pending'::character varying, 'In Progress'::character varying, 'Completed'::character varying, 'Not Done'::character varying])::text[]))),
    CONSTRAINT tasks_type_check CHECK (((type)::text = ANY ((ARRAY['Daily'::character varying, 'Special'::character varying])::text[])))
);


ALTER TABLE public.tasks OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 58142)
-- Name: timetable_intervals; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.timetable_intervals (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    timetable_id uuid NOT NULL,
    weekday integer NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    break_minutes integer DEFAULT 0,
    on_call_flag boolean DEFAULT false,
    overnight boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT timetable_intervals_weekday_check CHECK (((weekday >= 0) AND (weekday <= 6)))
);


ALTER TABLE public.timetable_intervals OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 58132)
-- Name: timetables; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.timetables (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(50) NOT NULL,
    timezone character varying(100) DEFAULT 'UTC'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT timetables_type_check CHECK (((type)::text = ANY ((ARRAY['Template'::character varying, 'Concrete'::character varying])::text[])))
);


ALTER TABLE public.timetables OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 90317)
-- Name: uploads; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.uploads (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    file_name character varying(255) NOT NULL,
    original_name character varying(255) NOT NULL,
    mime_type character varying(100) NOT NULL,
    file_size bigint NOT NULL,
    storage_path character varying(1000) NOT NULL,
    storage_type character varying(20) DEFAULT 'file'::character varying,
    uploader_user_id uuid,
    uploaded_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    deleted_at timestamp with time zone,
    deleted_by_user_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb
);


ALTER TABLE public.uploads OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 49323)
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
-- TOC entry 218 (class 1259 OID 41139)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    username character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    role character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT users_role_check CHECK (((role)::text = ANY ((ARRAY['HR_Manager'::character varying, 'Department_Responsible'::character varying, 'Employee'::character varying])::text[])))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 5092 (class 2606 OID 90388)
-- Name: attendance_exceptions attendance_exceptions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance_exceptions
    ADD CONSTRAINT attendance_exceptions_pkey PRIMARY KEY (id);


--
-- TOC entry 5096 (class 2606 OID 90415)
-- Name: attendance_overrides attendance_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance_overrides
    ADD CONSTRAINT attendance_overrides_pkey PRIMARY KEY (id);


--
-- TOC entry 5084 (class 2606 OID 90338)
-- Name: attendance_punches attendance_punches_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance_punches
    ADD CONSTRAINT attendance_punches_pkey PRIMARY KEY (id);


--
-- TOC entry 5088 (class 2606 OID 90368)
-- Name: attendance_settings attendance_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance_settings
    ADD CONSTRAINT attendance_settings_pkey PRIMARY KEY (id);


--
-- TOC entry 5099 (class 2606 OID 90441)
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- TOC entry 5033 (class 2606 OID 41193)
-- Name: departments departments_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_name_key UNIQUE (name);


--
-- TOC entry 5035 (class 2606 OID 41191)
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- TOC entry 5037 (class 2606 OID 41205)
-- Name: employee_departments employee_departments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_departments
    ADD CONSTRAINT employee_departments_pkey PRIMARY KEY (employee_id, department_id);


--
-- TOC entry 5124 (class 2606 OID 106722)
-- Name: employee_salary_adjustments employee_salary_adjustments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_salary_adjustments
    ADD CONSTRAINT employee_salary_adjustments_pkey PRIMARY KEY (id);


--
-- TOC entry 5077 (class 2606 OID 58166)
-- Name: employee_timetables employee_timetables_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_timetables
    ADD CONSTRAINT employee_timetables_pkey PRIMARY KEY (id);


--
-- TOC entry 5028 (class 2606 OID 41173)
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);


--
-- TOC entry 5052 (class 2606 OID 41278)
-- Name: meeting_attendees meeting_attendees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meeting_attendees
    ADD CONSTRAINT meeting_attendees_pkey PRIMARY KEY (meeting_id, employee_id);


--
-- TOC entry 5050 (class 2606 OID 41267)
-- Name: meetings meetings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_pkey PRIMARY KEY (id);


--
-- TOC entry 5057 (class 2606 OID 41336)
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- TOC entry 5061 (class 2606 OID 41372)
-- Name: permission_requests permission_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permission_requests
    ADD CONSTRAINT permission_requests_pkey PRIMARY KEY (id);


--
-- TOC entry 5065 (class 2606 OID 41412)
-- Name: position_salaries position_salaries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.position_salaries
    ADD CONSTRAINT position_salaries_pkey PRIMARY KEY (id);


--
-- TOC entry 5024 (class 2606 OID 41161)
-- Name: positions positions_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.positions
    ADD CONSTRAINT positions_name_key UNIQUE (name);


--
-- TOC entry 5026 (class 2606 OID 41159)
-- Name: positions positions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.positions
    ADD CONSTRAINT positions_pkey PRIMARY KEY (id);


--
-- TOC entry 5113 (class 2606 OID 90511)
-- Name: punch_file_uploads punch_file_uploads_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.punch_file_uploads
    ADD CONSTRAINT punch_file_uploads_pkey PRIMARY KEY (id);


--
-- TOC entry 5054 (class 2606 OID 41298)
-- Name: salaries salaries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salaries
    ADD CONSTRAINT salaries_pkey PRIMARY KEY (id);


--
-- TOC entry 5118 (class 2606 OID 90529)
-- Name: salary_calculations salary_calculations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salary_calculations
    ADD CONSTRAINT salary_calculations_pkey PRIMARY KEY (id);


--
-- TOC entry 5120 (class 2606 OID 106711)
-- Name: salary_parameters salary_parameters_parameter_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salary_parameters
    ADD CONSTRAINT salary_parameters_parameter_name_key UNIQUE (parameter_name);


--
-- TOC entry 5122 (class 2606 OID 106709)
-- Name: salary_parameters salary_parameters_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salary_parameters
    ADD CONSTRAINT salary_parameters_pkey PRIMARY KEY (id);


--
-- TOC entry 5106 (class 2606 OID 90482)
-- Name: salary_payments salary_payments_employee_id_month_year_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salary_payments
    ADD CONSTRAINT salary_payments_employee_id_month_year_key UNIQUE (employee_id, month, year);


--
-- TOC entry 5108 (class 2606 OID 90480)
-- Name: salary_payments salary_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salary_payments
    ADD CONSTRAINT salary_payments_pkey PRIMARY KEY (id);


--
-- TOC entry 5103 (class 2606 OID 90458)
-- Name: salary_raises salary_raises_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salary_raises
    ADD CONSTRAINT salary_raises_pkey PRIMARY KEY (id);


--
-- TOC entry 5046 (class 2606 OID 41247)
-- Name: task_comments task_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_comments
    ADD CONSTRAINT task_comments_pkey PRIMARY KEY (id);


--
-- TOC entry 5044 (class 2606 OID 41228)
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- TOC entry 5075 (class 2606 OID 58152)
-- Name: timetable_intervals timetable_intervals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.timetable_intervals
    ADD CONSTRAINT timetable_intervals_pkey PRIMARY KEY (id);


--
-- TOC entry 5071 (class 2606 OID 58141)
-- Name: timetables timetables_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.timetables
    ADD CONSTRAINT timetables_pkey PRIMARY KEY (id);


--
-- TOC entry 5082 (class 2606 OID 90327)
-- Name: uploads uploads_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.uploads
    ADD CONSTRAINT uploads_pkey PRIMARY KEY (id);


--
-- TOC entry 5069 (class 2606 OID 49330)
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);


--
-- TOC entry 5020 (class 2606 OID 41149)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 5022 (class 2606 OID 41151)
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- TOC entry 5093 (class 1259 OID 90404)
-- Name: idx_attendance_exceptions_employee_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_attendance_exceptions_employee_date ON public.attendance_exceptions USING btree (employee_id, date);


--
-- TOC entry 5094 (class 1259 OID 90405)
-- Name: idx_attendance_exceptions_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_attendance_exceptions_status ON public.attendance_exceptions USING btree (status);


--
-- TOC entry 5097 (class 1259 OID 90431)
-- Name: idx_attendance_overrides_employee_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_attendance_overrides_employee_date ON public.attendance_overrides USING btree (employee_id, date);


--
-- TOC entry 5085 (class 1259 OID 90349)
-- Name: idx_attendance_punches_employee_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_attendance_punches_employee_time ON public.attendance_punches USING btree (employee_id, punch_time);


--
-- TOC entry 5086 (class 1259 OID 90350)
-- Name: idx_attendance_punches_upload_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_attendance_punches_upload_id ON public.attendance_punches USING btree (upload_id);


--
-- TOC entry 5100 (class 1259 OID 90447)
-- Name: idx_audit_logs_entity; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audit_logs_entity ON public.audit_logs USING btree (entity_type, entity_id);


--
-- TOC entry 5038 (class 1259 OID 41421)
-- Name: idx_employee_departments_department_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employee_departments_department_id ON public.employee_departments USING btree (department_id);


--
-- TOC entry 5039 (class 1259 OID 41420)
-- Name: idx_employee_departments_employee_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employee_departments_employee_id ON public.employee_departments USING btree (employee_id);


--
-- TOC entry 5125 (class 1259 OID 106733)
-- Name: idx_employee_salary_adjustments_employee_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employee_salary_adjustments_employee_date ON public.employee_salary_adjustments USING btree (employee_id, effective_date);


--
-- TOC entry 5126 (class 1259 OID 106734)
-- Name: idx_employee_salary_adjustments_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employee_salary_adjustments_type ON public.employee_salary_adjustments USING btree (adjustment_type);


--
-- TOC entry 5078 (class 1259 OID 58181)
-- Name: idx_employee_timetables_effective_dates; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employee_timetables_effective_dates ON public.employee_timetables USING btree (effective_from, effective_to);


--
-- TOC entry 5079 (class 1259 OID 58179)
-- Name: idx_employee_timetables_employee_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employee_timetables_employee_id ON public.employee_timetables USING btree (employee_id);


--
-- TOC entry 5080 (class 1259 OID 58180)
-- Name: idx_employee_timetables_timetable_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employee_timetables_timetable_id ON public.employee_timetables USING btree (timetable_id);


--
-- TOC entry 5029 (class 1259 OID 49336)
-- Name: idx_employees_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employees_email ON public.employees USING btree (email);


--
-- TOC entry 5030 (class 1259 OID 41385)
-- Name: idx_employees_position_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employees_position_id ON public.employees USING btree (position_id);


--
-- TOC entry 5031 (class 1259 OID 41384)
-- Name: idx_employees_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employees_user_id ON public.employees USING btree (user_id);


--
-- TOC entry 5047 (class 1259 OID 41389)
-- Name: idx_meetings_scheduled_by; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_meetings_scheduled_by ON public.meetings USING btree (scheduled_by);


--
-- TOC entry 5048 (class 1259 OID 41390)
-- Name: idx_meetings_start_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_meetings_start_time ON public.meetings USING btree (start_time);


--
-- TOC entry 5055 (class 1259 OID 41391)
-- Name: idx_notifications_recipient_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_recipient_id ON public.notifications USING btree (recipient_id);


--
-- TOC entry 5058 (class 1259 OID 41393)
-- Name: idx_permission_requests_employee_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_permission_requests_employee_id ON public.permission_requests USING btree (employee_id);


--
-- TOC entry 5059 (class 1259 OID 41394)
-- Name: idx_permission_requests_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_permission_requests_status ON public.permission_requests USING btree (status);


--
-- TOC entry 5062 (class 1259 OID 41419)
-- Name: idx_position_salaries_effective_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_position_salaries_effective_date ON public.position_salaries USING btree (effective_date);


--
-- TOC entry 5063 (class 1259 OID 41418)
-- Name: idx_position_salaries_position_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_position_salaries_position_id ON public.position_salaries USING btree (position_id);


--
-- TOC entry 5109 (class 1259 OID 90544)
-- Name: idx_punch_file_uploads_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_punch_file_uploads_status ON public.punch_file_uploads USING btree (status);


--
-- TOC entry 5110 (class 1259 OID 90545)
-- Name: idx_punch_file_uploads_upload_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_punch_file_uploads_upload_date ON public.punch_file_uploads USING btree (upload_date);


--
-- TOC entry 5111 (class 1259 OID 90543)
-- Name: idx_punch_file_uploads_uploaded_by; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_punch_file_uploads_uploaded_by ON public.punch_file_uploads USING btree (uploaded_by_user_id);


--
-- TOC entry 5114 (class 1259 OID 90546)
-- Name: idx_salary_calculations_employee_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_salary_calculations_employee_id ON public.salary_calculations USING btree (employee_id);


--
-- TOC entry 5115 (class 1259 OID 90547)
-- Name: idx_salary_calculations_period; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_salary_calculations_period ON public.salary_calculations USING btree (calculation_period_start, calculation_period_end);


--
-- TOC entry 5116 (class 1259 OID 90548)
-- Name: idx_salary_calculations_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_salary_calculations_status ON public.salary_calculations USING btree (status);


--
-- TOC entry 5104 (class 1259 OID 90493)
-- Name: idx_salary_payments_period; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_salary_payments_period ON public.salary_payments USING btree (year, month);


--
-- TOC entry 5101 (class 1259 OID 90469)
-- Name: idx_salary_raises_employee_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_salary_raises_employee_date ON public.salary_raises USING btree (employee_id, effective_date);


--
-- TOC entry 5040 (class 1259 OID 41387)
-- Name: idx_tasks_assigned_by; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tasks_assigned_by ON public.tasks USING btree (assigned_by);


--
-- TOC entry 5041 (class 1259 OID 41386)
-- Name: idx_tasks_assigned_to; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tasks_assigned_to ON public.tasks USING btree (assigned_to);


--
-- TOC entry 5042 (class 1259 OID 41388)
-- Name: idx_tasks_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tasks_status ON public.tasks USING btree (status);


--
-- TOC entry 5072 (class 1259 OID 58177)
-- Name: idx_timetable_intervals_timetable_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_timetable_intervals_timetable_id ON public.timetable_intervals USING btree (timetable_id);


--
-- TOC entry 5073 (class 1259 OID 58178)
-- Name: idx_timetable_intervals_weekday; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_timetable_intervals_weekday ON public.timetable_intervals USING btree (weekday);


--
-- TOC entry 5066 (class 1259 OID 49338)
-- Name: idx_user_sessions_token_hash; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_sessions_token_hash ON public.user_sessions USING btree (token_hash);


--
-- TOC entry 5067 (class 1259 OID 49337)
-- Name: idx_user_sessions_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_sessions_user_id ON public.user_sessions USING btree (user_id);


--
-- TOC entry 5018 (class 1259 OID 41383)
-- Name: idx_users_username; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_username ON public.users USING btree (username);


--
-- TOC entry 5089 (class 1259 OID 90375)
-- Name: uniq_attendance_settings_dept; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX uniq_attendance_settings_dept ON public.attendance_settings USING btree (scope, department_id) WHERE ((scope)::text = 'department'::text);


--
-- TOC entry 5090 (class 1259 OID 90374)
-- Name: uniq_attendance_settings_global; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX uniq_attendance_settings_global ON public.attendance_settings USING btree (scope) WHERE ((scope)::text = 'global'::text);


--
-- TOC entry 5169 (class 2620 OID 106735)
-- Name: employee_salary_adjustments update_employee_salary_adjustments_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_employee_salary_adjustments_updated_at BEFORE UPDATE ON public.employee_salary_adjustments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- TOC entry 5166 (class 2620 OID 66172)
-- Name: employees update_employees_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_employees_updated_at BEFORE UPDATE ON public.employees FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- TOC entry 5167 (class 2620 OID 90551)
-- Name: punch_file_uploads update_punch_file_uploads_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_punch_file_uploads_updated_at BEFORE UPDATE ON public.punch_file_uploads FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- TOC entry 5168 (class 2620 OID 90552)
-- Name: salary_calculations update_salary_calculations_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_salary_calculations_updated_at BEFORE UPDATE ON public.salary_calculations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- TOC entry 5153 (class 2606 OID 90389)
-- Name: attendance_exceptions attendance_exceptions_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance_exceptions
    ADD CONSTRAINT attendance_exceptions_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- TOC entry 5154 (class 2606 OID 90399)
-- Name: attendance_exceptions attendance_exceptions_reviewed_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance_exceptions
    ADD CONSTRAINT attendance_exceptions_reviewed_by_user_id_fkey FOREIGN KEY (reviewed_by_user_id) REFERENCES public.users(id);


--
-- TOC entry 5155 (class 2606 OID 90394)
-- Name: attendance_exceptions attendance_exceptions_submitted_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance_exceptions
    ADD CONSTRAINT attendance_exceptions_submitted_by_user_id_fkey FOREIGN KEY (submitted_by_user_id) REFERENCES public.users(id);


--
-- TOC entry 5156 (class 2606 OID 90426)
-- Name: attendance_overrides attendance_overrides_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance_overrides
    ADD CONSTRAINT attendance_overrides_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- TOC entry 5157 (class 2606 OID 90416)
-- Name: attendance_overrides attendance_overrides_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance_overrides
    ADD CONSTRAINT attendance_overrides_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- TOC entry 5158 (class 2606 OID 90421)
-- Name: attendance_overrides attendance_overrides_exception_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance_overrides
    ADD CONSTRAINT attendance_overrides_exception_id_fkey FOREIGN KEY (exception_id) REFERENCES public.attendance_exceptions(id) ON DELETE SET NULL;


--
-- TOC entry 5150 (class 2606 OID 90339)
-- Name: attendance_punches attendance_punches_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance_punches
    ADD CONSTRAINT attendance_punches_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- TOC entry 5151 (class 2606 OID 90344)
-- Name: attendance_punches attendance_punches_upload_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance_punches
    ADD CONSTRAINT attendance_punches_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES public.uploads(id) ON DELETE SET NULL;


--
-- TOC entry 5152 (class 2606 OID 90369)
-- Name: attendance_settings attendance_settings_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance_settings
    ADD CONSTRAINT attendance_settings_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- TOC entry 5159 (class 2606 OID 90442)
-- Name: audit_logs audit_logs_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES public.users(id);


--
-- TOC entry 5129 (class 2606 OID 41194)
-- Name: departments departments_responsible_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_responsible_id_fkey FOREIGN KEY (responsible_id) REFERENCES public.employees(id);


--
-- TOC entry 5130 (class 2606 OID 41211)
-- Name: employee_departments employee_departments_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_departments
    ADD CONSTRAINT employee_departments_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- TOC entry 5131 (class 2606 OID 41206)
-- Name: employee_departments employee_departments_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_departments
    ADD CONSTRAINT employee_departments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- TOC entry 5164 (class 2606 OID 106728)
-- Name: employee_salary_adjustments employee_salary_adjustments_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_salary_adjustments
    ADD CONSTRAINT employee_salary_adjustments_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- TOC entry 5165 (class 2606 OID 106723)
-- Name: employee_salary_adjustments employee_salary_adjustments_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_salary_adjustments
    ADD CONSTRAINT employee_salary_adjustments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- TOC entry 5148 (class 2606 OID 58167)
-- Name: employee_timetables employee_timetables_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_timetables
    ADD CONSTRAINT employee_timetables_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- TOC entry 5149 (class 2606 OID 58172)
-- Name: employee_timetables employee_timetables_timetable_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_timetables
    ADD CONSTRAINT employee_timetables_timetable_id_fkey FOREIGN KEY (timetable_id) REFERENCES public.timetables(id) ON DELETE CASCADE;


--
-- TOC entry 5127 (class 2606 OID 41179)
-- Name: employees employees_position_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_position_id_fkey FOREIGN KEY (position_id) REFERENCES public.positions(id);


--
-- TOC entry 5128 (class 2606 OID 41174)
-- Name: employees employees_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5137 (class 2606 OID 41284)
-- Name: meeting_attendees meeting_attendees_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meeting_attendees
    ADD CONSTRAINT meeting_attendees_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- TOC entry 5138 (class 2606 OID 41279)
-- Name: meeting_attendees meeting_attendees_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meeting_attendees
    ADD CONSTRAINT meeting_attendees_meeting_id_fkey FOREIGN KEY (meeting_id) REFERENCES public.meetings(id) ON DELETE CASCADE;


--
-- TOC entry 5136 (class 2606 OID 41268)
-- Name: meetings meetings_scheduled_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_scheduled_by_fkey FOREIGN KEY (scheduled_by) REFERENCES public.employees(id);


--
-- TOC entry 5141 (class 2606 OID 41337)
-- Name: notifications notifications_recipient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES public.employees(id);


--
-- TOC entry 5142 (class 2606 OID 41342)
-- Name: notifications notifications_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.employees(id);


--
-- TOC entry 5143 (class 2606 OID 41373)
-- Name: permission_requests permission_requests_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permission_requests
    ADD CONSTRAINT permission_requests_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id);


--
-- TOC entry 5144 (class 2606 OID 41378)
-- Name: permission_requests permission_requests_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permission_requests
    ADD CONSTRAINT permission_requests_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.employees(id);


--
-- TOC entry 5145 (class 2606 OID 41413)
-- Name: position_salaries position_salaries_position_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.position_salaries
    ADD CONSTRAINT position_salaries_position_id_fkey FOREIGN KEY (position_id) REFERENCES public.positions(id) ON DELETE CASCADE;


--
-- TOC entry 5139 (class 2606 OID 41299)
-- Name: salaries salaries_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salaries
    ADD CONSTRAINT salaries_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id);


--
-- TOC entry 5140 (class 2606 OID 41304)
-- Name: salaries salaries_position_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salaries
    ADD CONSTRAINT salaries_position_id_fkey FOREIGN KEY (position_id) REFERENCES public.positions(id);


--
-- TOC entry 5162 (class 2606 OID 90483)
-- Name: salary_payments salary_payments_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salary_payments
    ADD CONSTRAINT salary_payments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- TOC entry 5163 (class 2606 OID 90488)
-- Name: salary_payments salary_payments_paid_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salary_payments
    ADD CONSTRAINT salary_payments_paid_by_user_id_fkey FOREIGN KEY (paid_by_user_id) REFERENCES public.users(id);


--
-- TOC entry 5160 (class 2606 OID 90464)
-- Name: salary_raises salary_raises_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salary_raises
    ADD CONSTRAINT salary_raises_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- TOC entry 5161 (class 2606 OID 90459)
-- Name: salary_raises salary_raises_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salary_raises
    ADD CONSTRAINT salary_raises_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- TOC entry 5134 (class 2606 OID 41253)
-- Name: task_comments task_comments_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_comments
    ADD CONSTRAINT task_comments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id);


--
-- TOC entry 5135 (class 2606 OID 41248)
-- Name: task_comments task_comments_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_comments
    ADD CONSTRAINT task_comments_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- TOC entry 5132 (class 2606 OID 41234)
-- Name: tasks tasks_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.employees(id);


--
-- TOC entry 5133 (class 2606 OID 41229)
-- Name: tasks tasks_assigned_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES public.employees(id);


--
-- TOC entry 5147 (class 2606 OID 58153)
-- Name: timetable_intervals timetable_intervals_timetable_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.timetable_intervals
    ADD CONSTRAINT timetable_intervals_timetable_id_fkey FOREIGN KEY (timetable_id) REFERENCES public.timetables(id) ON DELETE CASCADE;


--
-- TOC entry 5146 (class 2606 OID 49331)
-- Name: user_sessions user_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


-- Completed on 2025-09-08 13:24:52

--
-- PostgreSQL database dump complete
--

