--
-- PostgreSQL database dump
--

-- Dumped from database version 15.13
-- Dumped by pg_dump version 15.13

-- Started on 2025-12-07 19:35:32

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 250 (class 1259 OID 26062)
-- Name: complaint_attachments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.complaint_attachments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    complaint_id uuid NOT NULL,
    file_path text NOT NULL,
    file_name text,
    uploaded_by uuid,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.complaint_attachments OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 26021)
-- Name: complaint_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.complaint_history (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    complaint_id uuid NOT NULL,
    changed_by uuid NOT NULL,
    old_status text,
    new_status text,
    comment text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.complaint_history OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 26000)
-- Name: complaint_messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.complaint_messages (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    complaint_id uuid NOT NULL,
    sender_id uuid NOT NULL,
    sender_role text NOT NULL,
    body text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT complaint_messages_sender_role_check CHECK ((sender_role = ANY (ARRAY['employee'::text, 'director'::text])))
);


ALTER TABLE public.complaint_messages OWNER TO postgres;

--
-- TOC entry 249 (class 1259 OID 26041)
-- Name: complaint_notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.complaint_notifications (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    complaint_id uuid NOT NULL,
    recipient_id uuid,
    message text NOT NULL,
    is_read boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    title text,
    recipient_user_id uuid
);


ALTER TABLE public.complaint_notifications OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 25958)
-- Name: complaint_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.complaint_types (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.complaint_types OWNER TO postgres;

--
-- TOC entry 246 (class 1259 OID 25969)
-- Name: complaints; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.complaints (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    type_id uuid NOT NULL,
    title text NOT NULL,
    description text,
    priority text DEFAULT 'medium'::text NOT NULL,
    is_anonymous boolean DEFAULT false NOT NULL,
    attachment_path text,
    status text DEFAULT 'pending'::text NOT NULL,
    manager_comment text,
    handled_by uuid,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    completed_at timestamp without time zone,
    due_date timestamp without time zone,
    resolved_at timestamp without time zone,
    satisfaction_rating integer,
    feedback text,
    department_id uuid,
    CONSTRAINT complaints_priority_check CHECK ((priority = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text]))),
    CONSTRAINT complaints_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'completed'::text])))
);


ALTER TABLE public.complaints OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 17800)
-- Name: signalisations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.signalisations (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    type_id uuid NOT NULL,
    created_by uuid NOT NULL,
    title text NOT NULL,
    description text,
    photo_path text,
    is_viewed boolean DEFAULT false NOT NULL,
    is_treated boolean DEFAULT false NOT NULL,
    treated_by uuid,
    treated_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    localisation_id uuid,
    location text,
    priority text DEFAULT 'medium'::text NOT NULL,
    satisfaction_rating integer,
    feedback text,
    CONSTRAINT signalisations_priority_check CHECK ((priority = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text]))),
    CONSTRAINT signalisations_satisfaction_rating_check CHECK (((satisfaction_rating >= 1) AND (satisfaction_rating <= 5)))
);


ALTER TABLE public.signalisations OWNER TO postgres;

--
-- TOC entry 252 (class 1259 OID 26104)
-- Name: suggestions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.suggestions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    type_id uuid,
    title text NOT NULL,
    description text,
    category text,
    department_id uuid,
    status text DEFAULT 'under_review'::text NOT NULL,
    director_comment text,
    handled_by uuid,
    redirected_to uuid,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    reviewed_at timestamp without time zone,
    decision_at timestamp without time zone,
    CONSTRAINT suggestions_status_check CHECK ((status = ANY (ARRAY['under_review'::text, 'accepted'::text, 'rejected'::text])))
);


ALTER TABLE public.suggestions OWNER TO postgres;

--
-- TOC entry 259 (class 1259 OID 26261)
-- Name: critical_alerts; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.critical_alerts AS
 SELECT 'suggestion_stalled'::text AS alert_type,
    s.id,
    s.title,
    (((e.first_name)::text || ' '::text) || (e.last_name)::text) AS employee,
    d.name AS department,
    EXTRACT(day FROM (CURRENT_TIMESTAMP - (s.created_at)::timestamp with time zone)) AS days_pending
   FROM ((public.suggestions s
     JOIN public.employees e ON ((s.employee_id = e.id)))
     LEFT JOIN public.departments d ON ((s.department_id = d.id)))
  WHERE ((s.status = 'under_review'::text) AND (s.created_at < (CURRENT_DATE - '15 days'::interval)))
UNION ALL
 SELECT 'signal_untreated'::text AS alert_type,
    sig.id,
    sig.title,
    (((e.first_name)::text || ' '::text) || (e.last_name)::text) AS employee,
    COALESCE((((l.code_emplacement || ' ('::text) || COALESCE(l.description_ar, ''::text)) || ')'::text), sig.location) AS department,
    EXTRACT(day FROM (CURRENT_TIMESTAMP - (sig.created_at)::timestamp with time zone)) AS days_pending
   FROM ((public.signalisations sig
     JOIN public.employees e ON ((sig.created_by = e.id)))
     LEFT JOIN public.localisations l ON ((sig.localisation_id = l.id)))
  WHERE ((sig.is_treated = false) AND (sig.created_at < (CURRENT_DATE - '7 days'::interval)))
  ORDER BY 6 DESC;


ALTER TABLE public.critical_alerts OWNER TO postgres;

--
-- TOC entry 258 (class 1259 OID 26256)
-- Name: department_performance_detail; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.department_performance_detail AS
 SELECT d.name AS department,
    count(DISTINCT s.id) AS total_suggestions,
    count(DISTINCT s.id) FILTER (WHERE (s.status = 'under_review'::text)) AS pending_suggestions,
    count(DISTINCT s.id) FILTER (WHERE (s.status = 'accepted'::text)) AS accepted_suggestions,
    count(DISTINCT s.id) FILTER (WHERE (s.status = 'rejected'::text)) AS rejected_suggestions,
    count(DISTINCT sig.id) AS total_signals,
    count(DISTINCT sig.id) FILTER (WHERE (sig.is_treated = false)) AS pending_signals,
    count(DISTINCT sig.id) FILTER (WHERE (sig.is_treated = true)) AS treated_signals,
    round(avg((EXTRACT(epoch FROM (s.reviewed_at - s.created_at)) / (86400)::numeric)), 2) AS avg_suggestion_review_days,
    round(avg((EXTRACT(epoch FROM (sig.treated_at - sig.created_at)) / (86400)::numeric)), 2) AS avg_signal_treatment_days,
    count(DISTINCT s.employee_id) AS employees_with_suggestions,
    count(DISTINCT sig.created_by) AS employees_with_signals
   FROM ((public.departments d
     LEFT JOIN public.suggestions s ON ((d.id = s.department_id)))
     LEFT JOIN public.signalisations sig ON ((d.id = sig.localisation_id)))
  GROUP BY d.id, d.name
  ORDER BY (count(DISTINCT s.id)) DESC;


ALTER TABLE public.department_performance_detail OWNER TO postgres;

--
-- TOC entry 257 (class 1259 OID 26251)
-- Name: director_dashboard; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.director_dashboard AS
 WITH response_time_metrics AS (
         SELECT 'suggestion_review'::text AS metric,
            percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY (((EXTRACT(epoch FROM (suggestions.reviewed_at - suggestions.created_at)) / (3600)::numeric))::double precision)) AS median_hours
           FROM public.suggestions
          WHERE (suggestions.reviewed_at IS NOT NULL)
        UNION ALL
         SELECT 'signal_treatment'::text AS metric,
            percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY (((EXTRACT(epoch FROM (signalisations.treated_at - signalisations.created_at)) / (3600)::numeric))::double precision)) AS median_hours
           FROM public.signalisations
          WHERE (signalisations.treated_at IS NOT NULL)
        )
 SELECT ( SELECT count(*) AS count
           FROM public.suggestions) AS total_suggestions,
    ( SELECT count(*) AS count
           FROM public.suggestions
          WHERE (suggestions.status = 'under_review'::text)) AS pending_suggestions,
    ( SELECT count(*) AS count
           FROM public.signalisations) AS total_signals,
    ( SELECT count(*) AS count
           FROM public.signalisations
          WHERE (signalisations.is_treated = false)) AS pending_signals,
    round((((( SELECT count(*) AS count
           FROM public.suggestions
          WHERE (suggestions.status = ANY (ARRAY['accepted'::text, 'rejected'::text]))))::numeric * 100.0) / (NULLIF(( SELECT count(*) AS count
           FROM public.suggestions), 0))::numeric), 2) AS suggestion_resolution_rate,
    round((((( SELECT count(*) AS count
           FROM public.signalisations
          WHERE (signalisations.is_treated = true)))::numeric * 100.0) / (NULLIF(( SELECT count(*) AS count
           FROM public.signalisations), 0))::numeric), 2) AS signal_resolution_rate,
    ( SELECT response_time_metrics.median_hours
           FROM response_time_metrics
          WHERE (response_time_metrics.metric = 'suggestion_review'::text)) AS median_review_hours,
    ( SELECT response_time_metrics.median_hours
           FROM response_time_metrics
          WHERE (response_time_metrics.metric = 'signal_treatment'::text)) AS median_treatment_hours;


ALTER TABLE public.director_dashboard OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 17778)
-- Name: signal_type_responsibles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.signal_type_responsibles (
    type_id uuid NOT NULL,
    employee_id uuid NOT NULL,
    assigned_by uuid,
    assigned_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.signal_type_responsibles OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 17767)
-- Name: signal_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.signal_types (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.signal_types OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 17846)
-- Name: signalisations_status_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.signalisations_status_history (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    signalisation_id uuid NOT NULL,
    status text NOT NULL,
    changed_by uuid,
    note text,
    changed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.signalisations_status_history OWNER TO postgres;

--
-- TOC entry 242 (class 1259 OID 17829)
-- Name: signalisations_views; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.signalisations_views (
    signalisation_id uuid NOT NULL,
    viewer_id uuid NOT NULL,
    viewed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.signalisations_views OWNER TO postgres;

--
-- TOC entry 253 (class 1259 OID 26143)
-- Name: suggestion_attachments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.suggestion_attachments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    suggestion_id uuid NOT NULL,
    file_path text NOT NULL,
    file_name text,
    uploaded_by uuid,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.suggestion_attachments OWNER TO postgres;

--
-- TOC entry 255 (class 1259 OID 26184)
-- Name: suggestion_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.suggestion_history (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    suggestion_id uuid NOT NULL,
    changed_by uuid NOT NULL,
    old_status text,
    new_status text,
    comment text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.suggestion_history OWNER TO postgres;

--
-- TOC entry 254 (class 1259 OID 26163)
-- Name: suggestion_messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.suggestion_messages (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    suggestion_id uuid NOT NULL,
    sender_id uuid NOT NULL,
    sender_role text NOT NULL,
    body text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT suggestion_messages_sender_role_check CHECK ((sender_role = ANY (ARRAY['employee'::text, 'director'::text])))
);


ALTER TABLE public.suggestion_messages OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 26204)
-- Name: suggestion_notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.suggestion_notifications (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    suggestion_id uuid NOT NULL,
    recipient_id uuid,
    recipient_user_id uuid,
    message text NOT NULL,
    title text,
    is_read boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.suggestion_notifications OWNER TO postgres;

--
-- TOC entry 251 (class 1259 OID 26093)
-- Name: suggestion_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.suggestion_types (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.suggestion_types OWNER TO postgres;

--
-- TOC entry 261 (class 1259 OID 26271)
-- Name: top_contributors; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.top_contributors AS
 SELECT (((e.first_name)::text || ' '::text) || (e.last_name)::text) AS employee_name,
    d.name AS department,
    count(s.id) AS suggestions_count,
    count(sig.id) AS signals_count,
    count(s.id) FILTER (WHERE (s.status = 'accepted'::text)) AS accepted_suggestions,
    rank() OVER (ORDER BY (count(s.id)) DESC) AS suggestion_rank
   FROM ((((public.employees e
     LEFT JOIN public.employee_departments ed ON ((ed.employee_id = e.id)))
     LEFT JOIN public.departments d ON ((d.id = ed.department_id)))
     LEFT JOIN public.suggestions s ON ((e.id = s.employee_id)))
     LEFT JOIN public.signalisations sig ON ((e.id = sig.created_by)))
  GROUP BY e.id, e.first_name, e.last_name, d.name
  ORDER BY (count(s.id)) DESC
 LIMIT 10;


ALTER TABLE public.top_contributors OWNER TO postgres;

--
-- TOC entry 260 (class 1259 OID 26266)
-- Name: trend_analysis; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.trend_analysis AS
 SELECT date_trunc('month'::text, suggestions.created_at) AS month,
    'suggestions'::text AS type,
    count(*) AS count,
    count(*) FILTER (WHERE (suggestions.status = 'accepted'::text)) AS accepted
   FROM public.suggestions
  GROUP BY (date_trunc('month'::text, suggestions.created_at))
UNION ALL
 SELECT date_trunc('month'::text, signalisations.created_at) AS month,
    'signals'::text AS type,
    count(*) AS count,
    count(*) FILTER (WHERE (signalisations.is_treated = true)) AS accepted
   FROM public.signalisations
  GROUP BY (date_trunc('month'::text, signalisations.created_at));


ALTER TABLE public.trend_analysis OWNER TO postgres;

--
-- TOC entry 3662 (class 0 OID 26062)
-- Dependencies: 250
-- Data for Name: complaint_attachments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.complaint_attachments (id, complaint_id, file_path, file_name, uploaded_by, created_at) FROM stdin;
a120629e-f49a-4852-afce-9fd9bb13665e	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	/uploads/complaints/1763541939032-924820083.png	devoirTP.png	ad4800fd-c13f-4d2a-8558-cae29f052ea0	2025-11-19 08:45:39.062489
c0f76b9c-b9b4-4cf9-ac1a-e06b975a65b4	e1471e75-30bc-42a7-825f-e80f6e6f56ab	/uploads/complaints/1763542057409-871843126.png	devoirTP.png	ad4800fd-c13f-4d2a-8558-cae29f052ea0	2025-11-19 08:47:37.435533
66b48eb7-0a8f-4c1a-9586-4b12b20ddfe0	b62f5fa1-09db-40a6-8400-0634b50cd353	/uploads/complaints/1763543091432-523447644.png	devoirTP.png	ad4800fd-c13f-4d2a-8558-cae29f052ea0	2025-11-19 09:04:51.45633
348eea82-937d-41c5-a06c-4f2d5deb2863	fbdb5520-2835-4248-9437-6ea25d444ac0	/uploads/complaints/1763544035112-341261082.png	devoirTP.png	ad4800fd-c13f-4d2a-8558-cae29f052ea0	2025-11-19 09:20:35.139587
e7b1a97a-05a2-40a9-bd2a-3fdd01c78fcf	a24dec61-f216-41a0-a83f-a33b91b7bab2	/uploads/complaints/1763545296396-735531231.png	devoirTP.png	ad4800fd-c13f-4d2a-8558-cae29f052ea0	2025-11-19 09:41:36.42174
a7f32385-0ff1-4710-baa2-782bbbe7e3d8	968ee93f-09a9-4ef0-9aba-47dd64d86171	/uploads/complaints/1763545951763-843419483.png	devoirTP.png	ad4800fd-c13f-4d2a-8558-cae29f052ea0	2025-11-19 09:52:31.786562
4486cc3b-f34c-400c-bfb8-8d055d7fe2cc	e0cc3812-3bce-4bc2-b707-196538470f83	/uploads/complaints/1763545986212-74730697.png	devoirTP.png	ad4800fd-c13f-4d2a-8558-cae29f052ea0	2025-11-19 09:53:06.235035
51c964ae-404b-49b4-8638-eec5e7533c3e	f19fd934-c68d-470a-a9d6-7730c118bc06	/uploads/complaints/1763546210371-64265852.png	devoirTP.png	ad4800fd-c13f-4d2a-8558-cae29f052ea0	2025-11-19 09:56:50.394052
81a691e6-f3fb-4635-8cfb-d48302831e9b	51e290ec-f087-4eb4-b670-92b03e7c3147	/uploads/complaints/1763547553983-167947694.png	devoirTP.png	ad4800fd-c13f-4d2a-8558-cae29f052ea0	2025-11-19 10:19:14.004901
\.


--
-- TOC entry 3660 (class 0 OID 26021)
-- Dependencies: 248
-- Data for Name: complaint_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.complaint_history (id, complaint_id, changed_by, old_status, new_status, comment, created_at) FROM stdin;
ee4f8e2c-6264-4ac6-9222-1a95ead8a7f3	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	pending	تم إنشاء الشكوى	2025-11-19 08:45:38.997423
c016e419-520b-4a1a-acb2-612e1eca8e3c	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	pending	تم إنشاء الشكوى	2025-11-19 08:47:37.370714
06ea9b07-798e-4d1e-a465-8be4e7571b41	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	pending	تم إنشاء الشكوى	2025-11-19 09:04:51.392173
7518ab1b-55e0-4e33-bdf0-4d2e234c6ee5	fbdb5520-2835-4248-9437-6ea25d444ac0	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	pending	تم إنشاء الشكوى	2025-11-19 09:20:35.072257
97348c3f-9c6a-48c6-981e-d25d2b9a1f51	fbdb5520-2835-4248-9437-6ea25d444ac0	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	pending	completed	\N	2025-11-19 09:20:45.964504
a7bb2143-a1de-477a-834e-888ad1d50f81	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	pending	تم إنشاء الشكوى	2025-11-19 09:41:36.350216
50e021df-8fcc-4ea4-83ff-a98c77a6d995	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	pending	تم إنشاء الشكوى	2025-11-19 09:52:31.511234
6cf377e8-0e77-4437-bc3c-5036800932e7	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	pending	تم إنشاء الشكوى	2025-11-19 09:53:06.181939
cb679302-8084-4837-abfb-cb054cd4cb64	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	pending	تم إنشاء الشكوى	2025-11-19 09:56:50.319319
d6a02b72-cb6b-4c37-a28d-8265f6dc254a	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	pending	تم إنشاء الشكوى	2025-11-19 10:19:13.751177
002880b0-79e0-49de-8d7d-f242b2aadae6	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:27:26.067
6e7cb9ae-035d-402f-9def-34576c5850e3	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:27:26.21152
dfa897ba-51b6-4407-90cf-27ebe99f015e	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:27:26.226779
791a15af-5b9f-41f8-ac5d-bf837d9f2171	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:27:26.065735
c0dba57e-a675-4333-b127-5b076e98e197	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:27:26.121179
8cdaf110-40d7-4f63-acc1-54093818d6ce	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:27:26.324021
59ecf300-711b-4342-9f06-4a9b74514657	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:27:26.597988
4629c662-2fb0-49aa-becc-d8a2847f4b4a	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:27:26.622413
cfd3f686-ef51-4034-a8d2-0eff01ca3f12	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:20.144163
121038b6-ee49-4951-af53-e6622373d710	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:20.143712
ed68ba1d-4ce8-461b-8564-03428c4a70e8	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:20.298527
36bb9281-440a-4b2d-ba51-8b9177b93b61	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:20.332219
8f875d44-f956-456c-b3c3-fb2777ecf033	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:20.373351
c807e59d-7650-49ed-968d-2425e288f143	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:20.410917
c36f909b-72b9-4f7e-ba4c-7b5a4d3fc546	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:20.5012
812a2b99-9993-4878-b80b-93e4c1682097	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:20.526636
1b64d465-bb6d-40aa-9c19-dc57750924cb	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:20.771787
7756ab6f-9de2-4a73-b4b5-5fd97b711b20	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:20.771908
21369e7e-a146-43f8-8fb8-a53b22dfcc62	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:20.77192
f9211096-42c1-4c7a-9e0b-b956b9a33586	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:20.775365
e96dbbb2-5ec1-47b1-ac5f-52dc3d3c9088	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:21.00966
b6f58620-d212-482e-aa85-9529afb29475	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:21.050622
07fd7fba-be69-4b79-841f-b6d3794011d4	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:21.174509
0896e970-830d-41a8-a361-76459ec36055	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:21.17692
1d412634-6da5-40a9-9077-2b246c825d62	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:32.472192
8f773a19-9fef-4a17-8066-3ae50e4c323a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:32.472078
f263e130-1ab9-4852-89d8-44dfa21c7175	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:32.551459
457faea2-0c07-477a-a4ce-d8a01300b430	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:32.557549
ef1005b8-bb98-4428-ae76-79ef58b5a594	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:32.626327
400116d7-32f5-4421-b332-ba334dc4a255	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:32.660428
294463ce-c477-497e-a7df-4be90c672e2f	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:32.770597
6cb93904-5038-42e0-81f2-9979f2d7001b	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 07:58:32.772067
38043ba0-8fe7-4f7a-b81c-2ee829d6b30d	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:06:39.410945
13e86511-5ad9-4554-bca3-26074a12db10	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:06:39.410137
aeb390c7-f4e6-447a-b79d-d7cf92d46468	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:06:39.576483
5811ebed-d092-4d86-9b82-06a8408980b6	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:06:39.622643
5c93b7e5-4bc1-430b-8a77-af7f5ca9449d	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:06:39.62304
3c9dfdbc-bfa9-4e0c-a000-3a7e382e3ef9	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:06:39.702815
eb69bc11-f5e9-44e3-8cd3-0efe64c0921f	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:06:39.725741
e79cd18b-5b29-4de0-8c55-8c90bee3af8e	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:06:39.919846
bae97a9f-b632-4e35-8e18-88dad287cc30	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:06:42.43267
02d0254d-0e86-48ff-b1e7-963a38f6c72a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:06:42.434864
e61e24f1-9d96-4087-a8e1-5b0508925309	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:06:42.435539
4c33afe3-82ad-4ddd-a409-d3681b25b229	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:06:42.436146
8751baa7-a995-45f3-9dff-87e988aef8d6	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:06:42.438402
e6bfedcd-db5f-4953-905b-f2d5597ddc3b	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:06:42.454064
ef1315b2-52de-49b0-aa0d-f0ebf608da64	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:06:42.737831
9c7eb58d-5d02-472c-8b9b-f2f7a9f4dd10	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:06:42.74065
c8375062-6df6-4e26-89bf-77caae2911be	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:31:54.44714
d61e1155-f829-441c-9915-3bbfc3d32a48	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:31:54.449357
185c2568-ddfa-4798-a50f-92d2d3d1ac9f	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:31:54.646574
454066e8-5070-4daf-ad0b-01cb9c2b0e96	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:31:54.646824
07106003-d09e-441d-b434-73cbe9125ed7	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:31:54.727635
8a5fa1d6-0be0-436d-9979-df876e218bd7	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:31:54.746576
6002a74d-faf4-404a-8b13-57552ea3c169	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:31:54.859648
0ceb69d2-9b1c-4b1b-9779-b4ada329dfd9	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 08:31:54.860476
591b3db0-7e2c-4369-a128-2d61ee7f0224	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 09:24:22.197186
77ff9a40-0c59-4954-9876-56c8131699dc	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 09:24:22.196592
5881e1ff-0f8d-4e9c-9808-367dd21380e8	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 09:24:22.377467
22ea27aa-0bb8-423c-883b-9784152b33b0	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 09:24:22.377879
a91c11d4-4875-409f-8df6-e72229fdd736	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 09:24:22.37879
136f73a4-484a-443c-878f-6d8c04b02060	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 09:24:22.408708
5b859faf-b962-446d-b4c6-358ba02993e9	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 09:24:22.4335
4d961ca5-367d-45e9-b80f-3e74b1e8a588	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 09:24:22.45683
36af81fa-f789-4e4b-b114-2f954175aa40	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 10:58:52.396269
3924ff0e-6464-4317-94e9-f97fb891f09c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 10:58:52.395769
deb6b0e4-ad08-4950-9d7c-edfda81a7fef	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 10:58:52.499006
e291c4e3-9b3a-4339-b57a-c9d0c95069e3	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 10:58:52.504948
35e3502c-5eae-4fa1-b7a4-fcbd0291561f	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:08:51.490789
6563f7da-62b1-49b7-a05e-a471a5ced467	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:08:51.52914
6d318b4d-bf16-47d1-9194-34c2fa0f0d8a	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:08:51.549072
ee168a7c-2778-4073-9876-3d373ef3fee9	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:08:51.571189
43d60fbe-3c94-4a39-917e-3bdb6692268f	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:08:51.592553
cbfb1ac1-5e30-4d36-aec5-b15f6797ef3c	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:08:51.616265
cf37e43a-93fc-44ed-87d9-b7fe947b8d37	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:08:51.644657
feb95b13-b9cd-4e1d-9a44-e9efe2be42bc	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:08:51.677542
c40be15c-9d9b-4331-9ba6-a9e374d86152	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:02.934214
066ef113-3407-43ad-aca8-af4b6fc8442e	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:02.933345
f9a59375-0c3f-4e95-add4-df06c80c7738	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:02.933606
174a2789-e074-4aaa-9f61-9f453c9df5a8	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:02.933988
9217a4fb-793f-4bd7-8057-819d4760b22e	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:02.933794
e6ffef7e-fce1-4985-b859-5b6ef896ab40	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.011649
edb75bbb-0490-4732-bea8-ffcc5c8df129	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.012409
4ab75f34-b5a0-4ced-bc3c-52d59693def6	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.024664
be901789-7d9b-424e-95fa-1ad86b1a2526	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.346831
19880bd8-d9e4-438d-ad0c-bb3eb841bcb8	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.349569
4642a550-1eca-4be4-9d9d-a45ef889989c	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.350167
0dabca64-5733-4b55-9651-96102ea23b42	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.35044
63e25be7-b269-471a-9d63-1ffbc1239845	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.350264
e9e79fc6-5200-4e31-b901-2e5788ad2b2d	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.350617
25c8a4ec-e964-4edf-a6d7-2b837ed095c2	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.410313
7704de7e-d73a-4b58-8f82-455b1e1fd2d0	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.411406
20bf03d9-41f5-4831-905e-e8171882548d	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.791072
9a18fa0f-6902-499f-b4ce-613178d14698	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.791829
fad2a696-c338-441e-8762-9e3b4981c74a	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.791705
1c2bf6a1-c26f-44ee-b7d5-66eb4e520206	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.791944
d0ecc498-cf56-4c69-a836-dd93dce3a3ca	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.792073
cb1a11c3-2965-49e9-bf16-b3e92bb43223	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.792259
bc50cad1-1585-4c41-b4f3-3142c6cc159f	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.834318
8dac7f8e-094c-4b93-b26c-cc9261db5452	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:03.834408
404b21d4-4ef6-4835-837f-b0534f7180a8	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:04.16502
cbff6205-7740-4cbc-adc5-2bcd30528b97	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:04.167087
5d889cf1-3699-4ce4-9b2e-3b302b7ea202	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:04.167293
9d5ccdf7-8708-4f26-9f62-fbfa1de0c2b6	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:04.167499
42aeaa2a-4fd6-40a9-b7aa-57e0ec3c364d	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:04.167766
813a49a0-9a2a-46d3-a184-7e79ba4b34d4	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:04.16795
f93639d9-ac88-420e-9ffb-37a749bd06c5	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:04.222985
10f5345f-e83d-46d2-92d2-d6d8d4a0237f	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:04.223844
1b96becf-a68e-4334-9300-35ae02beeded	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:07.543734
a92eff53-2464-415e-b99a-94a0ea931a96	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:07.54236
f3af06be-e339-4f9d-b4cc-b90956dc62de	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:07.543311
faffd9b3-5244-4704-9318-91efd05f2f4b	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:07.545744
2972af7c-84d5-4a40-a28e-dc80a3e604bf	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:52:21.92054
0d358971-f297-4ba9-8c00-7069fe29a6b9	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:46:35.245054
2c705d08-1bfd-4d14-b484-315421d62076	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:58:01.590897
3686d5d2-f014-499d-ac9a-0d9628c670bf	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:40:19.310211
fcca10cc-84b2-45f0-bd1c-a8fd6e28d814	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:40:19.598776
47311e96-8cb3-4373-901a-da76c6bc0595	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:40:20.220976
df08c369-4ce2-4f47-8aa5-acb602cb5752	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:33.40803
31d21280-6cc0-4cdb-a783-bec8de83ac65	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:33.564454
e2151c13-2226-457d-a74f-494501e33f8f	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:36.697907
e04dfbe3-be2c-401d-aeb4-b8a48c8e5078	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:38.616215
e7904c78-fb51-4ccd-9db1-3a1fd7576b63	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:38.684837
eeb7be94-51df-4c12-b301-29b1845a6686	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:47.380982
14008071-05de-4381-8671-625f050d7c16	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:47.416432
d80ea3bc-796d-49a7-b651-b9f82bcaa84a	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:47.454521
7c529fa7-298c-42cf-b504-c163c6ecbcdb	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:47.498067
3618d10f-b864-4111-a110-21538ead5400	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:27:21.440786
caa3c968-16ca-41ad-b59a-6398a31f5071	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 09:56:26.997742
a82e1f58-ee1c-4548-bd31-07c77508470c	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 09:56:27.13311
9d6b5d35-28c2-496f-a087-05f17d83129a	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 09:56:27.14901
6430fbbd-583b-4fbe-a9c3-7317d0e82a9b	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:07.543504
82fa5b37-d3e6-49c2-9dc2-31e31b677280	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:07.589466
f9f14840-c3a2-4080-b237-b1f19845f156	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:52:21.920696
36b02ff4-990f-4f53-9bdc-0c135b723506	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:52:21.968119
e5c90b15-dd0c-4320-ad8b-15254321fe81	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 08:46:35.520056
cc463197-2006-4f9f-8356-fd7241bf86bf	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 08:46:35.753255
433018e6-f064-41f6-bd57-d6294a9412e2	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 08:46:35.801945
653c4cbd-4b48-45e7-b2b2-4db08b391bbd	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:58:01.595782
46bce580-981a-4660-9900-15d9cae31dca	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:40:19.390826
79392408-7db5-436f-b0f8-423e1aa438f2	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:40:19.591963
72be595d-9741-402b-96b6-899802a88135	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:42:22.035358
9afb2534-f86c-420a-9194-16583d0bca89	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:33.473726
9f9c230e-23b2-49aa-857e-f1a483e58832	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:38.619665
2c54e25a-af5e-4af2-99e5-d5c11fb7a744	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:39.365899
c857b87b-4404-4f8e-a77c-b7611e0e509b	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:27:21.455463
13114fbf-3ae4-478b-9815-13a1cd72a41d	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 09:56:26.997175
df17b182-d7f4-440e-bcb7-a11563bfe793	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 09:56:27.07671
174e73c5-7238-4d25-80b8-fd43159fc731	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:07.590169
24bb6807-aeb9-48a3-a8a6-cf2d7b46581f	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:45:29.883782
ab4b6247-39ae-464e-866c-5c5516e51ad4	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 08:46:35.730473
0dc091cd-9c4f-424b-a67c-bcc2fb162a16	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 08:46:35.77885
5b8807e7-3924-4b7a-8e0f-964518f1fef0	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 08:46:35.824972
b042bea9-d17a-452e-b490-4fd7d1827fab	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 21:58:01.892361
886543de-5fd3-46b1-a0fc-fb28c3398cf6	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 21:58:02.023157
fb0806df-df77-43f4-a8e8-2d94b4aeabdc	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 21:58:02.071169
82242229-a849-41fa-bf1b-9cddd406dbcd	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:40:19.398182
962507cb-749f-462a-80ae-17167584ad68	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:40:19.517786
73a92aa3-32a4-4c59-acf4-699adc5bdf5f	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:40:19.693949
af9fccf0-a2de-4e15-8cb6-44f34c08e0e1	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:42:22.092334
c27b7914-4323-49b8-888f-eadcd367eed8	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:33.480045
2553f46d-bf56-4398-bab0-f8bb653f37cb	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:38.684573
05fb0f69-d0f0-43d8-8553-b06ece23521a	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:39.36572
28398c99-919c-4828-bc6b-7160bdba89e0	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:27:21.856209
fd9bfedd-dd28-4355-95e7-a41d845b3c40	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:27:22.147757
86244efe-59b8-4401-8f91-6318cd360abb	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 09:56:26.998352
df56d628-dbd2-4b0a-afd1-c5a8785681e0	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 09:56:27.110959
6dbebfc4-faf5-43d6-87ae-a4543b0ebe30	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:35:20.993971
ad27b9db-df6e-4d31-82e0-e4f3aa0ba4c1	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:35:21.183985
d382bedb-5754-4cfd-84e5-b2549c9094c0	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:45:29.883466
37da849d-e8cb-4bd1-ad88-b833c2748d4a	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:45:29.963303
7487e335-7d71-4fb4-8b3a-41ac54835867	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:45:30.121519
9b13257f-e4e7-4ef6-ab4f-685db2a86982	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 08:46:35.825123
c640acbc-0a6f-4e44-9ad3-3467a2af9cf2	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 21:58:01.997008
60f15c04-3073-4461-b279-576597f98066	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:40:19.425738
c4680c4d-7c98-4e27-b39c-477da359e8ae	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:40:19.47528
039cd6f0-8d69-4d2d-957b-74578e4db98f	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:42:22.188075
f0b4b34b-ca65-425a-9444-bb72d82f065e	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:33.617275
4fb2045a-6167-44b7-87e2-32b2998d6600	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:36.698376
fd75204e-99a0-4eaf-b965-e196f10f3b74	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:38.620851
1af8c291-8efd-4214-83a5-004a85935f07	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:39.364289
e5c25a07-b105-4eae-b70c-107d2be61a6e	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:12:42.556645
a9035d70-90ff-4747-a597-02cd5a68c84c	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:12:42.936444
e78e254a-324b-4f06-988f-9f53745fa8f9	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:27:22.048728
54c28d2b-eaaa-443a-8603-67953c873412	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:27:22.085369
14e59a28-71a9-439c-8c73-eb046b22fbab	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:27:22.128423
b10c9618-699d-47d7-9199-6cca7949af0b	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 09:56:27.119815
4a66d277-3b22-4080-ba8b-59ffb7debbee	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:35:20.993334
5d45dc3e-8fb1-4300-981b-d6825b6a5e05	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:45:29.944385
e23ad517-ed96-4086-a051-0a30634b9e11	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 08:46:35.825244
13098c50-ecc9-4542-864a-a1c0981d98a0	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 21:58:02.045383
c0712d89-09a1-451a-82f7-2ae232ce08b9	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:40:19.595654
3352a308-d381-49c3-8f78-174307c5da75	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:40:19.693712
49888c19-3afd-4111-9a3d-bd685f847786	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:42:22.190233
3e4f4958-1a8d-4088-a1b4-25c1fe168f24	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:42:22.237245
4e68d008-9766-405c-bca4-15bbe8d47c91	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:42:22.260436
2074ea49-73a5-4e33-b943-b62bed4085f8	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:33.617482
74617b1d-5dd4-4f1c-b69a-ac2e9d14cb4c	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:36.697759
a36b3da7-4d4b-461a-8a2c-4e7a5ba8ca59	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:36.773194
364d3d34-6ce8-450e-a0bf-e17c9b31e02e	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:39.365554
a90fe218-9a7b-445b-b589-2f76479201e8	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:39.424961
52e0fb20-f643-44e3-80c3-1626f83ebe96	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:12:42.558417
7b2d92f3-5ecf-472d-8e59-4f18e2257ec6	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:12:42.871876
ddb47a78-bffd-48a6-b220-b7ae873d7333	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:27:22.053673
9fdcb087-ce3b-4be3-bf09-d83c64295fad	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:27:22.107025
a54ae15d-80be-4fdc-9c7c-05f86cab3362	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:27:22.141749
488b63cd-f8c7-4bbe-90f3-d87a2c708a7b	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 13:58:25.673816
13326b5d-48d7-4f36-95b4-3c09b487b74e	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 13:58:25.674106
4f060744-52c6-4feb-aa54-b1a606e23a77	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 13:58:25.674326
a9a27c94-4ce2-45ba-89da-1f0400c82f23	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 13:58:25.729521
b6929e0e-cd2e-4c5c-9e39-ec51193e0f1e	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 13:58:25.741244
9353d284-e047-4bed-8b28-0cb70fe76937	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 13:58:25.836507
c8532c71-effa-4f1d-bc44-471352e006e2	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 13:58:25.856866
c05d53c1-083c-4862-b8bb-2c03c1830c3c	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 13:58:25.860272
6d6add07-e38e-451c-8d58-1f85ecd771e3	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:35:20.99599
f9f7e490-3540-491b-8377-1ff187a4933e	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:45:29.965316
c6b3f0b2-5408-45be-8a19-32836b256e86	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:45:30.112769
5c519d58-d8ae-4a7a-99cb-97802704b884	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:45:30.156407
6ece7ab0-f885-4dec-81fc-13e2c25cce23	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:51:58.103268
d711241d-2976-411f-9ff3-86c113135fa7	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 21:58:02.049462
6ee127ac-c237-407f-815f-22637bc7e4ae	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 21:58:02.099081
795547c9-14b9-4e95-b2f5-9a7d8b4c07c7	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:40:19.616108
7d23f3be-750c-40f2-9b13-5dfc510a59f7	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:42:22.214272
f0472f85-217b-41ac-8007-54bb2b67382d	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:36.698049
04b539e6-acb1-465a-b31e-e246dd11f94a	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:38.619815
e8ee6259-31d7-43d6-a947-b7298054d2ab	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:12:42.558956
b035d47c-7785-491e-bc40-17927b0317f7	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:12:42.755247
4eb977bb-3e34-4f07-9f54-958debd8b770	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:12:42.821143
258c5ec5-c11b-41ae-bcf9-736afb80a07d	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:50:01.083728
6effdeaf-5651-4900-b585-087dbf329702	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:50:01.272868
2e0363f1-6797-4dd1-9288-0850d27b27e5	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 14:08:10.101261
36f9f8bc-2fed-4dd1-bf5f-e20e4ed3afa0	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:35:21.149416
be44bb6f-b74c-479a-97e5-1a5aa298ff63	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:45:50.327867
b6d12254-1e4c-4c95-89d0-a780a9105204	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:45:50.587597
cb751fd6-d748-42be-b091-844a4ceaac02	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:51:58.103935
2f4bcd50-ad36-44e1-bcf8-e91249755873	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:51:58.188307
e1afde71-d28d-4fb2-a73f-da7fc5b68d37	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 21:58:02.100693
82b6762e-464e-487a-a8bc-ef47409e0bf3	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:42:21.114645
df9d6ff8-086d-4808-a468-2982c47a39ce	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:42:22.227974
68c48b79-25a4-49c7-832f-6846d3bb2f77	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:36.698562
f9a0c2e6-789a-4ddc-8ff4-a7f4ca6670c0	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:38.620042
1c2ef481-5ded-4849-92af-324721462ad5	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:39.370707
f2a30068-95ee-48f8-b669-a3980d4a9ea8	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:12:42.557748
0419e21f-2aff-46ea-85f4-38e2a970eef4	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:12:42.739885
89ecca7b-04e7-46a9-b9a7-2f8fc0c275a0	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:12:42.771141
69680e77-5efd-4826-badd-b4a4469da134	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:12:42.837905
8c9f2749-6ed3-474b-86a7-c83962d55511	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:50:01.08426
2264c073-d7bc-4e1d-87c9-16a99115b5f4	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:50:01.271278
de3a5c8c-6b66-473f-a1d8-6e3f1906b4e4	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 14:08:10.10238
9fb221d9-feee-4586-bd52-243b08bbca5d	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 14:08:10.135276
719896bc-ff76-4a7f-86d1-141b01330531	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 14:08:10.203255
24d2ccc7-0ccd-456f-be04-6c070c57c328	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:35:21.206025
12ad8fe7-42b6-4fe5-aba4-2774872a797e	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:35:21.269984
3f5da134-e160-49c9-b1f2-28784bedb24b	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:45:50.436051
cdcbe10a-3b50-49a6-995d-bf49d0eb7a44	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:51:58.102784
9a33b173-265f-427c-bf25-e9de92411143	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 22:30:31.111173
85afaf60-a07e-45a0-a6f0-497922a0ff7e	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:42:21.114339
c3d3da99-b0a2-403c-ab7f-2709251b1d54	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:41.769629
118689b6-92c2-49e2-8503-e42ffb978fff	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:43.731789
17faa3c8-e5f8-4844-98ef-a8f01d358b27	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:36.710736
00c55da1-d888-4b11-a409-8959434ef4b5	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:47.35579
ed37bf5b-aa9b-4e30-9227-ff4c80ffddec	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:47.397925
fc3f4d3f-3066-41cc-b26d-ddcde42981f6	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:47.434359
36ae444a-001c-474a-8993-4a801dffebec	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:47.476878
afc2ba78-5982-40c1-97cd-1b2d48e53be6	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:12:42.568277
1b9e610a-cadc-44d1-b7da-5e916d32b668	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:12:42.77057
ca751d83-2196-44b6-8822-93c0bda4a5d5	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:50:01.084957
6e01679d-d759-43ef-897d-97189ab2268d	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 14:08:10.169655
b07d592a-7337-43fb-891f-55c83b445348	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 14:08:10.232494
5ca8993c-1643-4d80-b76d-37a7fe2840de	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 14:08:10.290774
10f3c4b0-347c-4de3-9f19-900a12393f7c	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:35:21.283649
40f545ac-9999-4ca0-86cc-5aacc01283b1	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:45:50.436768
0bbb9503-ad44-4892-886e-88739a5e14fe	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:51:58.103622
91063b90-3bb1-4b7e-9c49-5b20515f35e8	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:51:58.247368
4e4af955-bda3-46ae-bab7-cdb6acc25e83	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 22:30:31.110729
753fcc11-b5f4-4473-80e6-c2d7a74460b0	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 22:30:31.243889
0f24e3bc-b68d-43c5-a901-7a4f15568a2a	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:42:21.222841
507b64da-7b38-4e5c-8e08-88cc75479e9a	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:42:21.247334
ea55e704-e14a-4702-8081-ccbf8bdcb7b8	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:42:21.279637
5b65c472-0ff6-45f4-b61e-e1dedf993c2a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:41.770216
e40e82aa-a752-4fc5-b79e-fa3386d26b97	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:41.975038
20534af0-e026-4757-8f0e-ccca5126dfad	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:43.735748
2f6d20ce-58f0-4a08-a11e-9ed9ce3f99d9	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:43.824075
d93b683d-5cc0-4e82-a5b0-99791f79964a	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:44.70797
e425220c-878e-4549-b4d5-fbf9055c979c	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:36.771582
c3055673-d175-4818-93a9-154931e5f88d	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:39.366309
09ced9d8-0942-485e-a561-c8499a70280c	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:12:42.867671
17a90590-215d-4852-8319-f3b730d6ec59	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:50:01.232405
3bb11563-6b4e-4c3e-8518-d4fadf2cdf77	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 14:08:10.257514
a0b7afd5-f58f-4010-a1b0-2a379a467d1c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:47:27.478161
f0306524-f048-43f6-884c-78bd86fcad95	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:47:27.687108
6aaaeb1a-3665-4917-a788-15c543068525	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:45:50.444085
4d296465-22cb-4bce-8b1b-3e7988840af1	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:51:58.248545
e9d85c38-0ad1-4835-accf-3282819da974	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 22:30:31.111023
62a719cb-33d8-45e4-b0de-2715f4b2018d	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 22:30:31.210712
f781c729-85b3-4f33-b219-cf21cb02ca41	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 22:30:31.257623
c69fe89e-6f16-4626-a2ee-d731cbaf943b	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:42:21.235393
f3fe5405-43f3-4c0d-84ec-79bf524b85c6	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:42:21.258105
f4c74ade-e6cc-4ec6-ade7-03cb22b6007b	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:42:21.268176
22186336-9726-4bec-9e2d-75dd761792e1	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:41.89809
884d67d0-4902-44cc-b234-18964719e211	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:41.923245
125f55b0-b66d-430c-9975-e384e907fee6	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:41.95395
3f5578a7-136f-40ee-88a4-c1c016a503c2	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:43.746909
291a1f8c-ac2d-47ff-859e-ea08bb58b820	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:43.809193
151b8414-3313-4575-bda2-64ef081aa105	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:44.714723
35113fef-034a-4bac-b90a-9578d3dd66b5	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:05:07.992525
92ddc8a9-d0ea-4ac1-ba9b-1a17139392ce	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:05:08.216342
125286f0-4a47-4c83-b891-e5d68c8c5168	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:05:08.247489
2afd15fb-8eee-4f41-863a-cdd390cde318	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 11:21:25.422685
0e10dd77-c914-486f-a286-7d4c2500fcbb	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:12:42.921152
b9b47588-3f6d-4821-9f76-b707a1919ff4	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:50:01.232087
8a8ce758-03ea-422c-b49f-1b7cc3d46103	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 14:13:46.543106
6436de9c-ffde-4939-bddd-b239f5e690d2	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:47:27.664358
76d713bd-2560-41d8-8952-383fd5a8c9ff	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:45:50.462661
291ada5c-50ef-43b5-b179-1b1da0567f96	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:45:50.569547
06c67270-ddae-4fb9-8668-21d9237e6085	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:51:58.246992
15ba934d-d8df-4922-913e-2989d27a481c	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 22:30:31.165488
cd2bdd66-70bd-4a5c-a572-d5a2b5ddf374	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:31:45.017269
2b8be32e-9e69-4e43-a1d3-d094d2d75b20	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:41.938476
ecaa39b6-ed68-4ebf-b557-88da5471f997	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 11:21:25.422856
5f630d08-e3e9-40a4-92e5-2510e7ae2df6	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 11:21:25.614
c235fdde-6b3d-4c69-afdb-7e72a0588fbd	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:12:42.935294
313bed44-c4c4-4594-bd3e-6e4241633285	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:50:01.273158
ab8f419f-4e4d-4102-a96b-57a63ffc33aa	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 14:13:46.684156
267edadd-5981-48c6-a526-a33fe524d30e	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:47:27.687221
63f3ab76-20bb-4048-ad22-a060dc02f3c9	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:47:27.717949
6cb967e1-1805-4634-800a-96d7d1d88977	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:45:50.568076
51f1354a-1a05-4438-ac56-542cf55896d4	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:56:38.767406
f54436a3-c9e6-4056-b096-739651f42160	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:56:38.892108
b75f7f6d-ccb4-4627-a7e4-e1c280099392	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 22:30:31.268666
954d6713-c3ae-49da-a9b3-e9aec803bf2c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:31:45.016869
cd9fabfd-e19c-4598-aed3-86b9493c41e8	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:31:45.137442
295b43e6-f2aa-4a02-a8d5-3ea68611c3ea	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:41.973644
c2c52091-f81e-4b25-aa65-5115a6ecff0d	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 11:21:25.605558
61663ef1-f459-4b6e-94f3-538d7bef8c61	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 11:21:25.67533
0836e633-ed0f-4dbc-8735-ea884e403695	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:25:00.010474
bff97769-7a75-4710-9de7-f2eb1b75314f	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:25:00.226598
1c90d6ef-3f0d-4500-83dc-f7ef1d6624f4	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:59:26.335307
3e43128a-7c95-4f4e-8c59-bedbf2aecd7c	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 14:13:46.763352
4f7f1e14-e0fa-453b-9ae7-28c5404d26e4	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:47:27.687366
00e1cacc-b70d-41cd-a0cd-3f00b53e4c0f	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:47:27.73941
71bce4c9-8949-4c0c-b75b-a8914b2cf08f	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:46:29.515496
02367ca3-8bd8-4723-9f18-5fbded7f5662	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:46:29.648164
731500bb-53a6-4bd1-9738-28083c105745	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:46:29.842862
8a431337-a5b5-4f90-baab-af4ba1cf2a58	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:56:38.767266
22343c4d-1034-463c-aa2e-507fdce02178	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:56:38.822196
a98f3a30-8e75-4693-b4c9-076a2674e6ea	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:56:38.948462
3962b569-7ab8-4dd1-9d81-57f7fb206e47	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:37:21.916719
2d33701e-990d-4e22-8343-eb2465f436ba	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:37:22.08743
b542d810-e534-47af-a011-b246f3ccab9d	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:31:45.086793
1d4ef8b2-f560-404f-8379-d395c21482de	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:43.732198
1f8affba-867f-4a5e-b63f-4368443a4b97	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:44.702171
6dc664ce-f777-49d9-8598-ee2b2b1fe6cc	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 11:21:25.605722
04457642-658d-4a12-9480-1004289f9f81	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 11:21:25.670483
cd45ac91-e8dd-43eb-9ab9-55caaffa8e04	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 11:21:25.689857
3feae1bb-d7c5-43fc-99cb-4dd3286d70a4	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:25:00.157958
8f190217-ac3a-47cb-ab36-7e9b57917d83	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:25:00.301649
36ac78bf-ea46-49cb-ae97-bcd5d2ab23ae	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:59:26.335545
ce3b3ad0-9fc7-4277-8305-4ce16fd7107e	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:59:26.694712
ee95f277-1c4b-4568-829c-e199488709ab	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:59:26.77892
0c3eb375-511d-4ed7-bcd3-d32349f60edd	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 14:13:46.763741
c6d9fe8a-cb87-49ab-ba21-cd6a5f04935a	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 14:13:46.79648
c390631f-2ca6-4e0f-9e8c-551dd5a89c97	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:47:27.729841
03b76275-1330-4222-8a8f-5a014cc6c972	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:46:29.515068
20988136-e46b-49dc-802a-f418649ad45d	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:46:29.648561
dc25f29e-99ee-4267-a0da-799eae04f6ad	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:46:29.73813
fc649af7-3f45-443a-be25-013fd5d5a09a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:56:38.766989
c5fb4b6f-5be9-4090-a707-1edfc8b75307	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:37:21.964302
fee5bbe4-8f8a-4bec-8daf-b0e8718d87a9	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:37:22.08757
01fa8c20-2aab-4079-9010-57b18171ec24	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:31:45.215869
9e3ef865-10b4-46aa-b49b-37fd46ff458e	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:31:45.246094
500892dc-46d9-4df7-a4fc-217f99fa9f0c	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:31:45.267773
ab7252dd-1f5a-4629-9d85-b21276ecabf6	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:43.73548
20242b68-2130-493a-b75f-cab2865ab803	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:44.756904
9027aabb-a8ec-4578-a9a9-2b919edac98e	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:25:00.220503
a9911485-fc1a-4e64-be7e-074da1ef4276	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:25:00.270326
a77ba360-78bc-4ace-ae2f-358ec6a8ac13	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:59:26.336222
beda3382-d891-45cf-b5a6-ab08662069c2	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:59:26.505722
69b48a73-d505-4f9e-86c8-342a713d912a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:59:26.692679
f52958c7-d2a1-448c-8c32-0b9d5b3eb5b0	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 14:13:46.764075
d48cdf38-d1c3-4926-b89f-b9d4fe52d914	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 14:13:46.821763
059bc4da-6835-44e6-b889-fed296b86695	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:52:16.815676
0a21da53-f773-4119-8410-403a419ce647	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:52:16.995475
881c6cf2-c49a-4082-9e7d-5f8ac02e1a17	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:52:17.099979
b968bd68-befe-4814-aa15-6aab6046b278	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:46:29.842502
b4d0f832-72b1-42e8-815e-3cd65d387d33	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:46:35.362761
67ef9034-619d-4ac6-8a1b-aa6f8b8432cd	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:56:38.947666
bbdfb5f3-cffb-4c55-809a-0df988ee7cb9	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:37:21.997165
286f7472-9c35-4b48-9185-edc5dc383826	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:31:45.270255
c1defebc-7c42-40e2-93c5-3e2544c47b7a	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:43.736848
79aa93ff-2a82-4e77-b1c0-7f4b3e05f0e1	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:44.701621
8ef601c3-b8db-4ae8-a8fb-75ab14d54caa	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:44.756676
9891621c-232d-4631-8e8f-37e908f1c267	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:25:00.220926
5415b367-d1cd-479a-ac93-22cb8eefc4fd	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:59:26.336434
5ad08a75-6b06-42ed-84e1-5b9b540f92fb	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:59:26.52256
cefb2cdf-4b76-427e-a5db-56e867d0857e	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:59:26.776777
41e9c463-2360-46ef-b2bd-ff7255c6d67d	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 14:13:46.868626
6dc124dc-5cac-4a5f-aa7d-231f73c424e9	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:52:16.977649
cb0e8bfc-4e29-4a66-b0f1-0eaf95b171f5	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:52:21.922861
b44990ba-a5fb-4dda-b425-7c39a920628f	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:46:29.843521
3615f398-873f-44dc-b0f7-fde6b80e81f9	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:46:35.232317
323d4481-6438-4379-896f-0e9010f424f5	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:56:38.967392
1b730255-7f98-4b38-9096-a07701aa5e82	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:37:22.063
52a1c6bf-d94d-4c1a-9653-0b879926eb76	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:40:20.046429
ae382815-d78e-40cd-b3ff-5f6588e41efe	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:40:20.202349
b120c6fe-a29c-401e-b7cf-daad6f42e00a	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:44.699073
7713ff68-fc5a-476d-9d7a-298d7d9ce12f	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:04:44.700286
74881ce4-65a1-43e1-bc44-a3f178c48fd5	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:25:00.286435
a69b746d-0d5f-4974-8d4d-300b10683eab	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:59:26.33578
485e94e7-0add-4d24-9431-3495f08bb892	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:52:16.994874
d272a446-327e-4d82-a6a7-5bd471f366da	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:52:21.922724
4eff6eef-b5e3-4dc3-9acd-5d3bec06dc8f	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:46:35.228231
e6fa74a2-0619-48ab-9384-938223890009	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:58:01.317396
f12cd259-47ab-4c45-a408-97361353992c	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:37:22.083411
0203b499-3933-4d53-9aa1-d41e3422d9d3	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:40:20.09317
6d3ae3dd-c8b4-4b4c-a997-30808c9b46e6	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:05:08.191825
8c73e770-7705-4e85-bf23-95333f3d3783	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:05:08.253425
a9c4f9f3-7972-483d-9b2a-214a33478306	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:05:08.275957
73b9623c-0d22-46c5-af82-b97fbd00c2f5	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:27:21.245906
b0a4df1d-b737-4aec-9617-0527c9aca338	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:27:21.375471
aac400cc-f98a-4077-a64d-dd8f09468de3	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:59:26.335995
4cdcf8df-59fe-447d-9d63-f4165c583eb4	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:59:26.724849
c0c1f6f0-8f79-47bd-9e1f-cd34704b91b8	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:52:17.080381
f4e9df60-d37a-4e84-8cb9-6d79bbe4005a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:46:35.233857
dfbbd644-b9ee-47de-ba94-76024ac9800d	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:58:01.309061
d3787081-d153-4555-963f-e8fe11f5d291	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:58:01.636111
f68aa3f6-c287-428e-b3d3-7f442f273c58	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:37:22.119704
ec5500f8-1774-4a7a-a89d-e0b3b8fa57e4	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:40:20.173164
f8d0701d-faa4-4157-8638-85b9f1142f4e	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:40:20.225821
7596cffd-e431-4d0a-9ebd-e873a3994c7c	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:05:08.216505
70bc5c70-fab7-470a-b70b-2ef8c0222bb3	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:27:21.245689
4a070de7-f789-4b73-a8f8-02efd42c09ff	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:27:21.418426
4ae3ecb8-ec05-491d-8a7c-36b1090a5258	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:59:26.689069
01ea8972-bc7c-4919-b9ac-94b2d536f435	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:52:17.100341
51774e5f-2f13-42f0-ab73-0af5d6567d2c	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:52:21.922992
cf22cad1-33af-4ccf-bf29-436fe02e0f74	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:46:35.234206
9a62cd6e-35ac-4531-af55-9f8cde506e7e	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:46:35.361285
402a73ae-7db5-4ed6-8147-91884e90b3d5	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:58:01.475899
d8f2499d-edf9-4503-a714-83c840415671	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:40:19.273435
86ca44b9-4781-4db7-9eb9-5b03eeb47950	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:40:19.597117
866afd31-7ac8-4841-872c-283aad737d5c	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:40:20.198349
eb1f0f4e-0857-4b85-a175-8993d0b9199a	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:05:08.24783
36d865b5-6137-4bd6-bc0f-0b22b53485b2	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:27:21.325825
d231d788-df83-472b-b9df-0dd6e6ee7c12	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:59:26.696566
017cf8d0-871a-4847-98c9-452ef86dfda7	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:52:17.11594
24948d08-b687-4845-b642-baf559d71c03	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:52:21.923134
7762b2d6-98f9-4e65-bc07-c69dd2993f24	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 14:52:21.967197
3166d20d-8209-42b0-9a61-786c2f6e8cb5	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-25 07:46:35.235328
0f9f201d-4e24-43d1-9096-1eceb3b75499	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:58:01.500006
0eaecdf2-f640-475f-aaf8-f65679325933	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-30 20:58:01.596095
30f9145f-1213-47fd-86c7-3c63067d1ec1	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:40:19.276424
b0eb3a8d-9d90-4c21-8517-99dde6d631e4	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 07:40:19.618377
c40b2f4d-5d7c-4a62-ac89-eaa14899d9a8	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 08:40:20.219358
77c94cf9-d876-4086-b7f8-7f59be051b4e	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:33.4083
91967214-4c9b-467c-becb-8ba24d546736	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:33.601412
4fae8e1c-a2b6-415a-9a5e-f0762c7d4c18	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:38.617642
2bdd08bd-1aea-4842-bf32-97cd9a593b4e	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-01 09:07:39.424668
4e238b9d-33d8-4f15-b925-ad19bbc2711f	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 07:27:21.420164
a2d56500-a282-40e5-968e-4ca0f850cdb6	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-12-03 08:59:26.703541
4d02d0b6-1110-428f-be26-db92199c5e9c	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	pending	pending	تم رفع الشكوى للإداره	2025-11-24 11:09:07.54207
\.


--
-- TOC entry 3659 (class 0 OID 26000)
-- Dependencies: 247
-- Data for Name: complaint_messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.complaint_messages (id, complaint_id, sender_id, sender_role, body, created_at) FROM stdin;
484e1735-738a-4788-8420-256559487a9f	c4d5fc4f-4a8a-47bd-98f1-69cc2a546b82	ad4800fd-c13f-4d2a-8558-cae29f052ea0	employee	ok on va essayer de regler ca	2025-11-19 07:29:30.956677
630e82b4-294d-472b-8020-8e50379e8de9	c4d5fc4f-4a8a-47bd-98f1-69cc2a546b82	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	director	dcr merci pour votre comprehension	2025-11-19 07:33:02.670536
f7dfa2cf-0f69-4b00-93e5-bafbda9b5100	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	director	تم استلام شكواك وجاري دراستها.	2025-11-19 08:46:59.621723
9f5d8418-50f1-48e6-8110-55cf0fb9bee9	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	director	تم حل الشكوى بنجاح.	2025-11-19 08:48:03.453506
ed6c1fb3-665a-4dcd-84dd-63a04e771572	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	employee	merci	2025-11-19 08:48:31.289367
c0fc91e8-621c-4af4-9219-fd82a3e01a89	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	director	نحتاج إلى بعض المعلومات الإضافية:	2025-11-19 09:06:02.539898
29af36a2-33e9-4b89-b5a9-1c224f23bdcc	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	employee	vite	2025-11-19 09:42:28.274755
bc386a0e-8ba8-42ad-9017-274da4f2b581	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	employee	dfr	2025-11-19 09:54:18.886627
1021198f-4903-44f1-bd5b-c8a1f4f1323e	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	employee	cv	2025-11-19 09:57:21.110404
964b0006-b66b-40c6-8bb7-27f13b52f3ff	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	director	تم استلام شكواك وجاري دراستها.	2025-11-19 09:58:45.604068
294d72f3-72ab-4fba-ac0e-9ec38a456c75	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	employee	merci	2025-11-19 09:59:00.962996
78772d6f-9396-43d3-b166-0f02279c79ee	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	director	الشكاية قيد المعالجة حالياً.	2025-11-19 10:28:18.29852
\.


--
-- TOC entry 3661 (class 0 OID 26041)
-- Dependencies: 249
-- Data for Name: complaint_notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.complaint_notifications (id, complaint_id, recipient_id, message, is_read, created_at, title, recipient_user_id) FROM stdin;
6b0d6469-e175-4416-bd11-24d81e10e16e	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم إضافة رد على شكواك	t	2025-11-19 08:46:59.630427	\N	\N
70e5624c-55a3-4ff0-9df9-e68edb06d53a	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 08:06:39.563072	h	79f034a9-ee01-4de2-9238-549e53bb794f
7371ed93-9396-48ff-9892-8606dd87498a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم إضافة رد على شكواك	t	2025-11-19 08:48:03.456719	\N	\N
cdbe01fa-692f-4404-b0da-7b17689be2ad	b62f5fa1-09db-40a6-8400-0634b50cd353	5a1ab543-b2e1-445e-942d-d6ec24a576e5	تم تسجيل شكوى جديدة في قسمك	f	2025-11-19 09:04:51.403899	\N	\N
4399f48f-3b65-426b-b41d-3a424032e0c7	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 08:06:39.594193	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
9694e99e-b608-417c-942e-14ff70a3cfd2	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم إضافة رد على شكواك	t	2025-11-19 09:06:02.542991	\N	\N
b1de137a-a063-456b-afe6-db40c2c0533f	fbdb5520-2835-4248-9437-6ea25d444ac0	5a1ab543-b2e1-445e-942d-d6ec24a576e5	تم تسجيل شكوى جديدة في قسمك	f	2025-11-19 09:20:35.081216	\N	\N
6fb444da-cc21-4c6c-aa2d-1ae300142ecb	fbdb5520-2835-4248-9437-6ea25d444ac0	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم إغلاق شكواك	t	2025-11-19 09:20:45.966132	\N	\N
e9dc5196-33a1-4412-991a-12762c09c49e	a24dec61-f216-41a0-a83f-a33b91b7bab2	5a1ab543-b2e1-445e-942d-d6ec24a576e5	تم تسجيل شكوى جديدة في قسمك: b	f	2025-11-19 09:41:36.35899	\N	\N
9c7435f3-13d5-4697-b1af-40ed00387a4f	968ee93f-09a9-4ef0-9aba-47dd64d86171	5a1ab543-b2e1-445e-942d-d6ec24a576e5	تم تسجيل شكوى جديدة في قسمك: m	f	2025-11-19 09:52:31.72643	\N	\N
ffc99b2c-1a6f-4be0-a349-fc779a8cda71	e0cc3812-3bce-4bc2-b707-196538470f83	5a1ab543-b2e1-445e-942d-d6ec24a576e5	تم تسجيل شكوى جديدة في قسمك: d	f	2025-11-19 09:53:06.185768	\N	\N
4acbf1ee-95d8-4054-9613-6b1860b45358	f19fd934-c68d-470a-a9d6-7730c118bc06	5a1ab543-b2e1-445e-942d-d6ec24a576e5	تم تسجيل شكوى جديدة في قسمك: nj	f	2025-11-19 09:56:50.337161	\N	\N
a0ba7dcf-a822-4687-9595-a5883daef1a2	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 08:06:39.9177	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
c3c408c3-3ebe-4dc7-9bff-ee5933d959ab	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	رد جديد من المدير على: nj	t	2025-11-19 09:58:45.608855	nj	\N
16213513-1acd-45f3-9506-b4202b95ae26	51e290ec-f087-4eb4-b670-92b03e7c3147	5a1ab543-b2e1-445e-942d-d6ec24a576e5	تم تسجيل شكوى جديدة في قسمك: g	f	2025-11-19 10:19:13.759543	\N	8674a215-f103-4559-8f96-c55514a50e40
44026a60-4136-4357-9029-72f6b8f1ac76	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	📥 شكوى جديدة: g	f	2025-11-19 10:19:13.921576	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
30a42bed-d3f2-4bdc-a896-d46953f66b7b	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 08:06:39.964627	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
5963ad76-adfd-4a15-a4f9-53bb53ebf65d	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	📥 شكوى جديدة: g	t	2025-11-19 10:19:13.937585	g	79f034a9-ee01-4de2-9238-549e53bb794f
59f1abb1-79dd-4f9b-bd8d-c7843d039fa9	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 08:06:39.991206	nj	79f034a9-ee01-4de2-9238-549e53bb794f
238cd686-a0fc-4312-aa53-e2cc3d8b29e9	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	💬 المدير أضاف رداً على: g	f	2025-11-19 10:28:18.381212	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
8f181cd2-c72b-4942-8099-fcf470fdce92	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	💬 المدير أضاف رداً على: g	t	2025-11-19 10:28:18.396918	g	79f034a9-ee01-4de2-9238-549e53bb794f
7527cd25-e577-4924-ad7b-1c6e731c07d7	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	رد جديد من المدير على: g	t	2025-11-19 10:28:18.31143	g	36133c39-09fc-41b6-93f8-590a2eae35d1
f10e58b4-da23-46cf-884e-5d3d1c485d33	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-11-24 08:06:39.632778	d	36133c39-09fc-41b6-93f8-590a2eae35d1
180525df-7489-4036-b0cc-ff47d3d310f2	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-11-24 08:06:39.417293	n	36133c39-09fc-41b6-93f8-590a2eae35d1
8a6b1c6c-3bb9-4e83-9eb8-33191a108c71	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 07:27:26.344305	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
d61c2122-a0de-4efe-b572-32a74ceb7bea	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 07:27:26.367928	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
c22d1fb4-5667-4575-a4ed-2faf761df942	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 07:27:26.459151	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
0ccf71bc-e4b6-44c3-a11b-03b9aadf6b92	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 07:27:26.475998	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
d7f10d02-89ed-4e59-9bbc-0461682204d5	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 07:27:26.554822	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
6bf49de3-bc62-48f7-b184-e69e861b4c47	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 07:27:26.618266	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
ee58113d-b4d0-4558-bc71-4bc4cefbb8bc	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 07:27:26.650545	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
418846f7-f872-4e63-84c9-40bdc1886171	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 07:27:26.661908	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
d78f8818-23d4-48a3-afc9-b4c69da2bb0d	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-11-24 07:27:26.645514	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
984b14ee-85ac-43b8-8295-074814bba554	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-11-24 07:27:26.605364	g	36133c39-09fc-41b6-93f8-590a2eae35d1
e3cc676b-0670-4461-8ea3-a142a14336bb	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-11-24 07:27:26.301323	n	36133c39-09fc-41b6-93f8-590a2eae35d1
69408402-f6f9-4790-ab71-01f8d57bf330	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-11-24 07:27:26.298918	b	36133c39-09fc-41b6-93f8-590a2eae35d1
712db310-6319-4b90-a85f-c2369ec66d9a	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-11-24 07:27:26.297538	t	36133c39-09fc-41b6-93f8-590a2eae35d1
a61777be-705a-4516-9e39-181cd75774ca	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-11-24 07:27:26.295902	m	36133c39-09fc-41b6-93f8-590a2eae35d1
12ff67df-4d69-47cf-8eab-5fcb883c7046	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-11-24 07:27:26.292584	h	36133c39-09fc-41b6-93f8-590a2eae35d1
5e1559c0-be37-4b3f-930f-e4ebd06627ee	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-11-24 07:27:26.472733	d	36133c39-09fc-41b6-93f8-590a2eae35d1
fc70ad62-04a4-4ae4-9ca4-143e62c8c7c3	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	t	2025-11-24 07:27:26.727841	nj	79f034a9-ee01-4de2-9238-549e53bb794f
7d08818c-c750-4964-b650-f8f6403b2dc2	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	t	2025-11-24 07:27:26.555809	h	79f034a9-ee01-4de2-9238-549e53bb794f
c8a49704-0c28-49d5-a0d5-e4f336b215eb	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	t	2025-11-24 07:27:26.378144	t	79f034a9-ee01-4de2-9238-549e53bb794f
e8ad3e67-2ba3-43a0-9805-d95193c5e554	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	t	2025-11-24 07:27:26.347939	b	79f034a9-ee01-4de2-9238-549e53bb794f
e1d8644a-d873-4375-ab8f-ebdf4584cee0	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	t	2025-11-24 07:27:26.69336	g	79f034a9-ee01-4de2-9238-549e53bb794f
64b06f86-ed95-4bae-85bb-c5b13fcdbacd	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	t	2025-11-24 07:27:26.517036	d	79f034a9-ee01-4de2-9238-549e53bb794f
a65f2684-3faf-4abf-915b-f4c6383f60dc	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	t	2025-11-24 07:27:26.480112	n	79f034a9-ee01-4de2-9238-549e53bb794f
c1024e0c-bbbc-45f6-8e84-4870e1ba4154	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	t	2025-11-24 07:27:26.450657	m	79f034a9-ee01-4de2-9238-549e53bb794f
88aae1b0-270e-475a-975d-ec81ea40ec27	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 07:58:20.270219	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
8beb006e-420c-4403-ba1a-6df293ae9259	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-11-24 07:58:20.317486	t	36133c39-09fc-41b6-93f8-590a2eae35d1
0b47aa74-f5ac-4678-912c-682850693ff0	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-11-24 07:58:20.172671	h	36133c39-09fc-41b6-93f8-590a2eae35d1
ae7dc099-bf1a-4257-a5b5-a267649946e9	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-11-24 07:58:20.164505	n	36133c39-09fc-41b6-93f8-590a2eae35d1
aec33416-5248-4805-a78a-d31841dec7c9	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	t	2025-11-24 07:58:20.290631	n	79f034a9-ee01-4de2-9238-549e53bb794f
f6c34100-a294-4644-b3ff-4f837f1c6cca	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 07:58:20.315527	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
59f1e7b8-8bbe-4f4d-906e-21ca62cccb83	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:05:08.000811	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
1fd86282-2b68-464e-b6f6-09e81886e3df	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 07:58:20.393396	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
c839b4d7-2674-4d97-b0ba-c67abf6fac20	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	t	2025-11-24 07:58:20.34109	h	79f034a9-ee01-4de2-9238-549e53bb794f
79110dc4-096c-4fc5-b5c7-a80167bc26eb	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 08:06:39.905374	d	79f034a9-ee01-4de2-9238-549e53bb794f
9337a036-f47d-4863-a34d-2a4613170d9e	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 08:06:39.99393	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
087af75d-8ae1-42cc-8a11-d3a89a440db8	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 08:06:42.515157	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
e64867a7-da2f-44e7-bf0f-6736e6866efe	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 08:06:42.552566	b	79f034a9-ee01-4de2-9238-549e53bb794f
577acf81-89dc-4fed-b134-7a3bf104ccc2	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 08:06:42.626078	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
075bd28a-9758-4086-82c5-ebb9820d9953	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 08:06:42.671772	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
4c613d2d-fe35-44ed-89dd-a82e7c123f56	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 08:06:42.687114	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
4193337f-0429-4b80-81dd-fcc430ecf5f8	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 08:06:42.766824	nj	79f034a9-ee01-4de2-9238-549e53bb794f
1c265f06-a61c-484d-88e7-cce7ebec0c1a	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 08:06:42.840557	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
0dea100e-d150-4df4-8050-3c48e55a75d2	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 08:31:54.625972	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
1c9c18df-80db-4ae8-a3f7-da853d7cbda6	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 08:31:54.788966	g	79f034a9-ee01-4de2-9238-549e53bb794f
4896a8f0-e610-4f02-9d10-ac7948fd9f52	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 08:31:54.835208	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
ddd66d50-9b31-49e2-86b5-0caa18b01ae3	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 08:31:54.838979	t	79f034a9-ee01-4de2-9238-549e53bb794f
5ed85420-0fce-4a1e-8bec-e0244b0b2dca	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 08:31:54.9392	nj	79f034a9-ee01-4de2-9238-549e53bb794f
6fc29061-fc35-46d0-8a9e-7339ad916ff8	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 08:31:54.974168	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
02840f2b-568e-4c2c-9465-1826f2cf0252	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 08:31:54.998114	b	79f034a9-ee01-4de2-9238-549e53bb794f
f3803921-4771-4477-8af7-89123e43600c	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 09:24:22.223272	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
7bab11e3-cdaf-4472-a44d-2265ae5a58da	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 09:24:22.337779	h	79f034a9-ee01-4de2-9238-549e53bb794f
151e0783-4a7c-4575-a10e-c8d9a2844d04	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 09:24:22.360634	n	79f034a9-ee01-4de2-9238-549e53bb794f
57516d45-d407-4009-b4b8-73ca69428b30	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 09:24:22.398995	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
277acab9-7eae-44f3-b5c0-54880f7e508e	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 09:24:22.404344	m	e6a73462-6516-415b-b188-7352267c17e7
31f4fed9-61fe-42dd-aa0c-cad2dd6f9c82	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 09:24:22.422754	t	e6a73462-6516-415b-b188-7352267c17e7
d112ee4a-7a3f-485c-bf9e-8e88a7eda416	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 09:24:22.424831	t	79f034a9-ee01-4de2-9238-549e53bb794f
2da75866-6af2-4a4a-ad83-a40cbcf50ab5	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 09:24:22.435838	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
fbe4e73e-843f-4ac2-9b53-980770a3629d	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 09:24:22.441862	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
52aa6972-e021-4920-8f3f-9c4efc0c6c05	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 09:24:22.443809	d	e6a73462-6516-415b-b188-7352267c17e7
76c17455-992b-484b-a9b8-9d1571e0d7d9	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 09:24:22.473475	nj	e6a73462-6516-415b-b188-7352267c17e7
066f60b0-223e-4407-af52-77184032eecd	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 09:24:22.47608	nj	79f034a9-ee01-4de2-9238-549e53bb794f
41d48ddb-792d-4243-9770-7fc297d2e07b	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 09:24:22.480084	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
4e8bd50b-126e-4d08-9406-e31a480c3de1	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 09:24:22.487049	g	e6a73462-6516-415b-b188-7352267c17e7
3c1e9d9d-ec8f-460d-be29-1b800a1d2e98	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 10:58:52.484381	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c6e9e426-bb5b-4fb9-9c0b-2e1a0d96d18c	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 10:58:52.587042	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
5426bf41-2dcb-46f1-8486-cec3a1d34a34	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 10:58:52.597968	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
5a9a8c22-f8e1-421d-9b83-be34c089b519	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 10:58:52.603754	b	79f034a9-ee01-4de2-9238-549e53bb794f
7a0f3e3e-6123-44f3-8d0f-ee2ec350e51e	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 10:58:52.630876	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
c9ad4b58-54d7-48eb-8e48-91820d630419	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 10:58:52.706334	n	e6a73462-6516-415b-b188-7352267c17e7
c82d5503-bbd5-4dd7-9243-d511af470607	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 10:58:52.696631	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
8a4280a6-9187-4ea9-8412-481c24b45c4c	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 10:58:52.749016	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
f79a0da0-f64b-48e2-ad62-67074f073e48	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-11-24 10:58:52.567098	b	36133c39-09fc-41b6-93f8-590a2eae35d1
b0c4f193-cb85-409e-bea1-3a78424c30a4	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-11-24 10:58:52.440883	n	36133c39-09fc-41b6-93f8-590a2eae35d1
d838442b-ec0a-4eb8-b464-de1ff8a3a8e2	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-11-24 09:24:22.46194	g	36133c39-09fc-41b6-93f8-590a2eae35d1
d91274f8-e039-4f83-b01e-c53a2c81cadf	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-11-24 09:24:22.426988	d	36133c39-09fc-41b6-93f8-590a2eae35d1
ed6a5bba-c6f3-448a-beee-d8b83f1ac934	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-11-24 09:24:22.388247	m	36133c39-09fc-41b6-93f8-590a2eae35d1
093ba12a-e1af-4c82-8d2b-0bd8d1f85459	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-11-24 09:24:22.211597	n	36133c39-09fc-41b6-93f8-590a2eae35d1
4829e572-f4c2-42f1-9a73-5742280ae340	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-11-24 08:31:54.895619	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
6bf3f95f-97c1-4c0a-9919-84a0a1f4a438	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-11-24 08:31:54.481266	n	36133c39-09fc-41b6-93f8-590a2eae35d1
221d1e6b-5f98-46b0-a294-b280bb4ca776	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-11-24 08:06:42.750643	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
11d77a7b-7781-4285-89b5-6bff292ac8cf	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-11-24 08:06:42.451985	t	36133c39-09fc-41b6-93f8-590a2eae35d1
60ad4462-56d1-4359-8f54-a5fe9fb3dc58	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-11-24 08:06:42.445563	n	36133c39-09fc-41b6-93f8-590a2eae35d1
ecf3790c-b68f-4f39-bd2f-5e26a76f11ce	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-11-24 08:06:39.72474	b	36133c39-09fc-41b6-93f8-590a2eae35d1
2406944e-6af0-4482-847b-f79ca92aa5cc	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-11-24 08:06:39.42755	h	36133c39-09fc-41b6-93f8-590a2eae35d1
f38f294e-32f1-449c-9b91-25b5e67f459a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 08:06:39.537344	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
877d0b6c-b341-401f-8143-0046aded4ec2	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 08:06:39.596745	t	79f034a9-ee01-4de2-9238-549e53bb794f
f9909c67-bbd4-4cff-8dd7-1d1e8ae3a1fc	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 07:58:20.441782	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
eae6f758-5e62-4fc4-9521-837a37041530	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 07:58:20.460648	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
7f93d574-67e9-477f-864e-dd40516a0fc4	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:05:08.05213	h	e6a73462-6516-415b-b188-7352267c17e7
70817644-f5ce-40d3-b2ff-94b2efd9a44f	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 08:06:39.776955	b	79f034a9-ee01-4de2-9238-549e53bb794f
718f6009-702c-42fd-9ee2-37a061266547	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-11-24 08:06:39.630666	m	36133c39-09fc-41b6-93f8-590a2eae35d1
7d889a0a-7281-4205-937a-501d7b20eb86	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-11-24 07:58:32.485395	n	36133c39-09fc-41b6-93f8-590a2eae35d1
bf668e6f-354e-443c-bdcc-bb07a30c759c	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 07:58:20.534665	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
5f97cf5e-4dfd-4922-9221-f1342550f43c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-11-24 07:58:32.47751	h	36133c39-09fc-41b6-93f8-590a2eae35d1
ef969620-bc76-4792-b4a6-e8a91ceb892c	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-11-24 07:58:32.583828	b	36133c39-09fc-41b6-93f8-590a2eae35d1
1a9f4e26-c2bc-4700-907a-2542ada9df61	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 07:58:20.564769	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
63e49397-1bda-4ea5-a75e-4480d4b706ca	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 07:58:20.591107	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
926e85f1-c1ca-4881-a613-3bfd0d55bb3c	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-11-24 07:58:32.576563	t	36133c39-09fc-41b6-93f8-590a2eae35d1
00d71a48-b66c-4f9b-ad99-08694222016e	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 07:58:20.834564	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
ea0750ab-fde0-4386-819f-f8c1e45ef9a5	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 07:58:20.883437	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
914c6b83-b8a8-4439-90cb-60325bc57fd5	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 07:58:20.949394	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
e544198f-d084-4943-a26d-14e6b4063992	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 07:58:21.007264	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
b9b0b504-1898-416c-8616-4730c1b7b7be	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 07:58:21.021338	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
bca38d23-3c05-41fd-a21f-66892168c512	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 07:58:21.073441	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
8d7962c4-b0c2-49f0-a517-fffe2304e1ba	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 07:58:21.19263	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
6a2d8d50-8262-4982-ab89-ad60a9889715	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 07:58:21.206326	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
e8a0b0cd-976e-440f-80aa-4adfc16f0e1b	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-11-24 07:58:21.185217	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
5a264a00-f04d-4259-aea5-1bc1da20c05f	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-11-24 07:58:21.059372	d	36133c39-09fc-41b6-93f8-590a2eae35d1
a42ef478-e4bf-4a19-846a-dfd0390b6968	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-11-24 07:58:21.014074	m	36133c39-09fc-41b6-93f8-590a2eae35d1
b9830045-9dba-453f-b27b-04b30fe202df	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-11-24 07:58:20.781946	b	36133c39-09fc-41b6-93f8-590a2eae35d1
61ce4cf8-e779-4bfb-8771-f08c9bc17ba9	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-11-24 07:58:20.780205	h	36133c39-09fc-41b6-93f8-590a2eae35d1
84133477-d5cf-47e3-9603-9438653fff47	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-11-24 07:58:20.77872	t	36133c39-09fc-41b6-93f8-590a2eae35d1
529c6365-dbd0-46fc-a194-a931c9f739d8	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-11-24 07:58:20.776226	n	36133c39-09fc-41b6-93f8-590a2eae35d1
040b6f6b-0c65-4151-bed0-7f6a4eec13b4	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-11-24 07:58:20.558673	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
6ddf1cc6-f3f6-4993-86c2-780f8cb6272e	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-11-24 07:58:20.525912	d	36133c39-09fc-41b6-93f8-590a2eae35d1
0e207494-b86d-47dd-9518-130f7399f191	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-11-24 07:58:20.52111	b	36133c39-09fc-41b6-93f8-590a2eae35d1
b50713e8-30c5-438d-91e5-868a324016b2	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-11-24 07:58:20.428175	g	36133c39-09fc-41b6-93f8-590a2eae35d1
f3c294f6-fb78-48ed-8b0a-49767598977a	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-11-24 07:58:20.357141	m	36133c39-09fc-41b6-93f8-590a2eae35d1
2b0ef1bb-2155-47e9-9209-29317424f9e1	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-11-24 07:58:21.190146	g	36133c39-09fc-41b6-93f8-590a2eae35d1
5c7879ab-9676-44c1-8b9c-a3f7733e12a7	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 07:58:32.606557	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
19ae9533-d73c-4d2b-a757-80da270d6aec	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 07:58:32.645491	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
f77ab9d2-2183-4fac-a078-169b72858638	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	t	2025-11-24 07:58:32.657894	b	79f034a9-ee01-4de2-9238-549e53bb794f
c212f17e-0275-4e4b-a561-101d818ff7ac	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	t	2025-11-24 07:58:21.263267	g	79f034a9-ee01-4de2-9238-549e53bb794f
84f8bb5a-39e8-4e77-a6dc-042203e45e29	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	t	2025-11-24 07:58:32.623277	t	79f034a9-ee01-4de2-9238-549e53bb794f
1f3115f4-af5f-4ffb-ad56-60f8b167ceba	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	t	2025-11-24 07:58:21.194932	nj	79f034a9-ee01-4de2-9238-549e53bb794f
6945ec38-7551-4f0b-96e8-32257b9ec2d7	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	t	2025-11-24 07:58:21.154762	d	79f034a9-ee01-4de2-9238-549e53bb794f
a4284a6c-9d97-4dfe-8c71-205b427cdd1b	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	t	2025-11-24 07:58:21.127991	m	79f034a9-ee01-4de2-9238-549e53bb794f
d5cd1523-2a68-41fc-bfd7-d6d39823989d	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	t	2025-11-24 07:58:21.02808	b	79f034a9-ee01-4de2-9238-549e53bb794f
c55000be-72d0-47af-99e1-0ac30100161a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	t	2025-11-24 07:58:20.975862	n	79f034a9-ee01-4de2-9238-549e53bb794f
47f7abde-97ca-43ab-98b6-c3695c07fef0	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	t	2025-11-24 07:58:20.909911	t	79f034a9-ee01-4de2-9238-549e53bb794f
4b8ef6c3-dc77-4e8a-9660-a816c8ea200d	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	t	2025-11-24 07:58:20.841239	h	79f034a9-ee01-4de2-9238-549e53bb794f
3c92cf33-019f-4a0a-bee0-a45dedee175f	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	t	2025-11-24 07:58:20.715017	nj	79f034a9-ee01-4de2-9238-549e53bb794f
b8b74165-868f-4243-a820-807b405d3660	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	t	2025-11-24 07:58:20.629737	b	79f034a9-ee01-4de2-9238-549e53bb794f
725e9a2f-aef1-4c48-b767-45e1bbe2cbe6	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	t	2025-11-24 07:58:20.542927	d	79f034a9-ee01-4de2-9238-549e53bb794f
4a602622-70bf-467d-9a44-cb2aac271d1f	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	t	2025-11-24 07:58:20.486428	t	79f034a9-ee01-4de2-9238-549e53bb794f
cb3368b3-0c69-46ff-ac2b-7c511debb2c1	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	t	2025-11-24 07:58:20.498147	m	79f034a9-ee01-4de2-9238-549e53bb794f
f43a18d6-6f44-4edf-8e44-5f16b314d84d	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	t	2025-11-24 07:58:20.468732	g	79f034a9-ee01-4de2-9238-549e53bb794f
455e7e20-8768-44b7-96e4-cdc230af8700	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:05:08.058629	h	79f034a9-ee01-4de2-9238-549e53bb794f
84f870ba-be44-47be-8f7e-dc3e58c465ca	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 08:06:39.547591	n	79f034a9-ee01-4de2-9238-549e53bb794f
183a8797-a450-4dfd-b4e5-2da0978d6ae3	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:05:08.200797	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
d3117d22-1279-4d41-ac3e-2a97aa7cef9d	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 08:06:39.825995	m	79f034a9-ee01-4de2-9238-549e53bb794f
6a214f08-9d66-4040-ac69-1ebcd0026b98	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:05:08.225257	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
83f82282-e558-43fd-9fa4-4d4b21fedda3	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:05:08.238143	b	e6a73462-6516-415b-b188-7352267c17e7
b78604d7-ec4b-4c0b-84ef-bcbfc2a9862f	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 08:06:42.674589	d	79f034a9-ee01-4de2-9238-549e53bb794f
0b2dda29-b392-4902-991f-cab0b0e06176	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 08:06:42.700496	h	79f034a9-ee01-4de2-9238-549e53bb794f
20f1fb51-86b5-49f1-bc5f-c7852cd55ac3	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 08:06:42.761208	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
ac74ba9e-6527-4833-9555-75a71ed53c17	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 08:06:42.860314	g	79f034a9-ee01-4de2-9238-549e53bb794f
902fc9c8-833b-4a83-907c-ad29213de98b	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 08:31:54.596163	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
5d699150-561b-4800-bcfa-90fa65b1c9cc	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 08:31:54.644776	n	79f034a9-ee01-4de2-9238-549e53bb794f
15ce4dc9-d50c-4211-838b-eea3739e3e7a	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 08:31:54.677946	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
62d8ef3f-6571-4079-9ff0-56cacac86c44	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:05:08.261349	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
90c5c86c-b590-499a-b1d2-d52d7c11dd25	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 08:31:54.856177	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
4d34a3e2-8d7a-4646-ba64-0d8fdaa2b3b5	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:05:08.26921	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
52bc7c3d-b380-4eef-9c8f-ef712a811246	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 08:31:55.032275	d	79f034a9-ee01-4de2-9238-549e53bb794f
5f6fa192-ddf4-4e9a-880a-e1c6fd3b5058	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 09:24:22.294443	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
18a82853-995e-459a-8a02-957c2ab27201	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 09:24:22.352699	n	e6a73462-6516-415b-b188-7352267c17e7
2562504e-ba91-4bbd-b418-5d7fb731baab	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:05:08.293108	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
a1fe2390-6409-4c79-a734-53ff7f0e3d0c	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 09:24:22.406278	m	79f034a9-ee01-4de2-9238-549e53bb794f
0d42fab4-f6d2-46c3-8f1e-2ef3fb753e84	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 09:24:22.40795	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
7d4ae541-6afb-45be-9811-0ffaa8462f64	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 09:24:22.507629	b	e6a73462-6516-415b-b188-7352267c17e7
5856c84f-c747-421b-9904-8fb550a1bdd9	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-12-01 09:05:08.251854	m	36133c39-09fc-41b6-93f8-590a2eae35d1
320ab3b4-804a-479f-9bc1-097a974adb62	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 10:58:52.47194	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
027bffcd-8ff3-4f14-a7b2-3a6c61a83807	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 10:58:52.591544	t	e6a73462-6516-415b-b188-7352267c17e7
0372dc27-cffc-4565-ab53-cdc7bcebc2a3	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 10:58:52.683672	h	e6a73462-6516-415b-b188-7352267c17e7
0ce76dcb-6335-45fc-a12a-9b4379f6e048	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 10:58:52.709476	h	79f034a9-ee01-4de2-9238-549e53bb794f
f2967fcf-7566-49dd-8687-412c960fa442	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 10:58:52.724036	n	79f034a9-ee01-4de2-9238-549e53bb794f
88049d09-4ab6-42d4-bdf9-2e3a652f722c	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-11-24 10:58:52.555062	t	36133c39-09fc-41b6-93f8-590a2eae35d1
e96c22ea-f1c3-4c38-8cc2-0c32d9792dc0	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-11-24 10:58:52.453978	h	36133c39-09fc-41b6-93f8-590a2eae35d1
c547be39-8611-48b0-a912-77a873aca700	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-11-24 09:24:22.390182	b	36133c39-09fc-41b6-93f8-590a2eae35d1
04f7649f-f963-413c-afc9-66e242d02189	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-11-24 08:31:54.900582	d	36133c39-09fc-41b6-93f8-590a2eae35d1
2de80847-228a-41ae-8801-e0d450df97ae	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-11-24 08:31:54.758969	g	36133c39-09fc-41b6-93f8-590a2eae35d1
a636aaa3-afd9-47f3-af9d-180cb37f3b53	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-11-24 08:31:54.668479	b	36133c39-09fc-41b6-93f8-590a2eae35d1
85a3a488-4fa6-4a4d-a6a3-4641b1aff7c4	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-11-24 08:06:42.448134	b	36133c39-09fc-41b6-93f8-590a2eae35d1
ac387eb4-6b82-4c5c-a98b-bb6291ec5b6a	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-11-24 08:06:42.443987	h	36133c39-09fc-41b6-93f8-590a2eae35d1
7e61d490-9800-4020-80db-5f84af64c58c	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-11-24 08:06:39.943219	g	36133c39-09fc-41b6-93f8-590a2eae35d1
7fde0606-c9cd-495d-9c35-fa776169a5aa	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-11-24 08:06:39.812346	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
384a1f67-3e11-4719-95b1-3072e537e4e9	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-11-24 08:06:39.585622	t	36133c39-09fc-41b6-93f8-590a2eae35d1
7434ea07-43a0-4fa4-bc96-6709dd6c8018	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-11-24 07:58:32.665113	d	36133c39-09fc-41b6-93f8-590a2eae35d1
90ff2e03-34e2-44f9-b1bc-8717f833623c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:08:51.50466	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9c50b4ab-dc97-4207-8a29-e982b3ec21d0	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:08:51.506794	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
e229698b-e22c-4478-a40a-51e69a8cc7dc	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:08:51.509339	h	e6a73462-6516-415b-b188-7352267c17e7
f4a6681a-d5c6-4d2e-b317-f115d01590a7	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:08:51.510788	h	79f034a9-ee01-4de2-9238-549e53bb794f
ed149518-b59e-49bf-bd7f-7ac5e81085b4	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-03 07:12:42.606513	n	36133c39-09fc-41b6-93f8-590a2eae35d1
ee7e5805-74f9-4e05-9bb4-a446882af7c0	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:08:51.536319	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
a53e6599-7102-4b57-af56-bba86766c7d2	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:08:51.537318	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
3b6f047e-d918-4123-bf83-981f18b512d0	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:08:51.538411	n	e6a73462-6516-415b-b188-7352267c17e7
4a628b15-0387-46ad-99fc-2a398eb06897	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:08:51.540056	n	79f034a9-ee01-4de2-9238-549e53bb794f
9758cb1f-dafd-4e9f-bba8-c7ccffd62c36	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:08:51.554718	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
1cabc7b0-b52e-4311-9630-16fe24f8012b	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:08:51.557553	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
ec1fa8b2-154e-4661-8064-890b0995c801	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:08:51.558807	t	e6a73462-6516-415b-b188-7352267c17e7
195ee132-49b1-44fc-8e70-61f45ef54fee	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-11-24 11:08:51.551389	t	36133c39-09fc-41b6-93f8-590a2eae35d1
580b51e8-e3d1-42e4-b124-995b4df51fac	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-11-24 11:08:51.532796	n	36133c39-09fc-41b6-93f8-590a2eae35d1
9011933c-a8f0-4a6c-beea-6b2a17ff0932	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 08:06:39.554963	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
ef717bb5-a4d2-4879-91a7-c2ed3cbd3788	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:05:08.173643	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
9f113719-7a7e-4a7d-9f5a-9df396eca1e8	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 07:58:32.693183	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
7953d3b6-bf7a-4ac7-9ea6-3c4bec78124a	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 08:06:39.894843	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
f392672d-f739-40e0-bcb2-3e74d75e4a3d	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 07:58:32.714875	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
aa987949-940d-4412-9c3b-3bf2aa026283	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 08:06:39.949823	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
e5009d96-e686-4f2b-9c32-781f190c0f16	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 07:58:32.726679	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
821cbe0d-a7f1-44a3-ba84-07e2626520cd	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 07:58:32.783903	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
3fe33ba4-988d-4806-8d44-0ae19499c008	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 08:06:39.969318	g	79f034a9-ee01-4de2-9238-549e53bb794f
27aa8fb5-b73a-4470-8cdd-5ec1673ddeb8	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 07:58:32.828831	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
0219e484-cdc2-45aa-b440-6f57cb4717ab	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 07:58:32.882145	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
517f8524-c057-46cf-8322-2121c8e2690d	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 08:06:42.531072	n	79f034a9-ee01-4de2-9238-549e53bb794f
ebc08798-2610-4fbc-96d5-a20509eeb787	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	t	2025-11-24 07:58:32.890291	g	79f034a9-ee01-4de2-9238-549e53bb794f
e74ed960-e9ad-43a1-b0f2-827cbf95702d	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	t	2025-11-24 07:58:32.913024	m	79f034a9-ee01-4de2-9238-549e53bb794f
4b2b4439-2f28-4ce1-9532-771a8232c206	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	t	2025-11-24 07:58:32.719984	n	79f034a9-ee01-4de2-9238-549e53bb794f
a0436838-0a28-4715-be7b-956ceaf0c23a	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	t	2025-11-24 07:58:32.707298	d	79f034a9-ee01-4de2-9238-549e53bb794f
3cb7a68e-45f1-4b5a-a6ea-e431af7b7693	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	t	2025-11-24 07:58:32.788589	nj	79f034a9-ee01-4de2-9238-549e53bb794f
620c533a-2300-4eb3-b7a9-025d32d032fa	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	t	2025-11-24 07:58:32.675808	h	79f034a9-ee01-4de2-9238-549e53bb794f
2c1c736b-eecd-491d-bbab-0d8d85f0bdad	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 08:06:42.557261	m	79f034a9-ee01-4de2-9238-549e53bb794f
d2ed8fb1-696f-4163-9db0-f6e15417d802	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 08:06:42.600606	t	79f034a9-ee01-4de2-9238-549e53bb794f
a97c6bd2-ead5-4a8a-a7d3-4f818ef46dfd	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 08:06:42.686922	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
be3072e0-3913-4c1b-8e91-90e2201015ae	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 08:06:42.795812	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
222a362a-998d-4e1a-8379-ff24cc78da97	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 08:31:54.605885	h	79f034a9-ee01-4de2-9238-549e53bb794f
256eecee-e7ef-42fb-95a4-df92aaf6cf90	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 08:31:54.866694	m	79f034a9-ee01-4de2-9238-549e53bb794f
f8cf0b8a-fd1b-48f1-b944-a77b7186220a	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 08:31:54.936145	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
38a8ac15-c1eb-45d4-9952-265fa9f5f2c4	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 08:31:54.941923	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
4d38d974-10b3-4dc4-81c9-48066e79bcd0	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 09:24:22.217476	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
7dd2b430-58ae-4fbd-be26-5f277832c326	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 09:24:22.316311	h	e6a73462-6516-415b-b188-7352267c17e7
f369e0fa-5b18-4cc1-8acd-b29d3bcf8bdf	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 09:24:22.356943	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
ef319a23-7a3a-4704-b18e-e599e315d9bc	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 09:24:22.40126	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
5f678d20-31fe-49b5-9987-1f4b2b9b9822	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 09:24:22.411408	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
7b845f93-8b45-4362-9e60-4cbc2f0bbd87	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 09:24:22.41861	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
bb72cefa-b078-46ae-abc2-23d9f4e7376b	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 09:24:22.42053	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
2602ab40-d9c9-4b23-9c7c-8a98c79e6ba9	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 09:24:22.450611	d	79f034a9-ee01-4de2-9238-549e53bb794f
7b2307cc-b1d6-4722-85f3-15b56f2e7df2	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 09:24:22.464967	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e2913751-6e8c-4490-a54a-c15c3571dc28	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 09:24:22.47084	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
7ead02af-9931-4dbe-8406-f4ed8f2b98e3	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 09:24:22.485426	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
4a1cfc64-8cff-43c5-b694-d2f50ff1b244	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 09:24:22.488952	g	79f034a9-ee01-4de2-9238-549e53bb794f
de81182e-944f-47b2-b559-0106c8c2f1a6	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 09:24:22.509256	b	79f034a9-ee01-4de2-9238-549e53bb794f
8ba9c9ab-9087-461a-a434-18e84258e419	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 10:58:52.575591	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
27751339-f54a-4e40-a911-b858e8466d18	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 10:58:52.581692	t	79f034a9-ee01-4de2-9238-549e53bb794f
d16dcffb-7bf3-4039-9ca7-379de442cf0d	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 10:58:52.633598	b	e6a73462-6516-415b-b188-7352267c17e7
7893d42c-b68c-4916-adf3-b4c76ac6fca3	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-11-24 09:24:22.456088	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
dd4af3e8-e6e4-4e1b-b5a8-87cf2c2d977a	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-11-24 09:24:22.393004	t	36133c39-09fc-41b6-93f8-590a2eae35d1
6069f34e-103b-4028-878e-a0363ee50ba2	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-11-24 09:24:22.207086	h	36133c39-09fc-41b6-93f8-590a2eae35d1
36e29ca5-2a0e-4fed-9217-3b9081d1789a	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-11-24 08:31:54.764856	t	36133c39-09fc-41b6-93f8-590a2eae35d1
98f66cf7-af12-43f7-b2ab-7568b0624430	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-11-24 08:31:54.670659	m	36133c39-09fc-41b6-93f8-590a2eae35d1
bca08574-6eab-4229-bf38-da4f4b0cc2d5	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-11-24 08:31:54.469754	h	36133c39-09fc-41b6-93f8-590a2eae35d1
cd3a3c83-52f7-4a95-a891-e7855fdb7575	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-11-24 08:06:42.752814	g	36133c39-09fc-41b6-93f8-590a2eae35d1
da970364-7471-4c17-9e3b-66f1df65c288	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-11-24 08:06:42.560912	d	36133c39-09fc-41b6-93f8-590a2eae35d1
7b6b9249-69e0-4296-8c1d-d2c842633d19	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-11-24 08:06:42.44956	m	36133c39-09fc-41b6-93f8-590a2eae35d1
c98fa2fd-507f-4d07-a9d6-a883e3b9e533	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-11-24 07:58:32.77566	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
a2a94f71-51ad-413b-a63e-957558b5599b	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-11-24 07:58:32.778356	g	36133c39-09fc-41b6-93f8-590a2eae35d1
69733e4f-a427-471e-b120-83e6d70b1d7b	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-11-24 07:58:32.672303	m	36133c39-09fc-41b6-93f8-590a2eae35d1
74348988-da07-4a98-a092-771a7ae0b5e3	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:08:51.560372	t	79f034a9-ee01-4de2-9238-549e53bb794f
4fe2faae-66b1-43de-923e-93476bf4b7ac	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:08:51.577794	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
87bddd0e-da7b-4d51-b830-d093c1793760	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:08:51.602332	m	79f034a9-ee01-4de2-9238-549e53bb794f
086834a8-eeef-4df8-9bee-6c02e1dd0c80	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:05:08.200097	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
50e6b69a-c790-4c5a-8f63-38e861c4fdea	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:08:51.621869	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
456860d4-ed6a-4b05-af6c-b84e5a5414cb	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:08:51.655526	nj	79f034a9-ee01-4de2-9238-549e53bb794f
5675e783-46f6-465a-aa69-5c0e2a8a8f83	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:08:51.689002	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
c8a565fb-2b69-445c-a318-2fa7e7b10541	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-11-24 11:08:51.574264	b	36133c39-09fc-41b6-93f8-590a2eae35d1
96a22dd3-2da5-4520-a4a0-d3e44268c05b	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-11-24 11:08:51.618677	d	36133c39-09fc-41b6-93f8-590a2eae35d1
9312651c-b840-4b6c-adfd-93b2abb3c1b9	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:05:08.226888	t	e6a73462-6516-415b-b188-7352267c17e7
023c56f9-3e83-4585-94e1-188fb51e4eaf	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:05:08.235326	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
919d733c-2b3c-490e-b667-b3d238d728eb	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:05:08.267402	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
2923c3ba-1114-42fe-afd8-d97981ea6cc7	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:05:08.290417	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e8291578-ae52-4627-a3b4-a46111e781d0	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-12-01 09:05:08.281414	g	36133c39-09fc-41b6-93f8-590a2eae35d1
2992d740-c6de-4969-8326-e009c4b2e050	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-12-01 09:05:08.262805	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
79b06373-754d-4a9e-8358-28ed8c9f9cf5	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-12-01 09:05:08.197047	n	36133c39-09fc-41b6-93f8-590a2eae35d1
538eab60-2f67-4961-b74d-4e507db3269a	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-03 07:12:42.608067	b	36133c39-09fc-41b6-93f8-590a2eae35d1
d49f3367-c760-4df4-91df-1b8de3a1a2e3	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 07:12:42.690039	h	e6a73462-6516-415b-b188-7352267c17e7
636a9a6d-9706-40b6-a191-11d8edf9df3d	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 07:12:42.72414	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
841c0755-e60b-4704-a206-b42828daa8b2	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 07:12:42.731744	t	e6a73462-6516-415b-b188-7352267c17e7
dba0e4ae-55bd-4b17-94b3-bf136d520ff0	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 07:12:42.766421	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
3c2efc85-d1de-4a39-ac54-7a6dcc3108ec	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 07:12:42.805705	nj	e6a73462-6516-415b-b188-7352267c17e7
5dc49f32-2c58-4c47-a761-9e70fd21174e	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-03 07:12:42.836025	n	36133c39-09fc-41b6-93f8-590a2eae35d1
54e998f8-1d5c-4b07-853a-036f657ce500	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 07:12:42.855624	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f6c2b323-10c0-4180-bb09-049419f91a3d	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 07:12:42.877563	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
773bf2b7-6d2a-44c2-8075-e819a4ff4b57	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 07:12:42.97114	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
ba7303cd-f8ff-44cc-b662-8cf403bd5297	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-03 07:12:42.983232	g	36133c39-09fc-41b6-93f8-590a2eae35d1
25b37420-3ad9-46c3-9e5c-436c71f07186	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 07:12:43.030137	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
cf1462b9-d9ec-4788-b70b-8acbc0d77264	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	t	2025-12-03 07:12:42.719586	b	79f034a9-ee01-4de2-9238-549e53bb794f
0c29c924-d08e-4e9d-b1e3-5882bdd0aeb9	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-03 08:27:21.868991	h	36133c39-09fc-41b6-93f8-590a2eae35d1
af0f67aa-b8dd-4fe0-a00e-ea975ac34449	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 08:27:21.876094	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
be365439-4272-44d8-b71a-7ebcc912fd6b	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 08:27:22.061573	n	e6a73462-6516-415b-b188-7352267c17e7
20f78b4b-201b-4e22-aa4c-ddf3b9ac1fe5	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 08:27:22.070614	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
93d34a96-fb4e-441c-b0a7-83d24fb007f5	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 08:27:22.096045	b	e6a73462-6516-415b-b188-7352267c17e7
fe2f7fd8-bd0f-4b1e-b15f-7a0215385b9d	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 08:27:22.115663	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
28793f8b-d64d-4e7d-a958-3d847e112231	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 08:27:22.139053	d	79f034a9-ee01-4de2-9238-549e53bb794f
868866a4-9e97-4862-bc5a-ad08e541aac7	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-03 08:27:22.154919	g	36133c39-09fc-41b6-93f8-590a2eae35d1
34599293-6720-4406-9aea-c30fded6f6b2	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 08:27:22.159158	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
eaa9f520-fd79-4bc2-8d05-ba83b424a4cd	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-03 09:56:27.011847	h	36133c39-09fc-41b6-93f8-590a2eae35d1
0571667e-c9b0-41f6-9465-1beb473aef3c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 09:56:27.028965	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e3f34873-439a-4279-a1f6-05bf0dda43ac	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 09:56:27.048768	t	e6a73462-6516-415b-b188-7352267c17e7
fa74f7e7-250e-4064-bdf3-072ef8eb6d2c	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 09:56:27.10338	d	e6a73462-6516-415b-b188-7352267c17e7
58b08ae8-b490-4886-8cc6-4b8e0d4b6577	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-03 09:56:27.16584	m	36133c39-09fc-41b6-93f8-590a2eae35d1
992aae01-6c8c-4a21-af21-5f3125f92ffa	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 09:56:27.202897	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
701e1d19-e222-45c6-96a9-ef35c5dd4cd5	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 09:56:27.209636	g	e6a73462-6516-415b-b188-7352267c17e7
295f17df-b837-49ad-b62f-a78423d2263b	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 14:08:10.118555	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
fedf151e-b6b3-4fe7-9b80-7a41025a867c	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 14:08:10.153433	t	79f034a9-ee01-4de2-9238-549e53bb794f
cce1efb1-11c8-4a12-95cd-37a35e9f5f55	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-03 14:08:10.17553	b	36133c39-09fc-41b6-93f8-590a2eae35d1
aae43e0b-7763-4804-96c7-6e166118147a	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 14:08:10.183403	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
63731e7f-dc69-40f5-8b8e-12a3f2431a0f	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 14:08:10.219206	m	79f034a9-ee01-4de2-9238-549e53bb794f
53d084c9-2e16-4834-a875-dc3821416444	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-03 14:08:10.237557	d	36133c39-09fc-41b6-93f8-590a2eae35d1
c9d417cc-fdf0-4cbb-be21-005a23dbd119	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 14:08:10.240594	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
757f6e22-231f-47d6-89fa-6f3ac717cf76	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:08:51.578753	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
f674b9c6-1d8b-441d-aa22-47af7d628443	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:08:51.601276	m	e6a73462-6516-415b-b188-7352267c17e7
25af15ec-6448-4e27-87c7-c0757c1af1ce	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:08:51.62342	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
f48b4a71-c0e9-40f7-ac73-4c92503ee3ea	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:08:51.654037	nj	e6a73462-6516-415b-b188-7352267c17e7
4272c64e-2bda-4503-807a-affa5e4b90e9	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:05:08.201884	n	e6a73462-6516-415b-b188-7352267c17e7
cf5e3315-4275-407a-9148-4a826055f05e	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:08:51.687016	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
363e1f67-4d4a-413f-b713-903ee6085ca3	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-11-24 11:08:51.681864	g	36133c39-09fc-41b6-93f8-590a2eae35d1
62e9a598-b411-42f8-832a-1ee71ee390c3	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:05:08.234158	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9c85b428-25dd-4172-8d6c-4a9a463d62c6	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:05:08.257298	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
ba932acb-5509-406d-a1f4-6601e7e39d7c	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:05:08.271496	nj	e6a73462-6516-415b-b188-7352267c17e7
e975d9b2-19cd-4dad-8147-21aee0290b8a	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:05:08.29864	g	79f034a9-ee01-4de2-9238-549e53bb794f
ebf4659d-79ee-487b-b408-7a4f438ba1b3	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-12-01 09:05:08.229536	b	36133c39-09fc-41b6-93f8-590a2eae35d1
86dea44e-d5f0-40a5-a6d1-143ec2d38631	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-03 07:12:42.610461	t	36133c39-09fc-41b6-93f8-590a2eae35d1
dd067ef4-46c9-4290-a1bb-848f5ae36faa	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 07:12:42.721582	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
84e50134-fda7-4b83-91c9-6f3fe9c7fb39	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-03 07:12:42.773378	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
f90dc415-8037-4a6a-86f8-194a75788337	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 07:12:42.794841	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
0bc3fce5-aea6-49f2-bc56-0550c85c1fc8	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 07:12:42.812119	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
d826baf1-4b81-4705-9c87-cbf1e2d84405	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-03 07:12:42.932185	m	36133c39-09fc-41b6-93f8-590a2eae35d1
3192ef55-738a-4f88-991a-d956230d5a1d	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 07:12:42.991314	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
319e276c-4410-4cc8-b7a2-7b74e1e46b70	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	t	2025-12-03 07:12:43.02118	g	79f034a9-ee01-4de2-9238-549e53bb794f
f8bcde67-7793-4eaa-bdb0-b1d507ca0c84	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	t	2025-12-03 07:12:42.732105	t	79f034a9-ee01-4de2-9238-549e53bb794f
0bfe1725-7efd-4f06-b42a-33cf9a6f0be4	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	t	2025-12-03 07:12:42.693576	h	79f034a9-ee01-4de2-9238-549e53bb794f
226b4dd3-34b2-4d81-99c8-a25f83b51fb7	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 08:27:21.930716	h	79f034a9-ee01-4de2-9238-549e53bb794f
5c676116-09a9-427d-b483-49f80ec83b04	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 08:27:22.059497	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
ba43a301-92f2-4ec5-9ab7-4428c5e966c3	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 08:27:22.072104	t	e6a73462-6516-415b-b188-7352267c17e7
6b219182-f381-474e-8f86-c8fc3e42dfe9	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 08:27:22.095098	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
4aca2e84-bead-47fd-8a29-635753e2cd23	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 08:27:22.116761	m	e6a73462-6516-415b-b188-7352267c17e7
45a15080-03d7-4e6c-9019-a48612ff3e6b	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 08:27:22.137388	d	e6a73462-6516-415b-b188-7352267c17e7
68c217bc-643f-4863-84dc-19d3e618c1d8	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 08:27:22.150304	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
935e73f8-3a32-4e1d-8573-643696de7e9d	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 08:27:22.162805	g	79f034a9-ee01-4de2-9238-549e53bb794f
c377acae-ab4c-4dff-b2ac-475edfc69596	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-03 09:56:27.015069	n	36133c39-09fc-41b6-93f8-590a2eae35d1
e9b4beeb-907d-46d9-a9b9-a166aa91bf87	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 09:56:27.037114	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
d572f3ee-f618-42b8-8c76-056ac8e59e33	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 09:56:27.048147	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
39fa958a-06a4-492d-a9f3-fdb918c0aeb1	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 09:56:27.051343	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
5631edc7-acdc-496a-be33-d614ae366b30	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-03 09:56:27.082914	d	36133c39-09fc-41b6-93f8-590a2eae35d1
e7a33227-a134-4165-90de-ff282535fa79	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 09:56:27.088564	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f86832fa-adf4-48c3-8358-bf357d975dfc	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 09:56:27.092713	d	79f034a9-ee01-4de2-9238-549e53bb794f
41dfdbe2-9358-41fa-9fa9-5dff642a111d	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 09:56:27.145375	nj	e6a73462-6516-415b-b188-7352267c17e7
36f89d27-1cfe-4993-bf98-5bb8f5d3df5e	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-03 09:56:27.158062	b	36133c39-09fc-41b6-93f8-590a2eae35d1
ce692a0b-6ba8-454f-a35f-a0543f637333	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 09:56:27.173967	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
cc6aa42d-a23a-4be3-9008-1e47f44cd8c5	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 09:56:27.180028	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
ec703c90-4fe4-4843-98ff-e48429934ec4	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 09:56:27.206168	m	e6a73462-6516-415b-b188-7352267c17e7
67ee8a2d-83cf-445d-8cef-3bd833fc40e6	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 14:08:10.119892	h	e6a73462-6516-415b-b188-7352267c17e7
dd2d1003-26db-4285-ba6c-b5abf434fd2a	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 14:08:10.151651	t	e6a73462-6516-415b-b188-7352267c17e7
93426af1-c364-4de2-b9b9-5dc85c51095a	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 14:08:10.185761	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
2c3b4926-e364-4f5e-b7fd-ccc9a16f8966	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 14:08:10.215704	m	e6a73462-6516-415b-b188-7352267c17e7
23a85b2f-a006-4a45-9297-d2dfc5fea469	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 14:08:10.245233	d	79f034a9-ee01-4de2-9238-549e53bb794f
307c9101-a2d2-43a6-a020-b38b3c802d57	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-03 14:08:10.264929	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
e39c5f42-48ea-4904-a877-ebde7d653a54	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 14:08:10.271163	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
3c9ec0e1-5ea1-44da-a368-e7275568f338	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 14:08:10.308553	g	79f034a9-ee01-4de2-9238-549e53bb794f
11d8d048-9ddb-40a4-931d-a9376ce8ae33	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:08:51.579816	b	e6a73462-6516-415b-b188-7352267c17e7
88d9d740-90cd-47bb-9861-00f812b5b19c	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:08:51.600063	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
8fd70d27-8827-4e34-96a1-b8c135ba7693	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:08:51.62457	d	e6a73462-6516-415b-b188-7352267c17e7
171e8ecc-efe7-4f5d-8f1f-7038350c8d13	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:08:51.651746	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
31921468-eb18-4ef4-8694-480cc81facca	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:08:51.691686	g	e6a73462-6516-415b-b188-7352267c17e7
287ef97b-f4a8-4a8b-a2fc-bb04fa865381	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:05:08.20276	n	79f034a9-ee01-4de2-9238-549e53bb794f
5cda0bb5-ae24-4f78-a26b-21d82fec0ae2	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:05:08.223872	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
ce7fb6a3-5f99-4f7e-9331-e41e63605e48	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:05:08.239792	b	79f034a9-ee01-4de2-9238-549e53bb794f
3cf4c731-aa17-49b5-8b96-0326cac6fdf2	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:05:08.255771	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
a05a9a6c-8de1-4cc5-ae35-77b538cb1f77	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:05:08.273625	nj	79f034a9-ee01-4de2-9238-549e53bb794f
700a2432-d408-4776-abee-583ead0da6bc	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:05:08.297137	g	e6a73462-6516-415b-b188-7352267c17e7
d9d2af80-6a02-45cf-8abb-f2c7b851de9f	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-12-01 09:05:08.250365	d	36133c39-09fc-41b6-93f8-590a2eae35d1
4ddd405f-e773-405d-949a-f35470beeb61	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-12-01 09:05:08.218712	t	36133c39-09fc-41b6-93f8-590a2eae35d1
b3cb7453-ab9c-4792-8378-fb01ae404f66	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 07:12:42.645737	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
cad6facf-a28e-4355-9da5-c3e0d3ef9002	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 07:12:42.711512	b	e6a73462-6516-415b-b188-7352267c17e7
af0f08af-1d97-481b-bec1-ac72c65e8187	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-03 07:12:42.752042	d	36133c39-09fc-41b6-93f8-590a2eae35d1
dcee6498-3e5d-4ad9-9162-c13ca7e21159	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 07:12:42.759819	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
1b682774-bf0e-494c-8d88-e95ab46202c7	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-03 07:12:42.78755	g	36133c39-09fc-41b6-93f8-590a2eae35d1
b2250757-79fc-498a-b74a-30c86a770f0a	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 07:12:42.81052	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
cd1599de-f2e5-40df-a23e-8782b6386d6f	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 07:12:42.824129	n	e6a73462-6516-415b-b188-7352267c17e7
52f5a93f-7560-4ee3-8d14-28e1697aaa4e	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-03 07:12:42.845647	t	36133c39-09fc-41b6-93f8-590a2eae35d1
fb721138-f7e8-43d9-b998-d18af70838aa	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 07:12:42.874848	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
775a7f3a-674b-4e36-ae67-52751e95da34	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-03 07:12:42.981476	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
53cde961-543d-4fa1-b12e-932db4371477	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 07:12:43.01767	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
0de7a50f-f253-491e-a7a7-ad1a9945d1cb	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	t	2025-12-03 07:12:42.720915	m	79f034a9-ee01-4de2-9238-549e53bb794f
aa597dbd-f3e0-4713-9f1d-57bcc6f093a1	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 08:27:22.017814	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
18f47e28-c8d2-4c62-b023-4be5be3fe68f	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-03 08:27:22.064172	t	36133c39-09fc-41b6-93f8-590a2eae35d1
6d015676-50c7-46af-bc41-df5b3719e55c	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 08:27:22.069307	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
aaded999-40b2-4686-917b-e425ad059fd6	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 08:27:22.097289	b	79f034a9-ee01-4de2-9238-549e53bb794f
497de666-f147-4645-8801-277d1c04a793	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-03 08:27:22.111074	m	36133c39-09fc-41b6-93f8-590a2eae35d1
1d0c854a-90d7-4e7c-93a0-33be5109a27e	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 08:27:22.113785	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9db3808c-090e-44b0-8f17-6d0513ab8d38	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-03 08:27:22.146615	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
b5b2ef56-0656-43da-b30d-df279292393e	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 08:27:22.149343	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
04b2d7f9-374f-4b6a-8e42-e8ee7d3a7b23	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-03 09:56:27.020266	t	36133c39-09fc-41b6-93f8-590a2eae35d1
4d6e600f-342a-46c0-ac7f-bcf21d868daf	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 09:56:27.046193	n	79f034a9-ee01-4de2-9238-549e53bb794f
7c74cb7a-52c6-4411-bc3a-318deec6161e	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 09:56:27.050852	t	79f034a9-ee01-4de2-9238-549e53bb794f
f96d0c70-5f91-498e-a648-fc94e96a9e62	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 09:56:27.096626	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
29c7aff6-d197-4d4d-91ad-460fcba3e38c	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-03 09:56:27.128513	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
d09cb308-84af-428b-8120-9fd6b0ace7f3	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 09:56:27.142199	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
5184b8d3-141e-4f1b-b7d4-e008f2bbd897	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-03 09:56:27.162464	g	36133c39-09fc-41b6-93f8-590a2eae35d1
c4a7e914-a9a4-41e0-9806-f6266cf3f9a5	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 09:56:27.200275	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
0dd7daed-2fe7-48e9-abdd-1f1090025ebd	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 09:56:27.202657	g	79f034a9-ee01-4de2-9238-549e53bb794f
33fb9e1f-b1c0-43a1-9aee-0d1735dca398	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 14:08:10.121646	h	79f034a9-ee01-4de2-9238-549e53bb794f
80408e66-3eee-4436-9083-2a97cf5e51b4	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 14:08:10.150404	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
cdb6ad3a-eb91-43c6-9ae6-face91912a56	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 14:08:10.187344	b	e6a73462-6516-415b-b188-7352267c17e7
385a40b5-e2c9-4fc9-88b6-ad060b1d3970	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 14:08:10.214376	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
4dc36549-14a8-49eb-a2f5-3cb6dd7b2807	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 14:08:10.242582	d	e6a73462-6516-415b-b188-7352267c17e7
c55dfae5-cdde-474a-a5ed-afed202b7df1	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 14:08:10.27253	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
884296b7-93e9-4206-8f9e-0bc5f9b2916d	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 14:08:10.30633	g	e6a73462-6516-415b-b188-7352267c17e7
835a223f-f3e6-4676-92e5-ed65b6c68ae2	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:08:51.581103	b	79f034a9-ee01-4de2-9238-549e53bb794f
12658afa-dca7-44ce-af3c-419a706d0b2b	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:05:08.315774	t	79f034a9-ee01-4de2-9238-549e53bb794f
0b558104-fda4-4ceb-901c-d7e032358832	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:08:51.598944	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
5763c25f-24f1-4551-b8b9-33ea3139b1e3	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:08:51.626007	d	79f034a9-ee01-4de2-9238-549e53bb794f
799dccc4-3260-443f-a283-960756c7ef87	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 08:27:22.030696	h	e6a73462-6516-415b-b188-7352267c17e7
27155cd6-ef0c-48db-92f6-7383edadbc11	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:08:51.650219	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
a769e1f4-f1d0-495a-83e3-8f56c32a3081	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:08:51.694737	g	79f034a9-ee01-4de2-9238-549e53bb794f
a36d7814-4df1-44f7-afd6-e08b407ff746	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-11-24 11:08:51.499359	h	36133c39-09fc-41b6-93f8-590a2eae35d1
9c3d7eda-d486-4b47-b329-b2421b7a8458	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-11-24 11:08:51.647232	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
99f67704-003d-4bd8-be74-35c5ff937152	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-11-24 11:08:51.596217	m	36133c39-09fc-41b6-93f8-590a2eae35d1
aefdbcdb-ab06-4309-b97f-5567bdc923e7	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-11-24 11:09:02.944413	m	36133c39-09fc-41b6-93f8-590a2eae35d1
dcdb1779-83c7-4fd0-9592-2cec85cce8ff	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-11-24 11:09:02.947054	n	36133c39-09fc-41b6-93f8-590a2eae35d1
30a0256a-b625-4239-8054-df2c195baecf	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-11-24 11:09:02.948467	h	36133c39-09fc-41b6-93f8-590a2eae35d1
8b9e13ed-927d-4c6f-8428-80afc982bdba	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-11-24 11:09:02.950262	b	36133c39-09fc-41b6-93f8-590a2eae35d1
9a91216b-0a0b-4bee-b175-487e2926b56c	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:02.954742	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
77f8f5d5-ce0f-40bc-b788-10170a387948	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-11-24 11:09:02.957273	t	36133c39-09fc-41b6-93f8-590a2eae35d1
98367dd4-3fb5-475e-8dd5-721671b8aa9e	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:02.961833	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
46ab09d8-fb1f-4329-aa40-bbe4b7ea1680	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:02.963073	n	79f034a9-ee01-4de2-9238-549e53bb794f
a4b2d693-1cd2-4d63-97bb-8b6c866c7d34	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:02.970573	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
85d2aedd-ff2a-44bc-a31b-66f7cc192f37	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:02.975206	h	79f034a9-ee01-4de2-9238-549e53bb794f
3fd36a00-b8fb-404c-af9c-5c837a855fd5	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:02.974937	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
0e74eaad-e8b8-4a2f-a88f-8f8bbe6cfb39	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:02.980824	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
0e145390-51b7-41a6-9067-0f43c91491c5	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:02.981094	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
39773e91-8178-4a5d-9323-137dde9dc0a3	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:02.983829	b	e6a73462-6516-415b-b188-7352267c17e7
2a502c77-6425-49e6-b69c-99c86ea8974a	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:02.984081	b	79f034a9-ee01-4de2-9238-549e53bb794f
7c5c2ba5-45fc-4d58-ba6d-db0c7bbfb483	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:02.984339	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f0f7d3cf-3a63-48a8-b18a-130e56a553ab	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:02.984551	h	e6a73462-6516-415b-b188-7352267c17e7
35b75da2-350b-45f1-be22-f94110eae067	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:02.995378	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
68e91e00-c2b9-4e3b-8bc4-3c165b447852	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:02.997358	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
2f1ddc3a-6075-4de2-9af1-ca7336d985a3	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:02.997559	t	e6a73462-6516-415b-b188-7352267c17e7
d7742e58-dc86-429b-9f4a-b183f9d53ba7	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:02.997755	t	79f034a9-ee01-4de2-9238-549e53bb794f
3d64a269-19b8-48fe-b204-68dda4cd3b1d	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-11-24 11:09:03.019058	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
f449b9a4-d531-44b3-936e-b93eb94af1fe	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:03.029817	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
107b6017-d0aa-4ec5-bd0e-357da3ee9578	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:03.032133	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
f71186ec-e6f7-463d-8cf8-69450c1466b6	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:03.033373	nj	e6a73462-6516-415b-b188-7352267c17e7
80c6defd-f508-4fbf-9aa8-7d644614ae28	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:03.034831	nj	79f034a9-ee01-4de2-9238-549e53bb794f
014f92d0-a637-4f47-bb0a-a97c1f1fc423	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:03.041961	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
2a64b8cc-4679-4ce4-b066-58104c32e615	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:03.043253	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
a8b61774-5aba-4100-9cd2-751baf1ad007	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:03.045032	g	79f034a9-ee01-4de2-9238-549e53bb794f
6b3b0ce5-78a0-46a2-83b0-d63a32451aba	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:03.044819	g	e6a73462-6516-415b-b188-7352267c17e7
ebe5286d-e5e9-4958-8a4d-d8c112165667	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:03.053061	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
6f4c4c58-7dfe-46d3-82c9-6007a81d19bb	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:03.055936	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
f898c4bd-86ba-4547-862f-a806a85aace3	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:03.056922	d	e6a73462-6516-415b-b188-7352267c17e7
bf37708d-2054-441d-9980-c75c9bfaf5bf	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:03.058088	d	79f034a9-ee01-4de2-9238-549e53bb794f
5bc4524b-725c-4fd0-a6b5-5bdfeaa8afd5	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:03.062072	m	e6a73462-6516-415b-b188-7352267c17e7
bc732700-e91f-4908-a6df-c35e02f20d6d	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:03.063777	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
b9847950-11db-425a-aaa7-3887123d6bb7	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:03.070097	n	e6a73462-6516-415b-b188-7352267c17e7
4ccfa46a-c14a-4792-a2b4-b6fd72f5b90d	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:03.07235	m	79f034a9-ee01-4de2-9238-549e53bb794f
5b7f2f07-ea2b-49aa-af8b-5b16bddb39d8	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:03.361412	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
ce77ce8c-ab72-4275-b4f7-139d50df37fe	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-11-24 11:09:03.358316	m	36133c39-09fc-41b6-93f8-590a2eae35d1
e6e2f2ab-1bcc-4020-ab2a-cb9eebc5580e	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-11-24 11:09:03.357304	t	36133c39-09fc-41b6-93f8-590a2eae35d1
8e74f35c-afa7-456b-8a9c-a2e53c5f9630	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-11-24 11:09:03.355723	b	36133c39-09fc-41b6-93f8-590a2eae35d1
cdd577f0-5c41-4135-a384-87bb7da357c6	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-11-24 11:09:03.354439	n	36133c39-09fc-41b6-93f8-590a2eae35d1
cf511d28-0c56-4674-8abb-85f204ac40a1	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-11-24 11:09:03.352223	h	36133c39-09fc-41b6-93f8-590a2eae35d1
f1f03fdd-000f-408d-9ed8-72d5aa9a62a8	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-11-24 11:09:03.048741	d	36133c39-09fc-41b6-93f8-590a2eae35d1
f3af02bd-9668-45ca-81a5-a21c2bb3c551	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-11-24 11:09:03.024152	g	36133c39-09fc-41b6-93f8-590a2eae35d1
f57a9bd1-5b7e-44eb-8845-e5b81bd86f9c	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:05:08.344688	d	e6a73462-6516-415b-b188-7352267c17e7
49f27d6c-500f-4565-89b6-87490332d4e2	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:03.374629	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
a2fa93a6-94cc-4565-a4c2-8236afd6c2e7	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:03.382829	t	79f034a9-ee01-4de2-9238-549e53bb794f
1626d165-324e-4664-a8bf-53673035d6ec	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:03.399584	d	79f034a9-ee01-4de2-9238-549e53bb794f
90d940ca-5182-4cbf-8ec3-1cc35f4af00e	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 07:12:42.790693	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
2c3bba60-b0ee-4fc6-b820-c3db8244a9e4	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:03.421272	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
a469374a-2b44-4beb-86d7-190b4968028e	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:03.811907	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
ac55f73c-f619-472b-8ab3-f55fefcf4487	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:03.819901	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
e439d0b9-35d6-454d-bbe1-246a7ee6a68e	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:03.825562	b	79f034a9-ee01-4de2-9238-549e53bb794f
11487b12-dea8-48c8-8c4c-78242b572650	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:03.844039	g	e6a73462-6516-415b-b188-7352267c17e7
f3b519a2-99f9-4878-b9fc-7b3335e212c4	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:04.194709	n	79f034a9-ee01-4de2-9238-549e53bb794f
b0f30206-a102-41b3-880c-23a1cdd82021	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:04.19973	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
a5d450cd-f7ef-4f76-acf4-6e263cfb8b8e	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:04.209303	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
1571e351-3a21-476c-b042-db863225031e	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:04.235225	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
5a022ee3-854d-4b4a-994c-89e106b7c501	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-03 07:12:42.934994	b	36133c39-09fc-41b6-93f8-590a2eae35d1
5f09d488-b1de-4558-9092-ca2b3556bfe7	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:07.564748	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
751dca84-bfb1-4782-9be2-b03ded960e75	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:07.583425	d	79f034a9-ee01-4de2-9238-549e53bb794f
1319bb4d-f185-4cd9-89a5-e09e0eca08d7	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:07.599333	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
189631c4-d500-4ad7-a0b0-49817ae6a9af	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-11-24 11:09:07.549303	m	36133c39-09fc-41b6-93f8-590a2eae35d1
0d34e312-bc52-40c4-9c42-7a941c5ae199	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-11-24 11:09:04.22767	g	36133c39-09fc-41b6-93f8-590a2eae35d1
11a1016c-cc95-4df6-b85a-c1e3a460561c	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-11-24 11:09:03.415538	g	36133c39-09fc-41b6-93f8-590a2eae35d1
15071442-b3ac-4910-b3c9-3018ad094f12	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-11-24 11:09:03.359399	d	36133c39-09fc-41b6-93f8-590a2eae35d1
8531b6f2-4ba7-4baf-9581-45453183892e	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 07:12:42.957246	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c9fbc33b-756e-478c-b772-acb1749c8169	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	t	2025-12-03 07:12:42.99302	d	79f034a9-ee01-4de2-9238-549e53bb794f
d6d69b65-d10a-408e-a7e3-fbdd15501d9f	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	t	2025-12-03 07:12:42.815268	g	79f034a9-ee01-4de2-9238-549e53bb794f
4d159c57-979c-4c40-883a-f7f9f8ee6834	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-03 08:27:22.052168	n	36133c39-09fc-41b6-93f8-590a2eae35d1
f72c8c86-93c7-4a99-9685-6fa4e14aa5a7	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 08:27:22.0573	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e6a9050d-828b-4101-973f-5e2f8db31af3	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 08:27:22.07433	t	79f034a9-ee01-4de2-9238-549e53bb794f
d25d7cd9-84d6-47c0-b7ec-030376ff941f	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-03 08:27:22.088601	b	36133c39-09fc-41b6-93f8-590a2eae35d1
ee81ad03-1cf3-48df-a333-490725f20593	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 08:27:22.093922	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
39c8cc1b-b87a-4e46-9f9e-9536e6941adc	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 08:27:22.11797	m	79f034a9-ee01-4de2-9238-549e53bb794f
c723ebc4-407c-4253-a79e-ba19caf996bc	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-03 08:27:22.131679	d	36133c39-09fc-41b6-93f8-590a2eae35d1
d9c1bcb7-0260-4989-820e-e132fab79f39	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 08:27:22.135054	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
2fbbf05c-4956-48e5-8a04-a6e73cb160f8	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 08:27:22.152793	nj	79f034a9-ee01-4de2-9238-549e53bb794f
d87adc9f-5bc3-4fe8-b4c1-abff61946017	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 08:27:22.160682	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
72b7298f-0e71-480a-a002-36009f091b43	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 09:56:27.148705	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
f54daea6-ecbb-4a15-b541-241e0a0f0371	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 09:56:27.176207	b	e6a73462-6516-415b-b188-7352267c17e7
90931696-22ff-492b-8ec9-37566d1a1e8d	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 09:56:27.198424	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
d30324f9-7025-403a-a240-181146d46f16	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 09:56:27.20936	m	79f034a9-ee01-4de2-9238-549e53bb794f
eb23882d-27cc-4cf8-aaa4-588db93441c8	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 14:08:10.204945	n	e6a73462-6516-415b-b188-7352267c17e7
26d30211-9397-4528-a39c-121dab54391e	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:03.367247	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
dfaf233a-caad-4c58-ba1e-1a27301f673a	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:03.38167	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c6083f02-628b-424e-af76-8382b7b83e45	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:03.431736	nj	79f034a9-ee01-4de2-9238-549e53bb794f
0b9970d2-ad63-43e7-9d66-aa8901a71fdd	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:05:08.358249	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
41b1c9b0-aa29-4bd8-96d3-99ac29aecc24	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:03.817025	h	79f034a9-ee01-4de2-9238-549e53bb794f
6e70cdd5-1682-4e10-9a0d-ab262f043aa5	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:03.822625	d	e6a73462-6516-415b-b188-7352267c17e7
4b8ca3c0-ffb0-4629-9956-a04926d7d38a	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:03.847897	nj	e6a73462-6516-415b-b188-7352267c17e7
ca39c20d-9c11-4160-9dfb-ccb598aaca03	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 07:12:42.822501	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
04471992-830c-498f-818c-6c8c2c2c05a0	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:04.182454	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
ed3a79f4-827a-4d0c-9efa-6f261db134d3	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:04.197126	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
bfb3d94a-fa38-4f99-b3e1-5e4b6b3db1c9	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:04.215192	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
17988198-b593-48b0-842a-46997a5ebe6d	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:04.233253	nj	e6a73462-6516-415b-b188-7352267c17e7
cd13baf2-c83e-446f-983f-59f1942d0eaa	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:07.562897	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
f1b4d5cb-aae8-4eab-9087-4ca2e1387df5	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:07.58021	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
62fa7e52-a407-4749-8151-998899288aa3	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:07.600061	nj	79f034a9-ee01-4de2-9238-549e53bb794f
fbbd70ec-e5b2-4305-b34b-75dd72ef2b80	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-11-24 11:09:04.169766	n	36133c39-09fc-41b6-93f8-590a2eae35d1
95958e02-ec53-4711-ad79-6cdcfb48b053	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-11-24 11:09:03.798799	t	36133c39-09fc-41b6-93f8-590a2eae35d1
daa0d4bf-4283-4c7e-8841-38b1315566eb	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 07:12:42.849804	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
72b48149-fffc-4c2a-9e17-c73419242b61	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-03 07:12:42.951489	d	36133c39-09fc-41b6-93f8-590a2eae35d1
3943eb61-b20a-43da-92c6-fbb64046a61c	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 07:12:42.9871	m	e6a73462-6516-415b-b188-7352267c17e7
5d007892-e32a-45c7-8fed-56e6f71f9fd0	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	t	2025-12-03 07:12:43.028606	nj	79f034a9-ee01-4de2-9238-549e53bb794f
76b7307d-c041-419b-b469-3ce3edafb0ae	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	t	2025-12-03 07:12:42.976317	b	79f034a9-ee01-4de2-9238-549e53bb794f
c968df90-c77e-4ea5-89b8-b3a38897ebe9	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 08:27:22.11474	n	79f034a9-ee01-4de2-9238-549e53bb794f
912effe5-7aba-487e-bfdd-23c782fb6f61	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 08:27:22.136383	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
2338d9f1-cf88-476c-b284-147eb43b268b	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 08:27:22.151401	nj	e6a73462-6516-415b-b188-7352267c17e7
9a6bd6d0-353f-4ae1-9872-7470a6247a25	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 08:27:22.161877	g	e6a73462-6516-415b-b188-7352267c17e7
a9738572-b7b5-4b29-a813-3f553c5d7362	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 09:56:27.148181	nj	79f034a9-ee01-4de2-9238-549e53bb794f
6fca878c-51f2-4ea0-aea2-bfb5725a3eaa	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 09:56:27.178752	b	79f034a9-ee01-4de2-9238-549e53bb794f
64a390ce-e6e3-42c2-92c6-1a88c19446fc	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 09:56:27.205896	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
5f50df90-03de-4635-88b0-12394232497f	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 14:08:10.220991	n	79f034a9-ee01-4de2-9238-549e53bb794f
4652d6fa-a601-4625-8fcf-5eb9c2f396e6	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 14:08:10.241475	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
ae34aa1c-0cbe-4ac8-8829-5da7ca128b07	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 14:08:10.273468	nj	e6a73462-6516-415b-b188-7352267c17e7
f3375da1-83df-46a8-babc-c6fe1ed30a92	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 14:08:10.305255	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
c8672a96-aebe-48cf-86ac-c792d1c630db	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:03.367867	b	e6a73462-6516-415b-b188-7352267c17e7
a9bc5213-12ec-46cc-aab8-4d627d2757b9	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:03.381803	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
a1f7c88d-3a48-430f-8ccb-238802f91be3	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:03.429238	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
044a62f7-6bda-4481-834a-cd0967ea5c0d	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:05:08.359428	d	79f034a9-ee01-4de2-9238-549e53bb794f
eb32d14d-d29b-4a88-a49a-00589d4c7fa1	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:03.815939	h	e6a73462-6516-415b-b188-7352267c17e7
93f20a83-6a78-4cfe-be6b-6371f30e1527	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:03.822397	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
2f2d1eae-f915-4c50-bf06-0babe6fff8fa	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:04.193868	n	e6a73462-6516-415b-b188-7352267c17e7
bdd72684-9a45-436d-a2f3-994aeeeee42e	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:04.199651	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
dca6395d-95b2-4980-94e4-56b5f18e038e	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:04.208908	d	e6a73462-6516-415b-b188-7352267c17e7
467e3047-7882-4859-b252-0d825e536fce	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:07.56234	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
650f2622-1e38-4015-88a2-83e3d92c3c6a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:07.569518	n	79f034a9-ee01-4de2-9238-549e53bb794f
d008bca1-48b5-484a-ad68-db8791220639	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:07.582481	d	e6a73462-6516-415b-b188-7352267c17e7
0b8feedb-fd2f-4d97-bcfa-1943c1ac9bd1	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:07.598421	nj	e6a73462-6516-415b-b188-7352267c17e7
df9cb282-fe72-49ad-86ac-59e7d1e67915	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-11-24 11:09:07.54818	h	36133c39-09fc-41b6-93f8-590a2eae35d1
b57e8d7a-20f5-49b4-85ee-0b0e9c2e350c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-11-24 11:09:03.797613	h	36133c39-09fc-41b6-93f8-590a2eae35d1
d5469e23-347e-4ce9-93a2-9270dea71bac	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 07:12:42.989032	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
5be8e1e1-25ce-47b1-bebf-2e00f736421b	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 07:12:43.023632	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
85196dc5-133d-4556-9b85-8c8cc14cccef	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	t	2025-12-03 07:12:42.839107	n	79f034a9-ee01-4de2-9238-549e53bb794f
10a46570-a188-4786-a21b-ecb04dabdc8d	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-03 08:50:01.096821	h	36133c39-09fc-41b6-93f8-590a2eae35d1
29e55f62-a455-40d6-87ba-73d59abb9934	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 08:50:01.10615	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
4c4f4213-d6a9-4398-9261-cd3beff38ad1	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 08:50:01.125747	n	e6a73462-6516-415b-b188-7352267c17e7
5e74c813-1c0a-4b17-a530-697038665467	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 08:50:01.253656	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
f6a56bae-3464-4cd0-b44b-3ebe3e7de38f	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-03 08:50:01.279021	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
857270a4-2b70-4680-93e9-0f69edf6e1f3	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 08:50:01.296838	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
60404a83-2f26-4dc9-8ac5-feb399770b43	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 09:56:27.224721	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
c3f21309-3f21-40c3-a565-4abf9f431dac	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 14:08:10.274873	nj	79f034a9-ee01-4de2-9238-549e53bb794f
d8c8a5dc-dab0-41d9-943a-e7f6216d3616	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-03 14:08:10.297636	g	36133c39-09fc-41b6-93f8-590a2eae35d1
cc15c199-780a-4902-b004-9edb1f84f774	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 14:08:10.303791	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
289e1f60-6d96-44aa-83e3-3fc7600e32fa	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:03.373628	b	79f034a9-ee01-4de2-9238-549e53bb794f
b3240a90-9d85-452f-85ed-54fb88c888c8	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:03.381929	t	e6a73462-6516-415b-b188-7352267c17e7
89583b08-1080-4f9f-aa02-f47716d80337	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:03.425495	g	79f034a9-ee01-4de2-9238-549e53bb794f
0ab4bb85-ed93-4c09-a46b-a9a5520745d6	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:05:08.365291	m	e6a73462-6516-415b-b188-7352267c17e7
889c3387-10e0-4f54-a57d-7d3dbf8b6e05	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:03.818667	t	79f034a9-ee01-4de2-9238-549e53bb794f
840da7c0-0f7b-4998-b1ef-0388348226f5	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:03.823118	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
205a4307-0219-42f9-a7b9-830a89392ecd	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 07:12:42.857733	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
b04e6edf-0842-42c2-849c-f8a65a43d5d8	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:04.18375	h	79f034a9-ee01-4de2-9238-549e53bb794f
73251f6c-901b-4a9e-a0d5-edbba0465bb3	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:04.20651	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
7264da92-6002-459c-b047-9f2d50ec1534	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 07:12:42.973664	b	e6a73462-6516-415b-b188-7352267c17e7
8014bcf6-a52d-4d5d-a434-3366ade30c70	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:04.230522	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
1324a703-06e0-4ebf-b492-67a1a6ea9740	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:07.564557	h	79f034a9-ee01-4de2-9238-549e53bb794f
11489769-d3db-4917-af11-6b5719038620	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:07.57379	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9bc40490-e11a-4ce0-a003-2256c454d010	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 07:12:42.986917	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
2efcddc5-7a29-406a-ba12-c8e5e1423a9c	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:07.597458	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e4c5a957-c69c-480d-9877-11bd3fb81bd4	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-11-24 11:09:07.592489	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
d57870f0-6886-4c21-a958-5e34add11edd	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-11-24 11:09:04.22663	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
dc6f19c9-f580-403b-a73a-750448431080	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-11-24 11:09:04.177554	d	36133c39-09fc-41b6-93f8-590a2eae35d1
43bf2e31-964e-4ba7-a3ee-2c492f9a5291	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-11-24 11:09:03.800239	b	36133c39-09fc-41b6-93f8-590a2eae35d1
870a3027-f83b-47a8-ad80-821e1ce049c9	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 07:12:43.024349	nj	e6a73462-6516-415b-b188-7352267c17e7
44caaff0-6769-4fd9-a546-ca46f2644765	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-03 08:50:01.101492	t	36133c39-09fc-41b6-93f8-590a2eae35d1
fc68f8d0-8f7d-493f-a730-a06eea0957ed	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 08:50:01.114458	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c3e715f3-2f51-4767-894b-4bb5b66ebe34	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 08:50:01.124537	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
4d5e274e-9100-4987-9c2c-a8b9da131d86	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 08:50:01.254696	b	e6a73462-6516-415b-b188-7352267c17e7
1b3061b9-974c-4b6e-a299-f055887a144c	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 08:50:01.289005	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
5f244bee-e00c-4f25-aa85-8e0ae39110a6	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 08:50:01.303387	nj	e6a73462-6516-415b-b188-7352267c17e7
c92dbf9f-b976-4038-9536-b7881445e239	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 09:56:27.24436	h	e6a73462-6516-415b-b188-7352267c17e7
39e941a5-1c7d-41e2-b49d-5ef9158d5628	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 14:08:10.299622	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
b127f802-fddc-4c42-962a-172c75eec7e8	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:03.374978	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
d0af7322-851c-4336-9110-4652bac86470	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:03.407552	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
68974cbd-5ca1-43b3-a0f3-40a54644e776	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:03.81309	n	e6a73462-6516-415b-b188-7352267c17e7
6ba60672-b303-4c6f-a1c9-d022fa7a27ca	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:03.820372	m	79f034a9-ee01-4de2-9238-549e53bb794f
a014066c-16e7-4c5b-8422-e0d6fc349952	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:03.828772	b	e6a73462-6516-415b-b188-7352267c17e7
64e38f24-c8e6-4b17-b443-0e47f56c1196	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:05:08.370158	m	79f034a9-ee01-4de2-9238-549e53bb794f
f2fedaa1-a17e-4836-8ba5-50a40da90448	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:03.84154	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
ce2b8146-f09a-4acb-b419-a22ee18042ec	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:04.192722	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
60eb6d2c-5bb7-4788-99f1-848ee7502025	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:04.207794	t	e6a73462-6516-415b-b188-7352267c17e7
250f7365-c525-4b09-8c64-2bf85d0f4bd3	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:07.565891	b	e6a73462-6516-415b-b188-7352267c17e7
a68511c3-25f4-49d8-b6e8-a77b6a686859	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:07.571891	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
2d00f7f5-3c07-4929-b6a8-cf0cc5dbfb73	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:07.578151	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
18a9380b-c497-448c-b031-d285ebb266c7	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:07.602171	g	79f034a9-ee01-4de2-9238-549e53bb794f
4bf7e0b4-a90e-4437-94ed-5d6793e5b70e	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-11-24 11:09:03.838039	g	36133c39-09fc-41b6-93f8-590a2eae35d1
a83d69f2-81c8-4c9e-a7c2-6eec3b7fa088	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 07:12:42.859827	m	e6a73462-6516-415b-b188-7352267c17e7
29f91a66-9395-43d1-ae05-508f7e836b60	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 07:12:42.990312	d	e6a73462-6516-415b-b188-7352267c17e7
9758f1cb-9a66-428e-a57a-728a9db926a7	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 07:12:43.019785	g	e6a73462-6516-415b-b188-7352267c17e7
f9e8c7fd-82e2-432b-8a11-769923adfbb8	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-03 08:50:01.102795	n	36133c39-09fc-41b6-93f8-590a2eae35d1
72c41695-b579-4061-8212-96a3c3d7c38d	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 08:50:01.122659	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
8f2d8f45-33b6-4947-a240-243f01f2b35e	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 08:50:01.255956	b	79f034a9-ee01-4de2-9238-549e53bb794f
cfb4b466-021b-4f47-aa0c-ca9651018ece	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-03 08:50:01.275469	d	36133c39-09fc-41b6-93f8-590a2eae35d1
1ed3e8f1-64a0-41ea-a3b7-2e3613cc30c1	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 08:50:01.287716	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
fda1a086-dffd-496a-aef9-184db986d31c	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 08:50:01.305172	nj	79f034a9-ee01-4de2-9238-549e53bb794f
c1896b3f-1a97-4e7a-a422-7c21691e47d1	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 09:56:27.256581	h	79f034a9-ee01-4de2-9238-549e53bb794f
487a485c-de1f-469a-9962-7edd153d3c1c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-03 14:13:46.555036	h	36133c39-09fc-41b6-93f8-590a2eae35d1
d3ce87a4-413e-427f-8ba9-ca26b4cd71bb	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 14:13:46.559779	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
b8ded1a5-3da0-4515-aab7-e0b9a821ab5f	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 14:13:46.692062	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
dd21e4b8-126c-4d30-ada5-670c9f797069	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 14:13:46.77983	m	e6a73462-6516-415b-b188-7352267c17e7
ac8fd604-8090-4bcb-8bd9-334f8f6eb622	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 14:13:46.792672	t	79f034a9-ee01-4de2-9238-549e53bb794f
dceb922f-3588-4922-a323-27c8d20ba65f	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 14:13:46.81024	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
33560139-0eb1-4930-a0f6-53fb52b69d71	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 14:13:46.839635	g	79f034a9-ee01-4de2-9238-549e53bb794f
2089c3c9-1151-4a0a-a6a5-e9533e5e2a17	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:03.376509	h	79f034a9-ee01-4de2-9238-549e53bb794f
1bf5ad4c-5ffc-49fb-b0d3-5a566108f9cc	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:03.383178	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
4d56061e-2046-48fc-8f43-0e4eda1a4196	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:03.408825	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
2ea08269-3715-46cb-95bb-ddd8e119e1bd	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:03.423211	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
2985b052-fc82-46c7-a714-cf4744479981	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:03.813971	n	79f034a9-ee01-4de2-9238-549e53bb794f
ea3eff8c-b3f2-4186-973f-90b973c1c212	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:03.820146	m	e6a73462-6516-415b-b188-7352267c17e7
8b8e01f3-6c69-45cb-9196-f8523244e678	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:03.827949	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
a64af77a-6163-4dbe-805c-9abedbf29ff9	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:03.843231	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
4a12e4cb-3caa-46a6-bbbf-70c8f819c82c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:04.195835	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
6860a99d-eca2-4163-95c8-fa37c2284d88	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:04.20223	b	79f034a9-ee01-4de2-9238-549e53bb794f
cb26f5b1-96fb-46f1-80e2-e0b5e8af934d	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:04.216166	m	e6a73462-6516-415b-b188-7352267c17e7
b1d3e5f0-2f7c-47a1-b977-44824356f80f	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:04.232455	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
8315a7aa-fd1c-4b7b-bf70-06b104c64c22	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:07.563653	h	e6a73462-6516-415b-b188-7352267c17e7
c0e11121-393e-41d4-9857-e17826342d61	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:07.581269	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
1c206ff1-ff27-4d38-82e6-0f463557e7ca	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:07.596527	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
32deef0c-d214-47da-8cbf-22c7606efab0	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-11-24 11:09:07.593148	g	36133c39-09fc-41b6-93f8-590a2eae35d1
64581cbe-a8d8-49be-b43c-48d497018851	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:33.427409	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
fe9198e5-09ba-46e6-a4d0-6cd36a147b97	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:33.432882	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
aced7427-129a-4e07-a8e2-c577051a4f94	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:33.515785	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
c55f2c86-915f-44b2-92aa-26f654ba2213	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:33.535193	b	e6a73462-6516-415b-b188-7352267c17e7
9f5bbf80-132e-42c3-8f11-3f0e94f585ea	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:33.613981	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
32066c10-237a-4dfe-a7de-d37eced63a02	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:36.720185	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
620c7393-b4b5-4a63-86f1-3e59dba961d4	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:36.739586	t	e6a73462-6516-415b-b188-7352267c17e7
bfc8fbb9-e270-475d-8655-7859bd18ba32	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:36.750013	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
46a02cc4-2d67-49d4-b096-6733e562fdc9	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:36.777158	d	e6a73462-6516-415b-b188-7352267c17e7
7ee82e6a-d166-4ed0-b6a0-48fbef162c3e	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:36.797566	g	79f034a9-ee01-4de2-9238-549e53bb794f
b83b338a-ac05-4c9e-ae71-62e3c4a7511f	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-12-01 09:07:36.70472	n	36133c39-09fc-41b6-93f8-590a2eae35d1
7497ae5c-e2e9-4d82-8691-9f57bd031c15	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-12-01 09:07:33.607472	d	36133c39-09fc-41b6-93f8-590a2eae35d1
b081b4fc-3dbf-46ad-a668-b049661be90f	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-12-01 09:07:33.413837	h	36133c39-09fc-41b6-93f8-590a2eae35d1
712529ce-6d1a-404f-9411-34125bbba7a7	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-12-01 09:05:07.996489	h	36133c39-09fc-41b6-93f8-590a2eae35d1
ba6d1ed3-2a7d-4be3-ac82-200fc0de0e88	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:38.651436	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
a8c19356-4112-443e-b475-3836f57dcf88	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:38.664468	n	e6a73462-6516-415b-b188-7352267c17e7
231a6f5b-5894-4853-92fc-2504d9297fae	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:39.397048	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
2c2f25ad-0e1f-4b65-a449-881fe0f09cc4	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:39.409777	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f27b5c3d-9421-415d-977c-f4b6f1d393d7	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:39.439717	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
746bf200-cb7b-47ed-b7a3-37adab1a8d92	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-12-01 09:07:39.430431	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
b2dc60d0-55bf-490c-9d0d-7c4a8b58d488	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-12-01 09:07:38.624501	n	36133c39-09fc-41b6-93f8-590a2eae35d1
2cce11ea-1281-4940-ae8e-9f6a8d91993c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:47.370667	h	e6a73462-6516-415b-b188-7352267c17e7
0a051074-b0c6-4770-97b8-11ff3399854e	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:47.388317	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
6f6d9ef5-eb9f-4922-a859-c85426403ea0	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:47.407495	t	e6a73462-6516-415b-b188-7352267c17e7
2e7c3073-5da4-41fe-a165-7ee4af09bfac	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:47.423972	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
bb8a24cb-9f53-45fb-9d90-6d4bafe50681	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:47.442645	m	e6a73462-6516-415b-b188-7352267c17e7
d93c175a-abc9-4d8a-8c47-962abf19dfac	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:47.461692	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
b069ec65-d101-4de8-8067-7443f3ee0cca	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:47.487774	nj	e6a73462-6516-415b-b188-7352267c17e7
7ffc416a-91d9-4590-a7a0-aac4df2cd438	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:47.508448	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
2c6e1735-7e55-482d-9678-550c84a6e336	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-03 07:25:00.025918	h	36133c39-09fc-41b6-93f8-590a2eae35d1
54229273-d477-4998-9fc2-367a14e0668d	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 07:25:00.033464	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
4fdf2d50-8939-48f9-9a09-6294978de086	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 07:25:00.165548	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
e0be03d6-6adc-48c7-825f-b7c25475357d	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-03 07:25:00.232545	m	36133c39-09fc-41b6-93f8-590a2eae35d1
d8d45aa0-a549-4a20-a96f-c306674a2162	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 07:25:00.241724	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9e7ec4bb-3dc9-41ce-92a4-906ecd90bca8	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 07:25:00.281444	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
d32a5c31-6052-4670-8cda-1e000052e5ba	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 07:25:00.307827	nj	e6a73462-6516-415b-b188-7352267c17e7
a2028593-3346-499f-874a-a8d174a8bae9	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:03.377296	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
7ace5b8f-bbe9-4641-aa86-449400f272a2	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:03.383317	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
ce9f14ba-c9c3-41ec-88ad-ed2751214054	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:03.815294	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
d1898c0c-7891-4fc1-80a1-ac16e4124c34	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:03.822182	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
7116d645-1ca5-480a-9350-3adfdf9bda38	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:03.848744	nj	79f034a9-ee01-4de2-9238-549e53bb794f
11b9a85e-1830-4284-92a1-9c5d864ff59b	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:04.196946	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
e53dafce-52d8-40ea-9049-46102f7c4f10	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:04.209443	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
9885fa85-9e43-4c4a-b1d5-c591d4f97573	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:04.239199	g	79f034a9-ee01-4de2-9238-549e53bb794f
4cea5730-a4e3-42a5-a102-17996fdcde40	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:33.43166	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
7e4a39d7-7b11-4229-ba3c-450531c47aac	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:07.567296	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
df693969-126a-4631-ac1f-3c627f403915	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:07.572086	m	e6a73462-6516-415b-b188-7352267c17e7
299b651c-ee72-4b00-8e24-7b5f5b208f1e	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:07.578489	t	79f034a9-ee01-4de2-9238-549e53bb794f
b724be6b-277e-4b7b-9e09-eae1bd64bd8f	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:07.600754	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
f6db5a8c-3b6c-45bb-af6c-21fa6f11b888	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-11-24 11:09:07.551394	n	36133c39-09fc-41b6-93f8-590a2eae35d1
63564f5d-6d54-4fae-9362-3478c689dfb0	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-11-24 11:09:04.172817	h	36133c39-09fc-41b6-93f8-590a2eae35d1
0972765d-0167-44d8-b0a0-535161cad9d8	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:33.516916	t	e6a73462-6516-415b-b188-7352267c17e7
8fc03dfe-968c-4d65-ae1d-e78e62db8785	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:33.540851	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
e180366c-6f0f-4382-a8af-161f70e1385c	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:33.592297	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
b7886042-e2eb-482b-92ff-cabc2d8b3153	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:33.616545	d	79f034a9-ee01-4de2-9238-549e53bb794f
ad9ef277-9edf-4c5e-ac72-5b9ebefa460f	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:33.632555	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
dccbdacf-90f3-4c64-b744-bebf73f01247	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:33.645393	g	e6a73462-6516-415b-b188-7352267c17e7
d4a980bb-afdb-40f9-9b09-bcbc26d0e3fa	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:36.713817	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
0b0fe4a4-8eef-43e3-b7f8-aa828bc00367	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:36.730643	n	79f034a9-ee01-4de2-9238-549e53bb794f
bb93de85-8537-4fd3-be7d-4a4f00b8fe21	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:36.743814	b	e6a73462-6516-415b-b188-7352267c17e7
f67ab842-6a10-43d5-a432-7331137b0c19	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:36.800484	nj	79f034a9-ee01-4de2-9238-549e53bb794f
711605ab-8083-4335-9716-aa0735345dee	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-12-01 09:07:36.70244	h	36133c39-09fc-41b6-93f8-590a2eae35d1
ca8e2af8-a145-4621-9e37-ec2a04890a01	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-12-01 09:07:33.575149	m	36133c39-09fc-41b6-93f8-590a2eae35d1
490eeb65-a0c6-4ea5-9264-7d43fd1d83b7	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-12-01 09:07:33.423908	n	36133c39-09fc-41b6-93f8-590a2eae35d1
9f32e33a-c52c-4235-ae98-e1a11ab1d795	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-12-01 09:04:44.761102	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
1b544900-68c8-4bb1-9c8e-7f1ca8ed0da4	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:38.632576	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
cf9b8e5c-c1e4-4bab-860d-4f0117c43d0b	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:38.658154	t	79f034a9-ee01-4de2-9238-549e53bb794f
d1dbe9d0-3c1b-44c4-bc76-e7d4875c1c85	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:38.675148	m	79f034a9-ee01-4de2-9238-549e53bb794f
b9a3e5cb-9104-46c1-be09-79d169115734	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:38.697052	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
d973787a-20e8-4169-b3bc-365cd6cdb88a	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:39.394645	h	e6a73462-6516-415b-b188-7352267c17e7
52cd4d19-c2ba-4ad9-b09d-cf2c024b2770	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:39.401602	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
6e4f7913-8528-43b1-b630-19090f717568	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:39.423163	d	79f034a9-ee01-4de2-9238-549e53bb794f
fac0e680-01a9-4b6c-a783-a21e3297db2d	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:39.435045	g	e6a73462-6516-415b-b188-7352267c17e7
75666452-96f6-4b3e-b03e-e09e50be9dfc	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:39.440765	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
b485499b-8d02-4cdf-8e56-d97a9885cc5d	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-12-01 09:07:38.693832	g	36133c39-09fc-41b6-93f8-590a2eae35d1
1386f2df-5f14-4b76-8b0d-373ad7c94421	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-12-01 09:07:38.623171	h	36133c39-09fc-41b6-93f8-590a2eae35d1
3d1fd648-1291-4441-878c-4d68afdafa5f	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-01 09:07:47.384456	n	36133c39-09fc-41b6-93f8-590a2eae35d1
f00a3f2a-9a4b-43e8-8e18-0a056fe8b4c0	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:47.387136	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
77a6893c-e1fe-4d54-abbe-56830c02fb0e	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-01 09:07:47.419524	b	36133c39-09fc-41b6-93f8-590a2eae35d1
a0fbbacd-e63e-467e-bcae-86ca46fa7ab1	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:47.423096	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
d45098a1-08a4-48ad-af37-2eeea563fc1a	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-01 09:07:47.457839	d	36133c39-09fc-41b6-93f8-590a2eae35d1
73626775-2682-41c5-8160-6c439c149d3d	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:47.460617	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
2ebc30f0-0cc8-4242-b6c8-5087a7d39d34	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	t	2025-12-01 09:07:47.489847	nj	79f034a9-ee01-4de2-9238-549e53bb794f
24395f57-6eec-46a7-8565-533943663686	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	t	2025-12-01 09:07:47.443548	m	79f034a9-ee01-4de2-9238-549e53bb794f
732c8ffa-e074-4602-ad54-4d33877ea767	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	t	2025-12-01 09:07:47.408351	t	79f034a9-ee01-4de2-9238-549e53bb794f
eb8cb96e-5172-4175-8998-803c3f827487	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	t	2025-12-01 09:07:47.371905	h	79f034a9-ee01-4de2-9238-549e53bb794f
7aaef575-e94c-4d08-8ef5-2208ef1dd38d	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 14:13:46.611252	h	e6a73462-6516-415b-b188-7352267c17e7
e52c68b6-68b2-47c4-b3b8-32e449d47238	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-03 14:13:46.68707	n	36133c39-09fc-41b6-93f8-590a2eae35d1
cf6d5036-5d62-48d1-b7ca-92f273be1794	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 14:13:46.690764	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
b53154b9-d01a-4e90-b3ae-de3bf370f6f1	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 14:13:46.781247	m	79f034a9-ee01-4de2-9238-549e53bb794f
a5e8ce33-7d61-4acb-a843-22c10f84efe5	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:03.378557	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
1be22996-a9e9-4130-adf7-ee2ae83abef4	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:03.383533	m	e6a73462-6516-415b-b188-7352267c17e7
239e4156-bd90-470d-bd13-de555e34bf94	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:03.430575	nj	e6a73462-6516-415b-b188-7352267c17e7
411d39a3-1e82-40e6-98b1-cea96f268c07	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:03.801801	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
a5a48d4c-8b6b-4328-8c9e-525ba7a681cc	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:03.818535	t	e6a73462-6516-415b-b188-7352267c17e7
afa68fd9-f631-42f2-ba39-e78f4b0aefc1	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:03.822947	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
31a6e6f9-c924-4895-941e-20a521306c3f	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:03.847135	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
741da17e-f461-41aa-9158-7dbd147b0a21	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:33.513544	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
7f76aa24-f283-4a5b-b01e-1d913b3f218a	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:04.183534	h	e6a73462-6516-415b-b188-7352267c17e7
443d154c-fe7c-4e2a-9d8e-738b20b9a410	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:04.210662	d	79f034a9-ee01-4de2-9238-549e53bb794f
2f8c3d0a-279c-4a8d-9cb6-2abda1945e26	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:04.236437	g	e6a73462-6516-415b-b188-7352267c17e7
972e6af1-55ea-40a6-9a4c-8314eddf4d49	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:33.535623	b	79f034a9-ee01-4de2-9238-549e53bb794f
77b16b9c-f8dc-4f52-a64b-4ba5eb1aa0b2	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:07.566636	b	79f034a9-ee01-4de2-9238-549e53bb794f
b7f92bab-96b9-4f6b-9118-183d669f70e3	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:07.571948	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
07852dbf-fd88-4c06-ba0a-2f7300c620c8	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-11-24 11:09:07.550568	b	36133c39-09fc-41b6-93f8-590a2eae35d1
b0a8d729-787a-41f6-9a02-46d0466dd876	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-11-24 11:09:04.174194	t	36133c39-09fc-41b6-93f8-590a2eae35d1
8f24be77-5684-405a-b942-a840b8007e0a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-11-24 11:09:03.795699	n	36133c39-09fc-41b6-93f8-590a2eae35d1
91ceb534-41e0-4c6c-a7c4-28bdb11ad6bf	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:36.73447	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
4a489b91-a079-4709-bf06-e2126bc80b8a	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:36.763836	m	79f034a9-ee01-4de2-9238-549e53bb794f
791aad8f-c352-44d4-9ef4-79e9f25062c2	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:36.798415	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
a119191f-0491-4c5b-92b7-081df059b2a7	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-12-01 09:07:33.501189	t	36133c39-09fc-41b6-93f8-590a2eae35d1
a0049080-9a62-4c72-bd70-6ce24c135f36	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:38.657797	t	e6a73462-6516-415b-b188-7352267c17e7
11ccb375-f21f-4759-a028-4c8f11692174	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:38.673359	m	e6a73462-6516-415b-b188-7352267c17e7
3da779f0-f3db-41be-ba9a-49155d410227	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:38.70465	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
cf9ddfd9-b256-4f24-8ac4-fab6d0a1f0b6	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:39.3987	m	79f034a9-ee01-4de2-9238-549e53bb794f
95d3c1dc-044d-4aca-999d-bfc9e3483913	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:39.408026	t	e6a73462-6516-415b-b188-7352267c17e7
c072fc78-b597-439b-ab45-5d8579f05502	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-12-01 09:07:39.377551	b	36133c39-09fc-41b6-93f8-590a2eae35d1
5002d823-1611-4c3c-9997-31b9e2009552	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-12-01 09:07:38.627314	t	36133c39-09fc-41b6-93f8-590a2eae35d1
5b2d7171-700a-4c1b-a560-45de115c3257	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-03 07:25:00.161323	n	36133c39-09fc-41b6-93f8-590a2eae35d1
cbd460e8-4ad6-48f4-b6d8-94c53bee748f	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 07:25:00.164764	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
868146bd-564d-4c34-aad0-30f63e3d833e	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 07:25:00.230064	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
52de13d0-7998-49c7-98a8-0a29f1c4bf56	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 07:25:00.245423	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
eb88959a-0a12-47b2-b798-bb13a4f4fb85	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 07:25:00.327428	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
9bcb6341-5ac6-49fa-a86f-aa187dd11f90	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	t	2025-12-03 07:25:00.285101	d	79f034a9-ee01-4de2-9238-549e53bb794f
cf5301d3-8ff3-4162-a758-2cd0c6399f82	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	t	2025-12-03 07:25:00.096386	h	79f034a9-ee01-4de2-9238-549e53bb794f
1adce451-dd2a-4368-9da7-e894b1a1a746	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 08:50:01.175095	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
cb5402ce-44b5-46d7-937e-b4a2b9452f74	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 08:50:01.252359	m	79f034a9-ee01-4de2-9238-549e53bb794f
a63e9733-815c-4605-8cc7-f6254cfad01b	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-03 08:50:01.282387	g	36133c39-09fc-41b6-93f8-590a2eae35d1
0314a459-2d4c-4274-a91d-99c99aabde75	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 08:50:01.306489	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
609f5149-0cdb-44a5-8d2c-0e635f76edc5	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 09:56:27.254352	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
a1946d83-e84d-4233-a629-80b88355fd2b	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 14:13:46.717737	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
2d35d3ec-1bf4-42c8-8b26-52a889ef4ba0	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-03 14:13:46.771219	m	36133c39-09fc-41b6-93f8-590a2eae35d1
44a9c22e-6199-439b-8980-b7354f1e658b	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 14:13:46.776474	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
76566e4b-913b-489c-bad0-6ed57e846cec	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 14:13:46.791225	t	e6a73462-6516-415b-b188-7352267c17e7
e815fd7d-25f8-4991-b4e5-54197ffb9ef3	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-03 14:13:46.802636	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
7ae08dd4-74eb-4147-8ef1-00d3b8d2446d	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 14:13:46.807166	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
4517e7e3-ed14-4767-9a8c-cef40605ef4f	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:03.378816	n	e6a73462-6516-415b-b188-7352267c17e7
d491cc32-2ce5-4abe-8b42-0a8df3e9bea1	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:03.384605	m	79f034a9-ee01-4de2-9238-549e53bb794f
56d85cd8-b244-4eb8-8ef5-ec398ccf8bc7	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:03.427796	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e3da9bc8-f58a-463c-808d-15d2936909f0	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:33.533424	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
998019e9-0e16-45b8-82fa-29024c62f1d1	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:03.819614	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
5b0e21b7-6312-4251-ab4c-cb86b6d4c6ef	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:03.826603	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
dfe6a546-49af-4627-a6df-1e1fbd56ad83	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:36.724322	h	79f034a9-ee01-4de2-9238-549e53bb794f
251e9bd6-b2c2-4b7a-9752-bd36f016da44	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:03.846163	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
54143712-e07f-4d3f-a986-9068a78ee896	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:36.741515	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
e72f3d28-08c3-4c69-834c-f403d8630b5d	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:04.197282	t	79f034a9-ee01-4de2-9238-549e53bb794f
d9e19b13-051c-4e5f-b3e8-574d08539b47	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:04.214211	m	79f034a9-ee01-4de2-9238-549e53bb794f
90d56876-6452-4409-9533-39ce3a28fbd0	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 11:09:04.234256	nj	79f034a9-ee01-4de2-9238-549e53bb794f
f2031695-f995-483b-be7a-3ce778c8b9e4	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-12-01 09:07:33.508072	b	36133c39-09fc-41b6-93f8-590a2eae35d1
88745363-d57d-49b5-9c54-074478edcd2d	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:07.568064	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
b84660a0-16d6-4571-b932-68fbd698436d	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:07.574044	t	e6a73462-6516-415b-b188-7352267c17e7
e6a5788d-ab98-4a96-b664-98a77baec371	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-11-24 11:09:07.555421	d	36133c39-09fc-41b6-93f8-590a2eae35d1
568e8623-dd9f-46a9-9569-885ffcbbf30e	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-11-24 11:09:04.175854	b	36133c39-09fc-41b6-93f8-590a2eae35d1
ca26fab2-db49-4a90-8baa-0a9ce009f042	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-11-24 11:09:03.839422	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
29fc776c-ebd9-4a2f-86f8-90bc72897b8e	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-11-24 11:09:03.796646	d	36133c39-09fc-41b6-93f8-590a2eae35d1
973c39d3-01ca-4a1e-8896-b3286785e260	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-11-24 11:09:03.417068	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
734e8d21-a84f-4001-9a5f-30c867a6985c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:38.639121	h	79f034a9-ee01-4de2-9238-549e53bb794f
91a5e910-c80f-43c1-9026-b3fee7f1e6ae	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:38.66003	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
dfb620f0-65a5-45d8-8826-ace2e454d9b0	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:38.665829	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
84e9b4ea-d732-4e02-958d-4ef317013758	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:38.70583	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9922d56a-c2b4-47ac-af52-ee051e1bd5e1	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:39.398862	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
80e7c877-3656-45e3-a6bd-9a93c2a85f94	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:39.41391	t	79f034a9-ee01-4de2-9238-549e53bb794f
dab5ba2c-ad3b-4960-8e49-fb7d248c6ba5	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-12-01 09:07:39.378921	t	36133c39-09fc-41b6-93f8-590a2eae35d1
9a6acb29-23de-4741-80fc-3fe65989da50	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-12-01 09:07:38.694991	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
f3f51aac-a4b3-410c-94aa-d0bfcaac2871	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 07:25:00.191143	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
71268325-e7ed-4929-8f84-2226ae21f5f8	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-03 07:25:00.226222	b	36133c39-09fc-41b6-93f8-590a2eae35d1
3643fc8c-3ff8-4d02-a871-e0ea70611839	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 07:25:00.236062	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c63531fd-007d-44c6-976e-70c21476da1c	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 07:25:00.283695	d	e6a73462-6516-415b-b188-7352267c17e7
0d7841bd-d2cb-4f5a-ac97-896badcf3618	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 07:25:00.305135	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
4efb9f39-40ff-4126-9f37-c9622cb55e99	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	t	2025-12-03 07:25:00.243649	m	79f034a9-ee01-4de2-9238-549e53bb794f
b9220979-5fda-4a87-a995-6c3bac15f00a	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 08:50:01.195232	h	e6a73462-6516-415b-b188-7352267c17e7
933e5a7f-d456-4e6d-a191-2af7e5cb2fb1	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-03 08:50:01.237877	m	36133c39-09fc-41b6-93f8-590a2eae35d1
67ff1cb9-e7e0-45bb-8d0e-e5cfcd4da9b3	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 08:50:01.245217	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
583a1225-5d4c-4bad-b057-772685204222	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 09:56:27.266642	n	e6a73462-6516-415b-b188-7352267c17e7
c1338cc8-f3e0-4fe4-b44a-c6118d69ad5d	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 14:13:46.737062	h	79f034a9-ee01-4de2-9238-549e53bb794f
52e90691-290e-4307-9e03-7891e1e35154	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-03 14:13:46.774148	t	36133c39-09fc-41b6-93f8-590a2eae35d1
fa3604de-9d58-44c6-b663-eb81dd73f6b1	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 14:13:46.788069	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
5bbbd192-d438-4d1d-ac89-c7bd65498689	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 14:13:46.819254	nj	79f034a9-ee01-4de2-9238-549e53bb794f
fe084d66-aeed-484d-81b2-b3c95b51eb0b	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 14:13:46.836171	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
7dc0dabb-d30e-4ec0-9baa-326c444c4d07	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:03.38046	n	79f034a9-ee01-4de2-9238-549e53bb794f
fd8fa011-5a4d-4c89-8a35-afe7cb495e0a	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 11:09:03.389077	h	e6a73462-6516-415b-b188-7352267c17e7
e2473fc0-4d1a-4342-ab18-29af6fd523bd	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:03.398476	d	e6a73462-6516-415b-b188-7352267c17e7
eeda23f9-4b26-4644-b0f6-440d409729a3	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:03.424455	g	e6a73462-6516-415b-b188-7352267c17e7
482b304a-5b10-4d4f-ac12-1edf11bd225c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:33.55985	h	e6a73462-6516-415b-b188-7352267c17e7
f1ff3c60-badd-41ee-bb6f-a6dcf950efe4	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:03.817837	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
fc290026-f50e-450f-a095-b4d9e1ba86ba	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 11:09:03.822795	d	79f034a9-ee01-4de2-9238-549e53bb794f
93294b7d-0784-4239-bb57-d4a4bd69252f	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:03.844734	g	79f034a9-ee01-4de2-9238-549e53bb794f
c9428204-eccf-4a7c-bc35-2d4fa5a780ae	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 11:09:04.200757	b	e6a73462-6516-415b-b188-7352267c17e7
a8ce7546-b060-4684-a5e5-c5b390a9167f	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:04.213953	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
46b7691a-0281-4b00-89b9-e679f139db6c	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:04.237842	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
422d808b-c2c0-4882-921f-5b6285f9a7a1	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 11:09:07.568178	n	e6a73462-6516-415b-b188-7352267c17e7
8350289e-0c9b-4e55-87f2-2c0b4e95ab52	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 11:09:07.572236	m	79f034a9-ee01-4de2-9238-549e53bb794f
75d141cb-11dc-44cd-84fb-b44fd825b994	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 11:09:07.578367	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
79a03415-466e-4ffb-bf0a-d38e2054be41	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 11:09:07.601362	g	e6a73462-6516-415b-b188-7352267c17e7
72ea2fde-049f-470f-a928-b83ee27130bb	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 14:35:21.082857	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
5b14bd5e-1008-438a-9ebb-af6320963ba4	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 14:35:21.105471	t	79f034a9-ee01-4de2-9238-549e53bb794f
62b46813-f499-4163-9666-07e937d696e3	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 14:35:21.105164	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
d456745e-a1af-47fa-a4d1-d1ea2516dbc6	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 14:35:21.126089	t	e6a73462-6516-415b-b188-7352267c17e7
5e9b539f-faa4-41b7-948e-a88d1bd4ceeb	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 14:35:21.132019	n	e6a73462-6516-415b-b188-7352267c17e7
06e88ad8-75d0-4d21-beb8-84060c4ac0ab	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 14:35:21.132318	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
7b167d03-7029-4f32-9266-c5d0318e4aba	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 14:35:21.132783	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
64b02967-72b7-47cd-87c4-125558f4eba7	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 14:35:21.134485	n	79f034a9-ee01-4de2-9238-549e53bb794f
a1deb9d2-708d-4ab4-b209-8fbb75ca7ec2	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 14:35:21.191431	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
fcffd877-e5e5-4214-b4ae-35c201d2dcb1	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 14:35:21.195293	h	79f034a9-ee01-4de2-9238-549e53bb794f
0a3f1f46-81c7-4c8d-8592-becb899c0002	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 14:35:21.198685	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
72e91791-6651-4d95-b2d1-c6f7ab0bb22e	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 14:35:21.201205	h	e6a73462-6516-415b-b188-7352267c17e7
aca7a5d9-e4f0-4e59-8636-c8ad5709ac0a	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 14:35:21.23107	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
b5fee12d-b64b-4cb9-b195-0fbcfc950350	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 14:35:21.246988	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
737c0589-823b-4670-937a-9fc7f07cc0e6	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 14:35:21.251064	nj	e6a73462-6516-415b-b188-7352267c17e7
08cdff1f-6ff4-4220-a60f-c58e34b770e0	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 14:35:21.254166	nj	79f034a9-ee01-4de2-9238-549e53bb794f
3de2e907-8683-45c6-83d4-7dc95659ce71	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 14:35:21.301524	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c27f88c5-b241-49e7-ad0a-4cbe4e2ca297	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 14:35:21.305737	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
0143237e-d1e6-495b-a842-bd53e50cc864	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 14:35:21.309631	m	e6a73462-6516-415b-b188-7352267c17e7
f0c7e9f9-d019-4143-b7cb-9ee2142ec45c	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 14:35:21.319572	m	79f034a9-ee01-4de2-9238-549e53bb794f
bf1cee6b-eba6-4ef1-b22b-bd6fd125cd5d	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 14:35:21.315048	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
fb177b7d-0797-47a1-a9d2-42389bc818e7	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 14:35:21.338752	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f005bc6f-5f91-4110-a529-5804b11d77a6	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 14:35:21.343147	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
58c7a661-4770-47af-9be4-d267de359205	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 14:35:21.345462	g	e6a73462-6516-415b-b188-7352267c17e7
dff1259a-7eb4-4b62-a965-4830feed9483	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 14:35:21.348276	g	79f034a9-ee01-4de2-9238-549e53bb794f
5f0d68cf-703e-48ec-b7bb-d18786019d80	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 14:35:21.354054	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
91c0c805-87de-4d41-9369-aef7e83b22b8	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 14:35:21.356571	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
bb6aff4a-ab70-4926-9e13-16680902912a	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 14:35:21.359698	d	e6a73462-6516-415b-b188-7352267c17e7
607803d1-4837-4e71-a44c-eeaa1dac7b7b	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 14:35:21.363434	d	79f034a9-ee01-4de2-9238-549e53bb794f
febf4746-d91f-4a64-8e75-884d33171e3d	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 14:35:21.377051	b	79f034a9-ee01-4de2-9238-549e53bb794f
88d15b21-fae0-4a78-bc64-0639195ddc7f	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 14:35:21.381925	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
4f22a507-0768-4123-935e-a09d8805525f	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-11-24 14:35:21.326056	d	36133c39-09fc-41b6-93f8-590a2eae35d1
e15974d0-6fe0-4215-bf58-b7771881e18a	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-11-24 14:35:21.28278	m	36133c39-09fc-41b6-93f8-590a2eae35d1
29815bbd-5e0a-4758-8893-7a8a205b4b38	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-11-24 14:35:21.205181	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
bd5ea1ac-3cff-4be6-86de-f3ac4d4e44c9	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-11-24 14:35:21.180668	h	36133c39-09fc-41b6-93f8-590a2eae35d1
8de6adcf-3995-46d1-8e21-051702bde95c	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-11-24 14:35:21.069868	n	36133c39-09fc-41b6-93f8-590a2eae35d1
0967e43d-2d81-43ce-aa5c-8625555f07f8	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-11-24 14:35:21.059125	t	36133c39-09fc-41b6-93f8-590a2eae35d1
cc5ee80c-a65e-4bb9-88cc-d6b42fc91021	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-11-24 14:35:21.048607	b	36133c39-09fc-41b6-93f8-590a2eae35d1
047b3ba5-25e8-4cec-b904-a3f6886161a0	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-11-24 11:09:07.552677	t	36133c39-09fc-41b6-93f8-590a2eae35d1
1d57a1ba-dcd0-4780-8842-32ad6257745a	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-11-24 11:09:04.178718	m	36133c39-09fc-41b6-93f8-590a2eae35d1
99fa9c13-7f6d-481d-baf3-75275130b811	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-11-24 11:09:03.799438	m	36133c39-09fc-41b6-93f8-590a2eae35d1
d5f4a03f-84a4-4cfe-8585-b7f40822d339	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 14:35:21.389651	b	e6a73462-6516-415b-b188-7352267c17e7
bface09a-aa8f-416c-b25d-2ec30e273388	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:33.561596	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
efe21d12-767a-4f07-a6ad-8d0ae823832a	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 14:47:27.493333	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
1159b9be-b3b1-4b2e-a97c-923f4736a207	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 14:47:27.540723	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
7ca0ea3e-2809-46de-be39-3067e89ce7b8	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 14:47:27.54777	h	e6a73462-6516-415b-b188-7352267c17e7
63fab690-2a5e-4dd0-b586-e1d2346d6cf0	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 14:47:27.656446	h	79f034a9-ee01-4de2-9238-549e53bb794f
42326759-48c3-454c-8be0-d925d0665592	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:33.596634	m	e6a73462-6516-415b-b188-7352267c17e7
cb9d02b7-11e7-4241-8030-cbfc219a0b1f	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 14:47:27.672994	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
42cb4b94-59dc-40cc-8929-8c05e0b331d0	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 14:47:27.673775	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
f420fdcd-1dc4-466e-aa41-f128c8219310	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 14:47:27.67506	n	e6a73462-6516-415b-b188-7352267c17e7
49eb84f3-aa06-4c90-a0d1-52005a155183	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 14:47:27.675977	n	79f034a9-ee01-4de2-9238-549e53bb794f
eaea8b50-968e-4390-94e3-886cae615d57	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:33.631601	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
840407c3-ff9e-49a4-85f9-c1c3391b3f05	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:33.643799	g	79f034a9-ee01-4de2-9238-549e53bb794f
3be0cae6-a040-4f3a-88fc-739937f889bb	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 14:47:27.693907	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
8442d565-93c3-4544-94b2-a428b4342dcf	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 14:47:27.694827	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
28fa7709-378c-478c-ae2f-770f54515e09	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 14:47:27.697735	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
124ae8b4-4348-4304-b49d-d3bce3d0732c	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 14:47:27.701146	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
d3f282cb-81fc-484b-97f3-611fa98f7772	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 14:47:27.702142	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
7b669399-e26d-43a4-b88d-f6e5b8959e9d	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 14:47:27.703227	d	e6a73462-6516-415b-b188-7352267c17e7
25021b9a-875d-483f-a4be-e5daae5e99f5	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 14:47:27.705035	d	79f034a9-ee01-4de2-9238-549e53bb794f
46db0e6f-e864-4b1c-8b73-f28195e6c46e	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 14:47:27.724665	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
3fc1c198-e913-44f0-a139-266a103ce76c	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 14:47:27.725438	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
7d81040d-35b3-4305-a57a-3c95e26f1a9c	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 14:47:27.726465	nj	e6a73462-6516-415b-b188-7352267c17e7
1381b443-b146-415e-9275-d5cb2cda839c	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 14:47:27.727309	nj	79f034a9-ee01-4de2-9238-549e53bb794f
a3bfdf01-db2b-4eb4-9bba-198997314c45	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:36.732757	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
80e0bafd-d061-46c0-98f9-159ec6abaebb	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:36.761307	m	e6a73462-6516-415b-b188-7352267c17e7
1125711f-3490-4c07-a9e4-df0984f382b7	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 14:47:27.750411	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
bcf0fbfc-4c88-4fb6-9431-a9a67104385c	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 14:47:27.755324	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
739505a2-c0e4-4964-bb60-4d90d9670877	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 14:47:27.756461	g	e6a73462-6516-415b-b188-7352267c17e7
11481777-0274-41de-b961-76f6db6a0e2e	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 14:47:27.757641	g	79f034a9-ee01-4de2-9238-549e53bb794f
8911d77f-1666-4fd7-aad2-e8ca9cae6073	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 14:47:27.759313	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
76ca33d9-796e-4b40-bcf4-bf4cca4abe27	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 14:47:27.760339	t	e6a73462-6516-415b-b188-7352267c17e7
56377ba0-3972-4d49-b2eb-8e055e1a2b2c	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 14:47:27.760662	t	79f034a9-ee01-4de2-9238-549e53bb794f
6f92244f-04c0-41da-b1f9-c0dc1cecb357	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 14:47:27.760785	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
93a96d2a-6f58-4d79-a43a-fd9cf1867e67	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 14:47:27.774117	b	e6a73462-6516-415b-b188-7352267c17e7
ac45ec62-7eed-4f4d-8824-271de103e001	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 14:47:27.782164	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
0a42a45d-b295-497f-bc02-e561d1e03b9b	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 14:47:27.814353	m	79f034a9-ee01-4de2-9238-549e53bb794f
9684601b-c7eb-44f1-8044-b3367c9ad8ad	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 14:47:27.852634	b	79f034a9-ee01-4de2-9238-549e53bb794f
9428239f-6dec-4b91-88e5-b9760b6c23d4	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 14:47:27.885474	m	e6a73462-6516-415b-b188-7352267c17e7
2d3a8c21-e8df-4aa1-ac20-881518ec5c30	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-11-24 14:47:27.721306	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
3547802e-1b68-444b-a3eb-ffa205909ca8	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-11-24 14:47:27.692209	d	36133c39-09fc-41b6-93f8-590a2eae35d1
48f9b29f-d31a-476a-bdf7-3a41bc089a9c	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-11-24 14:47:27.690069	b	36133c39-09fc-41b6-93f8-590a2eae35d1
6d1378d8-7c8b-4c21-95c6-35086e45ffb5	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-11-24 14:47:27.745252	g	36133c39-09fc-41b6-93f8-590a2eae35d1
d7c2ccdc-5052-4cf8-8cfb-f5dbf5172b24	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-11-24 14:47:27.690899	m	36133c39-09fc-41b6-93f8-590a2eae35d1
819aa56b-dd36-4fcd-943a-fdf0d754c71c	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-11-24 14:47:27.743296	t	36133c39-09fc-41b6-93f8-590a2eae35d1
e5def969-6605-4eb5-a6b9-0ddd37571b33	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-11-24 14:47:27.669266	n	36133c39-09fc-41b6-93f8-590a2eae35d1
24e1548d-ea70-4dc3-a305-9825446edab1	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-11-24 14:47:27.48898	h	36133c39-09fc-41b6-93f8-590a2eae35d1
4548539b-7e89-4bfb-b471-0ddce749330d	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-11-24 14:35:21.294562	g	36133c39-09fc-41b6-93f8-590a2eae35d1
231a4704-0834-4b08-ae80-3a785c656b1c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-11-24 14:52:16.83403	h	36133c39-09fc-41b6-93f8-590a2eae35d1
38d938b2-e761-48ac-aacf-274930ced7c7	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 14:52:16.844599	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
7c5f5b8b-8af9-4b1a-be01-41198d3d3805	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 14:52:16.895331	h	e6a73462-6516-415b-b188-7352267c17e7
d0a15bfe-ede0-4c18-a790-e3dfab7ca945	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 14:52:16.904145	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
9cd359ca-fbb5-498e-9e5f-6f9d82f7af94	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-11-24 14:52:16.990716	n	36133c39-09fc-41b6-93f8-590a2eae35d1
c3fa9025-b5e0-4aa0-849b-f104dc7beede	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 14:52:17.001029	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
beb6c1fe-d18a-4c4d-9f7e-46ece81d8af4	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-12-01 09:07:33.62774	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
dc633150-5316-4029-b3b1-2e09bf4278f3	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-11-24 14:52:17.006788	t	36133c39-09fc-41b6-93f8-590a2eae35d1
4294f01e-a7f4-4bab-9f7c-08bdf86ce313	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 14:52:17.012798	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
331f3d9d-89ee-4133-9de7-d54fd0f5876d	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 14:52:17.025427	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
a0b1fdde-45a5-4a4b-8896-7c3b3a05f2da	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 14:52:17.091423	m	79f034a9-ee01-4de2-9238-549e53bb794f
d5112bdb-d028-4541-b99a-7516d4a9548c	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-11-24 14:52:17.106506	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
8a6824dd-87f8-43da-a381-b92dae1e0d23	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 14:52:17.117003	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e2a8a282-bfce-44b1-84a7-50ae5eb0b45c	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 14:52:21.949271	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
942d16c7-fe14-462f-8f23-7178d4186030	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 14:52:21.960818	d	e6a73462-6516-415b-b188-7352267c17e7
26aa99eb-af24-4132-a13f-291085d2ff0c	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 14:52:21.975543	nj	e6a73462-6516-415b-b188-7352267c17e7
f9102ef0-cf4e-4a9f-b4f0-37e057f929fd	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:33.569255	h	79f034a9-ee01-4de2-9238-549e53bb794f
b8491709-45a0-4734-895f-8654581193b1	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:33.594886	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
ca5c65b5-9c7a-4da4-92e7-eda2baab34f6	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:33.615716	d	e6a73462-6516-415b-b188-7352267c17e7
48de0ffa-7cfc-402a-905a-96ec0005c8a6	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:33.633619	nj	e6a73462-6516-415b-b188-7352267c17e7
a5c89fce-10e3-4484-9f5b-9ba7823e20a7	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:36.730743	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
d7fe2110-8a08-4480-bf1b-3972a04043e1	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:36.744498	b	79f034a9-ee01-4de2-9238-549e53bb794f
e0cbb82b-7f6c-4150-a3e3-64480d4bca10	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:36.779748	d	79f034a9-ee01-4de2-9238-549e53bb794f
dc9124fc-fd5c-4697-bbc2-540048330160	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:36.79545	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
dad8b0c9-142c-4518-ae9c-e0a9a556e5ea	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-12-01 09:07:36.709888	m	36133c39-09fc-41b6-93f8-590a2eae35d1
023ae206-2f25-4745-bd52-d39bfdc64196	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:38.65453	b	79f034a9-ee01-4de2-9238-549e53bb794f
72241eab-16fb-4b98-ba71-7dff88fd8576	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:38.670392	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f6c42c86-347b-4a56-9096-a13d2ebdcae5	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:38.699019	g	e6a73462-6516-415b-b188-7352267c17e7
9202f558-f3ac-4e35-891a-855aefd01eb9	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:39.399974	n	e6a73462-6516-415b-b188-7352267c17e7
5013c3a3-63c9-498d-a7b6-ceb5b50bba1b	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:39.406411	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
476ac75c-9747-4b7f-b38d-e8444bae25c6	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-12-01 09:07:39.380958	d	36133c39-09fc-41b6-93f8-590a2eae35d1
f3ac2af0-619f-4455-8638-c7c83145af2e	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-12-01 09:07:38.630056	m	36133c39-09fc-41b6-93f8-590a2eae35d1
31eadcfb-670d-4946-9923-192b3af33003	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 07:25:00.192703	h	e6a73462-6516-415b-b188-7352267c17e7
4cfd87eb-9858-41d5-9326-86e18580368d	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-03 07:25:00.224958	t	36133c39-09fc-41b6-93f8-590a2eae35d1
d4cbbe19-0781-4687-81c8-9174579e1967	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 07:25:00.228923	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
080f8120-037e-48a3-89a1-2f4c91260747	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 07:25:00.248191	m	e6a73462-6516-415b-b188-7352267c17e7
90e1bd0c-9297-4d7d-a74d-0f662c307781	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-03 07:25:00.275302	d	36133c39-09fc-41b6-93f8-590a2eae35d1
e6f8a34e-93ae-4ec3-9853-a41d8d5458aa	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 07:25:00.280141	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c0add6f2-3b92-4804-8b6b-d470b7cfd18e	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	t	2025-12-03 07:25:00.328977	g	79f034a9-ee01-4de2-9238-549e53bb794f
64b46dbc-79bd-4e03-8e45-c7e0ed3e305f	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	t	2025-12-03 07:25:00.306267	nj	79f034a9-ee01-4de2-9238-549e53bb794f
e52a6831-cbd3-4503-8598-f881dda73f4b	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	t	2025-12-03 07:25:00.238111	b	79f034a9-ee01-4de2-9238-549e53bb794f
80f59fa3-4895-4bc9-a278-1da91085bc1e	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 08:50:01.204215	h	79f034a9-ee01-4de2-9238-549e53bb794f
98b522c1-18a9-4917-98f4-c08d8f1863bd	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-03 08:50:01.238867	b	36133c39-09fc-41b6-93f8-590a2eae35d1
f56680f2-f9d2-490f-b68b-53767d02e8cb	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 08:50:01.246741	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
4b89b9af-afa1-4349-99e4-f717d0a33b48	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 08:50:01.311157	g	79f034a9-ee01-4de2-9238-549e53bb794f
00daa5df-7646-41da-8005-1448799d558e	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-03 13:58:25.687483	t	36133c39-09fc-41b6-93f8-590a2eae35d1
1128fdd1-7e1f-4b15-a1bb-4f1731c396ab	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 13:58:25.697467	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
fa9c875c-f121-494a-8b32-4f7d6c8cba7a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 13:58:25.736257	n	e6a73462-6516-415b-b188-7352267c17e7
1709b0c9-8ee2-4ecc-803e-5dec10ff5a52	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 13:58:25.741617	n	79f034a9-ee01-4de2-9238-549e53bb794f
ac591e6f-a4a4-4d08-b63c-e890423d5ab0	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 13:58:25.779613	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
42849950-64dc-4e61-9069-a93036ad84f7	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 13:58:25.784558	m	e6a73462-6516-415b-b188-7352267c17e7
31678ca0-1841-42ce-a0a9-34436188b8ea	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 13:58:25.811808	b	79f034a9-ee01-4de2-9238-549e53bb794f
1698708d-b7a4-454f-b096-d047dbbd6e00	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-03 13:58:25.868494	g	36133c39-09fc-41b6-93f8-590a2eae35d1
ef30d89a-3879-4d91-8346-5c7443351eba	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 13:58:25.898359	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
32b3190d-64cb-40bc-a1d8-8dd6aedb9129	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 14:13:46.746666	n	e6a73462-6516-415b-b188-7352267c17e7
d86f6aa5-8b59-4797-a3c0-725a5dee12b6	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-03 14:13:46.772564	b	36133c39-09fc-41b6-93f8-590a2eae35d1
3790f793-53f9-44a5-bbf2-b81440f431c5	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 14:13:46.782351	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
1c994627-7e94-4388-b652-0f417ba06b21	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-03 14:13:46.826195	g	36133c39-09fc-41b6-93f8-590a2eae35d1
c2cd4af6-d577-4d47-bce0-167d58a8a5c9	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 14:13:46.834599	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e2eee996-5da0-4cc1-8c6c-8bd28f3ce326	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-11-24 14:52:17.008602	b	36133c39-09fc-41b6-93f8-590a2eae35d1
a2a4ab86-8abc-4ac7-9916-914666036031	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 14:52:17.020843	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f12b3d5e-ab67-49c0-810a-848734a2eef4	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 14:52:17.023569	b	79f034a9-ee01-4de2-9238-549e53bb794f
f31c9b72-b412-4de8-8710-9cda2e6f3d28	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 14:52:17.118953	nj	e6a73462-6516-415b-b188-7352267c17e7
d7707279-6572-4320-84ef-d5ee29d39d31	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 14:52:17.131337	g	e6a73462-6516-415b-b188-7352267c17e7
95a4415a-50ac-4a0f-8601-66e5ce06848e	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-11-24 14:52:21.928528	b	36133c39-09fc-41b6-93f8-590a2eae35d1
1c4bbedb-311e-4c80-b6c6-a01e4ba66f2d	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 14:52:21.939414	n	79f034a9-ee01-4de2-9238-549e53bb794f
948c6bc9-ae74-41b7-a2ae-b0025f0e6c27	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 14:52:21.951108	b	79f034a9-ee01-4de2-9238-549e53bb794f
22333b21-2e0f-46c6-844e-e84a55137057	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 14:52:21.956027	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c308b025-b9f8-4e1f-9b69-174c02f92d65	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:33.58352	n	79f034a9-ee01-4de2-9238-549e53bb794f
a27e3140-b38d-4caf-bbbe-7ae07eeba79f	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:36.723056	h	e6a73462-6516-415b-b188-7352267c17e7
6c5d7eb2-04f1-49fa-9879-60008d0d487c	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:36.747432	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
1f83b113-6ed0-44a6-b16e-5a23f6072f8e	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:36.791735	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
98c041ff-9409-4faf-95ca-d5bf118f1057	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-12-01 09:07:36.782572	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
24cddc05-00a0-45dc-a12f-904c5834d6ff	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:38.636839	h	e6a73462-6516-415b-b188-7352267c17e7
e1fcbcbb-6546-47b8-b33a-581c5165e535	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:38.663523	d	79f034a9-ee01-4de2-9238-549e53bb794f
fa122342-1aa4-45ce-a8f3-9ac1e0d35034	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:38.668058	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
88e4dcaf-fc92-4170-916d-a21a378aa56c	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:38.69971	g	79f034a9-ee01-4de2-9238-549e53bb794f
5c758798-3f60-46ad-b1ba-1789337d6a4c	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:39.396175	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e16c2bd7-6dfe-4799-8d97-57fc4436e6b7	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:39.403584	b	79f034a9-ee01-4de2-9238-549e53bb794f
e0875a5e-80c0-4af9-88dd-ce779b65b8f8	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:39.420555	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
f94c8bbe-fb08-4a12-b6fb-420cfc7a90d7	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-12-01 09:07:39.373695	m	36133c39-09fc-41b6-93f8-590a2eae35d1
f1e62428-4956-4c57-bf1a-72b30e91c5dc	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-03 07:25:00.296099	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
39d2308d-23dc-4a64-989b-30a256f515e4	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 07:25:00.303616	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
02637c67-336f-4060-8bcf-cc1eb8de1291	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-03 07:25:00.313438	g	36133c39-09fc-41b6-93f8-590a2eae35d1
82ecef30-c80b-4dcb-b82a-5fcad82ebb45	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 07:25:00.323274	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
741b1156-479c-4682-8d8a-1e4371de7bfc	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	t	2025-12-03 07:25:00.230849	n	79f034a9-ee01-4de2-9238-549e53bb794f
36b3fb7a-6a40-451d-adec-6ac45aaa7e6a	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	t	2025-12-01 09:07:39.436709	g	79f034a9-ee01-4de2-9238-549e53bb794f
aee31466-1756-4740-a701-94033a29ee74	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 08:50:01.218061	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
19b3cfed-0792-4592-ad77-1cd29658aa00	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 08:50:01.249757	m	e6a73462-6516-415b-b188-7352267c17e7
ec7d8064-5040-4cd3-ae68-ace017e5e157	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 08:50:01.290336	d	e6a73462-6516-415b-b188-7352267c17e7
26db4493-0224-4709-be0d-4e9cc3db5003	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 08:50:01.300746	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
7494890d-435c-48e5-80ac-df83fdcbc5a0	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-03 13:58:25.691013	h	36133c39-09fc-41b6-93f8-590a2eae35d1
fc7ff7ad-e552-4205-9b30-19c627c1295d	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 13:58:25.711804	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
5c891949-24f8-44a5-9312-c8d09cb828e5	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-03 13:58:25.764157	b	36133c39-09fc-41b6-93f8-590a2eae35d1
094bdccb-d4b8-4ec1-85f3-7d61da067504	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 13:58:25.792583	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
725a8d24-3be0-4ff0-8c22-2369d6b907ad	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 13:58:25.815176	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
74f328ba-66c8-461c-b59f-be4c5fea0888	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-03 13:58:25.874075	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
a4c1de4e-a103-4d5c-b5c4-2a8d9968d9c8	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 13:58:25.907844	g	e6a73462-6516-415b-b188-7352267c17e7
c58788e2-baea-44e5-8cca-a0a4c86bf4a4	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 14:13:46.755085	n	79f034a9-ee01-4de2-9238-549e53bb794f
dcf6d731-8a85-4801-8eff-1a299ae57472	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 14:13:46.778262	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
2c005ed4-2682-46a4-a960-3334caacd4c6	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 14:13:46.789788	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
ab678eb3-a7c9-416f-beb5-a0b4d917cda6	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 14:13:46.81467	nj	e6a73462-6516-415b-b188-7352267c17e7
12891a41-4dee-4e68-a98a-a644af640076	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 14:13:46.838	g	e6a73462-6516-415b-b188-7352267c17e7
733c9f00-cea3-429b-96b7-a085eba79360	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 14:52:17.015195	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
f8e9f67d-90b7-464d-b766-86c1efa3b011	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 14:52:17.046006	h	79f034a9-ee01-4de2-9238-549e53bb794f
82de0cb8-7efa-4c38-ad61-0b13c3d64aa0	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 14:52:17.068683	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
22a14245-3c9e-43bf-b214-d123df9ab707	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 14:52:17.075929	n	e6a73462-6516-415b-b188-7352267c17e7
77ac1135-9f2f-4d5b-a0cd-c75906e1c61b	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-11-24 14:52:17.083922	m	36133c39-09fc-41b6-93f8-590a2eae35d1
6f99fa6e-23bb-4c72-9791-81635af7529b	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 14:52:17.088387	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f72226ad-60a3-4d4a-85b6-3cc279d36894	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 14:52:17.089224	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
0ced8d88-c577-4897-a72c-259ae0392200	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 14:52:17.090095	m	e6a73462-6516-415b-b188-7352267c17e7
dcb395ff-6ec2-4398-956f-0f34b3115ae0	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 14:52:17.092631	t	e6a73462-6516-415b-b188-7352267c17e7
5b216620-b946-4da0-9389-5f5116094328	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-11-24 14:52:17.105136	d	36133c39-09fc-41b6-93f8-590a2eae35d1
b84e515c-cdcb-40bd-8257-41367133818a	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 14:52:17.10985	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
2e9a56a7-0127-4012-b8da-91bfcab70afa	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 14:52:17.11167	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
d54a5513-37ae-4e20-81cb-b97af313fcc3	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 14:52:17.112783	d	e6a73462-6516-415b-b188-7352267c17e7
f6cd5096-e5f9-4671-b44c-78481c2c877f	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 14:52:17.114802	d	79f034a9-ee01-4de2-9238-549e53bb794f
056577f5-882e-4577-a45a-b300036163e8	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 14:52:17.110631	b	e6a73462-6516-415b-b188-7352267c17e7
61559c0f-e6fc-4a44-97e9-34ad4b24fde3	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 14:52:17.118027	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
06e70254-e997-488f-b373-aa1da930b00d	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 14:52:17.120184	nj	79f034a9-ee01-4de2-9238-549e53bb794f
89556ed3-27f5-4c87-b7f0-c94cd4442dab	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-11-24 14:52:17.123507	g	36133c39-09fc-41b6-93f8-590a2eae35d1
ad4a5264-5fa1-49df-bd21-0f29133cf5d2	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 14:52:17.127923	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
05080b06-5b01-4e14-8199-b9b87b4f381d	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 14:52:17.129368	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
48870135-0b07-4eab-8c88-898378e49e93	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 14:52:17.132627	g	79f034a9-ee01-4de2-9238-549e53bb794f
eb6b1936-e804-4dde-a395-4b235641b1fe	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 14:52:17.179633	n	79f034a9-ee01-4de2-9238-549e53bb794f
635dc7da-d29b-4491-ad46-1545c1ad1966	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 14:52:17.194381	t	79f034a9-ee01-4de2-9238-549e53bb794f
66e415ad-b968-47aa-9d9e-1a83de90ed25	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-11-24 14:52:21.925496	h	36133c39-09fc-41b6-93f8-590a2eae35d1
5d470000-9a01-48cb-84b2-028b262f57a4	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-11-24 14:52:21.926543	n	36133c39-09fc-41b6-93f8-590a2eae35d1
5f900a5b-fe10-4f74-bf0e-3dc8890442a5	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-11-24 14:52:21.930139	t	36133c39-09fc-41b6-93f8-590a2eae35d1
f838668e-f0f6-4450-baa2-540abbb4b1ac	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-11-24 14:52:21.931346	m	36133c39-09fc-41b6-93f8-590a2eae35d1
7654c75b-7939-475a-8b8b-da76e091728b	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-11-24 14:52:21.932819	d	36133c39-09fc-41b6-93f8-590a2eae35d1
e7f56db8-af96-450a-8d42-f7302c1668c9	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 14:52:21.9341	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
410957a4-55c8-458a-b847-4bab9c199a42	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 14:52:21.936622	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
a9d58ec8-057f-44ee-ac0a-ee347733d2c1	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 14:52:21.937805	h	e6a73462-6516-415b-b188-7352267c17e7
5b2020ad-cd6b-49f9-9697-a30f98335109	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-24 14:52:21.938011	h	79f034a9-ee01-4de2-9238-549e53bb794f
97020339-5af0-4131-925b-56d3b00b1ad3	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 14:52:21.945239	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
29c09d02-13b2-4a56-8f15-adfe967c9ba4	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 14:52:21.94721	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
708b280b-9988-4c7b-9aa8-3232dd925ebf	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-24 14:52:21.948475	n	e6a73462-6516-415b-b188-7352267c17e7
2eba3332-51b2-41ea-912f-74bf1636ef7b	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 14:52:21.949387	m	e6a73462-6516-415b-b188-7352267c17e7
e1af6a20-bb7c-47dc-839a-3f1e8e8fccb1	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 14:52:21.950133	m	79f034a9-ee01-4de2-9238-549e53bb794f
f85c5e91-3503-4f1f-b9de-0b92c3ba31af	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 14:52:21.951219	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
a9460273-1b93-47b2-81fa-470ec9ad677e	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 14:52:21.9526	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
091cb035-2579-4bb7-94a6-23dea21dce6f	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 14:52:21.953598	t	e6a73462-6516-415b-b188-7352267c17e7
0278e8ad-9284-420f-82a6-11b72db2a61d	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-24 14:52:21.954506	t	79f034a9-ee01-4de2-9238-549e53bb794f
7cbf5d18-efbd-4538-b934-636406e7d2f6	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 14:52:21.956135	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
16d96fcf-460a-4dbc-9c63-3e355456d42a	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-24 14:52:21.95586	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
12398fe8-1d8c-4639-b414-8f9d19fb953d	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-24 14:52:21.956277	b	e6a73462-6516-415b-b188-7352267c17e7
15da1e43-fca3-4ac1-b5cb-b603cf7d4025	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 14:52:21.957652	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
11002a9a-5633-4364-981f-c0fb3d0973db	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 14:52:21.958771	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
ed2e332a-e6d9-4080-876b-e02dcb8cd5c9	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-24 14:52:21.962697	d	79f034a9-ee01-4de2-9238-549e53bb794f
4ded8bb6-6920-4091-8b64-49b1360f348a	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-11-24 14:52:21.970204	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
b3f5adbd-4521-445c-889e-dcdff1cd1516	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-11-24 14:52:21.972199	g	36133c39-09fc-41b6-93f8-590a2eae35d1
1e112576-3d8d-44a8-a9b3-8d7f866f166a	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 14:52:21.973807	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
63d71c74-8e0a-4128-ad79-d6840bf7e190	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 14:52:21.974826	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
77f662d0-5d92-4059-91f0-eb3b92bd897b	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-24 14:52:21.976381	nj	79f034a9-ee01-4de2-9238-549e53bb794f
ef4d35a9-efa3-4c81-a38a-84d4a63f54c0	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 14:52:21.978393	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9ee85216-0aa5-4a9b-81dc-45735f4ff1f5	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 14:52:21.979935	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
6d3d5cb9-1003-4dbc-a115-b1b1d013eea5	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 14:52:21.981314	g	e6a73462-6516-415b-b188-7352267c17e7
2b3b9422-abcf-4f98-bc43-7fa9de8ef169	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-24 14:52:21.982493	g	79f034a9-ee01-4de2-9238-549e53bb794f
2ceca9c5-160f-43da-bbc1-ba3fa1b0f94f	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-11-25 07:45:29.914269	n	36133c39-09fc-41b6-93f8-590a2eae35d1
cde553ed-bb13-4379-a79a-998c1ab7055d	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 07:45:29.941627	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
1dc63402-550a-496e-b3d9-24d9b67acbeb	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 07:45:30.038056	m	79f034a9-ee01-4de2-9238-549e53bb794f
9d4f4e3f-4496-4341-aeac-0b5a9487cce4	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 07:45:30.09691	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
4493e73a-b8ff-4ec3-a91a-a4a7ea3965be	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 07:45:30.107926	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
2dd7a7b7-e851-4afe-85a9-cfe98d7de647	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 07:45:30.189703	nj	e6a73462-6516-415b-b188-7352267c17e7
f71644ec-e198-415f-97be-916c46e46ebd	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 07:45:30.208226	n	79f034a9-ee01-4de2-9238-549e53bb794f
23aa4c31-dbe0-47c9-a13d-8a751b860e7e	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:33.584798	n	e6a73462-6516-415b-b188-7352267c17e7
3c5f0b29-fc79-4dad-bc84-9c35ee2990e2	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:33.640499	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
ee711574-5278-486c-8254-f9951d35c253	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:36.737239	n	e6a73462-6516-415b-b188-7352267c17e7
66b66156-e6ab-4d29-8ea5-763a659a2357	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:36.774941	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c993c993-5077-4001-8688-d6b41b503ad7	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:36.799437	nj	e6a73462-6516-415b-b188-7352267c17e7
def9547d-ad24-46a1-9614-3e11f93c871f	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-12-01 09:07:36.706167	t	36133c39-09fc-41b6-93f8-590a2eae35d1
78bb4a86-493f-4599-b6e8-fdc71f228b6d	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-12-01 09:07:36.748696	d	36133c39-09fc-41b6-93f8-590a2eae35d1
55c04d78-0b60-49bd-8a88-de48c8d54627	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-12-01 09:07:33.628789	g	36133c39-09fc-41b6-93f8-590a2eae35d1
5a3f05d9-822e-4fb9-a54b-8e40489aa15a	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:38.661477	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
6575d846-bc3d-4294-a0d9-53ffa82fc2da	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:38.665949	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
1702930a-93e8-426e-a186-55fd73059f5c	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:38.708529	nj	79f034a9-ee01-4de2-9238-549e53bb794f
1f63954c-ac2b-4583-b64e-7d5f04126060	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:39.393104	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
2e621a3e-ecd6-4461-aa2a-449b55cb973e	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:39.400363	n	79f034a9-ee01-4de2-9238-549e53bb794f
77140e86-5ab9-473f-a086-ed47f3e3f18b	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:39.417251	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
2358d586-51de-4c3d-9bf9-2f89c2e68f2d	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-12-01 09:07:39.372482	h	36133c39-09fc-41b6-93f8-590a2eae35d1
439d3775-8470-4f56-b1b6-85cf08215201	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-12-01 09:07:38.628774	d	36133c39-09fc-41b6-93f8-590a2eae35d1
a2083a24-355c-444e-acde-a8e1e273500d	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:47.369133	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
2c8c3ef0-0c65-4601-8fb0-7ab158fa919c	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:47.389566	n	e6a73462-6516-415b-b188-7352267c17e7
19215331-af2b-473e-ab1b-72775b29fad1	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:47.406362	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
aec57692-57f4-4326-8578-a3418caebedd	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:47.424702	b	e6a73462-6516-415b-b188-7352267c17e7
35b4b6c0-0ea3-403f-b1c8-d145e6e3f8b0	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:47.441857	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
3f60c064-ddbb-4bbe-93ac-624212122487	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:47.462575	d	e6a73462-6516-415b-b188-7352267c17e7
2ed8309e-a3c6-4652-bd0e-3ba954a05003	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:47.486257	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
c1f22fac-d908-4f17-a8d1-83b19a3ea5cb	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:47.509499	g	e6a73462-6516-415b-b188-7352267c17e7
0c9f2c14-351c-4c84-aa00-2d241653c307	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	t	2025-12-03 07:25:00.31829	t	79f034a9-ee01-4de2-9238-549e53bb794f
278c6b76-31de-4773-aef8-2e6d39455f22	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 08:50:01.227674	t	e6a73462-6516-415b-b188-7352267c17e7
a9afb082-88ef-4910-896e-ba7a347866c8	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 08:50:01.248605	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
1d2dc388-a466-4524-b382-6e2894b309b3	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 08:50:01.309035	g	e6a73462-6516-415b-b188-7352267c17e7
cef3169b-6e46-4130-ae73-cdd915f8e3bd	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-03 13:58:25.692974	n	36133c39-09fc-41b6-93f8-590a2eae35d1
51988d20-d499-4bd1-a9f4-a4029e77fc82	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 13:58:25.735721	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9868cb26-4054-4f39-b3de-42d073e520df	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-03 13:58:25.749291	m	36133c39-09fc-41b6-93f8-590a2eae35d1
a3cf63d6-c4c6-4047-8b64-35daa06d73d6	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 13:58:25.784877	m	79f034a9-ee01-4de2-9238-549e53bb794f
2e14f455-0e8b-4da6-aeb8-c4e278c1418f	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 13:58:25.803884	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
266ed059-f24b-455a-b73f-3f9e645e57fc	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 13:58:25.811524	b	e6a73462-6516-415b-b188-7352267c17e7
3503d917-a0c0-4c1b-ab9b-b1d9b95e2426	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-03 13:58:25.855786	d	36133c39-09fc-41b6-93f8-590a2eae35d1
c12b6f6e-8fa1-4494-b6bc-85f8616cd62e	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 13:58:25.875737	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
db7dd0bf-3481-4ff7-b4df-3c72f535eae0	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 13:58:25.899866	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
6181cab1-9da4-4d05-aac7-547c8b7d71e1	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 14:13:46.851111	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
921efee2-3a47-4935-8d63-0cf313b24322	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 14:13:46.887492	d	79f034a9-ee01-4de2-9238-549e53bb794f
212e3b7c-c1a0-4c3d-b0c8-460a86de9bcb	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-11-25 07:45:29.972421	t	36133c39-09fc-41b6-93f8-590a2eae35d1
82ce171e-5f68-4a77-a561-362bb8f8271e	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 07:45:30.046963	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
f100fd1d-ad07-4c63-b32e-358815caecf3	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 07:45:30.068178	t	79f034a9-ee01-4de2-9238-549e53bb794f
de4d2987-c605-4209-89cf-401b605b2909	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 07:45:30.101968	b	79f034a9-ee01-4de2-9238-549e53bb794f
ca920a11-3353-4194-b133-5d29659ff3c9	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 07:45:30.166022	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
188884e6-e265-47bc-a8b2-0388c16e9623	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 07:45:30.187032	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
c3788268-cbee-4ef7-a29c-75db104384f5	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 07:46:29.81918	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
85a9d279-59e1-4583-a5d2-e7812db32f4c	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 07:46:29.896745	g	e6a73462-6516-415b-b188-7352267c17e7
a1b81745-0235-4a66-8510-47934b233831	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 07:46:29.93499	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
76697efc-4eaf-4f5f-9fa9-6324627c9cd6	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 08:46:35.910814	g	79f034a9-ee01-4de2-9238-549e53bb794f
4036c749-56c3-4e92-b30b-9398341fea7d	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 20:56:38.929965	n	79f034a9-ee01-4de2-9238-549e53bb794f
f462bfac-0f5c-4e5c-8bff-4f4b1e5fbf53	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-11-30 20:56:38.978189	g	36133c39-09fc-41b6-93f8-590a2eae35d1
91fc865e-5884-40f6-986c-40460e3ca0a6	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 20:56:38.988768	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
ed0fc688-7517-4d3d-b3d2-2964f03b2f6b	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-11-30 22:30:31.125175	t	36133c39-09fc-41b6-93f8-590a2eae35d1
78076146-ed1f-422a-9e63-ef56f8120a5c	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 22:30:31.139953	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
a0b2eda7-8267-4613-bd9c-bd3d225d28ed	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 22:30:31.152987	n	79f034a9-ee01-4de2-9238-549e53bb794f
f54bfce9-8c06-4c81-b68b-56373feb5e9c	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 22:30:31.191549	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
33a1d761-734e-4754-8c75-51b2ebe84bb9	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 22:30:31.228806	m	79f034a9-ee01-4de2-9238-549e53bb794f
5a190fa4-79c2-464e-94b6-bb5c721b1a95	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-01 07:40:19.327552	n	36133c39-09fc-41b6-93f8-590a2eae35d1
59215dc6-30ba-4f97-ad15-1200a3dce8d1	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 07:40:19.355731	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
0757810e-849f-4ad5-bcf7-3140ae5deeb4	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 07:40:19.361074	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
6c745f9f-02e9-4fe1-a4cc-2e5a00a671e4	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 07:40:19.379933	n	79f034a9-ee01-4de2-9238-549e53bb794f
d96f1033-2074-4f42-9c78-125c97fb4d49	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 07:40:19.472691	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
0746f499-c6c7-4507-ab30-619fec2116a2	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 07:40:19.511025	b	e6a73462-6516-415b-b188-7352267c17e7
c7bead64-d8f8-43e1-abaf-dd939da7a432	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 07:40:19.523364	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f5dad632-5e27-49b0-9ff8-ab739b913b24	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-01 07:40:19.610486	m	36133c39-09fc-41b6-93f8-590a2eae35d1
2539872d-bb69-40b0-93a6-ea667f4debf4	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 07:40:19.630671	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
ef85a9d0-6c78-4f85-b34d-47c6850f49d8	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 07:40:19.633129	m	e6a73462-6516-415b-b188-7352267c17e7
8a80cddf-94f2-4db2-9459-8b8f27dac9de	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 07:40:19.663476	b	e6a73462-6516-415b-b188-7352267c17e7
eae17831-dc3e-4354-93b9-40f2ca17a932	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 07:40:19.690927	g	e6a73462-6516-415b-b188-7352267c17e7
02d887c0-6146-4f50-818e-38c687231487	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 07:40:19.713776	g	79f034a9-ee01-4de2-9238-549e53bb794f
c8f96627-1ec5-4d36-9be7-56b9fa106e17	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 08:31:45.199825	h	e6a73462-6516-415b-b188-7352267c17e7
b509c0a0-d722-4cac-90ac-72fa463dda4b	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 08:31:45.244264	m	79f034a9-ee01-4de2-9238-549e53bb794f
4c4de949-5837-4f67-b983-678a1c3de84a	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 08:31:45.264766	d	79f034a9-ee01-4de2-9238-549e53bb794f
ba70c1cf-cdf7-4f14-81e7-81b7c973f53a	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 08:31:45.282784	nj	e6a73462-6516-415b-b188-7352267c17e7
19954e4b-38cd-4d60-8872-052642ae114f	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 08:42:22.233661	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
85042599-6c48-440e-a34e-9eebfb1ac788	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:33.597844	m	79f034a9-ee01-4de2-9238-549e53bb794f
131949ad-fefc-4969-8f86-8c6eea35afac	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:33.614923	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
7500941f-d349-400b-aa07-d03bfb3e79ef	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:33.634521	nj	79f034a9-ee01-4de2-9238-549e53bb794f
ab0bcc08-6b59-47d4-a7c7-f239365dc28b	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:33.641745	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
e16bee7e-2a81-4e24-a225-e8e74a5ac690	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:36.731823	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
8798eec7-8081-46de-9c12-dfdaa0873dd2	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:36.759892	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
89df70ed-016f-4b92-9787-25a9c8c438b8	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:36.778433	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
8938b57c-b9ca-4baf-9010-b4269ebb0630	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:36.796512	g	e6a73462-6516-415b-b188-7352267c17e7
33cdf2e0-a95c-430b-8719-355ca77365dc	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-12-01 09:07:36.707924	b	36133c39-09fc-41b6-93f8-590a2eae35d1
81243bf8-9d38-4139-b297-285beba2b2ed	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:38.656026	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
875fdadd-186b-42bd-8d3f-0355e923646d	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:38.672036	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
e23d96b8-03d6-4814-8982-2f7570013013	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:38.698064	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
cbd91407-528d-48ca-9a4a-c8f9aeaf4509	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:39.393813	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
4376dfeb-bd54-4082-9512-2cb25fd355fd	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:39.400638	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
50a7d61d-e773-478b-b074-d2abd9feec74	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-12-01 09:07:38.626123	b	36133c39-09fc-41b6-93f8-590a2eae35d1
138a6cbf-15f1-427e-a623-4cd0c08d2bb3	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 07:25:00.325397	g	e6a73462-6516-415b-b188-7352267c17e7
63f4ec27-36b8-41f3-b00b-3cc2058fbdd4	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 08:50:01.2415	t	79f034a9-ee01-4de2-9238-549e53bb794f
fd9f4a52-a2eb-4ed5-aadd-6bafba2b3bae	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 08:50:01.291571	d	79f034a9-ee01-4de2-9238-549e53bb794f
4c0a865b-187a-431d-8de6-34397a9512be	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 13:58:25.840546	t	e6a73462-6516-415b-b188-7352267c17e7
2e51687e-9756-45c0-a4ed-c4c4bb14544f	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 13:58:25.884434	d	79f034a9-ee01-4de2-9238-549e53bb794f
c3ee7546-ac2d-47bb-8ada-ce4788853b57	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-11-25 07:45:29.997416	b	36133c39-09fc-41b6-93f8-590a2eae35d1
e249859c-4f0d-4b6d-a7c2-144e7a33e6e4	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 07:45:30.064156	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
268c7e16-ca17-4b73-995e-42f1471c99b5	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 07:45:30.098831	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
2da25ed2-5995-4baa-85c0-db37bf3583bd	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-11-25 07:45:30.13352	d	36133c39-09fc-41b6-93f8-590a2eae35d1
4ca00f89-2928-4d73-a998-082b9b02dbe4	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 07:45:30.183957	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
919b37b9-f641-499e-9209-9bb24265974b	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 07:45:30.236445	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
a410ed94-28b0-4a93-9acb-95d5f04ee5ba	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 07:45:30.277193	g	e6a73462-6516-415b-b188-7352267c17e7
9a63a01b-11c6-465e-a5c9-61e4649bb602	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 07:46:29.834021	h	79f034a9-ee01-4de2-9238-549e53bb794f
8155cca5-f6d5-4634-8d38-bec6943f4050	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 07:46:29.892524	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
a9eb0069-5049-4ff0-a88b-b1a7ba71305b	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 07:46:29.930631	d	79f034a9-ee01-4de2-9238-549e53bb794f
50692163-68d0-418d-a6e6-b5a75f4989b0	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 08:46:35.918606	d	e6a73462-6516-415b-b188-7352267c17e7
a1ebaa7d-44d9-440d-a1e4-825d8cb8594e	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 20:56:38.953075	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
74dcbba1-2cef-4b38-8672-b7b9924c2c36	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 20:56:38.974715	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
98132bcc-61a1-4e9b-a15e-a631f3c37907	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 20:56:38.995583	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
a7d7418f-b633-4b3f-98d4-20ad5a5fd931	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-11-30 22:30:31.126384	n	36133c39-09fc-41b6-93f8-590a2eae35d1
03951305-fa48-4186-a57b-3394ca0f039f	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 22:30:31.150168	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
0030219a-6209-4686-bb64-ba4d3816c9fc	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 22:30:31.195197	b	79f034a9-ee01-4de2-9238-549e53bb794f
413c42cc-fe48-4338-939a-59438bb0a7ae	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-11-30 22:30:31.220359	m	36133c39-09fc-41b6-93f8-590a2eae35d1
b949ec99-9a3f-4eab-8057-e5e191ed44b6	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 22:30:31.225148	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
d5b8b682-78b2-4853-966c-d34c4f61a44e	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-11-30 22:30:31.264855	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
4bc59bdf-931f-4062-8229-8db1120d17c9	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 22:30:31.27031	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
a8003bbc-ae96-4e37-8ae0-0592c8ea23b0	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-01 07:40:19.330512	d	36133c39-09fc-41b6-93f8-590a2eae35d1
785e1fe1-34d6-4d39-bb29-b605c8364be5	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 07:40:19.375093	d	e6a73462-6516-415b-b188-7352267c17e7
4e74f6bd-5cad-410e-9356-6c6d2310a981	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 07:40:19.379567	n	e6a73462-6516-415b-b188-7352267c17e7
b2c38a6c-38e7-4201-a430-3435af6fc566	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 07:40:19.474942	h	79f034a9-ee01-4de2-9238-549e53bb794f
a92414bb-dd8e-4f14-bd5d-debd7acb1075	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 07:40:19.508547	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
8c96db00-cd82-47db-a68f-3e71c12819b8	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 07:40:19.523086	m	79f034a9-ee01-4de2-9238-549e53bb794f
a705626f-1008-4dd9-bc20-0f611a1df440	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-01 07:40:19.614362	d	36133c39-09fc-41b6-93f8-590a2eae35d1
523d20f5-1d4d-493b-9e93-ccd41a99db1b	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 07:40:19.633413	m	79f034a9-ee01-4de2-9238-549e53bb794f
e0e89a04-100f-48ee-80b8-e7dd8308772c	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-01 07:40:19.663659	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
70786bf3-c083-4ec4-a6c3-1e5785c7633a	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 07:40:19.67836	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
53b95ba8-efc1-4ecf-b1ca-4a03fd9d6b58	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 07:40:19.711353	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
63f9eee6-69a8-4a43-9201-2d53d5287c7d	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 08:31:45.209492	n	79f034a9-ee01-4de2-9238-549e53bb794f
8d916d06-fbcc-4029-9635-a97c37e04696	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 08:31:45.242239	m	e6a73462-6516-415b-b188-7352267c17e7
7e8cb701-f1e5-4580-99ce-720697caf71a	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 08:31:45.292436	g	e6a73462-6516-415b-b188-7352267c17e7
2732fbba-ff23-4b94-83e3-13e39351dd21	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:04:41.789977	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
dbb6f8e8-ed78-49b5-b65e-347be348556d	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:04:41.999574	g	e6a73462-6516-415b-b188-7352267c17e7
0409c609-4f68-4d19-abe4-586fc9abf1f3	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:04:43.754783	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e8348291-d484-4f4a-a44f-c26c997b55f5	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:04:43.795374	m	e6a73462-6516-415b-b188-7352267c17e7
1a36aacf-1b69-4de9-95a0-e86a96d26d93	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:04:43.80675	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
c32ee468-a0d2-4178-bbae-cf64c3046ecd	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:04:44.719906	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
01ac84ea-c065-4b82-a6c0-b07227b16f57	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:04:44.736266	b	e6a73462-6516-415b-b188-7352267c17e7
4520bea1-809a-4f0d-8ec9-9a635fc70373	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:04:44.750507	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e709d8ec-7ac9-49b8-b4b2-d26deb427405	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:04:44.774257	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
3247cac8-3f04-48c9-8f16-e8db109ff3a7	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:33.611288	t	79f034a9-ee01-4de2-9238-549e53bb794f
49a25205-14d0-4226-bf76-68ab42c48791	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:36.739949	t	79f034a9-ee01-4de2-9238-549e53bb794f
35190926-d22e-402e-9216-874403a39ebb	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-12-01 09:04:43.74	h	36133c39-09fc-41b6-93f8-590a2eae35d1
ddf61c32-d0e6-4d05-a4f4-7fecf0918245	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-12-01 09:04:41.778547	h	36133c39-09fc-41b6-93f8-590a2eae35d1
00a1f590-83d0-446c-883e-bbb4a06edcce	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:38.653343	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
5168073f-58b6-4f6b-b86b-8f661b8fba8a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:07:38.664708	n	79f034a9-ee01-4de2-9238-549e53bb794f
86f23e91-7cfd-4435-9e88-e84460689424	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:39.395383	h	79f034a9-ee01-4de2-9238-549e53bb794f
49077f35-a705-4c17-b7a8-bff74df64b52	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:39.40195	b	e6a73462-6516-415b-b188-7352267c17e7
4111add0-529d-49fc-874f-5a223690fd47	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:39.422102	d	e6a73462-6516-415b-b188-7352267c17e7
2029d6e3-f78a-475f-b9a4-4955a2217710	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:39.433166	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
7f9a92ff-f580-47d3-8ee2-d25dea0f4bc3	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:39.44217	nj	e6a73462-6516-415b-b188-7352267c17e7
7a6e032b-f1d1-4812-affb-17cc221da877	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-01 09:07:47.360298	h	36133c39-09fc-41b6-93f8-590a2eae35d1
8cddd150-cd97-484e-9cf2-691ef0799bff	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 07:45:30.173604	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
4d5e4529-8c35-48e7-82e7-243481ccfbe3	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 07:45:30.17571	d	79f034a9-ee01-4de2-9238-549e53bb794f
16a65dce-202f-452c-a013-ef997f93881f	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 07:46:29.858304	b	e6a73462-6516-415b-b188-7352267c17e7
ac926ab2-783e-4c8b-ad86-afc236ccf7dd	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 07:46:29.925508	nj	79f034a9-ee01-4de2-9238-549e53bb794f
6a16718e-66d0-43f9-903a-541dc6b4d159	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 08:46:35.92496	d	79f034a9-ee01-4de2-9238-549e53bb794f
2550a67c-51c9-4551-a24a-d199af8ea1e2	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 20:56:38.962177	b	e6a73462-6516-415b-b188-7352267c17e7
b8983cc2-93aa-410b-8d94-6820e98e76e2	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 20:56:38.998748	g	e6a73462-6516-415b-b188-7352267c17e7
c1af2d5e-8aca-4255-bc98-72ccbd79fcbf	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-11-30 22:30:31.182558	b	36133c39-09fc-41b6-93f8-590a2eae35d1
487a1d2b-a383-495c-9f33-3a92e6ed017b	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 22:30:31.189393	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
bb581a7a-72ed-43d1-a426-32c12cc10898	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-01 07:40:19.425122	h	36133c39-09fc-41b6-93f8-590a2eae35d1
19d8ece5-46a5-49eb-8d5f-01a91127b9ec	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 07:40:19.460635	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
3b28c12e-5b8e-4b82-b77b-640d65b42437	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-01 07:40:19.466622	m	36133c39-09fc-41b6-93f8-590a2eae35d1
58a3a061-3c42-4f05-ab5a-290e7e488a0e	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-01 07:40:19.504572	h	36133c39-09fc-41b6-93f8-590a2eae35d1
752de0fc-f516-4505-99b4-9e0c90b8a9e6	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 07:40:19.520784	m	e6a73462-6516-415b-b188-7352267c17e7
c846f7ae-52ad-45cd-9035-6cc24f6c93e8	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 07:40:19.538523	h	e6a73462-6516-415b-b188-7352267c17e7
bc686d45-ff9e-49fd-873e-a1491b58af7d	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 07:40:19.566181	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
7f101ae9-6ba0-41c9-ae5b-d42d1111aad6	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-01 07:40:19.603448	t	36133c39-09fc-41b6-93f8-590a2eae35d1
6b1eeaf4-3f9e-4fc0-b5af-651872409fa7	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 07:40:19.622215	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
4464af5e-0471-47f4-91fa-5beec0a23e12	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 07:40:19.645756	t	79f034a9-ee01-4de2-9238-549e53bb794f
96e89569-03c8-402e-9970-2395ffd45f34	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 07:40:19.668708	b	79f034a9-ee01-4de2-9238-549e53bb794f
9fcc528c-e32e-4199-8134-1514f529c7c7	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 07:40:19.67987	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
c060ee8d-ad8a-4a3c-952e-b9d71dc17a9f	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 07:40:19.719217	nj	e6a73462-6516-415b-b188-7352267c17e7
eed3f808-e89b-46e6-b1bc-6fbd847e5cca	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 08:31:45.212792	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
0b8f5d90-f197-42cf-ada5-e45881d0dcf6	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 08:31:45.240217	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
176c12a9-f9ca-4fa4-9edd-413724ebbb1a	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-01 08:31:45.277157	g	36133c39-09fc-41b6-93f8-590a2eae35d1
c6365e1c-80c2-4c31-abc7-57b95dd156ed	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 08:31:45.288221	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
edd271c0-61a5-4e76-937a-c390f63d2c71	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:04:41.798859	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
416af082-b50e-4e12-8554-d1d9fa5d7bdf	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:04:41.993959	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
246813cc-41fb-4c3a-9bfb-9d3d68ac5794	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:04:43.782029	n	e6a73462-6516-415b-b188-7352267c17e7
cd08dd3a-80c7-4978-9b8c-1a4744d4bdb5	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:04:43.804083	b	79f034a9-ee01-4de2-9238-549e53bb794f
f66122f7-8e97-40ad-9be1-a7ed18509a24	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:04:43.815361	d	79f034a9-ee01-4de2-9238-549e53bb794f
ca73d2e7-47d5-410a-ad5d-01eece21a34a	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:04:43.839167	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
cafdfea4-1153-4b17-ac4d-00ddc1f3d78b	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:04:44.730376	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
1bed432a-07da-4dc7-be60-8b3f88f9850d	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:04:44.737857	h	e6a73462-6516-415b-b188-7352267c17e7
d16b003c-7d98-4b32-879b-be7a844c3a75	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:04:44.754723	m	e6a73462-6516-415b-b188-7352267c17e7
a8a3ce04-4acf-40c0-8ed7-6fc753a24372	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:04:44.770621	nj	79f034a9-ee01-4de2-9238-549e53bb794f
57484be4-d68f-4993-9bb2-c8acb300d86c	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:36.79352	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
ad4ade35-39a5-4cac-a4c3-2f13c098254a	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-12-01 09:07:36.783916	g	36133c39-09fc-41b6-93f8-590a2eae35d1
6ced6851-c15f-4d1a-8076-e3900a62f998	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-12-01 09:04:44.716271	t	36133c39-09fc-41b6-93f8-590a2eae35d1
6fe20bc3-dc8f-4740-af79-bff9bf4c94f5	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-12-01 09:04:43.8322	g	36133c39-09fc-41b6-93f8-590a2eae35d1
12a3f19f-351f-4d26-93d6-7897785ac9a6	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-12-01 09:04:43.748277	t	36133c39-09fc-41b6-93f8-590a2eae35d1
9c1d31b5-18c1-4be2-a460-761876f63593	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-12-01 09:04:41.980369	g	36133c39-09fc-41b6-93f8-590a2eae35d1
b72d5b40-574f-4c8b-a13f-2fd5e8421844	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-12-01 09:04:41.784813	n	36133c39-09fc-41b6-93f8-590a2eae35d1
c8f9ecfa-1a96-48ff-9fdf-c49025fa1f89	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:38.63516	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
1ee7f33d-5bab-4d34-b6eb-fdc4b7ba7728	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:07:38.662409	d	e6a73462-6516-415b-b188-7352267c17e7
8e4973a4-5942-4e8c-aeb9-933a58e6b1dd	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:07:38.666103	b	e6a73462-6516-415b-b188-7352267c17e7
583010fe-4c88-4416-916c-e0bdd31b13bc	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:38.706905	nj	e6a73462-6516-415b-b188-7352267c17e7
3e97b15c-c9ef-465b-8840-1bbe1cd3a9d0	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:39.397773	m	e6a73462-6516-415b-b188-7352267c17e7
e8710616-43f2-433f-af56-54b845c03f92	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:39.41202	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
ef8bddec-c102-4c3f-879c-65963a6d8a78	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:39.432181	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
44e1ef8a-d469-43bb-be7f-38331ad19394	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-12-01 09:07:39.428677	g	36133c39-09fc-41b6-93f8-590a2eae35d1
15899b1d-ecf0-49db-9c1d-91c342b72d28	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-12-01 09:07:39.375829	n	36133c39-09fc-41b6-93f8-590a2eae35d1
f0dd70ed-027c-44f7-b6a6-7eb10dc5a423	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 07:25:00.336962	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
fb2d646d-f726-4c18-afa5-6d629832d75d	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	t	2025-12-01 09:07:39.443791	nj	79f034a9-ee01-4de2-9238-549e53bb794f
fdc74ccd-2964-4f75-a9fe-9a2a08f72d01	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 08:50:01.266934	n	79f034a9-ee01-4de2-9238-549e53bb794f
1f062dc2-7dd0-40cb-aa1f-4f1008b601d2	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 08:50:01.307835	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
011285c4-9a24-4901-8c53-1cae2ee777b2	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 07:45:30.199434	n	e6a73462-6516-415b-b188-7352267c17e7
e2e909a1-3987-416b-8958-24b45a686910	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 07:45:30.284049	g	79f034a9-ee01-4de2-9238-549e53bb794f
96784099-e009-4daf-8b05-c3ab1392c88d	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-11-25 07:45:50.34115	n	36133c39-09fc-41b6-93f8-590a2eae35d1
efa7ca86-a282-42c1-af2d-7be6d519708c	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 07:45:50.359645	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
36f72483-e821-4219-9232-65440faba864	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 07:45:50.501375	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
7cde93bb-39c8-453b-9b3c-b3b5e57f8d8e	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 07:45:50.529513	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
a022983f-78c1-484f-a652-9346b022bf7f	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 07:45:50.561607	m	79f034a9-ee01-4de2-9238-549e53bb794f
f0c4441a-548d-4a79-ad4f-8e4ca5434489	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-11-25 07:45:50.613476	g	36133c39-09fc-41b6-93f8-590a2eae35d1
2f73f393-cfad-4dec-a72a-6b55f90ab689	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 07:45:50.630253	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
75bef337-36bb-47c6-b7ad-636e310a207f	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 07:46:29.880659	b	79f034a9-ee01-4de2-9238-549e53bb794f
faf67eba-322a-430b-919f-3c6780677f74	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 07:46:29.93383	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
0dcca800-db12-4421-9cb3-41290d7ff02b	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 08:46:35.929498	nj	e6a73462-6516-415b-b188-7352267c17e7
fe5fb705-816c-4dec-9547-d6c41fcdf14c	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-11-30 20:56:38.969428	t	36133c39-09fc-41b6-93f8-590a2eae35d1
d50c342a-5766-45f2-a7d6-9c222fb0b979	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 20:56:38.990297	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
18230736-7946-45ea-a7a1-76b78245fbe4	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 22:30:31.208995	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
a649fdad-bcb0-4058-adf3-28ac4bb9c6de	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 22:30:31.226488	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
c6b35a05-9628-46b3-9050-b511b1b4e0f4	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 22:30:31.256387	d	79f034a9-ee01-4de2-9238-549e53bb794f
d6db7e1c-943d-427f-9aeb-b703eacb8d89	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-01 07:40:19.446528	b	36133c39-09fc-41b6-93f8-590a2eae35d1
52721aa5-1c80-4021-96c0-9003ec0b7ccd	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-01 07:40:19.529505	n	36133c39-09fc-41b6-93f8-590a2eae35d1
c5354671-4ce3-450f-a713-4d5102f3dad6	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 07:40:19.560716	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
958aae1e-2814-4fd0-85d1-fd091c5d8797	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 07:40:19.659871	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
59505784-8c2e-4391-a362-688f687f9804	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-01 07:40:19.703821	g	36133c39-09fc-41b6-93f8-590a2eae35d1
3312cfe3-2581-473f-a346-e81c14fc8c34	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 07:40:19.709127	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
449580c5-3dde-4373-ab67-71e3018dbe29	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 08:31:45.23255	t	79f034a9-ee01-4de2-9238-549e53bb794f
5c2a331b-1a8e-4878-9f6a-4a11da50a296	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 08:31:45.263759	d	e6a73462-6516-415b-b188-7352267c17e7
eb088e9e-4c42-47bb-a7cc-756cdaeeb68e	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 08:31:45.281952	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
ec1a52c4-aead-4ce7-a696-1aba3c8e8f91	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:04:41.792809	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
0b7292e5-65dd-44b7-9a28-bf2cd5bb2afc	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:04:41.984575	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
ad11acb0-f379-4b9a-93f6-632d44496f06	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:04:43.76354	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
709d0648-41ab-4a82-a16f-9c349b057f24	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:04:43.806965	m	79f034a9-ee01-4de2-9238-549e53bb794f
e65baa14-9e50-4868-8a5c-17a523ca3d83	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:04:44.737637	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
2f267b7c-f32b-42be-bf7f-7d92b647fbd3	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:04:44.755432	m	79f034a9-ee01-4de2-9238-549e53bb794f
f32d8adf-d9f3-4e12-9513-aa33511be385	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:04:44.769725	nj	e6a73462-6516-415b-b188-7352267c17e7
9277b76a-8dba-45e0-b840-e032d5a961ec	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-12-01 09:04:44.72918	m	36133c39-09fc-41b6-93f8-590a2eae35d1
e77f65eb-4e34-4ccc-9c56-5b8a8630a708	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-12-01 09:04:41.978781	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
c6ec2388-456f-41c6-8e1b-a823e166da6e	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:07:47.366504	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
58520b9d-5788-4ca1-843d-fbea60249b4c	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-01 09:07:47.401796	t	36133c39-09fc-41b6-93f8-590a2eae35d1
39f76a13-38c0-40fb-859c-09c6b19c2031	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:07:47.405078	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
4f1436d9-1aa2-40d4-9d05-372dc15d6b32	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-01 09:07:47.437786	m	36133c39-09fc-41b6-93f8-590a2eae35d1
9768a6fb-dfa4-4388-8a99-0fe241cd516f	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:07:47.441248	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
7107d108-134f-4b82-9bde-71c8d51dbc92	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-01 09:07:47.479865	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
182c721e-44ab-4ee0-9d06-cbc4c91504ed	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:07:47.484067	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e72c218e-7f91-4384-905d-dd393665f1a4	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 07:25:00.344761	b	e6a73462-6516-415b-b188-7352267c17e7
ae38e457-1bb0-4484-a9aa-64ab6914e47e	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	t	2025-12-01 09:07:47.510493	g	79f034a9-ee01-4de2-9238-549e53bb794f
f2376c66-0bf1-4cea-85d7-89c2194a3112	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	t	2025-12-01 09:07:47.46396	d	79f034a9-ee01-4de2-9238-549e53bb794f
d4e04968-0a2c-4c69-9be7-72c1579f316a	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	t	2025-12-01 09:07:47.425493	b	79f034a9-ee01-4de2-9238-549e53bb794f
44c9d555-2c10-4419-adb8-7fa65b4b2fd2	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	t	2025-12-01 09:07:47.390501	n	79f034a9-ee01-4de2-9238-549e53bb794f
d8068efe-e34f-49c5-bf07-d222e2e95de2	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-03 08:59:26.351375	h	36133c39-09fc-41b6-93f8-590a2eae35d1
591dad0f-1c47-4492-ad01-d9cdb70c4947	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 08:59:26.373821	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c3106b8f-33fd-4439-93fa-ea34169dda39	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 08:59:26.431777	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
62da3c63-261e-4c39-902f-28df13b3ecee	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 08:59:26.437925	m	79f034a9-ee01-4de2-9238-549e53bb794f
0de02ba5-2189-405a-af3f-ea72ee4e54e8	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 08:59:26.48106	n	79f034a9-ee01-4de2-9238-549e53bb794f
f5e859f4-3dba-43db-bc8c-d69c3a939100	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 08:59:26.49536	b	79f034a9-ee01-4de2-9238-549e53bb794f
14e84735-1fe8-4789-887b-a12bf1eca7cf	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 08:59:26.556794	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
ad87d535-78ba-486f-8934-e7abe9730689	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-11-25 07:45:30.211847	g	36133c39-09fc-41b6-93f8-590a2eae35d1
f1ac7b69-9075-41fd-9b8e-041641ac1536	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 07:45:30.265291	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9a0ec3d4-5059-43d9-8998-2f54d1a73916	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 07:46:29.941777	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
20a9a3ed-7216-44c2-90a6-4bf0ed09c36a	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 08:46:35.94489	nj	79f034a9-ee01-4de2-9238-549e53bb794f
b173d54a-df0a-47ac-be18-9b2b9fcbaa4c	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 20:56:38.980005	b	79f034a9-ee01-4de2-9238-549e53bb794f
4d92a32b-01e4-40f9-a198-1412e1092190	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 22:30:31.218139	h	e6a73462-6516-415b-b188-7352267c17e7
07430117-0af9-42e4-861d-609996d17b65	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 07:40:19.477927	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
3100be26-0848-4ba6-8262-d042b3d2c50f	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 07:40:19.520491	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
6d633774-6440-4abb-82a1-11843da14e1a	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 07:40:19.536592	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
61bdbf5b-f158-401a-9e9f-7f71815faab2	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 07:40:19.56917	n	e6a73462-6516-415b-b188-7352267c17e7
d4a42593-b3f3-4230-960a-c20def5fcb0a	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 07:40:19.642855	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
7618717e-ab1c-4319-a01c-6b283479f566	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 07:40:19.666014	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
ad7f2e47-06ad-45f2-8045-6322d9eb045f	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 07:40:19.680963	nj	e6a73462-6516-415b-b188-7352267c17e7
50962972-08bb-4e18-b134-1738f1d1dfc0	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 08:31:45.234103	h	79f034a9-ee01-4de2-9238-549e53bb794f
add270e1-6201-4dc6-9b86-87caf92da2bc	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 08:31:45.262078	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
4bfb862d-14b1-44b4-967e-a43067ba1f91	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 08:31:45.284003	nj	79f034a9-ee01-4de2-9238-549e53bb794f
e7258a7e-fa09-45dc-9022-7d5bf9d04dd4	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:04:41.861558	h	e6a73462-6516-415b-b188-7352267c17e7
c3b97b1a-ed5c-4526-8ee6-d8db04768f3e	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:04:41.946447	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e2ad770a-88af-409f-835f-9fc59479eae9	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:04:41.966966	d	79f034a9-ee01-4de2-9238-549e53bb794f
c5f819a9-4a84-4dd8-8ab2-776928928694	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:04:41.988964	nj	e6a73462-6516-415b-b188-7352267c17e7
282cf214-5e33-4fa2-a9e1-5f23cb134ebd	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:04:43.802518	b	e6a73462-6516-415b-b188-7352267c17e7
559f76e5-7747-4e9d-92dc-1afe377fe7f8	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:04:43.814149	d	e6a73462-6516-415b-b188-7352267c17e7
c4c81b88-01b8-4edd-a3a2-df628e73f8fb	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:04:44.72092	d	79f034a9-ee01-4de2-9238-549e53bb794f
48caadf5-bc85-49e2-9626-30959c9264b9	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:04:44.736401	b	79f034a9-ee01-4de2-9238-549e53bb794f
fb82571b-cde2-47e9-b67f-c171507b85d9	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-12-01 09:04:41.941843	m	36133c39-09fc-41b6-93f8-590a2eae35d1
ae5ffa1e-7d2a-4b57-8372-ecdc537009f4	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-01 09:07:47.502319	g	36133c39-09fc-41b6-93f8-590a2eae35d1
5e9cfac7-1957-4b66-8617-609c4897e11e	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:07:47.506772	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
ea4d4079-97ad-4294-9cbd-96bf0cef2bc5	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 07:25:00.350398	n	e6a73462-6516-415b-b188-7352267c17e7
70bbcdc4-0913-4199-80ec-d4ca603ff0f6	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-03 08:59:26.35531	t	36133c39-09fc-41b6-93f8-590a2eae35d1
944bed0e-622f-46ae-806e-73769e9a9e8d	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 08:59:26.38698	t	e6a73462-6516-415b-b188-7352267c17e7
5e9e8616-797a-49ed-91f0-3c28cbd5dab2	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 08:59:26.438601	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
58074a00-30ae-499f-a59d-bcd3a3bb4434	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 08:59:26.480599	n	e6a73462-6516-415b-b188-7352267c17e7
901323d5-eb12-43b8-baf4-b23dc1d0b01e	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-03 08:59:26.521566	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
d384fed1-c7f8-411a-91e3-dc5d4c1d84a9	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-03 08:59:26.546001	g	36133c39-09fc-41b6-93f8-590a2eae35d1
8b0c3d87-4ffa-4912-98e7-43d8808de524	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 08:59:26.579061	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
a6c742d6-661c-412a-b1a4-39d752630b5b	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-03 08:59:26.71626	n	36133c39-09fc-41b6-93f8-590a2eae35d1
b21f5acf-e581-4f04-822c-39eba23c4a97	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 08:59:26.741902	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
2c7ae451-9649-48e5-a55b-daf382242c2f	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 08:59:26.754916	n	e6a73462-6516-415b-b188-7352267c17e7
ff4ebe89-dcc7-4372-a795-ca72b6e8e79c	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 08:59:26.772545	m	e6a73462-6516-415b-b188-7352267c17e7
702e5fac-1749-4c8f-947c-dc7aef718881	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 08:59:26.806622	nj	79f034a9-ee01-4de2-9238-549e53bb794f
0c7f8eef-1074-428a-b537-9a421fa04efd	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 13:58:25.84383	t	79f034a9-ee01-4de2-9238-549e53bb794f
f037d2dd-c9e0-40c5-b1dc-6c7ed1776767	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 13:58:25.882466	d	e6a73462-6516-415b-b188-7352267c17e7
2884ea64-92eb-4e8b-a500-7706515241ec	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 13:58:25.911382	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
28200e03-7a99-4450-bb6c-f18cb6b42ef4	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 14:13:46.852295	b	e6a73462-6516-415b-b188-7352267c17e7
5985d996-5c89-4784-b3e6-e0a6c0b5e93a	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 14:13:46.886465	d	e6a73462-6516-415b-b188-7352267c17e7
d3b7495d-6f41-4649-a596-57c11a87992b	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 07:45:30.223295	h	e6a73462-6516-415b-b188-7352267c17e7
83bacf9a-7f70-45fe-90c3-01ec0270cf12	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 07:45:30.271371	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
650a4da7-c2dd-476c-b80d-09c4979a94e0	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-11-25 07:46:35.240386	h	36133c39-09fc-41b6-93f8-590a2eae35d1
cc990d0a-729f-4e52-874e-578ad1a6f797	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 07:46:35.27002	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
d927f68b-13be-4338-bb9e-37b872ccc0ba	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 07:46:35.327891	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c9c50d12-9ba3-413a-aabe-cfcf9fb6019d	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-11-30 20:51:58.133945	n	36133c39-09fc-41b6-93f8-590a2eae35d1
886d5008-9e3c-4887-8194-99118dca8be3	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 20:51:58.19904	m	e6a73462-6516-415b-b188-7352267c17e7
b5b18561-90ea-4252-82a9-ecd764620132	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 20:51:58.215458	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9d64325c-2a2c-4e61-95fd-3b8cf1d8fe1a	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 20:51:58.241143	h	79f034a9-ee01-4de2-9238-549e53bb794f
d623da2c-1d71-491f-b5ca-91165bb5de80	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 20:51:58.294696	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
87d46d6d-563b-45c5-8491-79aae077d7e8	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-11-30 20:58:01.334653	h	36133c39-09fc-41b6-93f8-590a2eae35d1
b159cd0f-b372-44db-adc6-dc9593e6e65c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 20:58:01.345352	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
4472d00a-c7f1-42bc-a581-8fa42e5c840d	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-11-30 20:58:01.66319	g	36133c39-09fc-41b6-93f8-590a2eae35d1
d2e3cb8f-b8f4-4e9e-b336-45647318e2f2	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 20:58:01.672534	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
84b7fed8-1941-4df2-9d1a-4806f34caddd	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 22:30:31.233784	h	79f034a9-ee01-4de2-9238-549e53bb794f
f2c77f83-7e5f-4725-aa7e-7c476200f9d5	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 22:30:31.255365	d	e6a73462-6516-415b-b188-7352267c17e7
ffdc1b04-d8a0-4152-83e4-f3a0bd5e4d10	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 22:30:31.273027	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
09415857-536e-437e-bd6d-4e04bd6d3a22	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 22:30:31.285642	g	e6a73462-6516-415b-b188-7352267c17e7
545561af-9e3c-416a-b8f6-32827555c7e7	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 07:40:19.50825	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
18a70500-8c08-4f06-b91e-6d1d75cc076e	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 07:40:19.533713	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
14c62b38-c9ce-405b-a883-a448ab3005e3	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 07:40:19.661775	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
bba0ca13-7819-4b6d-9b6d-d70f10dc6464	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 07:40:19.692883	g	79f034a9-ee01-4de2-9238-549e53bb794f
0021bfdb-bb84-49bf-bb7d-768134b88a15	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 07:40:19.712536	g	e6a73462-6516-415b-b188-7352267c17e7
4556bf55-e720-415f-b4f3-a7e5639ff392	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-01 08:40:20.062643	h	36133c39-09fc-41b6-93f8-590a2eae35d1
8089aa6a-ac08-4b3f-aad1-6e733bf4973c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 08:40:20.073121	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
1f4c9f1b-0d21-48d5-acd3-6d6c812ce3b7	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 08:40:20.12049	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
7b3c74ef-1eb2-4d6f-ae49-e114223b7883	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 08:40:20.188437	b	79f034a9-ee01-4de2-9238-549e53bb794f
56dc49cf-c609-482c-9a61-2e5e9be1be12	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-01 08:40:20.20793	d	36133c39-09fc-41b6-93f8-590a2eae35d1
f24e3a48-f192-4fc4-9db8-fb05da8ece29	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 08:40:20.210984	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
be898a9a-30c1-491d-b5d7-6929035b2548	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 08:40:20.229755	nj	e6a73462-6516-415b-b188-7352267c17e7
e1b0c9a9-67c4-4d02-82de-a8c52edd97ad	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 08:40:20.240804	g	e6a73462-6516-415b-b188-7352267c17e7
4d0ece20-7c1c-4a93-a2d5-eb78a4b0a66b	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:04:41.871401	h	79f034a9-ee01-4de2-9238-549e53bb794f
47a7cd1b-a19a-418b-804a-491fa7eb014c	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:04:41.919395	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
33ddac1e-6343-4556-888d-9d1f44a578fe	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:04:41.932261	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
91e1dfaf-a1b2-498c-9966-c0caa85e4bd0	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:04:41.964407	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
4e0aa920-87e8-4f3f-9331-28183655b4f5	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:04:43.805226	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
fff8bf14-b16a-4b44-a25d-e38cbdc9c7c0	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:04:43.827388	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
af84e18b-b56a-440d-b31c-b8c20425a866	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:04:44.734864	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
85107d83-68b6-4e27-b456-55f41e22236b	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:04:44.747635	t	e6a73462-6516-415b-b188-7352267c17e7
16525b9e-19a2-4f37-ab80-75b584820220	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:04:44.77556	g	e6a73462-6516-415b-b188-7352267c17e7
9f0e13c6-02e2-459d-9757-484e1605cd86	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-12-01 09:04:43.823455	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
0d3fe319-9981-4325-bb4a-dd5338fda7a2	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-12-01 09:04:43.779186	d	36133c39-09fc-41b6-93f8-590a2eae35d1
9cdab8f4-f768-492e-a904-0de75d6e78bc	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-12-01 09:04:41.957673	d	36133c39-09fc-41b6-93f8-590a2eae35d1
7639251f-3918-4dc3-97bc-39789e7c695e	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-12-01 09:04:41.927132	b	36133c39-09fc-41b6-93f8-590a2eae35d1
e3759535-ac6b-4fd5-9e5c-2e3528677964	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	t	2025-12-01 09:04:41.909559	t	36133c39-09fc-41b6-93f8-590a2eae35d1
ac7649bf-4011-4097-95ff-f562be75f9b1	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-01 11:21:25.453981	h	36133c39-09fc-41b6-93f8-590a2eae35d1
fb66943a-6468-4383-95d0-dcd909cc054c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 11:21:25.486014	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
5b76fb86-ab07-4348-9b72-9a8d2613c37a	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 11:21:25.62455	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
30b9f304-372f-4848-b7f2-c51b8e5e0144	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 11:21:25.651645	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
4e92ce54-bcd8-45f6-a696-6c88c23018c6	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 07:25:00.38239	t	e6a73462-6516-415b-b188-7352267c17e7
0ae4387e-8194-423c-8b95-f1f2b435c2bf	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	t	2025-12-01 11:21:25.634533	h	79f034a9-ee01-4de2-9238-549e53bb794f
a5472654-8a0b-45ee-b500-f53dbc2e6ec7	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	t	2025-12-01 11:21:25.712391	d	79f034a9-ee01-4de2-9238-549e53bb794f
85191d72-c543-43dc-9b22-6305caa49560	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-03 08:59:26.356954	m	36133c39-09fc-41b6-93f8-590a2eae35d1
33702cc9-a6b7-4d05-bc2c-90239da3642c	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 08:59:26.476339	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
be0a788c-8ac4-4719-bf9b-87e3c004748e	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 08:59:26.494669	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
46a3fc6e-9c3b-4dc3-8f83-6497adeb27e8	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 08:59:26.548763	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
3d9a1e8e-19a0-4f1b-8b7c-cdb092052613	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 08:59:26.585798	g	e6a73462-6516-415b-b188-7352267c17e7
682bdb5d-bdc4-4c67-ad48-7821c4bd570f	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 07:45:30.229964	h	79f034a9-ee01-4de2-9238-549e53bb794f
2f149d5b-a748-452c-bbaf-b54e5ac9bd33	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-11-25 07:46:35.247489	n	36133c39-09fc-41b6-93f8-590a2eae35d1
64ad6002-771f-4a06-bb1a-5a9a27c41e48	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 07:46:35.274062	t	79f034a9-ee01-4de2-9238-549e53bb794f
6eda5347-20b8-4ab2-8e32-beefb74573b7	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 07:46:35.310566	b	79f034a9-ee01-4de2-9238-549e53bb794f
c13240cc-11d9-4c2c-9b61-520b0a5908f9	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 07:46:35.3585	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
b4ded8ac-975a-42c3-9ab0-7f409472fd7f	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 07:46:35.391849	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
13d40d43-4466-47f5-97d6-77af2b0735f5	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-11-30 20:51:58.138668	m	36133c39-09fc-41b6-93f8-590a2eae35d1
d27d5114-0313-496f-bf7d-2866e3303988	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 20:51:58.181989	t	79f034a9-ee01-4de2-9238-549e53bb794f
b14e4e20-8f92-484e-ab4d-eadb03bcb667	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 20:51:58.198793	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
4fa11fb3-fabf-4985-b882-341ca81fc07a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 20:51:58.212921	n	e6a73462-6516-415b-b188-7352267c17e7
83caef66-4caa-4d60-af89-55ec4e3870a5	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-11-30 20:51:58.220798	h	36133c39-09fc-41b6-93f8-590a2eae35d1
d48cbed3-cabf-4093-b581-000632fd240c	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 20:51:58.232949	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
1e41ce1f-9cbe-4606-8176-2ec5d7950b44	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-11-30 20:51:58.256072	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
05bdf546-1401-412a-bd21-a2f9acf9e110	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-11-30 20:51:58.277492	d	36133c39-09fc-41b6-93f8-590a2eae35d1
befe6422-ff3f-40dc-b632-ff8e4dd23f96	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 20:51:58.293034	b	79f034a9-ee01-4de2-9238-549e53bb794f
78c39337-159a-42a0-97ce-85f2f25ddf81	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 20:51:58.311945	d	e6a73462-6516-415b-b188-7352267c17e7
4f237484-e36b-44c0-aa31-6e4c6a182d9e	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 20:58:01.412782	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
dd874b2f-fc51-42d5-8898-75d68c0acdf0	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-11-30 20:58:01.597575	m	36133c39-09fc-41b6-93f8-590a2eae35d1
e23f9a8b-d11f-466d-9798-6ccf9db10b4d	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 20:58:01.630339	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
886f4fb3-ebfd-495a-a5bb-554795977ed3	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 20:58:01.642535	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9c5f1e10-2a7b-41c6-be22-143bde726ca8	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 22:30:31.238473	t	e6a73462-6516-415b-b188-7352267c17e7
81d9665b-8ffd-4165-b37b-bebb6cbe513f	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 22:30:31.254544	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
570cd5c0-d693-4d21-8642-e28f341e3c57	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 22:30:31.274031	nj	e6a73462-6516-415b-b188-7352267c17e7
ff3f3195-4110-40ee-b7ad-cfb9c1ed3eee	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 22:30:31.284563	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
bfaab6fd-ddbf-436b-9d5e-a0a58d93ab2f	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 07:40:19.546319	t	79f034a9-ee01-4de2-9238-549e53bb794f
447b5c24-6055-4412-902c-9890e350019d	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 07:40:19.643784	t	e6a73462-6516-415b-b188-7352267c17e7
9accef31-cc50-41b1-8ded-7e35afadae06	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 07:40:19.666291	d	e6a73462-6516-415b-b188-7352267c17e7
4e1ead49-5c7e-49c2-a5f2-08e7421e67b1	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 07:40:19.682863	nj	79f034a9-ee01-4de2-9238-549e53bb794f
af3ae023-7c5a-4180-9b04-150a1eb83bbc	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-01 08:40:20.1103	n	36133c39-09fc-41b6-93f8-590a2eae35d1
ac9463f1-924a-4f1b-9f0b-96b40a2b7c70	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 08:40:20.119146	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
5e326cac-a100-4ef6-84e9-c1158961e922	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 08:40:20.244929	t	79f034a9-ee01-4de2-9238-549e53bb794f
93c1a8c5-1d7d-47cc-989f-f9986cd72a0b	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:04:41.888696	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
51c715f9-602f-43c6-8616-50916e44608e	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:04:41.921321	t	79f034a9-ee01-4de2-9238-549e53bb794f
b3f58385-850a-4d80-9f64-8c88671f314f	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:04:41.93396	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
d4ff3828-dcc6-405d-9711-25e496a0a7eb	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:04:41.951171	m	79f034a9-ee01-4de2-9238-549e53bb794f
37854946-891a-4611-8bec-d2f66f5b31ad	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:04:41.996422	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
6be2a959-194a-47f1-b5fa-6476fb5c5f25	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:04:43.764994	h	79f034a9-ee01-4de2-9238-549e53bb794f
66b12208-74aa-4fcd-8905-6ea500209239	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:04:43.791528	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
3bf7188c-70e7-4b4c-9db1-e877386b4ef7	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:04:43.794732	t	e6a73462-6516-415b-b188-7352267c17e7
c7a123c1-b74e-4117-951d-fedcfbf2f904	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:04:43.807238	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
7bc2477f-6769-4997-94bf-2e083309431b	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:04:43.831112	nj	79f034a9-ee01-4de2-9238-549e53bb794f
f279eaa1-21b7-4405-9e83-a5a131078e67	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:04:43.840441	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
a40cf64a-7b8c-4812-a932-589ed792d126	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:04:44.717609	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
205700dd-10a8-4a51-b495-22af622a21bd	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:04:44.736058	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
cfb6e877-bd51-46b8-84cf-47bef3d2ce5d	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:04:44.748914	t	79f034a9-ee01-4de2-9238-549e53bb794f
1f5c8550-d2e6-41ce-92e5-d4ffcc43c49b	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:04:44.768925	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
736957ec-9f8f-4806-8b8b-811ad4d89280	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	t	2025-12-01 09:04:44.709616	d	36133c39-09fc-41b6-93f8-590a2eae35d1
0d5dfe1b-96fd-451d-9a52-ab85addb0963	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-12-01 09:04:43.741928	n	36133c39-09fc-41b6-93f8-590a2eae35d1
1c5d018c-b3c7-4bf2-925a-5535dbc56437	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-01 11:21:25.472458	n	36133c39-09fc-41b6-93f8-590a2eae35d1
cdcdcc15-4379-4e74-a85f-77c0858889fc	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 11:21:25.51941	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
52fefd2d-f934-4420-af43-cb96b6977d88	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 11:21:25.64876	m	e6a73462-6516-415b-b188-7352267c17e7
6ad03562-1780-4986-8c8a-705c3f8342ff	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-01 11:21:25.71742	g	36133c39-09fc-41b6-93f8-590a2eae35d1
5ab41ba8-8cb7-44c7-8a99-7e6fb32cc5dd	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	t	2025-12-01 11:21:25.628501	b	79f034a9-ee01-4de2-9238-549e53bb794f
c862b18d-e3ee-4894-9287-650490b88991	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-11-25 07:45:50.45406	b	36133c39-09fc-41b6-93f8-590a2eae35d1
4cf86fc6-fd43-4687-9c1b-42a8eb6ed500	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 07:45:50.518293	b	e6a73462-6516-415b-b188-7352267c17e7
56b2ed74-1c14-42ab-a126-68f09e66519a	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 07:45:50.522498	b	79f034a9-ee01-4de2-9238-549e53bb794f
f46580d9-c576-4148-95ee-33ef35dac73d	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 07:45:50.603769	nj	79f034a9-ee01-4de2-9238-549e53bb794f
1e8e6b68-4be3-48e6-acf7-8628bea128b7	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 07:45:50.642489	g	79f034a9-ee01-4de2-9238-549e53bb794f
9f223908-06f0-4fbb-9f8d-120e7d29ff8b	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-11-25 07:46:35.250436	t	36133c39-09fc-41b6-93f8-590a2eae35d1
71ae48c9-1c78-41dc-a077-f3bf72f0a2fa	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 07:46:35.273683	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
ccf921f6-9963-4120-a69e-32cbb9989641	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 07:46:35.309527	b	e6a73462-6516-415b-b188-7352267c17e7
5d33c31f-8b12-471f-9145-3d2b5cac2e2d	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 07:46:35.351866	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c884af0d-275e-458f-bd5d-4500b5670b56	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 07:46:35.389132	g	e6a73462-6516-415b-b188-7352267c17e7
ac856231-8f6d-4dda-9a50-aff0a46a546f	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-11-30 20:51:58.141214	t	36133c39-09fc-41b6-93f8-590a2eae35d1
dbf4cdf9-4312-4b03-a31f-4a2da8335ce5	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 20:51:58.178221	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
cb8766a0-5d89-4f2a-8ea4-077b59a60de2	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 20:51:58.209537	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
eea2dab3-7790-450e-8ea1-3f073c5309da	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 20:51:58.284892	g	79f034a9-ee01-4de2-9238-549e53bb794f
4da6b94b-fe01-4b5c-8db3-a0f2fe107dfc	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 20:51:58.287323	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
584b594c-4c19-4c90-a711-764116e7045e	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 20:51:58.3137	d	79f034a9-ee01-4de2-9238-549e53bb794f
48ed3073-dae1-4d9e-b598-f72110347853	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 20:58:01.431101	n	e6a73462-6516-415b-b188-7352267c17e7
8d60c81a-5c39-406f-a97a-b6db8f034b29	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 20:58:01.498114	t	79f034a9-ee01-4de2-9238-549e53bb794f
81480514-4d13-4799-a2e5-d9c765e3c673	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 20:58:01.58894	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
d152c1e8-2729-44c4-9da0-b1188e348037	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 20:58:01.633826	m	e6a73462-6516-415b-b188-7352267c17e7
ca7965dd-06e6-437e-8d6e-646492a9f798	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 20:58:01.65423	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
fafdda06-e93d-4710-a6bc-922cdc8291e6	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 20:58:01.675738	g	e6a73462-6516-415b-b188-7352267c17e7
a943cdce-820e-4c76-a0bf-3ab51bdfc503	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 22:30:31.251141	t	79f034a9-ee01-4de2-9238-549e53bb794f
e4e5fe68-8496-4154-8cc9-63ff152f302a	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-11-30 22:30:31.278337	g	36133c39-09fc-41b6-93f8-590a2eae35d1
922951f1-04b0-4189-98bc-ef3108477dd7	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 22:30:31.283386	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
965c9be1-aefc-4133-9cfa-f09878929ab9	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 07:40:19.548226	t	e6a73462-6516-415b-b188-7352267c17e7
ba9d4a85-a484-4717-9d93-573014c14686	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 07:40:19.647927	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
9a9f4944-228e-470e-b337-7118147c5af6	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-01 07:40:19.670603	g	36133c39-09fc-41b6-93f8-590a2eae35d1
d69e935d-24c1-4d7a-abf0-af1f25fda4b8	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 07:40:19.686275	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
00440a55-1252-45ee-81de-fb1e2d4a0492	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 07:40:19.722055	nj	79f034a9-ee01-4de2-9238-549e53bb794f
22aba238-02e3-4137-af15-3924bc925bab	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-01 07:42:21.117942	h	36133c39-09fc-41b6-93f8-590a2eae35d1
9ff8f34b-f531-46b2-a1e1-8efaa5d4db31	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 07:42:21.122892	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
b1fa31ad-0a52-44d5-aa2a-7e60c897fe55	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 07:42:21.139455	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
73d04325-4a92-4435-bde2-573443954a1b	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 08:40:20.137457	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
e8027414-c1fe-417a-98f8-bb85fc7fc65c	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 08:40:20.185696	b	e6a73462-6516-415b-b188-7352267c17e7
5c5721e9-9b26-4319-bfe0-af5a19bc5262	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 08:40:20.205509	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
1e6ea42c-ddb7-4114-9390-a78b5adb6565	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 08:40:20.216174	d	79f034a9-ee01-4de2-9238-549e53bb794f
a31b2a5f-4339-4ff4-9191-e3fdfd685ac1	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-01 08:40:20.22221	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
2737887e-d4db-4867-bb0a-b25425c60771	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 08:40:20.22566	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
42626509-90ed-43c0-a4a6-dc48a4180d93	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 08:40:20.242934	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
35c018c8-f0d7-4308-ba05-840ae0656977	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:04:41.891979	n	e6a73462-6516-415b-b188-7352267c17e7
0df971f0-abfe-48ee-a6d4-bddf0c759b8d	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:04:41.920499	t	e6a73462-6516-415b-b188-7352267c17e7
4cbfcfb9-219c-4327-b604-76a80f9020c3	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:04:41.935516	b	e6a73462-6516-415b-b188-7352267c17e7
7dccdbc8-b2b6-400c-b588-a228e3017c5d	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:04:41.949758	m	e6a73462-6516-415b-b188-7352267c17e7
7979e3b4-6def-4bde-9c49-04cde8b26290	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:04:41.965805	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
800c2366-b4c6-4c0d-a26b-ff3cb4a0801e	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:04:41.990101	nj	79f034a9-ee01-4de2-9238-549e53bb794f
67ebff76-2e53-4482-bd40-902cc0a9d1e0	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:04:43.76466	h	e6a73462-6516-415b-b188-7352267c17e7
b4e0731f-ecec-4cc9-a8e4-180ab97ecdf4	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:04:43.800624	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
1ddf2204-3a93-4364-8b35-a6dc44a8bde9	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:04:43.812713	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
5cc14a22-feb9-4142-8526-27ae3b29e813	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:04:43.829008	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
1f624983-e03c-4ad1-931a-67da1ef106ee	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:04:43.843632	g	79f034a9-ee01-4de2-9238-549e53bb794f
b4d21de8-6511-4729-b30b-6bb24ef6dbc8	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:04:44.733218	n	79f034a9-ee01-4de2-9238-549e53bb794f
6a6aeedd-996c-4f72-8faf-a84bdb0b928e	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:04:44.740557	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
1b0aaf04-946c-4188-ba91-7cf595671e71	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-12-01 09:04:44.714505	b	36133c39-09fc-41b6-93f8-590a2eae35d1
3fd7f4e7-b178-4516-8162-a59d99c09b98	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	t	2025-12-01 09:04:43.751732	b	36133c39-09fc-41b6-93f8-590a2eae35d1
82d620e1-afd4-4138-a9ee-52f97dd06202	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-11-25 07:45:50.458482	h	36133c39-09fc-41b6-93f8-590a2eae35d1
f139da67-398f-4c09-8e86-fd601f489d4e	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 07:45:50.488956	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
94ccc5a5-c9ce-48f0-9af4-6d1f469c8db3	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 07:45:50.534394	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
3ee33099-d2f7-4948-9331-98d85c170242	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 07:45:50.557558	m	e6a73462-6516-415b-b188-7352267c17e7
e807f077-a8b7-4c16-966d-20390b09763b	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 07:45:50.600289	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
dbb8df6c-318b-4ea3-9a78-5ee6eb82ff5e	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-11-25 07:46:35.252922	b	36133c39-09fc-41b6-93f8-590a2eae35d1
e5789ade-ad59-4221-a287-8b7986563a65	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 07:46:35.297669	h	79f034a9-ee01-4de2-9238-549e53bb794f
36a00b28-fe98-4f07-bd16-b221f3b732c6	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 07:46:35.324779	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
a51233d5-4561-4ce7-a834-2272da547dde	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-11-25 07:46:35.370545	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
a198aa4c-bac7-48b9-9c5f-77f0304aa045	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 07:46:35.399692	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
17f35f95-0ba6-471f-8bbd-33d2337a4c2b	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-11-30 20:51:58.144101	b	36133c39-09fc-41b6-93f8-590a2eae35d1
da373780-e096-4e0e-8984-6a422542dbf1	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 20:51:58.170188	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c0f9f327-cf70-45a3-a517-3ee072ef4b61	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 20:51:58.204766	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
e65f13f4-7cc7-4e38-9856-06b5306f4213	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 20:51:58.21516	n	79f034a9-ee01-4de2-9238-549e53bb794f
f6adb3b4-768f-4d62-b05a-a04a8dc71bdf	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 20:51:58.239229	h	e6a73462-6516-415b-b188-7352267c17e7
f398d5c8-5f36-4aa2-872d-c7326afae7ac	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 20:51:58.282984	g	e6a73462-6516-415b-b188-7352267c17e7
9027e2f1-3011-4d2b-ad09-efe1c76f0ff8	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 20:51:58.307217	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
cf710621-257e-4c62-b63c-e02389899514	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 20:58:01.447553	n	79f034a9-ee01-4de2-9238-549e53bb794f
cc4bad6e-c34b-47d8-91f8-13ad7667d4f8	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 20:58:01.496265	t	e6a73462-6516-415b-b188-7352267c17e7
a1204512-5ee0-41ff-85c9-73a9d6c055a3	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 20:58:01.515161	b	e6a73462-6516-415b-b188-7352267c17e7
95b60a4e-420b-46c7-9d2c-296b8f16c2c6	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-11-30 20:58:01.610332	d	36133c39-09fc-41b6-93f8-590a2eae35d1
4e09b1b1-b45b-433d-84e4-1307b785b32e	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 20:58:01.649223	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
7b982791-4cde-4b6d-af54-e2714b604bbd	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 22:30:31.266413	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
9f66ebd7-85ba-4aac-a680-a2a58877b290	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 07:40:19.55609	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
331357f3-9934-467e-b49a-806b328b4407	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-01 07:40:19.608243	b	36133c39-09fc-41b6-93f8-590a2eae35d1
7beea684-ee91-4ece-b003-c0e47880ee9d	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 07:40:19.666545	d	79f034a9-ee01-4de2-9238-549e53bb794f
c0914510-f98f-4b4e-b094-fafe6446f1b2	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-01 07:40:19.705227	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
592d8938-a357-462d-aeeb-47e36a8b9a08	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 07:40:19.715592	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
3a3dc103-08b9-49e6-9e9a-40663e8770f8	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 08:40:20.144355	h	e6a73462-6516-415b-b188-7352267c17e7
e384eb4a-8120-4258-8776-f68ae3ebf515	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 08:40:20.187134	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
1820652e-574a-46b7-bcb6-3579ad2257c1	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 08:40:20.207	m	79f034a9-ee01-4de2-9238-549e53bb794f
5258bd58-da42-4afc-82e0-91d02713fa4d	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 08:40:20.21278	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
b00e2519-0c64-403d-b045-a5ef9421c223	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 08:40:20.226862	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
0cc8edfe-5210-4e41-bb16-4f53bab0d453	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 08:40:20.241514	g	79f034a9-ee01-4de2-9238-549e53bb794f
4f362b5d-4f92-4fd6-82f1-4b723d81ba6a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:04:41.899991	n	79f034a9-ee01-4de2-9238-549e53bb794f
20eaf5fc-18bb-4833-b9c0-7b8f55844dee	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:04:41.917142	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
ba44259d-0855-4b4a-b798-63fbf5b0ba88	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 09:04:41.936894	b	79f034a9-ee01-4de2-9238-549e53bb794f
654600dc-e10c-4f33-a285-870ef543d696	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:04:41.948119	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
6a10fa0d-4c2c-4c82-bf9f-147df79caad3	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:04:41.968656	d	e6a73462-6516-415b-b188-7352267c17e7
d453475d-c487-45bb-8e7d-da3d97a3c08a	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:04:41.987609	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
32830635-b718-4e9e-866e-4656190a1a45	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:04:43.766967	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
b2397903-7657-4d46-b36b-d658039fb65f	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:04:43.7951	t	79f034a9-ee01-4de2-9238-549e53bb794f
4e932a6c-5fac-4b66-a24b-d354af983642	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:04:43.810955	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
828d1a44-a581-4d59-9d31-c8d33440b20d	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:04:43.830056	nj	e6a73462-6516-415b-b188-7352267c17e7
48cbbad9-bed7-4a51-8aec-859ad0ca1d38	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:04:43.841615	g	e6a73462-6516-415b-b188-7352267c17e7
b99613e4-09a5-48b2-9016-ba6b20718e68	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:04:44.730681	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
fc0d1977-5d7f-4c2b-9fff-15f236c56372	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:04:44.738044	h	79f034a9-ee01-4de2-9238-549e53bb794f
d69265c3-de96-4a39-a93e-023e8432f763	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 09:04:44.753858	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
0f5b7890-7fef-4743-a2d7-1b85a4dee6b9	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	t	2025-12-01 09:04:44.712385	h	36133c39-09fc-41b6-93f8-590a2eae35d1
2bc3901f-7246-4576-ab24-88b5e0e44165	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 11:21:25.501543	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
dff7f386-10bf-4913-863b-008d09dcf9b7	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-01 11:21:25.612878	b	36133c39-09fc-41b6-93f8-590a2eae35d1
1426e136-e07d-44d0-ae45-75c74564ce74	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 11:21:25.626132	b	e6a73462-6516-415b-b188-7352267c17e7
540b31cc-afea-48c0-af35-c1e2f0465190	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 11:21:25.634344	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
8f134686-a177-4185-801e-eb9e734ea25c	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-01 11:21:25.67898	d	36133c39-09fc-41b6-93f8-590a2eae35d1
356884c4-5d59-404e-be16-d19c53585457	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	t	2025-12-01 11:21:25.651504	m	79f034a9-ee01-4de2-9238-549e53bb794f
8d8a3745-da95-4964-a1cb-a346073c1284	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-11-25 07:45:50.475	t	36133c39-09fc-41b6-93f8-590a2eae35d1
7cd4aff1-dc7b-4ae7-a05b-70aad496e7e6	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 07:45:50.514281	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
706e3059-0967-4ec8-9213-f7ede2399033	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 07:45:50.541451	t	79f034a9-ee01-4de2-9238-549e53bb794f
0f2e8917-13e6-494f-acc9-ac3aeb935a5d	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 07:45:50.602279	nj	e6a73462-6516-415b-b188-7352267c17e7
a5177092-8428-4c1a-b217-cd3eae1cd571	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 07:45:50.617712	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
cc858c56-f1c8-466c-b905-1fbb03004b6c	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 07:45:50.639324	g	e6a73462-6516-415b-b188-7352267c17e7
99337b7a-e35c-4543-a95f-285f6b0cf435	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-11-25 07:46:35.255878	m	36133c39-09fc-41b6-93f8-590a2eae35d1
8b4e4f0d-6aa1-4bd6-8d46-f59508c47312	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 07:46:35.303519	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
574188bc-05fd-4f16-9385-5d9395d40eef	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 07:46:35.342475	d	e6a73462-6516-415b-b188-7352267c17e7
cf750081-36f4-4599-b997-b5d53c53462d	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 07:46:35.401809	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
3696458e-9626-4da0-831a-fe519dd4343b	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 20:51:58.201632	m	79f034a9-ee01-4de2-9238-549e53bb794f
d778ff11-f72d-4db9-afb1-03932de46494	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 20:51:58.220282	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
1ce313bc-bfad-409c-8094-2f98c1151c20	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 20:51:58.236692	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
188fe5c7-9b5f-4266-afde-e12ae1c691af	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-11-30 20:51:58.261753	g	36133c39-09fc-41b6-93f8-590a2eae35d1
05c36b4d-6d6c-4c14-9e07-63144cb75ac8	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 20:51:58.28137	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
5a4ecded-05ab-4b28-b0bd-612d918e48a5	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 20:51:58.293414	t	e6a73462-6516-415b-b188-7352267c17e7
8da25285-be72-46cc-b253-2c33c78e1d84	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 20:51:58.310626	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
d805acda-ab87-468c-892d-c7302f40b6a9	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 20:58:01.453501	h	e6a73462-6516-415b-b188-7352267c17e7
95a1c9f4-250d-43fc-ba90-9248cd2d2b04	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-11-30 20:58:01.481629	t	36133c39-09fc-41b6-93f8-590a2eae35d1
c6a98072-755d-4abe-9547-82b71964128d	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 20:58:01.491589	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e7c10c87-88c6-4dd7-b97c-60eb0191c539	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 20:58:01.590535	b	79f034a9-ee01-4de2-9238-549e53bb794f
cfe3c19c-8d10-4139-a605-17e56c3c534b	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 20:58:01.632174	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
cc5d72c7-494f-4a97-9cde-3092867c3acf	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 20:58:01.656222	d	e6a73462-6516-415b-b188-7352267c17e7
9beeaf17-acb8-44bf-96b1-9d7b3a1d7eb1	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 20:58:01.674268	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
1e522682-7e9b-448b-9dab-63aeacef268f	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-01 07:37:21.938032	h	36133c39-09fc-41b6-93f8-590a2eae35d1
a537fa0f-3ffa-46b9-b5f2-d569edec193a	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 07:37:21.950555	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
8542213c-486e-41f2-b7fc-f5b00dde726e	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 07:37:21.988753	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
4fc228c1-0083-42f7-8c75-e941e649b4b4	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 07:37:22.025765	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
fd1817f9-dc1b-4d46-a64b-0def84236b4b	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 07:37:22.072832	m	79f034a9-ee01-4de2-9238-549e53bb794f
2670b521-0e8e-4489-8685-0973e0d190c6	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-01 07:37:22.089928	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
f4741b6c-d3d0-41af-9c54-f04a435c985a	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 07:37:22.097513	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
2ee73f49-5160-42b8-8442-f5940ef6ff0b	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-01 07:42:21.128413	n	36133c39-09fc-41b6-93f8-590a2eae35d1
4792d5ed-1735-4eb1-a7a8-03fea9b51da0	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 07:42:21.135538	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e3ffda5b-7e34-4c97-a504-e77932c49379	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 08:40:20.154546	h	79f034a9-ee01-4de2-9238-549e53bb794f
0142c8b7-bac4-4c70-a886-d15c7d565017	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-01 08:40:20.177231	b	36133c39-09fc-41b6-93f8-590a2eae35d1
2d48f6a3-aab5-4dcc-8ef2-cf5fa196b573	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 08:40:20.184311	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
d4f3b024-b759-4d28-adb8-0d5c2e00082f	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 08:40:20.206184	m	e6a73462-6516-415b-b188-7352267c17e7
a8583422-c2d6-4a96-a1a5-c7df96f88593	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 08:40:20.214735	d	e6a73462-6516-415b-b188-7352267c17e7
9c050951-4076-4826-9655-07197b7ebb10	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-01 08:40:20.236169	g	36133c39-09fc-41b6-93f8-590a2eae35d1
97883df2-4c95-42dd-9dc5-72aaa0c070a1	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 08:40:20.238753	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
d3ab7052-89bb-43f9-b954-2ed28fa55038	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:04:42.178698	g	79f034a9-ee01-4de2-9238-549e53bb794f
3abf155d-ffd1-4937-9d3c-e0df284303c2	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:04:43.783748	n	79f034a9-ee01-4de2-9238-549e53bb794f
0612ebf4-590b-4a01-aaaf-3df53670aa4b	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:04:43.80497	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
d93c441e-d5c3-4b10-98b7-c9657e4709d0	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:04:44.732108	n	e6a73462-6516-415b-b188-7352267c17e7
7eda0c9a-9667-4ead-95c3-bb51ef0b616e	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 09:04:44.744537	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
5761e384-21e5-48df-847f-fa4a0887a533	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:04:44.771987	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
6f3e217f-a1af-422c-83e6-a79ae7116537	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-12-01 09:04:44.762492	g	36133c39-09fc-41b6-93f8-590a2eae35d1
40e87551-c739-44c2-b836-9bf849d6ce47	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	t	2025-12-01 09:04:43.750019	m	36133c39-09fc-41b6-93f8-590a2eae35d1
e017813d-7763-4171-92b1-97ba4c24a1cc	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 11:21:25.509351	h	e6a73462-6516-415b-b188-7352267c17e7
0d4507f0-1bcc-44d4-a348-d5432671c54c	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-01 11:21:25.611515	t	36133c39-09fc-41b6-93f8-590a2eae35d1
cfb97370-3d89-4456-8856-12aeaedb8449	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 11:21:25.617827	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
869b70d9-2db9-42c2-83c9-62a0ce1d34c1	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-01 11:21:25.630733	m	36133c39-09fc-41b6-93f8-590a2eae35d1
ed287fae-a6ef-445f-9dbf-a60a64761599	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 11:21:25.646804	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9f5680c0-7c6b-4d9b-9f98-57a7d309b88a	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-01 11:21:25.684493	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
380fcd83-9764-42e3-9a07-85aabd799d66	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 07:45:50.462187	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
8a2dc0a8-7c1e-47a7-b01d-4e894621f2bd	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-11-25 07:45:50.522831	m	36133c39-09fc-41b6-93f8-590a2eae35d1
08dd6abb-5030-4a85-942e-d1ac900a28de	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 07:45:50.546104	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
24ed6b99-1017-42ca-8755-48ef5a62cfdc	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-11-25 07:45:50.580002	d	36133c39-09fc-41b6-93f8-590a2eae35d1
0c7472bb-04d3-4e45-a321-f72dc99d3908	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 07:45:50.620339	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
1b970f75-14f4-4f21-bd0f-34d882b28fcf	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 07:45:50.63463	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
741aa5dc-d867-48d5-a2a5-2ab978ddf7bd	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-11-25 07:46:35.260442	d	36133c39-09fc-41b6-93f8-590a2eae35d1
d2911f8e-65c6-43d4-b614-f7b8ae69c0fa	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 07:46:35.310881	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
2c622a8d-ab11-40a2-8e7c-7167d52529f6	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 07:46:35.344424	d	79f034a9-ee01-4de2-9238-549e53bb794f
368e848e-8ba1-41f3-9adb-31f329727df9	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 07:46:35.394345	g	79f034a9-ee01-4de2-9238-549e53bb794f
fe657d80-c8fb-43f4-b519-49da9fa77e83	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 20:51:58.278995	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
a7253e4f-2f9a-428b-b715-625706c78c24	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 20:58:01.473084	h	79f034a9-ee01-4de2-9238-549e53bb794f
7b97960e-1e20-41d2-8e41-da3ddc53e78c	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 20:58:01.493021	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
1f633559-99bd-4319-b108-10dec143bd63	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-11-30 20:58:01.506395	b	36133c39-09fc-41b6-93f8-590a2eae35d1
1c190545-3611-453c-9cbb-714ca40977ae	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 20:58:01.512352	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f815fc75-b75a-4e92-ba27-719dc005f8b7	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-11-30 20:58:01.599983	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
89f0d01f-d622-45bc-8c3d-4477ed9ee011	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-01 07:37:21.980581	n	36133c39-09fc-41b6-93f8-590a2eae35d1
ebc99100-8db5-4abc-bfcc-7d9815fe2b96	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 07:37:21.986904	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
591e5b9a-8fcf-4afd-83ea-c1af01cdc27d	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 07:37:22.0295	b	e6a73462-6516-415b-b188-7352267c17e7
cdeff068-32b7-42cc-9a56-c93bdf321f56	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 07:37:22.071713	m	e6a73462-6516-415b-b188-7352267c17e7
5a79f7f5-0e7a-42e3-a56a-bc1fb73e5b6a	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-01 07:37:22.091009	d	36133c39-09fc-41b6-93f8-590a2eae35d1
f98c3dd6-f9db-4975-a450-618435d880e6	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 07:37:22.098173	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f8dfae19-142a-4538-81bd-431c08242efd	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 07:42:21.183357	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
bfad939b-7a82-4d91-84a8-40fcdf196bff	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-01 07:42:21.239448	b	36133c39-09fc-41b6-93f8-590a2eae35d1
9aad22d1-c11b-454e-8a5d-1e276135bf30	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 07:42:21.243155	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9d464909-b282-42c3-8319-ba6bd7f17a57	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-01 07:42:21.261106	d	36133c39-09fc-41b6-93f8-590a2eae35d1
6cc1c6fd-b2dd-47d6-b80d-83e65a5b93ad	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 07:42:21.263932	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f08650b6-b548-45c2-abe1-5c7e66067730	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-01 07:42:21.27137	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
09e1dda4-ddbc-4419-9bfd-22bab28e0b7b	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 07:42:21.27476	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
de6c4386-d455-442c-95b4-a6410b0856d2	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 08:40:20.175826	n	e6a73462-6516-415b-b188-7352267c17e7
b6f5acc1-f0b5-4916-9863-7184d49f9261	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 08:40:20.243671	t	e6a73462-6516-415b-b188-7352267c17e7
69a1fb31-5193-4870-84ae-3ba947a8e51d	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 09:04:43.85249	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
937b0fbb-bf19-4ee2-8a6b-782ea4e627cb	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 09:04:44.72069	d	e6a73462-6516-415b-b188-7352267c17e7
7a95e60d-c814-44fd-ab30-8b221eff9094	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 09:04:44.737378	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
40c1d3d9-ed72-4e74-87e3-786c7b060767	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 09:04:44.77711	g	79f034a9-ee01-4de2-9238-549e53bb794f
586d89d2-aa64-4cac-9c45-0e1d754db9e1	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	t	2025-12-01 09:04:44.71372	n	36133c39-09fc-41b6-93f8-590a2eae35d1
62313915-cade-47b3-811c-a99ea568f3a8	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 11:21:25.631475	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
20348738-71dd-4c1c-aebb-13e6006642dd	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 11:21:25.701623	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
52dc7123-4026-4d10-acfd-f5b485b1235b	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 11:21:25.731831	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
ed33ae9a-8f74-42fa-abbf-201c43c44762	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-03 07:27:21.253527	t	36133c39-09fc-41b6-93f8-590a2eae35d1
94cca347-957c-4b43-98de-ca7df78e23d4	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 07:27:21.268549	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
fd5d5464-e51e-4140-863c-fb285db2c4c3	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 07:27:21.360451	b	e6a73462-6516-415b-b188-7352267c17e7
c530c549-3111-4afd-b868-23fbae5c999d	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-03 07:27:21.381486	m	36133c39-09fc-41b6-93f8-590a2eae35d1
d956bd8d-69e3-49b0-81be-537e6920b9d3	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 07:27:21.3981	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e32dcc67-37ea-4b31-b0b4-4e8957c85436	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 07:27:21.448198	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
fa3db4ca-c7bc-4dbf-8808-6790fb675321	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 07:27:21.459913	nj	e6a73462-6516-415b-b188-7352267c17e7
dadb36a6-d032-4941-a889-0b7fda0cca1f	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	t	2025-12-03 07:27:21.475486	g	79f034a9-ee01-4de2-9238-549e53bb794f
19931b33-c5f7-4c27-9052-443996e932f4	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	t	2025-12-03 07:27:21.43733	d	79f034a9-ee01-4de2-9238-549e53bb794f
74bfd2bc-f154-4692-aa59-c5e164104e55	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	t	2025-12-01 11:21:25.721556	nj	79f034a9-ee01-4de2-9238-549e53bb794f
402f4b0c-4b6c-4fd6-a292-16a5dacebd6b	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-03 08:59:26.361293	d	36133c39-09fc-41b6-93f8-590a2eae35d1
2eb3e726-9851-4603-aff6-acdf3256a1f8	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 08:59:26.384132	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
802aa480-3901-4074-8d63-a7636ef9a83e	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 08:59:26.392572	t	79f034a9-ee01-4de2-9238-549e53bb794f
3c72196d-5a7e-465e-991b-5033b732d44c	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 08:59:26.457063	d	79f034a9-ee01-4de2-9238-549e53bb794f
4e75b5b9-7670-44ce-aab3-9051a271fd0c	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 08:59:26.482691	m	e6a73462-6516-415b-b188-7352267c17e7
33230ce6-d427-4817-b1df-bfa741ee1117	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 08:59:26.495669	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
e9067882-ca47-4f85-9dcf-aa01a3ca02d5	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 08:59:26.567537	nj	79f034a9-ee01-4de2-9238-549e53bb794f
4aee2272-a4ba-4e9d-82f3-25a208b79f8e	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 07:45:50.51102	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
0b38c131-cbff-48f3-82b5-8c74e5a7186d	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 07:45:50.537756	t	e6a73462-6516-415b-b188-7352267c17e7
885db500-ea3e-444c-8e1b-ed5ccfe07be9	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 07:45:50.555631	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
7509751e-4148-497e-9d14-800a9bd5734d	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-11-25 07:45:50.585929	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
94df171c-4727-4346-ac20-534f4aa0e4fe	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 07:45:50.596253	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
3be5f016-7cfc-494a-ab14-64f20ec702dc	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 07:45:50.621879	d	e6a73462-6516-415b-b188-7352267c17e7
60cbfe16-dbd2-4a4e-902e-3d9bf58718e4	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 07:46:35.292922	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
ef80701b-fc63-4f45-983f-2a4e6f2e446e	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 07:46:35.316438	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
3eff3cda-52ea-4a02-9bf7-179c4f8aaa8f	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 07:46:35.339428	m	e6a73462-6516-415b-b188-7352267c17e7
ed16d415-9278-4352-a672-3ef089d01c23	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 07:46:35.405522	nj	e6a73462-6516-415b-b188-7352267c17e7
c8543d7f-afef-495a-97a2-90bcb7593867	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 20:51:58.287863	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
eb28d08c-b0ad-4ffd-9d26-520ff262fcb2	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 20:58:01.716548	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
f07ebaf1-4617-41b5-ac7b-8b945ad61d73	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-01 07:37:22.01599	b	36133c39-09fc-41b6-93f8-590a2eae35d1
508cf4d9-d516-4f8e-b2d6-7c8bb8f56a9a	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 07:37:22.023126	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
abee9edd-7fc6-4a6a-bd61-dc03c3460949	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 07:37:22.102761	d	e6a73462-6516-415b-b188-7352267c17e7
c8267cbe-ab2d-432a-9bba-d0cce7a1f87e	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 07:42:21.189694	h	e6a73462-6516-415b-b188-7352267c17e7
f3292d77-db81-4d9b-a5f2-b160a3a916dc	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 07:42:21.234188	t	79f034a9-ee01-4de2-9238-549e53bb794f
c3a0f190-bdcf-4b1d-9be6-c5ff73d5adbc	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 07:42:21.245443	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
3754a1ea-4005-48b9-b33a-b9bae26027e9	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 07:42:21.255939	m	e6a73462-6516-415b-b188-7352267c17e7
00477ace-8dc1-4f8c-a011-0636c06e7d19	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 07:42:21.265631	d	e6a73462-6516-415b-b188-7352267c17e7
b00f580c-9fb7-4119-b066-dccef57fdb07	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 07:42:21.277236	nj	e6a73462-6516-415b-b188-7352267c17e7
8c07cd31-a522-4df3-8f0b-f75ade7a99e5	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 07:42:21.289676	g	e6a73462-6516-415b-b188-7352267c17e7
1fd27140-691b-4d2c-afce-bd8ac2b5ee66	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 08:40:20.181835	n	79f034a9-ee01-4de2-9238-549e53bb794f
0e5bab40-9ef3-4c38-996a-50765b60e522	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-01 08:40:20.201131	m	36133c39-09fc-41b6-93f8-590a2eae35d1
992adced-9b93-418d-9764-2a4ff668d2f5	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 08:40:20.204111	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
3c824216-121f-4dd2-94db-89394ae90c02	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 08:40:20.228058	nj	79f034a9-ee01-4de2-9238-549e53bb794f
87550f32-1a23-457d-bfac-31ecbe7058c7	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 08:40:20.239571	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
a955abaf-5b16-4171-9604-260d1d92d36e	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 09:04:44.767559	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
19a187c1-0876-4483-8628-dfdfd15572fb	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 11:21:25.673798	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
791447ef-f06d-4995-9c53-b90a459c814d	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-03 07:27:21.263126	h	36133c39-09fc-41b6-93f8-590a2eae35d1
6a229959-a2f9-4803-a882-be1250379c4b	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 07:27:21.277234	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
802263fe-6cca-43f0-80d9-27ba9778c575	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 07:27:21.358591	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
b08e3af4-2761-44b7-9091-8c16c92e7e7c	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-03 07:27:21.422935	d	36133c39-09fc-41b6-93f8-590a2eae35d1
d370207e-bf56-4635-9449-ef63311dfcad	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 07:27:21.43036	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
483f6f86-4c6a-4e4c-87e7-abd457b30cb1	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 07:27:21.449841	n	e6a73462-6516-415b-b188-7352267c17e7
f04db0c6-f8b4-4e6b-98fc-95550dce9c4c	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 07:27:21.458588	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
adc81a5e-cb15-4828-9829-3ea3c4b187f9	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 07:27:21.47209	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
7d98d4ef-2803-4492-82b7-db8eb1544341	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	t	2025-12-03 07:27:21.405154	m	79f034a9-ee01-4de2-9238-549e53bb794f
e5c9e135-c789-4df7-ad5a-69bf34e7424b	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-03 08:59:26.363754	b	36133c39-09fc-41b6-93f8-590a2eae35d1
0867ada1-c535-4f7e-b738-92630c43e0d3	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 08:59:26.451865	d	e6a73462-6516-415b-b188-7352267c17e7
f984770d-6908-4874-aa72-ed5cc7d54ebe	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 08:59:26.481904	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
7ccd8668-656a-4895-a4f9-08c832fc0613	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 08:59:26.495119	b	e6a73462-6516-415b-b188-7352267c17e7
c5fe1058-0510-46e9-87bc-0e8dc7a949a5	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 08:59:26.559118	nj	e6a73462-6516-415b-b188-7352267c17e7
c314e63d-cb44-4d55-a246-a855b299994e	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-03 08:59:26.713423	t	36133c39-09fc-41b6-93f8-590a2eae35d1
c9a18ba1-7b8d-4291-8a60-f7561bace5fb	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 08:59:26.748601	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
595fe508-dd93-4a49-b27b-1dc0acaf8c27	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 08:59:26.757081	t	e6a73462-6516-415b-b188-7352267c17e7
72d8ae77-77a3-439b-a58e-3d3ce1890b26	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-03 08:59:26.798011	g	36133c39-09fc-41b6-93f8-590a2eae35d1
f6676f65-9e99-4cb1-9477-4700659eea23	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 08:59:26.809592	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
3a33a5d9-f364-4340-bfd6-b85407a7e269	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 13:58:25.847336	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
2f37005e-9137-405f-ab7b-558b4bd78195	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 13:58:25.881127	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
77b0dbb4-3863-42f6-94de-b2e10db8b6cf	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 13:58:25.910634	g	79f034a9-ee01-4de2-9238-549e53bb794f
855ab68f-d16e-4ba5-9b0a-69d9511e2a2d	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 14:13:46.866903	b	79f034a9-ee01-4de2-9238-549e53bb794f
c499cf1b-5a54-487f-a429-ccb6b92681d2	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 14:13:46.88519	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
464ac67f-96d3-4f31-ab38-6c8e47896523	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 07:45:50.573828	n	79f034a9-ee01-4de2-9238-549e53bb794f
fc8f5156-8a1f-4a90-a884-66a2537d1f5d	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 07:45:50.624	d	79f034a9-ee01-4de2-9238-549e53bb794f
86f7820f-6d03-4b32-8075-c63a76d132b1	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 07:46:35.295708	h	e6a73462-6516-415b-b188-7352267c17e7
5ebd57f2-4dc7-4640-af89-bce912b581fa	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 07:46:35.316727	n	79f034a9-ee01-4de2-9238-549e53bb794f
0e8173c3-5b76-428b-9ec7-532bbb569ff2	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 07:46:35.337837	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
762adcd6-cefd-408a-9150-cb226d8dafd5	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-11-25 07:46:35.375928	g	36133c39-09fc-41b6-93f8-590a2eae35d1
6ee6e812-ecc8-4148-bc23-6958191d7762	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 07:46:35.385439	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
84a245a2-d6f9-41c3-b92b-efc83d4daa3b	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 20:51:58.29117	nj	79f034a9-ee01-4de2-9238-549e53bb794f
13b6bb9b-7738-487d-8a6e-9c8e5e5c8c38	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 20:58:01.718991	nj	e6a73462-6516-415b-b188-7352267c17e7
d5d92868-b9b9-4eaa-b5ba-fbb0c84d2ddd	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 07:37:22.013628	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
8909128c-2fa9-4d45-83a0-b04751779550	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 07:37:22.104029	d	79f034a9-ee01-4de2-9238-549e53bb794f
32e3620b-72db-494a-ade6-b0eb2ad12ffd	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 07:42:21.201924	h	79f034a9-ee01-4de2-9238-549e53bb794f
d59d24c4-f63d-4db8-bbe9-26e587e33441	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 07:42:21.233128	t	e6a73462-6516-415b-b188-7352267c17e7
5bd4481e-3f8a-4b97-a38d-a95e3bc3d1ad	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 07:42:21.244254	b	e6a73462-6516-415b-b188-7352267c17e7
ed4ee947-62f3-4383-8112-08ba87098637	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 07:42:21.257209	m	79f034a9-ee01-4de2-9238-549e53bb794f
ba9d80f5-ade0-4d7d-811c-80ebe88e4c97	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 07:42:21.264891	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
801e1b81-2513-4097-b231-127db4c37207	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 07:42:21.278336	nj	79f034a9-ee01-4de2-9238-549e53bb794f
205beae9-6241-4a23-948c-10f1f95a0cb5	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 07:42:21.287861	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
87c8ddb4-1f97-4430-9c48-ed1f8dbf7304	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-01 08:40:20.23514	t	36133c39-09fc-41b6-93f8-590a2eae35d1
e78f2f5a-1373-4710-80bf-4cb45e2ad7a7	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 08:40:20.242254	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
4f4772ff-f72a-478a-a10e-60cd5b8a29c6	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 11:21:25.687852	n	e6a73462-6516-415b-b188-7352267c17e7
300e411c-d53d-4c9c-b2b9-98f45ece4877	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 11:21:25.720543	nj	e6a73462-6516-415b-b188-7352267c17e7
99b9343a-bf05-4e7e-8b16-8585dd710449	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 11:21:25.733913	g	e6a73462-6516-415b-b188-7352267c17e7
041a8937-69ef-49b6-9019-8886b32b2dd7	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-03 07:27:21.343502	b	36133c39-09fc-41b6-93f8-590a2eae35d1
abda26e3-a8b2-4799-9eca-f72d76a7aba0	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 07:27:21.352561	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
72b0d118-4398-49bc-91eb-7f6f0350cd7e	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	t	2025-12-03 07:27:21.356538	b	79f034a9-ee01-4de2-9238-549e53bb794f
93bbaa42-5275-4068-a08b-24a2b0d65562	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-03 08:59:26.368361	n	36133c39-09fc-41b6-93f8-590a2eae35d1
e7ec8773-d0d3-4090-8bbe-3b7581c5b505	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 08:59:26.438923	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
180ad728-3989-4325-9427-2a669e664fe7	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 08:59:26.486811	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
558f5f27-2c86-44d0-9eea-c480237ec729	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 08:59:26.583637	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
e94c23c8-a87b-430c-9d4a-6ba50acc4915	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 08:59:26.754722	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
ecf4e7fa-0c2b-4a2f-b815-4829e51a28cd	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 08:59:26.77373	m	79f034a9-ee01-4de2-9238-549e53bb794f
1c9b7b89-76c2-46d7-9d6a-a23bdef2d492	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 08:59:26.787477	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
8f03a711-8029-4d5f-a820-62f6bf78fade	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 08:59:26.804536	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
1c5bc1c6-af98-40d6-8133-9dad96862947	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 13:58:25.878767	h	e6a73462-6516-415b-b188-7352267c17e7
8a662c02-5ad7-4d8c-a2d7-2f988c2cc9c3	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 13:58:25.914555	nj	e6a73462-6516-415b-b188-7352267c17e7
0d325261-ed68-422f-a233-063b7ffe28a2	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-03 14:13:46.880394	d	36133c39-09fc-41b6-93f8-590a2eae35d1
eec29c87-e908-42e9-9554-e81343c8941c	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 14:13:46.884174	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
604a2d1c-0273-493b-a603-e94f78c57220	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 07:45:50.575644	n	e6a73462-6516-415b-b188-7352267c17e7
5b8329db-9983-46c6-b06c-d86752ea5976	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 07:46:35.299852	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
31938d60-ffa9-4877-a10b-f0a3eda2ba7a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 07:46:35.327487	n	e6a73462-6516-415b-b188-7352267c17e7
ebaa4ce1-9f65-4ab5-9b1d-7aef169775df	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 07:46:35.414992	nj	79f034a9-ee01-4de2-9238-549e53bb794f
08f274cc-3529-4551-88f4-6c43364c8a7d	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 20:51:58.289469	nj	e6a73462-6516-415b-b188-7352267c17e7
076e647c-36ec-4b87-a141-a66bb1e3ad16	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 20:58:01.728352	nj	79f034a9-ee01-4de2-9238-549e53bb794f
cc232341-05f1-4c7d-9cf4-cfb5247e0946	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 07:37:22.0176	h	e6a73462-6516-415b-b188-7352267c17e7
034cdfdd-67cc-4e8f-9cac-02019acb9514	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 07:37:22.101676	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
30062fc1-b3b1-4ad4-a070-5cd6a84cbfa2	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 07:42:21.207506	n	e6a73462-6516-415b-b188-7352267c17e7
26343daa-fbc2-44b8-9724-52e25e7a9774	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-01 07:42:21.227239	t	36133c39-09fc-41b6-93f8-590a2eae35d1
65ea0760-ec49-4492-8c91-ddb564bec850	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 07:42:21.230939	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
d59fed68-06f7-4633-9722-528291efdb8f	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-01 07:42:21.250047	m	36133c39-09fc-41b6-93f8-590a2eae35d1
70352435-35e7-4b6e-9ae7-3b395a41a303	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 07:42:21.252945	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
320a4882-859f-4281-9c62-5b851aa86703	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-01 07:42:21.282309	g	36133c39-09fc-41b6-93f8-590a2eae35d1
97622445-413a-4b1c-b501-470052302c03	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 07:42:21.286149	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
799d13b4-76d8-4659-8df5-d8208fa44ef8	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-01 08:42:22.052955	h	36133c39-09fc-41b6-93f8-590a2eae35d1
8e2d57b6-1d42-473c-9c11-fa4c1d50a88f	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 08:42:22.061385	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
844ac640-fe1b-4b50-af78-7cf09d1d1517	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 08:42:22.111983	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
9554e539-d6e5-4d0f-85bb-9bb5e2d31616	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 11:21:25.695511	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f7b6712f-0a4c-46db-a73f-5d3cc0ce4bf1	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 11:21:25.71959	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
09fa8674-b2fd-4680-8f45-18e1ba68e5fc	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 07:27:21.339179	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
19b33e59-9feb-4ee9-8518-fe808657e817	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	t	2025-12-01 11:21:25.736337	g	79f034a9-ee01-4de2-9238-549e53bb794f
d1731286-06c4-4fbe-97f2-8aac1a69dabb	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 08:59:26.55449	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
aca3f070-86cd-4446-a1b6-5bb715d39079	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 08:59:26.744739	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
a0de9828-7924-4c7f-91b6-91a656bfb06b	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 08:59:26.755292	n	79f034a9-ee01-4de2-9238-549e53bb794f
c9f8bc55-b8d1-4450-8215-6b9681a48a78	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 08:59:26.813065	g	e6a73462-6516-415b-b188-7352267c17e7
3539059a-9264-406b-a749-c502b8fd5f50	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 13:58:25.886524	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
07fca062-548f-4bc0-9a88-f774c7d39150	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 13:58:25.916205	nj	79f034a9-ee01-4de2-9238-549e53bb794f
26cce80f-ed11-40aa-b75d-c909cf705ae8	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 07:45:50.615414	h	e6a73462-6516-415b-b188-7352267c17e7
8a58aa43-fc73-491c-bf4c-1bea7ab1b172	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 07:46:35.302849	t	e6a73462-6516-415b-b188-7352267c17e7
95acdca3-6fb0-40d1-bd9a-2083409a2dab	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 07:46:35.328209	m	79f034a9-ee01-4de2-9238-549e53bb794f
e85cf25e-11d7-4aec-af94-b9e705b6498a	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 20:51:58.325247	b	e6a73462-6516-415b-b188-7352267c17e7
daff9da1-fca1-41a2-820d-9b77881953be	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-11-30 21:58:01.911627	h	36133c39-09fc-41b6-93f8-590a2eae35d1
12d4cd42-a82b-4f16-91b4-1c54bbc74f62	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 21:58:01.91892	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
5822700e-ee96-4169-a48c-9aa3e5658ec9	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 21:58:02.010209	t	79f034a9-ee01-4de2-9238-549e53bb794f
bb3db0b8-4286-47fc-9e8f-c8e7bea3d489	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-11-30 21:58:02.025975	b	36133c39-09fc-41b6-93f8-590a2eae35d1
f569f562-f73b-4357-821a-a74da8b9495b	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 21:58:02.02949	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
af200337-3ded-461f-87ca-95147182981e	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 21:58:02.058696	m	79f034a9-ee01-4de2-9238-549e53bb794f
381c3eba-fee5-4364-9b92-15e93592bf29	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-11-30 21:58:02.074576	d	36133c39-09fc-41b6-93f8-590a2eae35d1
59c628fb-a771-406b-9d37-12c25babccf3	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 21:58:02.083297	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
031bdd42-1170-4bc8-a2be-be1a8da2bb1b	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 21:58:02.119474	nj	e6a73462-6516-415b-b188-7352267c17e7
1584dcc5-a391-4645-846f-b6ed867dd936	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 21:58:02.128769	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
8412f6a9-e999-4795-8157-02afa8c296e2	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 07:37:22.037247	h	79f034a9-ee01-4de2-9238-549e53bb794f
d8cb9573-eeb1-4b6e-a4ba-533730a3d4ba	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 07:37:22.070717	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
cbb4bf47-acc8-493e-96cb-a9fb18150143	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 07:37:22.098958	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
47d1590a-09e5-4aff-ae61-0c965959b8de	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 07:37:22.111802	t	79f034a9-ee01-4de2-9238-549e53bb794f
f339629d-071b-4c5a-94e6-23ccdc3ba150	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-01 07:37:22.12337	g	36133c39-09fc-41b6-93f8-590a2eae35d1
3ab44c0f-ccd8-4cb4-a707-819d521d277d	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 07:37:22.130043	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
b45612c9-4234-4953-ae01-cac61a2b1aca	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 07:42:21.213913	n	79f034a9-ee01-4de2-9238-549e53bb794f
805536b0-6d5b-4300-b8ce-4f105f7dabe6	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 07:42:21.232106	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
828906ed-c8d0-43e7-8413-53b2d4f06895	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 07:42:21.24642	b	79f034a9-ee01-4de2-9238-549e53bb794f
534998e5-9db5-4688-b700-a03cc4ff2d1b	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 07:42:21.254642	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
73e52ba3-89e2-46bd-bad6-cb45eeb788f6	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 07:42:21.26698	d	79f034a9-ee01-4de2-9238-549e53bb794f
e16a56f1-6d44-42da-8207-42669af10b97	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 07:42:21.275992	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
82fe73e4-ad0f-4d7b-99e7-f88d32e6a158	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 07:42:21.291011	g	79f034a9-ee01-4de2-9238-549e53bb794f
f659bc2f-5de1-433f-b9ee-411e2c780487	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-01 08:42:22.10495	n	36133c39-09fc-41b6-93f8-590a2eae35d1
e0af6a0f-c2a4-48a5-af03-48f3b9bfb3a1	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 08:42:22.110973	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
79a97455-7780-46ba-a936-e67c6a8bfd2f	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 11:21:25.707103	d	e6a73462-6516-415b-b188-7352267c17e7
657fa56c-87b6-4694-a724-7ee29037f2e9	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 11:21:25.726909	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
d3d9bc4d-79f8-41ec-8272-0e4a0e9800c7	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 07:27:21.403684	m	e6a73462-6516-415b-b188-7352267c17e7
7fae6050-fd53-46a9-89c8-4e7ea20b826c	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 07:27:21.434191	d	e6a73462-6516-415b-b188-7352267c17e7
a34120fd-ef08-4eef-8de9-db5b7e3149c7	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-03 07:27:21.444956	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
db3d55d9-04b9-4b4b-a168-c64479364370	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 07:27:21.457144	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f5877f9d-fd68-43c2-a469-b37c549f1123	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	t	2025-12-03 07:27:21.372561	t	79f034a9-ee01-4de2-9238-549e53bb794f
2ca3b1a6-9299-4382-a04d-767657b59b33	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 08:59:26.561315	h	e6a73462-6516-415b-b188-7352267c17e7
25ecf4a2-fede-4913-b7f1-4d35ac4bbcd2	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-03 08:59:26.718272	h	36133c39-09fc-41b6-93f8-590a2eae35d1
052df26b-5cc0-4481-bcc9-ed8768ec994e	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 08:59:26.752357	b	e6a73462-6516-415b-b188-7352267c17e7
2fb25f2d-b8af-47d7-be83-ad90409fa9eb	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-03 08:59:26.768873	d	36133c39-09fc-41b6-93f8-590a2eae35d1
b6681426-aece-4312-8df7-c744ab65a62d	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 08:59:26.782491	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
99134da2-2baf-4478-9ee5-a4a971e86b2b	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 13:58:25.911828	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
20d0b712-c922-4644-92ee-f27963dd030e	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 07:45:50.656061	h	79f034a9-ee01-4de2-9238-549e53bb794f
22ed964f-04a6-45c5-9583-c8544d443bca	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-11-25 07:46:29.52169	n	36133c39-09fc-41b6-93f8-590a2eae35d1
5970aded-d975-4af3-9d96-2b8a369120ba	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 07:46:29.537423	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
66245821-1b47-417f-be23-ff7f66a72559	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 07:46:29.553758	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
6001ac8f-c5ac-491e-a9c4-b9c2e7f825b8	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-11-25 07:46:29.658709	b	36133c39-09fc-41b6-93f8-590a2eae35d1
af799b61-59cf-43d5-8654-ccee838b7f01	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 07:46:29.677888	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c1939f23-4171-444b-a965-51b6e638ab34	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 07:46:29.712157	t	e6a73462-6516-415b-b188-7352267c17e7
cf4cad99-8480-4064-a7ce-730b99762b88	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 07:46:29.807258	m	79f034a9-ee01-4de2-9238-549e53bb794f
19d40f10-05c0-4f8a-b4d3-fe3ba0a43f5e	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-11-25 07:46:29.872159	g	36133c39-09fc-41b6-93f8-590a2eae35d1
5d67ebbb-1695-4c8f-b55e-4d0f9b1a8858	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 07:46:29.887037	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
fe23f955-9f57-41a0-aefe-832829da6c7e	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 07:46:29.923693	nj	e6a73462-6516-415b-b188-7352267c17e7
031f5795-5810-497b-8aef-ed094e4ef90a	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-11-25 08:46:35.539842	h	36133c39-09fc-41b6-93f8-590a2eae35d1
11674d2f-48eb-4d16-9ea2-97f643898f76	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 08:46:35.552043	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
32eba449-2a96-4f8d-b03c-b7f9748a31a5	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 08:46:35.738966	n	79f034a9-ee01-4de2-9238-549e53bb794f
ed30ce6a-4159-4961-bc5f-6474eaed7f4e	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-11-25 08:46:35.755748	t	36133c39-09fc-41b6-93f8-590a2eae35d1
d4a56bc3-29a6-4ca5-9d04-6e0268801d0d	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 08:46:35.75924	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
557fe084-de68-4d4b-9f5f-aaf9dce142bc	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 08:46:35.788001	b	79f034a9-ee01-4de2-9238-549e53bb794f
70ab0fdb-5035-45bf-9335-ad4eb3b2d6ad	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-11-25 08:46:35.804488	m	36133c39-09fc-41b6-93f8-590a2eae35d1
33ba5c32-7237-4ada-ad58-ce13f0d46c61	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 08:46:35.80787	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
fcce8969-87de-4fb1-a324-a2541474c038	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 08:46:35.834933	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
c1f0e0e3-0e40-4c44-a496-794a44471c2f	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 08:46:35.84543	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
8fdc1dcf-ed7f-4e2d-95f8-eb4fcc0241b9	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-11-30 20:56:38.778912	n	36133c39-09fc-41b6-93f8-590a2eae35d1
f5fc145e-41d0-40ad-bcff-db5f6007645b	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 20:56:38.788945	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
0bde93bd-0da5-4d62-8504-a4ceb292509b	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 20:56:38.798247	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
7dcc47ec-179c-453c-8809-dbd73b03c9b7	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 20:56:38.858534	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
1bb4beb8-8dc8-4e67-baa9-1fdee499ab0b	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 20:56:38.925217	d	e6a73462-6516-415b-b188-7352267c17e7
8151a80e-4e6e-4a7b-9df9-2fb58d7c15f9	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 20:56:38.977115	nj	79f034a9-ee01-4de2-9238-549e53bb794f
0b39df50-f378-4d8a-8471-c602fa380a44	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 20:56:38.991495	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
ecb83aa4-3059-4c67-9bff-bfe1fe52807a	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 21:58:01.965021	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
d8555dce-bdb1-423d-893d-5f23a7af70d3	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 21:58:02.008794	t	e6a73462-6516-415b-b188-7352267c17e7
840029bf-a0b1-4d1d-83d7-5e10951097bf	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 21:58:02.030421	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
2e186e44-279c-438b-89be-17c405bc1cab	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 21:58:02.056819	m	e6a73462-6516-415b-b188-7352267c17e7
1dbab709-c4b8-41e9-b93d-43577a71e6b0	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 21:58:02.077735	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
c1ec5771-505d-45b6-a8cb-d0cd00290683	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 21:58:02.085884	d	e6a73462-6516-415b-b188-7352267c17e7
c4965168-177d-459b-b1e6-5dff0399f1e1	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-11-30 21:58:02.108611	g	36133c39-09fc-41b6-93f8-590a2eae35d1
f7490e79-8840-4a3d-94f0-ef576073be5d	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 21:58:02.127413	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
82f7a4a8-a28a-40f2-9af5-419daf3ad210	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 07:37:22.048806	n	e6a73462-6516-415b-b188-7352267c17e7
77773e8f-68e4-4ae9-93f4-82abb54926c3	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-01 07:37:22.066188	m	36133c39-09fc-41b6-93f8-590a2eae35d1
994676d9-2817-47ce-a571-030c1493ac2e	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 07:37:22.06952	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
51c66a2f-bc1f-451c-b976-7983fd80950f	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 07:37:22.09973	nj	e6a73462-6516-415b-b188-7352267c17e7
1ecbc537-3a41-44c5-be2d-ba0a7bcf8c9b	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 07:37:22.110566	t	e6a73462-6516-415b-b188-7352267c17e7
c0492798-f97e-4cd3-a0f9-1b90e2d9ba3a	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 07:37:22.131452	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
16a51d17-f907-4b26-b8ed-c0e73a63c0de	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-01 08:31:45.031122	h	36133c39-09fc-41b6-93f8-590a2eae35d1
61a14737-fe17-4c9c-883d-339ef862c2b4	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 08:31:45.052429	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c4e3c283-5e7f-4a1c-a20a-bab70e0be16d	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 08:31:45.124606	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
377d7ea0-c0c5-4dc9-8353-d7872dd7adf4	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-01 08:31:45.14833	b	36133c39-09fc-41b6-93f8-590a2eae35d1
dec26868-5cff-4b62-a0e2-ddb1ea3e2113	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 08:31:45.164214	b	e6a73462-6516-415b-b188-7352267c17e7
eede198a-de97-4246-85fc-39b8bcc2093c	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 08:31:45.167071	b	79f034a9-ee01-4de2-9238-549e53bb794f
1b848d6e-acde-4d5f-9264-f672b6e202f7	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 08:42:22.126131	h	e6a73462-6516-415b-b188-7352267c17e7
6c2c5d7a-0047-45b8-9c11-bc4e9557a7b1	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 08:42:22.199998	b	79f034a9-ee01-4de2-9238-549e53bb794f
0a9e9e29-1141-4e15-b19d-7cbdc386a5be	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 08:42:22.211016	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
42238cd0-6d46-4220-8089-6dc1336725e5	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-01 08:42:22.235312	d	36133c39-09fc-41b6-93f8-590a2eae35d1
b06de941-ba49-4259-8a10-e169bb926475	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 08:42:22.239833	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f330211c-54fe-45c8-b3cf-74e8da721a27	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 11:21:25.730109	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
fe37e9e2-5d2a-4e8a-ada3-d43392485425	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 07:27:21.377614	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
839916d5-aa19-483e-a10e-8e4d74c98c4c	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 07:27:21.401237	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
94f60cd0-b4a1-4b94-85ef-bb3ed2cd3c8b	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-11-25 07:46:29.533715	h	36133c39-09fc-41b6-93f8-590a2eae35d1
d13ea3af-28c1-4169-8c6b-a2350ce852d7	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 07:46:29.548407	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
6f16d96f-d4bd-4135-8438-ca9462c447b8	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-11-25 07:46:29.671408	t	36133c39-09fc-41b6-93f8-590a2eae35d1
c2705c35-b1c9-4a41-b988-454fef7dda29	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 07:46:29.705927	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
efa2f122-57ba-4317-bda6-04c886b34ae8	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 07:46:29.710526	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
7872af48-b25c-4639-a0d0-4f3e47debf65	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 07:46:29.714107	t	79f034a9-ee01-4de2-9238-549e53bb794f
e2127b16-0d04-4396-b860-3210ecf1da9e	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-11-25 07:46:29.754746	m	36133c39-09fc-41b6-93f8-590a2eae35d1
cb8f6021-2f54-48f3-8042-d3bf15985ce8	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 07:46:29.790547	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
ea31c96d-06ce-4c53-9b19-cd5e0b02ba91	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 07:46:29.919716	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
6232153a-b8c0-49aa-ac65-c7b8e457342b	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 08:46:35.603813	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
f23a2ba2-a7ba-4f16-a186-0f3a8f1974d8	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 08:46:35.737799	n	e6a73462-6516-415b-b188-7352267c17e7
aadfbfae-cb41-48fc-a495-6a6ebcb578e2	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 08:46:35.760336	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
0949e09d-ce19-48ad-9bc3-f038819158ec	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 08:46:35.786815	b	e6a73462-6516-415b-b188-7352267c17e7
e573fbcb-bcce-444a-9240-64ab34f01779	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 08:46:35.80888	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
f7f94d39-b988-4ff4-8be9-0647bd4a1d97	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-11-25 08:46:35.831703	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
3be594f0-f97d-4b0b-82aa-540b7b9e4879	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 08:46:35.843778	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c8fc0ebd-350a-489d-b1ad-24913d1c33e0	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-11-30 20:56:38.781516	b	36133c39-09fc-41b6-93f8-590a2eae35d1
d7cd8fef-3233-48ed-a04a-f70caae4604c	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 20:56:38.795645	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
d9debc4d-3c43-45c1-af89-b92c0211997b	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 20:56:38.801809	h	79f034a9-ee01-4de2-9238-549e53bb794f
1e7e3c85-eb9e-403c-b135-5c9937c7b602	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 20:56:38.86406	m	e6a73462-6516-415b-b188-7352267c17e7
d1fa676f-25ea-4449-9b99-350f7e8c6f23	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-11-30 20:56:38.901554	d	36133c39-09fc-41b6-93f8-590a2eae35d1
3f8bf760-e705-417b-b990-e13547a80e56	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 20:56:38.917549	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
5cbcfbb5-3d70-458c-8167-8696cb079015	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 21:58:01.97331	h	e6a73462-6516-415b-b188-7352267c17e7
ca34f803-69ef-4dcd-992c-d28b29c6d590	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 21:58:02.006247	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
671c5397-9cd1-47a0-a09d-669ba46ccf57	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 21:58:02.033388	b	79f034a9-ee01-4de2-9238-549e53bb794f
3c942257-be20-498d-a965-1986046b098f	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-11-30 21:58:02.048604	m	36133c39-09fc-41b6-93f8-590a2eae35d1
ffb8103c-53e6-4da5-bb43-ac9fc7212ff7	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 21:58:02.052938	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
7f3494ba-190e-4b14-8ca3-18878eab9206	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 21:58:02.08017	n	79f034a9-ee01-4de2-9238-549e53bb794f
e8f3bbab-d159-4524-86a6-1c5cdf5c1fa5	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 21:58:02.122426	nj	79f034a9-ee01-4de2-9238-549e53bb794f
5d97dd1c-bb47-47e9-84ab-6181363ae1a1	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 07:37:22.058653	n	79f034a9-ee01-4de2-9238-549e53bb794f
9b883111-4b51-4501-9da2-49e38039d1c0	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 07:37:22.10085	nj	79f034a9-ee01-4de2-9238-549e53bb794f
b49a19f1-6b81-471b-afe6-a073b4ede3a0	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 07:37:22.108713	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
1cdb333c-e24e-41c5-a0d3-ef8417fccaf2	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 07:37:22.132638	g	e6a73462-6516-415b-b188-7352267c17e7
d88588ac-36e7-4f21-b8f7-8aa917b6fb8a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-01 08:31:45.032687	n	36133c39-09fc-41b6-93f8-590a2eae35d1
bd63449d-da77-4121-a374-ac38fa74104a	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 08:31:45.045349	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
6322f03a-dcd8-4430-b351-4f5ff6f84d1d	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 08:31:45.13072	t	e6a73462-6516-415b-b188-7352267c17e7
3af9dc0d-dd40-4408-bfab-a44ad048f032	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 08:31:45.159626	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
7b8bd780-33fc-4062-8690-755f5fba5537	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 08:42:22.135385	h	79f034a9-ee01-4de2-9238-549e53bb794f
ed965cab-fff8-4222-8482-0452759b8557	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 08:42:22.198692	b	e6a73462-6516-415b-b188-7352267c17e7
05da6d06-15d9-4f51-9446-89c08de88825	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-01 08:42:22.217397	m	36133c39-09fc-41b6-93f8-590a2eae35d1
9114146a-2aba-47bb-9228-fd63250b2a3a	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 08:42:22.222442	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9eacd2ca-e727-4cc1-a179-291ed33a9acb	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 08:42:22.245287	d	79f034a9-ee01-4de2-9238-549e53bb794f
031e258c-65cc-4f86-a91d-5623578f56ed	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 08:42:22.257478	nj	79f034a9-ee01-4de2-9238-549e53bb794f
07fc10b4-cdae-4931-a44c-95c308256bdb	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 08:42:22.269106	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
58d238f4-3e53-4f2a-8842-810f6fcf6dce	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 07:27:21.392126	h	e6a73462-6516-415b-b188-7352267c17e7
f5e41fdd-96a4-4414-8dc1-00ac99c65311	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	t	2025-12-01 11:21:25.751997	t	79f034a9-ee01-4de2-9238-549e53bb794f
7242fa6e-3bd2-4182-a7aa-7621c718a448	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 08:59:26.588343	g	79f034a9-ee01-4de2-9238-549e53bb794f
8b0ec887-2430-4dd5-be82-924ef7425d9b	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 08:59:26.746734	h	79f034a9-ee01-4de2-9238-549e53bb794f
51580986-4d7a-4db5-9dea-c675af075bf2	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 08:59:26.755521	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
c0c10bdd-5440-4e59-9bbc-9cd67f6b6898	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 08:59:26.814193	g	79f034a9-ee01-4de2-9238-549e53bb794f
3161c5c1-5104-450e-8225-28955ed0c8b6	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 13:58:25.928673	h	79f034a9-ee01-4de2-9238-549e53bb794f
fd4f14ad-5cb5-436b-ba4a-b9cbb9e5e4e2	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 07:46:29.725152	n	e6a73462-6516-415b-b188-7352267c17e7
e960851a-6f7a-4d7f-bd53-2e9142900ccf	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 07:46:29.797216	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
34c405b4-e559-436e-af8a-51017879fd38	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-11-25 07:46:29.877869	d	36133c39-09fc-41b6-93f8-590a2eae35d1
cae21eab-1e92-4511-ab99-c9d4b02bb553	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 07:46:29.928225	d	e6a73462-6516-415b-b188-7352267c17e7
d44d1e62-2c18-4d24-9817-1e9272af894b	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 08:46:35.6063	h	e6a73462-6516-415b-b188-7352267c17e7
dc531e21-fffe-489c-9934-8235cb76f83c	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 08:46:35.737051	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
ace0cc10-5868-4386-bd6b-cd6999d98509	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 08:46:35.76154	t	e6a73462-6516-415b-b188-7352267c17e7
49bdb45b-3151-4c87-a05e-d6b52676ad8c	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 08:46:35.786046	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
2cc81598-6efc-4507-b9e1-205c693180d3	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 08:46:35.810667	m	e6a73462-6516-415b-b188-7352267c17e7
cc810d94-43e4-4638-a562-78d889caf0d9	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-11-25 08:46:35.830684	d	36133c39-09fc-41b6-93f8-590a2eae35d1
2b91c11c-594e-45a2-ad06-7454f91dd055	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 08:46:35.837708	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9ee0b39f-cec3-4288-bca4-b1cd8b98259a	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-11-30 20:56:38.782982	h	36133c39-09fc-41b6-93f8-590a2eae35d1
c1a78189-0c18-4eca-9e52-e24a815efc65	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 20:56:38.798774	h	e6a73462-6516-415b-b188-7352267c17e7
b2284be2-b6da-48d1-aa3e-1e35fb0317bc	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 20:56:38.805555	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
bd94ea51-fdc0-41ac-95b1-924e9edea1ec	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-11-30 20:56:38.828222	m	36133c39-09fc-41b6-93f8-590a2eae35d1
bd2614b6-9cfd-4973-8857-058f05ff7373	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 20:56:38.843662	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f6f547e3-2b01-4b04-b174-fa84a9c44009	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 20:56:38.854403	m	79f034a9-ee01-4de2-9238-549e53bb794f
9b5136d2-f23f-4dc6-8fa0-2516ab9ec4b6	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 20:56:38.926605	d	79f034a9-ee01-4de2-9238-549e53bb794f
f0d93648-4b43-4342-a811-1682da9b2068	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-11-30 20:56:38.960567	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
d5a3e25e-0277-4c50-af08-723a17b50437	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 20:56:38.972437	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e7799866-ed43-4479-8f80-afe622b4d480	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 20:56:38.994045	t	79f034a9-ee01-4de2-9238-549e53bb794f
7b644886-a501-4dec-8020-e7cbb028ab5f	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 21:58:01.980762	h	79f034a9-ee01-4de2-9238-549e53bb794f
303f26b8-a44c-404a-a9fb-43f308e1581f	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-11-30 21:58:02.000849	t	36133c39-09fc-41b6-93f8-590a2eae35d1
61e2cab9-b05a-4bab-84e1-9d3f7bc70186	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 21:58:02.007561	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
8e8f8eb9-c34c-4d02-b8ef-f45a4ba302c2	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 21:58:02.031842	b	e6a73462-6516-415b-b188-7352267c17e7
41189e76-012f-45b6-a7a5-33f97a5b8f98	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 21:58:02.055471	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
18fd4410-e643-4486-91de-ccdc888d67f4	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 21:58:02.078912	n	e6a73462-6516-415b-b188-7352267c17e7
f1fc98e4-16b7-4e15-abbf-87c9493d9fc3	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 21:58:02.084635	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
c8fc383f-3300-4570-adae-528f9eca6905	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 21:58:02.115412	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
9d2526da-9c76-414b-ba1e-bd10024861c7	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 21:58:02.13386	g	e6a73462-6516-415b-b188-7352267c17e7
41d41fdd-a222-428b-8f43-aec8b40cad40	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-01 07:37:22.095353	t	36133c39-09fc-41b6-93f8-590a2eae35d1
177ff9a3-1d88-4fc7-b663-67fdd5cd97ff	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 07:37:22.106813	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
87e90721-7bf9-460a-a7da-ad50d9505f83	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 07:37:22.133704	g	79f034a9-ee01-4de2-9238-549e53bb794f
ac56f2dd-642f-47d0-86ad-492138b01476	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-01 08:31:45.106056	t	36133c39-09fc-41b6-93f8-590a2eae35d1
79f3db4b-6df2-4330-b52b-cd5ba11a8a4b	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 08:31:45.116094	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f5a4115a-f42e-445b-8a60-739310e6fc94	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 08:31:45.161847	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
59016bbb-f9a4-43f3-bf5b-502e1eca09a0	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 08:42:22.164116	n	e6a73462-6516-415b-b188-7352267c17e7
cec0aec4-d789-4315-8200-9777678e4cd8	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 08:42:22.19752	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
eefcedc1-560d-466e-abf9-09480843af3d	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 08:42:22.212769	t	e6a73462-6516-415b-b188-7352267c17e7
5b319f8e-b8df-4a71-b5a7-50760ec4ca27	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 08:42:22.22549	m	e6a73462-6516-415b-b188-7352267c17e7
07cef9aa-c61e-4331-892a-04334bc237bd	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 08:42:22.242542	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
30bfd675-3cc1-40db-a774-30f45ea0e492	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 08:42:22.25397	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
d4e1f8a4-6ae2-4b43-a755-fc3233bff715	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 08:42:22.269983	g	e6a73462-6516-415b-b188-7352267c17e7
a3b4bdae-605b-45f1-8b68-659f19b8b46c	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 11:21:25.758027	t	e6a73462-6516-415b-b188-7352267c17e7
d492dcf0-c458-44de-8f27-d9e86c7469cf	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 07:27:21.432067	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
ba489e64-3d61-4a1a-9560-5209280cd7b4	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	t	2025-12-03 07:27:21.451433	n	79f034a9-ee01-4de2-9238-549e53bb794f
378c2a4b-5883-4a40-bd34-524825a287f9	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	t	2025-12-03 07:27:21.413111	h	79f034a9-ee01-4de2-9238-549e53bb794f
95b4d59b-7cd7-4ac9-9a88-77cb3b1506c3	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 08:59:26.610925	h	79f034a9-ee01-4de2-9238-549e53bb794f
103a57e8-661e-4fc8-9b2a-1bbf312fb660	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-03 08:59:26.723768	m	36133c39-09fc-41b6-93f8-590a2eae35d1
1f0080be-41b1-4f48-8085-a93b99eff2f9	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 08:59:26.746288	h	e6a73462-6516-415b-b188-7352267c17e7
ce19ad0d-920d-47ef-a984-b54aa624a895	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 08:59:26.755753	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
65894308-44eb-4c9a-bd7e-d2487b58df2e	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 08:59:26.791515	d	79f034a9-ee01-4de2-9238-549e53bb794f
0e38c6c5-027e-48df-b9e5-7289a7b1ae63	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 08:59:26.811689	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
afe1570b-a562-4ced-8ebc-63fb2725a0b1	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 13:58:25.957619	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
99e151ef-8de4-4b9d-8c7d-073f59e05416	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 07:46:29.736162	n	79f034a9-ee01-4de2-9238-549e53bb794f
8d2ac7a8-2cf1-43fb-9207-fedb9e4c41fd	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 07:46:29.803086	m	e6a73462-6516-415b-b188-7352267c17e7
3c8530cf-e1c5-4eba-9ae5-7d3cba1c9d52	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-11-25 07:46:29.874283	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
639a5bb5-0624-4f04-be89-aa2408d821b5	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 07:46:29.911904	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9f8bc05c-ed04-4374-a3d3-5131584a92f2	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 08:46:35.706442	h	79f034a9-ee01-4de2-9238-549e53bb794f
29f0e38a-b13d-4496-8d35-96e3497df39d	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-11-25 08:46:35.733159	n	36133c39-09fc-41b6-93f8-590a2eae35d1
4127efe9-89c5-448f-8303-71d89cab876e	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-25 08:46:35.736379	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
595a38e1-b1f3-4855-b228-0cb6fdcd34fd	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 08:46:35.763794	t	79f034a9-ee01-4de2-9238-549e53bb794f
8547fbb5-918a-4e95-9682-fa212ad7cfdb	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-11-25 08:46:35.782102	b	36133c39-09fc-41b6-93f8-590a2eae35d1
c28e2bb5-d287-4409-9990-c065edaf233c	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 08:46:35.785301	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
44941ee3-be46-40f7-ab7e-7d72827e57bc	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 08:46:35.812082	m	79f034a9-ee01-4de2-9238-549e53bb794f
e8d4ae65-a236-4051-bbed-3ef4815d7a3d	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-11-25 08:46:35.828894	g	36133c39-09fc-41b6-93f8-590a2eae35d1
5d19c065-73cc-4496-aaee-9248f74e4b07	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 08:46:35.833991	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
18d8c04d-045d-438f-a51d-52a8585655f4	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 08:46:35.840518	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
af2410ae-41d1-4d23-9b17-75e46ef4d1f2	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 20:56:38.886465	n	e6a73462-6516-415b-b188-7352267c17e7
26023b34-f657-4760-969c-49a6a9019247	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 20:56:38.920942	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
e12e0e7b-77a1-4fb7-9809-84d81d4e06e0	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 20:56:39.000227	g	79f034a9-ee01-4de2-9238-549e53bb794f
ad71b14f-69b0-4861-9f0e-2cffd68816b0	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-11-30 20:58:01.32657	n	36133c39-09fc-41b6-93f8-590a2eae35d1
543f8b3f-b5a4-4e36-b2b0-2dd7d2f686f5	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 20:58:01.338338	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
ba05a133-2227-43a9-9a78-8c3fb5246db5	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 20:58:01.348115	h	eef65169-a61e-45bf-b7ed-c7897d7443d6
a7636bc1-4714-4e2a-9d22-ed89ae239ef3	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 20:58:01.635454	m	79f034a9-ee01-4de2-9238-549e53bb794f
b184cc5c-26d6-4195-927a-392e8af29aba	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 20:58:01.651757	d	79f034a9-ee01-4de2-9238-549e53bb794f
bae0fc32-fe01-4392-81fc-30b7ab26b791	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 20:58:01.683906	g	79f034a9-ee01-4de2-9238-549e53bb794f
822a2373-4c2b-44c4-bad4-5f979e6079a9	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-11-30 21:58:02.069126	n	36133c39-09fc-41b6-93f8-590a2eae35d1
de86722e-d9e4-4451-809c-5850abe149d4	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 21:58:02.076417	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
5604ef1e-d081-49a5-92c4-4e2fa3720e87	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 21:58:02.087624	d	79f034a9-ee01-4de2-9238-549e53bb794f
3a47937e-79a8-49af-84df-5a6a8baa0ad3	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-11-30 21:58:02.104493	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
8c19c5e4-9435-43e1-8656-f8dd02eadf71	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 21:58:02.111396	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e0441eac-92a1-4335-bb10-10233ddc2f19	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 21:58:02.130645	g	79f034a9-ee01-4de2-9238-549e53bb794f
a13b3522-39c4-4738-b1da-c87bbed8794f	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 07:37:22.185478	b	79f034a9-ee01-4de2-9238-549e53bb794f
95f53187-33a9-42b9-a6aa-897274f7e760	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 08:31:45.176763	n	e6a73462-6516-415b-b188-7352267c17e7
f7defd57-5625-40bb-8299-efc2d448c664	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-01 08:31:45.225531	m	36133c39-09fc-41b6-93f8-590a2eae35d1
ae21ede4-2918-401c-950b-e99b77dd44ea	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 08:31:45.237472	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
7ef92304-c3fb-423e-9a70-947fc15fc778	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-12-01 08:31:45.254091	d	36133c39-09fc-41b6-93f8-590a2eae35d1
e70cacda-2e08-4860-9e1b-6c682d75ec97	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 08:31:45.260506	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
eccbe0f5-41ee-4629-bf9c-3e7db083cd25	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-01 08:31:45.274073	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
393f36c9-ac37-48d2-a9b9-5d6b1825840f	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 08:31:45.279132	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
fa3374fb-3f19-432b-9c12-e772b4a118c2	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 08:31:45.290436	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
6232abfa-0c10-4835-973f-8d652692f864	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 08:42:22.169215	n	79f034a9-ee01-4de2-9238-549e53bb794f
3ff02a67-0fea-400e-93b4-22c5678fa88b	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-01 08:42:22.192967	b	36133c39-09fc-41b6-93f8-590a2eae35d1
3d038d6b-d291-4aaf-894a-ec846301ff40	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 08:42:22.196237	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
5ae35a34-ca73-4b01-b1b3-82a905649e60	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 08:42:22.21341	t	79f034a9-ee01-4de2-9238-549e53bb794f
4d66c741-4767-4b87-8b4f-23601c0a3f85	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 08:42:22.223679	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
5e0f76a4-0e52-4fe2-b098-afe39a3dd000	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 08:42:22.24422	d	e6a73462-6516-415b-b188-7352267c17e7
252b1230-e315-4717-b0c8-2ff1afb0a465	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 08:42:22.255707	nj	e6a73462-6516-415b-b188-7352267c17e7
cec833af-82f8-41a2-aa68-b67d56c7a5f6	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 08:42:22.270924	g	79f034a9-ee01-4de2-9238-549e53bb794f
d164aa9e-3078-4cc3-82c3-4af501506461	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-03 07:27:21.439836	n	36133c39-09fc-41b6-93f8-590a2eae35d1
0e238244-645e-42b9-8e80-e0092f5aa100	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 07:27:21.44707	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
06ddaf40-7a0b-435e-b6a7-b66a1bf04817	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 07:27:21.473661	g	e6a73462-6516-415b-b188-7352267c17e7
5aa130f5-8032-4931-9bde-61486e6c6bb1	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	t	2025-12-03 07:27:21.460828	nj	79f034a9-ee01-4de2-9238-549e53bb794f
33c77af9-48e3-46d7-8adf-9a8f8c570031	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	t	2025-12-01 11:21:25.767239	n	79f034a9-ee01-4de2-9238-549e53bb794f
9fa0ec35-4b43-4157-b59a-95e84ca5c483	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 08:59:26.666165	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
d7ebf8f3-d7f5-4052-aa37-32acef607e05	a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: b	f	2025-12-03 08:59:26.720448	b	36133c39-09fc-41b6-93f8-590a2eae35d1
2ed65359-56ad-438d-8359-f2685501aeae	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 08:59:26.753637	b	79f034a9-ee01-4de2-9238-549e53bb794f
cf15f0a6-4cc7-49bc-a606-afa7fa0462e1	968ee93f-09a9-4ef0-9aba-47dd64d86171	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 08:59:26.771106	m	eef65169-a61e-45bf-b7ed-c7897d7443d6
4656a88a-7d13-436e-b774-f8dcf770b4f6	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 08:59:26.805466	nj	e6a73462-6516-415b-b188-7352267c17e7
aa3c8224-5d48-43c9-9396-dc2bafee0689	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 07:46:29.779192	h	e6a73462-6516-415b-b188-7352267c17e7
abc0ab04-0aa1-491b-9358-285db1f610f9	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 07:46:29.901813	g	79f034a9-ee01-4de2-9238-549e53bb794f
7d0f8ece-5886-4a28-af63-0679aa4c85f5	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-11-25 08:46:35.899066	g	e6a73462-6516-415b-b188-7352267c17e7
75451bd5-b70a-45c2-9dee-1dead15f6f26	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 20:56:38.928109	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
e397bc6e-cfbf-40c4-ab88-68402ba71a79	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 20:56:38.975663	nj	e6a73462-6516-415b-b188-7352267c17e7
3219a4cf-9b89-418f-9908-2708442de2f8	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 20:56:38.99281	t	e6a73462-6516-415b-b188-7352267c17e7
97db1d2b-8230-4e55-acf4-d2e8315ad337	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-11-30 22:30:31.123815	h	36133c39-09fc-41b6-93f8-590a2eae35d1
1bdd4d8d-e4b6-47fe-b3e1-eb0761dcdd12	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-30 22:30:31.134863	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
8ffc8e7f-1c73-4e69-b465-98effc89349e	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-11-30 22:30:31.146426	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
a5000009-e917-4d54-b360-fe8c1263b4fc	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-11-30 22:30:31.152672	n	e6a73462-6516-415b-b188-7352267c17e7
8c54dc8a-bdc5-42ba-a819-15956bf9a285	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-30 22:30:31.193299	b	e6a73462-6516-415b-b188-7352267c17e7
370a43af-34e0-4914-a2d3-2e278a150e8e	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-30 22:30:31.227648	m	e6a73462-6516-415b-b188-7352267c17e7
989f9d9a-b7a8-4361-b6a2-fc014fb01e44	e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: d	f	2025-11-30 22:30:31.24981	d	36133c39-09fc-41b6-93f8-590a2eae35d1
03a40436-45fb-4f99-a5b9-c2d9478ce363	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-30 22:30:31.253268	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
a9e23d82-961b-44ec-bd79-3353f3dac7c5	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-30 22:30:31.275289	nj	79f034a9-ee01-4de2-9238-549e53bb794f
ad1c619e-37fe-4bd2-8f76-5261a736ee33	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-11-30 22:30:31.286575	g	79f034a9-ee01-4de2-9238-549e53bb794f
a4d1028a-966a-471d-87a6-100220c3a74f	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-01 07:40:19.306884	t	36133c39-09fc-41b6-93f8-590a2eae35d1
31e75572-56ba-4c1e-961a-ee160efafe9c	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 07:40:19.336373	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
eee2e6c3-e584-4eed-95e3-28bccd23b933	e0cc3812-3bce-4bc2-b707-196538470f83	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 07:40:19.361426	d	eef65169-a61e-45bf-b7ed-c7897d7443d6
13917fa8-61c0-48c1-a181-bc20cfb8a2f1	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 07:40:19.379283	d	79f034a9-ee01-4de2-9238-549e53bb794f
f07aad6d-e77d-4a23-84b4-a9ed9c1dddc8	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 07:40:19.469614	h	e6a73462-6516-415b-b188-7352267c17e7
3df43672-18aa-4ae4-bdce-6988ff877096	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-01 07:40:19.513489	b	79f034a9-ee01-4de2-9238-549e53bb794f
e4671a9e-1feb-4b03-939f-5e8a02856d2a	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	f	2025-12-01 07:40:19.531559	h	79f034a9-ee01-4de2-9238-549e53bb794f
89389f20-efb3-406f-aaaa-56dd2c25eade	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 07:40:19.572531	n	79f034a9-ee01-4de2-9238-549e53bb794f
09bf5247-1370-49b5-a87c-b517c2afbbcb	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-01 07:40:19.664103	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
4dd9ffbc-b67a-4534-af13-5c57ced0faa5	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 07:40:19.689735	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
d7b9197a-35c5-4482-9a9b-519c5a5c69dd	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 07:40:19.717546	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
ab89f1a9-24e1-464f-b892-a62825708d24	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: n	f	2025-12-01 08:31:45.180568	n	eef65169-a61e-45bf-b7ed-c7897d7443d6
26817496-4b38-4fc0-a3de-3521bd059b1b	51e290ec-f087-4eb4-b670-92b03e7c3147	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 08:31:45.294219	g	79f034a9-ee01-4de2-9238-549e53bb794f
2fd2091b-fa74-47fc-90c6-9a0fe7faaaf0	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-01 08:42:22.203428	t	36133c39-09fc-41b6-93f8-590a2eae35d1
ecc0a361-4743-4e99-a526-1a015588cf4b	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-01 08:42:22.211687	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
a72bdf04-8d5b-4013-a34a-e43e893114f8	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	f	2025-12-01 08:42:22.226828	m	79f034a9-ee01-4de2-9238-549e53bb794f
99b1f0be-22cd-4930-b2f1-585b9143a7a2	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-01 08:42:22.252062	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e721d1f0-d7be-4e4d-9d56-7f885422c00e	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-01 08:42:22.268199	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
e2db3d10-42fb-49a2-ac3f-a2feb0e6b394	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	t	2025-12-01 08:42:22.246627	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
d801e68b-9279-4d35-9d7d-16d994a2e1b8	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	t	2025-12-01 08:42:22.263371	g	36133c39-09fc-41b6-93f8-590a2eae35d1
0f20e327-72e3-4588-8a44-044da5e7000d	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-03 07:12:42.601621	m	36133c39-09fc-41b6-93f8-590a2eae35d1
3283bdf6-e796-4b87-9706-a80e5bd0988a	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 07:12:42.705229	b	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
01bbc00e-a0b9-4216-9ccb-a8069619d78b	b62f5fa1-09db-40a6-8400-0634b50cd353	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 07:12:42.720557	t	eef65169-a61e-45bf-b7ed-c7897d7443d6
c39596b0-0773-4cda-82fd-da772a98a32b	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 07:12:42.766747	d	e6a73462-6516-415b-b188-7352267c17e7
a4dba5ac-5fab-4573-95d3-bc2a239cfe1d	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-03 07:12:42.783229	h	36133c39-09fc-41b6-93f8-590a2eae35d1
ced11633-1ef5-4a54-b702-d2a57ae393f9	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 07:12:42.812841	g	e6a73462-6516-415b-b188-7352267c17e7
42a70edc-9fd6-4a0b-8a3d-0645231b7ffd	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 07:12:42.823579	h	e6a73462-6516-415b-b188-7352267c17e7
d2d32790-4578-4f80-bac8-4916fbd923d2	51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: g	f	2025-12-03 07:27:21.463009	g	36133c39-09fc-41b6-93f8-590a2eae35d1
997a4f05-e5da-4b72-b792-7961663a362d	51e290ec-f087-4eb4-b670-92b03e7c3147	\N	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 07:27:21.47043	g	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
d51f67c3-7ea8-4adc-a741-3dcb13a1b99b	968ee93f-09a9-4ef0-9aba-47dd64d86171	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: m	t	2025-12-03 07:12:42.979965	m	79f034a9-ee01-4de2-9238-549e53bb794f
64fedc02-942f-47d7-a3f9-c7a1023e4eba	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	t	2025-12-03 07:12:42.886834	t	79f034a9-ee01-4de2-9238-549e53bb794f
f675dba9-cdde-4d74-8298-5c42821a4116	e1471e75-30bc-42a7-825f-e80f6e6f56ab	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: n	t	2025-12-03 07:12:42.853543	n	79f034a9-ee01-4de2-9238-549e53bb794f
187ffe35-c7de-4cf3-ac08-636d0624c832	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	t	2025-12-03 07:12:42.807068	nj	79f034a9-ee01-4de2-9238-549e53bb794f
35cb6f26-9e0e-4230-9c76-a98a99c0bf2a	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 08:59:26.743252	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
9c3c416b-0357-4aa8-9e8c-8844f987f041	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 08:59:26.767435	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
7fec0143-ea08-45c2-a49d-f57bdbd34b09	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-12-03 08:59:26.789639	d	e6a73462-6516-415b-b188-7352267c17e7
2ce1f2a0-2b01-46fb-93ea-9ae610be5e6f	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-03 14:08:10.107965	h	36133c39-09fc-41b6-93f8-590a2eae35d1
acf2ec22-9ced-45fc-a1e1-910af04b53f1	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 14:08:10.115184	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
d3cb2bbc-abdb-4113-b184-9a2d5b959db9	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-11-25 07:45:29.911115	h	36133c39-09fc-41b6-93f8-590a2eae35d1
eb9987e8-9fd1-43da-920d-0dac7b1d1e6f	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-11-25 07:45:29.952242	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
caefd2d1-8fd3-46a8-aaab-dda0b3135e0e	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-11-25 07:45:29.985029	m	36133c39-09fc-41b6-93f8-590a2eae35d1
5e4c3e8b-2dcf-4509-aa59-c874d2aa28f5	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 07:45:30.028039	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
0ba7e395-eec0-4fb7-ba04-a2e0999a1d6e	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-11-25 07:45:30.037187	m	e6a73462-6516-415b-b188-7352267c17e7
d21834a2-75ed-4d72-8bfe-67cf266dafa0	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-11-25 07:45:30.064532	t	e6a73462-6516-415b-b188-7352267c17e7
6a2b5dd3-3843-4da2-9adc-b8baf7a3e45c	a24dec61-f216-41a0-a83f-a33b91b7bab2	\N	⚠️ تم تصعيد الشكوى: b	f	2025-11-25 07:45:30.09911	b	e6a73462-6516-415b-b188-7352267c17e7
8d867303-773f-417c-bc33-a5c2136e3bb1	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-11-25 07:45:30.139389	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
b3235db3-6534-468b-996d-d7d6621125a1	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 07:45:30.168058	d	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
20099605-7ef5-4a48-b0a3-03e7660eed87	e0cc3812-3bce-4bc2-b707-196538470f83	\N	⚠️ تم تصعيد الشكوى: d	f	2025-11-25 07:45:30.175362	d	e6a73462-6516-415b-b188-7352267c17e7
1833ba15-c653-43b4-9ff7-98a34577fbe0	f19fd934-c68d-470a-a9d6-7730c118bc06	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: nj	f	2025-11-25 07:45:30.21123	nj	79f034a9-ee01-4de2-9238-549e53bb794f
036b6209-3fbd-4d54-9a45-8e9e1af519d7	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: h	f	2025-12-03 07:12:42.605005	h	36133c39-09fc-41b6-93f8-590a2eae35d1
8189cc76-35f7-42d2-b28a-7bc42e3da307	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 07:12:42.683903	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
d1645022-416f-46c8-a056-91c36fc6f1b5	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 07:12:42.710511	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
14f69199-17dc-4da6-8da6-4b1c90a5d22f	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 07:12:42.719943	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
298caafb-7438-4610-bd96-21ac91a92f53	f19fd934-c68d-470a-a9d6-7730c118bc06	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 07:12:42.803205	nj	eef65169-a61e-45bf-b7ed-c7897d7443d6
9bbf2d93-0f90-45ec-8521-76a46fa0e4ac	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	\N	⚠️ تم تصعيد الشكوى: h	f	2025-12-03 07:12:42.818529	h	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
2a182361-4706-49e0-b737-787517206f71	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 07:12:42.851412	n	e6a73462-6516-415b-b188-7352267c17e7
aef4b8f6-2fb4-4bb4-8d00-f3af9232c5fd	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 07:12:42.884302	t	e6a73462-6516-415b-b188-7352267c17e7
0eeadcc2-26dc-4fd9-8db6-ff0544e2dd6b	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 07:12:42.977974	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
8864e2ac-8eb5-4e5c-9718-825b588aee01	51e290ec-f087-4eb4-b670-92b03e7c3147	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: g	f	2025-12-03 07:12:43.03314	g	eef65169-a61e-45bf-b7ed-c7897d7443d6
17c3706e-b5a5-4e13-9f50-09c5095cf358	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 07:27:21.479039	t	e6a73462-6516-415b-b188-7352267c17e7
8cf62034-2d40-4bb6-b67a-7b4cf2810ed4	f2c657e6-d543-4bd0-a18f-1d8e920a43e8	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: h	t	2025-12-03 07:12:42.823814	h	79f034a9-ee01-4de2-9238-549e53bb794f
2f34588e-df5c-4d71-ba22-576e7ca151e7	e0cc3812-3bce-4bc2-b707-196538470f83	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: d	t	2025-12-03 07:12:42.770134	d	79f034a9-ee01-4de2-9238-549e53bb794f
9423ddae-e0af-4e17-a542-22a76261b313	a24dec61-f216-41a0-a83f-a33b91b7bab2	ec603af3-61a2-4673-a614-3284a0bfc96c	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 08:59:26.750648	b	eef65169-a61e-45bf-b7ed-c7897d7443d6
87ec9d54-b2b4-437a-a920-f86aaec7ba64	b62f5fa1-09db-40a6-8400-0634b50cd353	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 08:59:26.757739	t	79f034a9-ee01-4de2-9238-549e53bb794f
454a1b7c-755b-468d-8b3d-fad903b55509	f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: nj	f	2025-12-03 08:59:26.793933	nj	36133c39-09fc-41b6-93f8-590a2eae35d1
eab29a32-5de7-46b6-9d7c-f8ac77e9d2a4	f19fd934-c68d-470a-a9d6-7730c118bc06	\N	⚠️ تم تصعيد الشكوى: nj	f	2025-12-03 08:59:26.802759	nj	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f6d4a1ce-6a39-4077-b669-41317c8bb098	e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: n	f	2025-12-03 14:08:10.108914	n	36133c39-09fc-41b6-93f8-590a2eae35d1
fd3ab938-d620-400d-ac47-1edbde529fcc	e1471e75-30bc-42a7-825f-e80f6e6f56ab	\N	⚠️ تم تصعيد الشكوى: n	f	2025-12-03 14:08:10.122912	n	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
f1ce3e8d-f551-4583-9821-7d7ed03dfac5	b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: t	f	2025-12-03 14:08:10.140221	t	36133c39-09fc-41b6-93f8-590a2eae35d1
a9d12648-5eec-4642-8ced-8d8a7b6bb51c	b62f5fa1-09db-40a6-8400-0634b50cd353	\N	⚠️ تم تصعيد الشكوى: t	f	2025-12-03 14:08:10.148875	t	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
5143e918-7136-40a7-a279-90328d366bc5	a24dec61-f216-41a0-a83f-a33b91b7bab2	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	⚠️ تم تصعيد الشكوى: b	f	2025-12-03 14:08:10.189082	b	79f034a9-ee01-4de2-9238-549e53bb794f
154c82dc-c877-4043-8ca2-5eeccd078cb5	968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	تم رفع الشكوى للمتابعة: m	f	2025-12-03 14:08:10.206558	m	36133c39-09fc-41b6-93f8-590a2eae35d1
01b8adb4-ee74-41c3-abf6-5bd49321fa20	968ee93f-09a9-4ef0-9aba-47dd64d86171	\N	⚠️ تم تصعيد الشكوى: m	f	2025-12-03 14:08:10.211061	m	6d927a2a-83ba-4a6e-81d5-5d53d6457b43
\.


--
-- TOC entry 3657 (class 0 OID 25958)
-- Dependencies: 245
-- Data for Name: complaint_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.complaint_types (id, code, name, created_at) FROM stdin;
d4b20570-8451-4190-854c-4c57f12de6ef	EDUCATIONAL	شكاوي تربوية	2025-11-18 07:59:36.905182
ebcd7481-f4b8-4985-944d-c37f94314881	TRANSPORT	شكاوي النقل المدرسي	2025-11-18 07:59:36.905182
35addc2a-8009-4c1f-9c05-f26b5e5a99f3	BEHAVIOR	شكاوي سلوكية	2025-11-18 07:59:36.905182
221b47d1-c04d-4303-ba28-e49de169ac2f	ADMIN	شكاوي ادارية	2025-11-18 07:59:36.905182
0d1a535f-3d9b-4131-8182-d33375e24e5c	TECH	شكاوي تقنية	2025-11-18 07:59:36.905182
27903d18-1563-463b-a291-ba192f07521c	FINANCE	شكاوي مالية	2025-11-18 07:59:36.905182
694504c1-b006-4ae3-b3f2-33620c9fcabb	ACTIVITIES	شكاوي الانشطة و الرحلات	2025-11-18 07:59:36.905182
6d068828-fd1b-43bb-93cf-6e381fd81782	FOOD	شكاوي متعلقة بالاطعام	2025-11-18 07:59:36.905182
41dafeed-a629-4ec6-8bca-6bca01d82eb1	SAFETY	شكاوي النظافة و الامن و السلامة	2025-11-18 07:59:36.905182
72e5efb4-ec05-4b0a-9354-fc8d0672d464	GENERAL	شكاوي عامة	2025-11-18 07:59:36.905182
\.


--
-- TOC entry 3658 (class 0 OID 25969)
-- Dependencies: 246
-- Data for Name: complaints; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.complaints (id, employee_id, type_id, title, description, priority, is_anonymous, attachment_path, status, manager_comment, handled_by, created_at, completed_at, due_date, resolved_at, satisfaction_rating, feedback, department_id) FROM stdin;
c4d5fc4f-4a8a-47bd-98f1-69cc2a546b82	ad4800fd-c13f-4d2a-8558-cae29f052ea0	ebcd7481-f4b8-4985-944d-c37f94314881	tres lent	nécessite un peu d organisation	medium	f	\N	completed	bonjour ! on va prendre ca en consideration dcr	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	2025-11-18 08:08:39.850666	2025-11-19 07:33:32.527812	2025-11-21 08:08:39.850666	\N	\N	\N	\N
f2c657e6-d543-4bd0-a18f-1d8e920a43e8	ad4800fd-c13f-4d2a-8558-cae29f052ea0	41dafeed-a629-4ec6-8bca-6bca01d82eb1	h	l	medium	f	\N	pending	\N	\N	2025-11-19 08:45:38.98285	\N	2025-11-22 08:45:38.939	\N	\N	\N	\N
e1471e75-30bc-42a7-825f-e80f6e6f56ab	ad4800fd-c13f-4d2a-8558-cae29f052ea0	0d1a535f-3d9b-4131-8182-d33375e24e5c	n	b	medium	t	\N	pending	\N	\N	2025-11-19 08:47:37.357491	\N	2025-11-22 08:47:37.307	\N	\N	\N	\N
b62f5fa1-09db-40a6-8400-0634b50cd353	ad4800fd-c13f-4d2a-8558-cae29f052ea0	694504c1-b006-4ae3-b3f2-33620c9fcabb	t	t	medium	f	\N	pending	\N	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	2025-11-19 09:04:51.381559	\N	2025-11-22 09:04:51.38	\N	\N	\N	\N
fbdb5520-2835-4248-9437-6ea25d444ac0	ad4800fd-c13f-4d2a-8558-cae29f052ea0	6d068828-fd1b-43bb-93cf-6e381fd81782	u	u	medium	f	\N	completed	\N	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	2025-11-19 09:20:35.059434	2025-11-19 09:20:45.961961	2025-11-22 09:20:35.059	2025-11-19 09:20:45.961961	\N	\N	\N
a24dec61-f216-41a0-a83f-a33b91b7bab2	ad4800fd-c13f-4d2a-8558-cae29f052ea0	35addc2a-8009-4c1f-9c05-f26b5e5a99f3	b	k	medium	f	\N	pending	\N	\N	2025-11-19 09:41:36.338501	\N	2025-11-22 09:41:36.337	\N	\N	\N	\N
968ee93f-09a9-4ef0-9aba-47dd64d86171	ad4800fd-c13f-4d2a-8558-cae29f052ea0	41dafeed-a629-4ec6-8bca-6bca01d82eb1	m	c	medium	f	\N	pending	\N	\N	2025-11-19 09:52:31.507566	\N	2025-11-22 09:52:31.506	\N	\N	\N	\N
e0cc3812-3bce-4bc2-b707-196538470f83	ad4800fd-c13f-4d2a-8558-cae29f052ea0	35addc2a-8009-4c1f-9c05-f26b5e5a99f3	d	ds	medium	f	\N	pending	\N	\N	2025-11-19 09:53:06.172708	\N	2025-11-22 09:53:06.172	\N	\N	\N	\N
f19fd934-c68d-470a-a9d6-7730c118bc06	ad4800fd-c13f-4d2a-8558-cae29f052ea0	41dafeed-a629-4ec6-8bca-6bca01d82eb1	nj	jn	medium	f	\N	pending	\N	\N	2025-11-19 09:56:50.315994	\N	2025-11-22 09:56:50.314	\N	\N	\N	\N
51e290ec-f087-4eb4-b670-92b03e7c3147	ad4800fd-c13f-4d2a-8558-cae29f052ea0	27903d18-1563-463b-a291-ba192f07521c	g	g	medium	f	\N	pending	\N	\N	2025-11-19 10:19:13.738745	\N	2025-11-22 10:19:13.737	\N	\N	\N	\N
\.


--
-- TOC entry 3653 (class 0 OID 17778)
-- Dependencies: 240
-- Data for Name: signal_type_responsibles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.signal_type_responsibles (type_id, employee_id, assigned_by, assigned_at) FROM stdin;
cd2efb1e-b5b3-429f-861a-1ca3d371aefe	70c000ea-a3b2-400b-bb35-d419066b6183	\N	2025-11-05 07:08:32.29298
f7cedf4e-f684-485b-a43d-922a35611f54	e80eca21-e374-453c-8a52-51667058f8a3	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-11-05 08:13:45.767174
fd54d142-da52-4820-be69-749b0fcefba4	ad4800fd-c13f-4d2a-8558-cae29f052ea0	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-11-05 10:00:31.227082
40c76013-87bd-42fc-987b-a227f58672bf	4f25e54e-db75-486b-8e8b-8d87b0d83d64	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-11-17 10:15:09.733787
702f65c4-1367-444c-ab73-868b332fa353	6e7fb1ce-4d2a-4402-b51d-2fe948e1476e	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-11-17 10:15:17.971064
0b294050-f79e-4212-93a2-5351df3e9e6d	8aaf47c6-0c0a-495d-8802-b7bf151e24ae	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-11-17 10:19:23.144148
\.


--
-- TOC entry 3652 (class 0 OID 17767)
-- Dependencies: 239
-- Data for Name: signal_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.signal_types (id, code, name, created_at) FROM stdin;
cd2efb1e-b5b3-429f-861a-1ca3d371aefe	FURNITURE	الاثاث و التجهيزات	2025-11-05 07:01:03.043425
fd54d142-da52-4820-be69-749b0fcefba4	ELECTRICITY_SIGNAL	الكهرباء و الاشارة	2025-11-05 07:01:03.043425
f7cedf4e-f684-485b-a43d-922a35611f54	TECH_IT	الاجهزة التقنية و الاعلام الالي	2025-11-05 07:01:03.043425
18200c7a-d3f4-4028-8eca-48b7eb55ead2	WATER	الماء	2025-11-05 07:01:03.043425
9a8f7296-b17b-4565-ba1f-396ffbf5fc66	CLEANLINESS	النظافة مشاكل او اقتراحات	2025-11-05 07:01:03.043425
40c76013-87bd-42fc-987b-a227f58672bf	TYPE_1763374509720	عامة	2025-11-17 10:15:09.721573
702f65c4-1367-444c-ab73-868b332fa353	TYPE_1763374517967	ببببببببببب	2025-11-17 10:15:17.968774
0b294050-f79e-4212-93a2-5351df3e9e6d	GENERAL	general	2025-11-17 10:19:23.139962
\.


--
-- TOC entry 3654 (class 0 OID 17800)
-- Dependencies: 241
-- Data for Name: signalisations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.signalisations (id, type_id, created_by, title, description, photo_path, is_viewed, is_treated, treated_by, treated_at, created_at, localisation_id, location, priority, satisfaction_rating, feedback) FROM stdin;
a63da118-2cdc-44d7-ad88-c87e304a6706	f7cedf4e-f684-485b-a43d-922a35611f54	5a1ab543-b2e1-445e-942d-d6ec24a576e5	yyyy	yyy	/uploads/signalisations/1762772610410-594417610.png	t	t	e80eca21-e374-453c-8a52-51667058f8a3	2025-11-10 11:07:49.566765	2025-11-10 11:03:30.468018	e23b88d7-fae1-428d-bb4e-9a97b008463d	\N	medium	\N	\N
eba2ca88-d053-41ea-93f6-37ab1b44309c	f7cedf4e-f684-485b-a43d-922a35611f54	5a1ab543-b2e1-445e-942d-d6ec24a576e5	mpapa	papa	\N	t	f	\N	\N	2025-12-03 13:50:56.726286	5d21e19e-8ed3-4c2f-9d4b-41936dcbd636	\N	medium	\N	\N
c884d8fd-bf28-4e58-adc1-46c942cb07dd	f7cedf4e-f684-485b-a43d-922a35611f54	2ab3b987-fc12-4e33-bbfa-5fa1a17dbb13	t	toooooo	\N	t	f	\N	\N	2025-12-03 13:39:39.226506	afeacd55-e107-4a59-b19b-6053cb2b4110	\N	medium	\N	\N
9f10dccc-280a-44ce-b2a4-2be5e51b28cc	fd54d142-da52-4820-be69-749b0fcefba4	2ab3b987-fc12-4e33-bbfa-5fa1a17dbb13	pc panne	dddddd	\N	t	f	\N	\N	2025-12-03 12:53:04.9612	e23b88d7-fae1-428d-bb4e-9a97b008463d	\N	medium	\N	\N
fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	fd54d142-da52-4820-be69-749b0fcefba4	2ab3b987-fc12-4e33-bbfa-5fa1a17dbb13	ref	pililo	/uploads/signalisations/1762336876270-660592620.png	t	f	\N	\N	2025-11-05 10:01:16.311699	\N	\N	medium	\N	\N
1c42946d-594f-4b90-a350-e00c08244d80	f7cedf4e-f684-485b-a43d-922a35611f54	2ab3b987-fc12-4e33-bbfa-5fa1a17dbb13	papa	papa	\N	t	f	\N	\N	2025-11-05 09:57:38.069957	\N	\N	medium	\N	\N
88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	cd2efb1e-b5b3-429f-861a-1ca3d371aefe	2ab3b987-fc12-4e33-bbfa-5fa1a17dbb13	fff	fffff	/uploads/signalisations/1762332933546-668605910.png	t	t	70c000ea-a3b2-400b-bb35-d419066b6183	2025-11-05 10:17:04.725325	2025-11-05 08:55:33.70922	\N	\N	medium	\N	\N
c008bc44-7ac7-4388-b600-91d993a416e4	cd2efb1e-b5b3-429f-861a-1ca3d371aefe	2ab3b987-fc12-4e33-bbfa-5fa1a17dbb13	yhth	thjbj v	/uploads/signalisations/1762329711224-168178723.png	t	t	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-11-05 09:32:41.439241	2025-11-05 08:01:51.263646	\N	\N	medium	\N	\N
3cb1231f-25df-45d0-8e6e-fa36321401ce	cd2efb1e-b5b3-429f-861a-1ca3d371aefe	2ab3b987-fc12-4e33-bbfa-5fa1a17dbb13	dddddd	dddddd	/uploads/signalisations/1762327317820-238371666.png	t	f	\N	\N	2025-11-05 07:21:57.870036	\N	\N	medium	\N	\N
092f6964-dc38-4b37-81d4-edb1f0d00c82	cd2efb1e-b5b3-429f-861a-1ca3d371aefe	2ab3b987-fc12-4e33-bbfa-5fa1a17dbb13	tt	fll,zgkzgz	/uploads/signalisations/1762326692608-361135409.png	t	f	\N	\N	2025-11-05 07:11:32.646378	\N	\N	medium	\N	\N
c3077fb6-6765-4c91-a5a8-192187a76b0a	cd2efb1e-b5b3-429f-861a-1ca3d371aefe	70c000ea-a3b2-400b-bb35-d419066b6183	ttttt	grzehu	/uploads/signalisations/1762326472880-28007053.png	t	f	\N	\N	2025-11-05 07:07:52.918506	\N	\N	medium	\N	\N
\.


--
-- TOC entry 3656 (class 0 OID 17846)
-- Dependencies: 243
-- Data for Name: signalisations_status_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.signalisations_status_history (id, signalisation_id, status, changed_by, note, changed_at) FROM stdin;
c802cada-5082-4511-8a11-2f28e510726c	c008bc44-7ac7-4388-b600-91d993a416e4	TREATED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Traitée	2025-11-05 09:32:41.45193
4e2efa8f-acb0-4997-9430-133f63f603f3	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:03:10.050644
d74fae9b-86e6-4519-9fc2-5725d74e85f9	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:16:45.379616
e4f60547-7017-4f74-b6ce-2a90f7f8f25a	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:16:45.379825
071de257-8f0a-487d-a4c9-c5af01ebc34c	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:16:45.379983
1a5fca85-8473-4453-97ea-b90cb4529758	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:16:45.400295
2ba498ae-4b5f-4199-b779-1fd268327246	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:16:45.401116
36089758-f542-479b-9d9b-f4d676137086	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:16:45.40197
daf8426d-21e8-4be2-9650-b622620e3585	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 10:16:56.374695
22db6cdc-8a72-42e5-9278-029d108edf53	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 10:16:56.401195
a67d9624-8036-4727-8ec6-4dd1c1058366	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 10:16:56.416408
0b1cdbbf-46ba-45dc-bfc7-e4935c42a7aa	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 10:16:56.437586
74f697cc-e7a6-4cf1-a051-e6c29e2e2fdc	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 10:16:56.446209
2e43ed47-a2ef-47ef-b6c5-81e119236204	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	TREATED	70c000ea-a3b2-400b-bb35-d419066b6183	Traitée	2025-11-05 10:17:04.730752
62938923-2dda-4b7b-ac55-20adfe2c022d	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 10:17:04.767746
081c841a-458b-412a-8a45-87b11f75f1e7	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 10:17:04.767478
e96708bb-6979-4a45-ace9-2b724dd79a17	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 10:17:04.786819
bfeca395-3618-4ecb-a41f-8c61e90b47a2	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 10:17:04.787698
2806a9e9-d2a2-40e1-9f1c-9fcc4d552492	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 10:17:04.828974
c23ac271-ecc7-44e1-a3ce-593e9e6d19fb	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 10:17:06.517037
592d20f4-3caa-4714-bfa3-ab1177e24874	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 10:17:06.517248
5b4b4cc9-f142-4f41-9727-19589fc40a0a	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 10:17:06.521118
69dc0aff-bda6-4acc-80ef-87e5fdbac687	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 10:17:06.584002
37f6d2d0-f80a-4351-8420-fa5c3289aed8	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 10:17:06.587541
cecfa520-1495-4cc5-a958-98a179ed59ac	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-05 10:17:14.937347
5d359d1d-1c09-45da-aac1-c2b306ff2cd5	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:17:29.93055
0169bf02-fe5f-438c-8284-2731349191b6	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:17:29.954966
38d490de-ef61-41cf-abe5-50d364ddb862	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:17:29.967316
07d6a247-b489-46a0-9ae0-803d5e8c0c6b	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:17:29.986727
00d1e068-bb5b-4fdb-8d01-62cebbce0c24	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:17:29.995067
d6206c1d-2d5e-449e-8505-d4a2a0b118dd	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:18:03.499518
cd784ec0-2562-44c8-bc82-2451780e9e0a	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:18:03.549742
ffa645ae-ca8e-478e-a3e2-81e44f0d562c	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:18:03.556668
cd2960fa-3a71-4aa8-9edb-98b89de89ecd	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:18:38.989456
0a47ac31-f1d7-4863-abc6-493319b86ef0	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 10:18:40.161152
34900ef2-9f5e-4995-9c18-365c2437e59e	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-05 12:21:00.756541
63504763-a128-44a0-9e63-668b578cb558	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 12:21:05.683456
32ef21d4-f49b-4769-8bb4-9ded9db4cacf	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 12:21:05.68818
4f6c817e-7e71-4395-89c1-5acf0c585023	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 12:21:05.704797
f43bedab-4bc6-430c-959f-aa16e933922d	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 12:21:05.715546
0cd8938c-4064-42d5-9164-42ce1f09bc17	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-05 12:21:05.742324
726548e2-e7e1-452d-98ad-96fd618326c1	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 12:21:20.236116
fc3e2c9f-49aa-4df7-98a0-d15dbbd266f1	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 12:21:20.236042
cc8b50c2-a92b-4c9b-807b-f8b8b6a0dd85	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 12:21:20.253143
47112d9c-0cf6-4e44-982c-40f434d4efca	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 12:21:20.25326
b20bf4c0-2d91-4445-a311-894adbf59e71	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 12:21:20.272737
8c19f912-d45c-4d8d-936a-04ffd8961f7a	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 12:46:58.056226
0f780295-742b-43a2-aead-49ddf1bcaf9e	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 12:46:58.085526
a18d8ef9-57f6-48a0-b59a-67be4186399e	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 12:46:58.098839
59ef3259-33e0-43e5-805b-85cb7eee83e5	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 12:46:58.116036
f72b7b42-6ecd-48b4-a7b5-1b3f7422cbd7	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-05 12:46:58.210245
422631b0-277f-4c2c-9bda-8707856d17c3	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-10 08:09:49.255029
b881e767-1aa5-4aad-8968-e6d09a3b871c	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 08:10:00.335073
9d5b7084-98d0-43ec-ac90-ae6e9e6a835c	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 08:10:00.341478
75e8c4ad-9180-4242-bf6a-b55552d3ba53	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 08:10:00.371194
b9f7018d-740d-4af5-89fb-a26db7da9263	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 08:10:00.376912
3e8a949f-3152-41d7-8876-3074c2ce9110	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 08:10:00.419093
7958a4aa-e3b6-4a82-92ef-23e0e85440dd	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 08:10:22.467542
4dd3fae3-c93b-484b-a8c3-e7e9cdba0e26	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 08:10:22.47329
708913d4-d458-4deb-866b-7cad6182afb7	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 08:10:22.497216
a6c53c43-3733-4384-9615-05bbd669499d	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 08:10:22.505895
afbdeccc-9374-47d8-88bb-780973800a66	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 08:10:22.547962
66dfad89-67c0-435d-94a2-a2cb2f15087a	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 09:37:55.225469
703e200d-9448-459a-95d8-473c93f51415	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 09:37:55.239147
4a88ac11-1438-4111-a4e3-faadd503c84e	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 09:37:55.259362
45b8646b-703b-4d94-877b-a895a2077e87	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 09:37:55.272889
80cc1fca-4ec4-48b6-be8b-731a2a3a630d	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 09:37:55.282756
e436ff68-d5ff-4ef0-9072-88e7564cc1a5	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 09:38:01.577313
46a84c62-f4b4-4fda-a0a6-fdc08702edb6	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 09:38:01.577047
b290cc0f-115b-48c2-aa91-6caa5166ded0	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 09:38:01.576844
8d2fbe38-45cf-4874-9530-cae958c36ffc	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 09:38:01.653041
6b9840c8-93f7-43be-a052-760fe44f0638	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 09:38:01.659019
66adff24-9a2e-4b15-b627-fd674a5dffa6	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-10 09:38:01.929052
fe09aaba-f80d-4a6e-97cb-d7dba37181f5	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-10 09:38:02.831719
1a56a9f3-97cf-4d5e-a9b0-21cce99882a5	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:07:06.961294
6e323af8-322b-4929-a21b-3019e0120828	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:07:06.984548
cac2e634-d716-45c1-8a39-1dec7eef9e2f	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:07:06.999459
947b58d0-e745-45ab-8edc-b0862639f789	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:07:07.013921
a2754ba1-c920-4a29-9372-13691eaf15d7	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:07:07.011818
d736513f-5412-40e5-91bf-a5990ee34ac3	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:07:08.059081
7205801b-c191-4e59-8e27-02d81b5369e7	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:07:08.058724
2538bb10-faa4-4602-8c91-577fde7bc707	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:07:08.123289
f13d2d29-d6a3-4a5d-bf59-5358e2b8e43a	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:07:08.133388
ae1995ed-055b-4eab-a76d-25ba7b86a5b5	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:07:08.246308
6cb4d73c-b447-4d11-9e75-e1d23c8ccc91	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 10:07:11.781592
4dc61037-fb56-49e1-b222-7a1c9e02f9b2	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 10:07:11.78185
3a1c30dd-7feb-4fa0-a5cf-fc31b15e5d3a	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 10:07:11.782112
d11484f4-66e7-407e-ab31-c442765d325e	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 10:07:12.987768
3d8fa6bd-6693-4894-a6fe-e97bb9dc3b85	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 10:07:12.993172
b6485ebf-eb82-41c4-a93d-45a12b2140a9	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 10:07:12.993372
d0b47327-5e89-4361-901c-285cb46ff099	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-10 10:07:14.531971
7e0522ae-2f69-4b91-bfe7-c4eb444c3617	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 10:07:11.782693
8e9e52c5-779f-47bf-a0e4-cc568449cc1e	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 10:07:11.782429
ace96748-5426-4a46-8063-eb21cc13a6d4	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 10:07:12.987469
100a01e3-0f66-4eee-9a96-448ddd4e2554	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-10 10:07:12.991558
f55123d2-42a5-4342-a188-6f95e12dc5b7	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:07:28.832331
31abe1a6-7efe-41d4-9190-223f15a5da70	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:07:28.852397
dd7e87f2-7783-4c10-8224-64f70783ca72	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:07:28.866258
04c71dec-f588-494f-b15e-b595e3477062	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:07:28.878468
d406600a-5120-471b-909a-48fc55d9ab62	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:07:28.882915
008805df-405f-4abd-8b63-796ba87b7598	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:14:19.300944
b159eaa9-53c2-4873-b474-908e79123c2b	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:14:19.314786
550e14c0-10d8-439b-8328-1c55f8d620a4	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:14:19.335772
5deeded6-aee0-407d-a547-71202243316e	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:14:19.349639
eeafe89f-6934-4331-bffa-762f8e57a0a8	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:14:19.367329
d9b5dc71-5808-4131-98d9-e1cae5d3eee5	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:20:06.388735
9baf70eb-5cff-40c6-9fb9-04b31eca42ab	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:20:06.419014
7dffe2c5-b455-442a-8ce8-72865852a4c3	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:20:06.439947
7cd4116d-cd77-4ef8-bcf2-d60ed52ec27c	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:20:06.462757
4d5e1ca9-8204-4542-9aea-3e807d58cccc	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:20:06.54891
7dbf88e7-2ea3-45b5-bc0f-f30f759422ed	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:49:46.960401
eaf947f5-e130-45d4-9cf2-7f4195be1657	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:49:46.965895
60a595c0-0e3f-41c3-9ae0-c761d936a69d	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:49:46.984419
68aea7dd-f1d6-44ee-9165-e6c76c4a5999	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:49:46.997133
74c659ee-2f8e-450a-be7a-265316e70389	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:49:46.99782
d6059fb8-f1f6-43b0-9a0d-fc0555a6272e	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:52:58.244392
d2441b15-3efc-43cf-b6d1-5209e8767642	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:52:58.274759
f430f317-d220-4a6f-b345-e33b6346e1b8	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:52:58.297637
edf77b18-2a35-4526-8cb2-2bea6ec6a7e1	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:52:58.369119
1edbbada-8538-49ac-b9d0-a7446ec83cad	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:52:58.380584
5cb95766-6840-41dd-916f-3179c2d62f95	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:52:59.478171
b2961a4d-519c-4a98-8fe2-fdb1aec4a6dc	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:52:59.477997
147ad7ea-d5bb-45f4-83bf-db128c01f4a4	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:52:59.477324
489210ba-533d-4fc4-b869-3988da0b4a2f	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:52:59.590963
f425de41-54b3-47a8-a1c1-982043a937c1	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:52:59.598899
fbb8bd62-cb46-41cc-9b51-c06510b89dce	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:53:36.963902
411e182b-0ad7-4206-8458-e35978fb94b0	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:53:36.987127
eae31855-ff34-4c4a-8616-cf2198b0ff23	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:53:37.004748
49a4563f-9ff7-479b-bc67-de58cc700fdf	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:53:37.020402
ea6767ec-aadc-4cd1-bdd6-7ded118e357b	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 10:53:37.023757
16e7a53d-7629-4e5a-9578-b6328b3f4b61	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:00:35.657421
dbf64572-72db-4506-b249-4c5d7332de72	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:00:35.657178
d7fcfd67-4066-4a6d-9356-45fac0ddcc53	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:00:35.736768
260ab243-48a4-4add-a9f2-500790cbf253	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:00:35.752344
9b8c1c00-e044-4962-a544-c935d74868a1	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:00:35.755569
4f943c6f-1f10-4e58-965c-627ba03d658f	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:03:13.090702
a7b9f4f0-f26b-428c-9d46-0a9845c95ae2	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:03:13.117077
510cb7ab-393c-43b3-bbd5-a0665a849cb0	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:03:13.133179
25551a07-1ab8-42d1-8591-7a6c91dd14e2	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:03:13.151399
62126986-7bd7-4fb3-b49d-1eae58869178	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:03:13.157826
64518d72-8f32-44cb-b821-04da74696c01	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:03:30.54511
4fa37f70-b211-4277-81e9-db5a4d14520d	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:03:30.566049
86792e8a-f096-4d7f-8670-5af4b9321a28	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:03:30.581168
080bbc5b-5dfc-4199-9aa9-320c734751f1	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:03:30.5969
d353a675-b9da-4059-b0e4-4d69e37033b6	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:03:30.60758
d2efc569-34f3-497a-afee-34cd058a79b5	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:03:30.624277
463ff96e-9c25-4070-a747-eb3a7f7e9076	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-10 11:07:35.3691
af358235-5c2b-40b3-8aa0-a65f26185c81	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-10 11:07:35.371987
5c807cfa-a79f-4d91-8c76-f935acff291e	a63da118-2cdc-44d7-ad88-c87e304a6706	TREATED	e80eca21-e374-453c-8a52-51667058f8a3	Traitée	2025-11-10 11:07:49.580137
2cd3aeb3-42a8-45e9-8c81-faeaac0eb986	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-10 11:07:49.610813
42be7b53-486b-4965-b0a0-bf33b06d1b1b	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-10 11:07:49.628087
6ea7ca54-bed5-4940-a65d-e059043ffa75	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-10 11:07:51.518683
8c46edf4-fd55-4ac7-a435-86ca272d4254	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-10 11:07:51.522532
e1975128-228f-45cf-92da-3e34ee90ae6f	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:07:54.850154
f852cee1-d072-490b-9efb-6e44271113f6	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:07:54.850437
4e25f3c4-7119-49ed-996c-93dbef1b7734	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:07:54.850633
cdd21519-6c8c-449b-a62f-fa1877ba788a	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:07:54.873763
ba71915e-36a6-441b-9682-f84d33fac423	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 11:07:54.936652
d63dcf68-26e6-4621-8f0d-75861e39a62c	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 14:29:07.865849
ffb3f9a3-55f5-4c46-a97e-3170e9ade423	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 14:29:07.910402
56bd6452-0ee6-42f9-9af7-72886143b9bb	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 14:29:07.937913
1eb3d94f-e2b9-4d76-9032-529da2c7e798	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 14:29:07.968367
35121512-de08-4456-a03b-339bd6363227	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-10 14:29:07.983217
d7ba21ad-b221-4ff3-a9b8-fc2e31647021	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-11 07:57:13.270466
d1cf160f-d137-40cd-8187-249dbc010f0f	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 07:57:19.472675
468e9c68-d9d9-44f2-9d91-fd67cafde5de	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 07:57:19.476175
c2b2f3b1-f999-479c-9e00-d866b5d37bd0	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 07:57:19.492332
aedac924-0afa-4cc9-bc83-84d1d8b380a1	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 07:57:19.502512
4e656607-1469-44ab-9f81-83c733c50dee	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 07:57:19.510969
351d4891-66bb-487d-8515-26ca2b0991d7	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 07:57:32.241689
cc31c943-e6a8-4ada-a88e-a4a41d02dc9c	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 07:57:32.241769
af134fa8-8249-43ad-9f1b-326fa3b31d02	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 07:57:32.257744
2558d7fe-f2ca-458a-8dd4-9c17bd32e49b	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 07:57:32.257486
94f95864-c7fe-426d-b9a9-dd01c5f98675	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 07:57:32.275274
005b6935-7113-4d56-a896-e5b248f266dc	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:04:31.254708
293cfe0e-60ec-40e1-b9b3-5372e82c0183	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:04:31.268598
a480a49f-4b3f-4f77-8833-9802dd31f860	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:04:31.306273
f5d1994a-2334-4ca4-8a57-a525df3c50c6	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:04:31.324069
fbc189ba-f2b1-4cbd-862d-898fce8b3f04	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:04:31.32973
3191fb64-3af2-4996-b739-b672e3e75359	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:04:32.249564
67d14860-1b57-4d3f-8829-18d426a84b8d	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:04:32.250274
c68fb4db-e2cc-4904-8518-64c51ea2de7e	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:04:32.249995
cd478151-3e6a-4b22-9658-e2f3a41fc168	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:04:32.308421
2d90cd38-560a-4e91-9f8f-8530491cdd9f	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:04:32.423959
c7dc7c21-18c4-4ca7-ab12-826c66746b1a	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-11 08:04:32.847333
3cd24d9e-a4eb-412b-b6ed-467281f785cd	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-11 08:04:33.528629
13216bcc-e56f-4df4-8234-3356b1c02fae	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:06:18.211938
db453c5b-a204-4b42-8c2a-95cea4d1129b	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:06:18.239632
4142c620-7259-4cb2-8479-58b60dc4b244	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:06:18.254055
b179ffa8-7d11-440a-9f83-c02500788040	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:06:18.275611
19aa1040-9819-4343-935e-f45c3c0b2153	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:06:18.283364
019d0280-53ea-475b-8f81-f1f5b9bad7f8	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:06:24.860414
531d4b1c-b60e-48ff-86eb-45085e135beb	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:06:24.860262
52d5c91b-4de2-495f-88d6-71df2e0d9413	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:06:24.860519
31b53dd5-d2e3-4fd2-84b2-b4f199d1419c	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:06:24.87994
891c1723-a728-4dbc-8037-515ff573ee70	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:06:24.880092
4c460ea3-2174-40ce-b716-64954eb45b20	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-11 08:06:36.394347
9bf51eae-198b-41bc-a3ef-1e6014d1de2a	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:10:25.011524
383237fa-2f3e-42ad-88c0-0d45a4474ed8	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:10:25.032809
4d5980b2-702f-4a4a-9a29-e31f3fd8d7c7	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:10:25.047621
fc1a6217-8148-4c4b-80d3-397830ba5c5b	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:10:25.065976
77539b10-8ae3-4d72-acb0-bef898422056	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:10:25.065851
ecf77ec1-8034-48cf-8ce6-ff082995a787	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:16:35.909679
a1629118-6b3f-4421-9d91-0f4c3780f48d	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:16:35.932937
3780a125-db9b-4c68-abe1-1f15c59be5f9	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:16:35.946522
01d9b0d5-0054-4d89-96a0-10e57690ef80	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:16:35.958876
35cfc081-a5f5-4846-b4bc-a7d24c641067	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:16:35.964771
3127df6f-8b01-4236-a8db-a61a5e4d61b8	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-11 08:16:49.25223
c1d45b91-b1d9-483e-93f5-da8a3b8aa3c4	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-11 08:17:30.421174
6db81eec-bafd-409b-b812-78e30303230d	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-11 08:17:30.425802
4187d6e1-6e4d-4497-b70b-b7001cf0bd39	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-11 08:23:31.131006
942b5ed0-266a-4c15-8d1f-716eef04e74b	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:23:32.745903
21ecba59-bf84-4e81-ad7e-72aab880e49a	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:23:32.750027
6f66b33a-bec1-483b-8f45-8b6835050088	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:23:32.766494
5db66392-92d0-40de-af3c-ce7830f02b25	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:23:32.778891
1bc193e7-67ce-4770-9ca5-a489691c04c5	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:23:32.808166
6b02bb82-ac86-4202-997f-92d59dbc1517	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-11 08:23:33.722034
7892cded-51f5-48ee-a477-0514765ab0d2	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-11 08:23:33.722156
ecab44c8-b353-4d98-91ea-b2803e863f7c	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:23:34.614203
55d8a99b-88f7-411f-94c5-2fd0e1c5ddb3	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:23:34.614399
1f7490a0-5bfd-486d-a874-0256617cdd98	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:23:34.61403
2e887139-495f-45f7-b789-13a3718699b0	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:23:34.692433
5c8095b2-64c4-404d-8165-7b75ce8b99e2	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:23:34.71127
294f6d5b-6deb-4ec3-a271-dcfffaaa6150	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:23:35.324229
7e9047c9-ea85-4d2e-9d85-c221aae8a788	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:23:35.329903
d7dd0ea6-9027-4436-b029-661e71459800	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:23:35.330315
37c63949-bf26-46c5-b09d-dc3073e37746	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:23:35.330797
4b623999-19b5-4318-86ee-da9af4b2524f	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:23:35.330085
46fd4420-333a-4619-80a8-fe1afdb62f74	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:25:25.117865
c09f328f-cad8-4cd5-97e7-453f6c0540b2	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:25:25.146878
cccaa120-d7f1-4e02-aca6-16dcaf3bd8d6	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:25:25.166434
f49196a0-ac0c-4b2a-9eaa-8992e971347f	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:25:25.19215
35500bcb-7fc6-40b8-be03-695e3bf557f8	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:25:25.212908
be129f1d-7a94-4226-bb30-b1cf27496406	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-11 08:25:26.796235
4178242f-77ec-4468-857a-f34ccebee02c	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-11 08:25:26.796455
931777ff-e12c-492c-87d5-22e127e0df96	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:25:33.021339
ef5ce555-7a72-47d6-8d97-bec907cba2c2	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:25:33.021498
60f03334-0bd7-4167-8ffc-96f609b22b75	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:25:33.02171
93df80a9-ceb5-493f-842b-4902afacc045	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:25:33.03896
a01c91d7-74b9-4ef5-890c-10c42ca305d5	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:25:33.040439
ba05733d-e7e6-4d42-ae56-ce1a0e8d4694	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-11 08:25:35.019724
5f777063-d5d6-4c42-9613-fd9e83e01a87	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-11 08:25:35.776421
a90caa69-1563-4e14-ac51-87ee8eaa64d6	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-11 08:25:36.060213
d1a17f97-4dba-4b80-9de7-8b5bc5dac4fc	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-11 08:25:36.322694
c0d8e8b5-e231-41b7-ab82-ad74d6758cb5	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-11 08:25:36.601594
10445742-8553-440c-9287-3823767d4f73	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:26:57.501177
e5ff15c4-fb13-4584-a425-0348ae799666	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:26:57.525914
e2b36369-ab77-4e3b-80ae-7663273759d9	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:26:57.541381
ee216ac5-52c7-4487-91ff-f656e7d38542	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:26:57.556823
12a89d44-39f4-4f20-b54a-8ef55357c868	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:26:57.555003
6e1632b8-0c20-491e-bd53-80ce5bc511e0	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:26:58.229574
cae13221-3121-41b9-ad6d-e8ca11b407ac	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:26:58.229812
e640a9b2-1e89-43a3-aad3-880274da9dac	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:26:58.324942
9d734b98-3293-4282-bc87-1e98512516a4	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:26:58.333403
6af51928-be00-4659-b629-57f1d7ada39b	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:26:58.337084
855c18ef-6d6b-448a-bb8b-0d7cec9a1542	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:27:07.811201
49293f89-82a5-4816-b395-f3453fbdaae0	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:27:07.811858
18994336-a40d-499d-b4b6-764abd36ce86	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:27:07.828026
1348801d-7d07-4c27-9c30-b8cdea5ae7cf	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:27:07.827838
383c362a-c076-4d78-8973-f7e55b4e0342	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:27:07.843753
95d1ecbd-140d-443f-9da0-b4a290feef01	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:29:03.363876
5e7e0cd8-373a-48ac-b797-540865420867	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:29:03.39088
9bb9ef27-3945-4999-a05d-73d8a3560461	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:29:03.408791
6e650823-bd98-4cd4-bd1e-b7de7d1b77bd	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:29:03.424093
5d9480af-d9fe-4235-98b4-64b11b74b11c	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-11 08:29:03.429344
d22df1d4-e9c3-4bb1-b6ca-651cbd6ff164	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-11 08:29:10.585084
236493e0-0678-4531-b02b-fbabf8477d04	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-11 08:29:10.590398
d6d1d7d9-8ad2-4e8b-af88-df15b16c79d9	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-11 08:29:11.904643
e6333368-0576-46bc-ac1d-3a85ec18903a	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-11 08:29:11.904833
2f8a5482-e23a-40fb-bbb8-f728f8a34c9b	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:29:13.163451
61f4fa4f-fa44-4f8c-9fd8-c02e145e8852	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:29:13.163758
327215dc-7eab-4bfc-82a7-6104cbb055ae	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:29:13.16364
588e97b0-021c-42ef-aff8-a11e8e151db3	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:29:13.182254
9b363585-a8b7-45b2-b55a-461c87509308	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:29:13.182806
b6a7072b-7b48-48ec-82e7-7aa12a6df7cb	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-11 08:29:14.538555
a6c3653d-5ca3-4678-85ba-7483ada4029c	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-11 08:31:29.362804
b82dedbe-c8ec-41da-951d-90728a0f7a0f	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-11 08:31:29.367818
0a522231-9805-412f-9a2e-ddff795ee945	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:31:30.572069
c2fa5aae-48e4-4457-ae43-ef32d267ee33	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:31:30.57715
47aa3e7d-6136-4629-988d-f990054da0eb	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:31:30.576917
93a381a9-2fd0-4f8d-bf16-1546b94a936b	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:31:30.63013
2bbd5c5a-d038-4ab9-b87d-83628c1adaa8	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-11 08:31:30.635326
bf008ea5-64de-434b-a421-6967754a1b70	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-11 08:31:31.601418
7df3d913-68fc-49af-b1cd-d907a1c9bb6b	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:31:31.030675
6da171f9-7a8e-4081-89d5-5dc8b6940487	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:31:31.070419
eab2496b-4174-4dee-870d-483b1d1e7d82	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:31:31.081083
15123762-4fbe-44cb-9e74-9dbe45b8708c	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:31:31.089537
d2eb551c-ffd1-4fda-9d27-dbdc5ef840e9	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:31:31.08707
3c6ab7f4-add5-46b7-b636-69e1184201e3	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-17 07:31:37.325019
d3bed252-0f12-4ac0-a4e1-921f1cdb9472	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-17 07:31:37.325316
d55d47b5-5cc6-429c-a08b-03360bbb3f82	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-17 07:31:49.69535
695a5821-1470-4c46-837d-90fba13b47fd	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-17 07:31:49.702402
809b4f69-87ad-44de-a1c5-170a3fd5cc82	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-17 07:31:49.702175
de0f2589-7c66-4d49-8c52-6cff7582d42b	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-17 07:31:49.74676
3591ae7e-af4b-4479-891f-09ac05e7f91d	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-11-17 07:31:49.752496
2b662d4f-fe7e-4725-865f-74e05dd45f93	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-17 07:31:54.853646
122c1730-342f-4b58-88dd-2ef5336f5b4a	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-17 07:46:50.106498
b6b9e5ed-8b05-4d3b-9dad-964b6a55365a	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:46:51.230605
85f63866-dcbb-4799-ab86-e70b19bae374	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:46:51.231757
449503a2-5270-4012-9918-7b51234c360f	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:46:51.254754
3155d3c5-5a6c-4600-be62-7ae3c762a9fe	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:46:51.255934
928619e5-c695-4c6b-be10-f1618ba37775	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:46:51.321931
a826fef6-78c1-4bfb-94cb-d7ae40af569c	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:46:52.128923
65716b66-5fda-487a-94ae-14add91fa5a1	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:46:52.129536
fdc006d2-5d3a-44d6-af3d-f241b7338bfa	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:46:52.129862
d43ad6a5-a377-429b-ae53-c3815935f343	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:46:52.228225
40834905-c222-4f83-9444-5c3c8044572d	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:46:52.234852
fe0722c8-3cbe-4a24-9b1e-97e6d83b1846	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:48:47.953212
cb6ace07-9d1e-49e1-96c3-ebf3b11761cc	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:48:47.959049
c2c55705-7fb3-47b7-8d89-9fbc2e62ab73	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:48:47.980049
263404bf-7dd2-4b7d-b32e-6498ff089931	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:48:47.986395
8e59a1e6-5db4-47bc-8a11-06c5ae2eb52f	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:48:48.027687
e00b92ed-d4c2-4d96-bc8d-098fc3669182	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:48:48.402807
dffc733d-da84-4307-9e9e-ae6b94084420	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:48:48.4023
c472f64f-b520-483b-8b1c-3767db5274fa	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:48:48.40376
c7a75813-dc38-4140-a54d-2ebc402aa0c2	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:48:48.479359
7697b70a-79b2-4dae-80c7-ca2e27985e48	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:48:48.488478
429a9eec-7078-4bf9-b9e1-7261e1859f36	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:51:10.538575
b62ce4a2-f2c6-4311-ba6d-fab681b1f956	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:51:10.56785
5086dede-782e-434d-a6be-fcdc8b6f5827	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:51:10.582983
30bbaa4e-fb8b-4091-bd28-43bb699a00b1	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:51:10.590549
a432779e-ca3a-49d2-84dc-0a1ac8fc003b	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:51:10.59852
ab18b85c-02b8-418a-a129-12420ddf9b7e	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:51:11.220509
07d9c68f-c042-4ba2-9f0e-32b579b77ed3	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:51:11.221366
2d2b02a5-6906-4e03-a799-a3acfebf831a	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:51:11.297277
5621c291-75ba-4542-8b7e-694c6b5d08db	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:51:11.302611
72132d01-ae73-4f22-b354-4ffa21b9c969	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:51:11.31289
37bf27d2-9d18-4aec-b526-e56395dc8575	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:51:11.901509
6143dab4-1df1-4d13-a688-dee56a44c8b0	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:51:11.901687
17cf9d37-d161-41a9-a5fa-5d103ec258ec	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:51:11.901381
b09376f3-ab23-461b-8526-9b10c149b3ff	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:51:11.909572
84ef62f6-a358-4ed5-8cb6-7a61bf1f9401	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:51:11.909788
330b04f2-36b3-4241-9bf8-be4270370737	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:13.282595
20fe4512-0d27-4f8d-8224-b1524a7e4deb	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:13.304285
a1c58c1b-678c-4c43-8612-c250bd0fb21e	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:13.319338
84aa256e-d5c0-4f29-b2e6-ece72dfdca1b	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:13.334291
22e164f4-335e-4c94-9629-c1366d053f97	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:13.333509
7879d1d4-0e06-4dcc-bd4c-e9405c7cad87	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:14.154741
90de99dd-68bd-4e4f-b54a-6bce385e9fb2	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:14.153937
91ce024a-947f-44ce-b1e1-415f0551f675	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:14.182416
30a8c0a3-0709-41b4-baaf-3be84591b6a3	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:14.253483
0948aa8f-226f-42a4-b073-9bcc2ab51dea	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:14.264181
3af400f2-17e7-4866-97f1-1fed40324c3d	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:15.074769
4820d349-395a-4bc5-8d64-481ffa1b3f1d	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:15.084258
9409c593-4c90-44ec-90e9-11ef4eae7052	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:15.086027
50683625-ba7f-4f35-ae9d-bcae30fa2a4c	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:15.087128
4209a45e-ac7e-46b6-93c1-df2c906ca85f	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:15.083924
541ac8cc-0a6a-4977-b04d-50b2baa0f145	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:18.673923
bdd74fc9-05b6-4b99-b0cf-b105b23656ce	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:18.673734
9fded4c2-2136-4d73-96e0-e18a8741b270	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:18.674503
788aa500-ed15-4c44-b3aa-fe0a2258073f	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:18.674282
fbbcc726-6de3-482b-9177-52acf10fd822	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:18.66946
751ea279-48c3-4a56-9d0a-573e8d450015	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:45.132767
45a68e27-33b9-4151-8895-6a981c393612	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:45.14466
80b03e2e-05fa-4277-8ee3-6af9daaaad81	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:45.156249
c10210a2-2a7f-4a7f-a776-2399c032078b	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:45.171786
d489a90d-c881-4948-973a-0ba1b0be40cc	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:45.173361
1b47c77d-9eda-40d6-b5c3-e664d9b15f23	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:45.649679
55e546d2-46c8-49f3-92db-2ceae6552729	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:45.649283
040e937a-f23b-4f6a-a473-3335d8043e6e	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:45.723143
6ffdc1f5-835e-4ac0-89ba-acfc0640fcac	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:45.731731
1ea7865d-2bd8-40d8-b21b-6480ad95f913	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:52:45.844565
0d13556a-8b46-430f-8493-20057f76a4c9	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:55:22.468546
613e01f2-e3ca-47cb-9688-ac1d0711a311	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:55:22.494472
9b00aab9-d36e-4048-a6ca-0141274fbacc	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:55:22.509791
ef5f474e-1e69-4751-9990-63de8a1e3bd0	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:55:22.524687
b6cc2436-0ea7-4758-89d7-ead544eb60d2	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:55:22.522428
dd97bbb4-9a2b-4a29-97e1-abf5614393e5	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:55:23.621687
e4a87a04-5685-4688-8eef-94b7c54e3de2	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:55:23.621964
edbbd75e-7938-4959-9b52-5f48661353a4	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:55:23.705348
58fb6376-729a-4871-9c05-61d6861e9af9	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:55:23.709702
18ff6a98-21a9-4059-99a2-2e354ec445ab	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:55:23.714299
244675f2-17cd-48ad-810c-2d3886758672	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:55:24.503342
d53c9ba3-8c81-4057-8f81-eb19e374de4f	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:55:24.503808
67da1f4c-7b25-4a1c-aa24-30b51bc9747d	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:55:24.509284
e799b52d-f078-49b2-9ab9-b5fd8a13885d	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:55:24.511991
e7019e43-0f8f-430c-a2ac-a4cc5aea31fd	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:55:24.521417
395d7206-18d4-4425-885e-6935168405e3	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:56:52.107162
3c4c99a5-c8b7-4929-a4c0-3e96e2bd854c	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:56:52.143583
a342979f-1d28-4ce1-93fe-16f237edf249	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:56:52.179942
a1c99985-922d-4e85-b468-c5caf55551d9	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:56:52.175446
8bb50b34-308d-43f1-84ad-e75c9418191c	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:56:52.180886
5dad550a-574d-4253-94cc-b95dbe516442	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:56:52.44796
7299ddc2-3e26-4c51-89fe-4426c5660bd5	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:56:52.448118
75065718-8151-4b1f-86ee-0be2b41e00be	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:56:52.448242
2e2eb997-c807-491f-8be2-43cb59d713a2	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:56:52.465114
159d3174-50b4-4216-9755-09c64eefcd1d	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:56:52.466264
4c7c0b17-3358-462c-ac7b-a16db5f4b2e2	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:56:52.977292
a2799ee8-9f2b-4468-8a34-809208684381	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:56:52.977561
35b4453a-917b-40d9-8de1-69ef76ce383a	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:56:52.981767
6c34e78d-d27c-469a-ab9d-3b2696994645	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:56:53.052163
45811dce-cd6a-4a09-bfc1-bd81999120ef	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 07:56:53.05823
360de32f-fe6e-4b39-b5ae-c792fc7be97e	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:00:15.122826
605f88dc-f85a-419a-9243-e23fb364d210	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:00:15.147209
dde9aae4-e0c3-409a-b748-95318b02b864	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:00:15.160716
591b754d-5248-4ef8-9284-3ccd753c9af6	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:00:15.176213
4c8a56ff-97fc-4ffa-8986-f7014293d5da	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:00:15.173712
f9292124-cecb-4613-a7eb-21427886b325	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:00:16.200802
41e95529-e908-46f6-8868-e00f8362a041	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:00:16.20053
8868a03c-31dc-45fa-9a09-0872f4d24afe	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:00:16.289889
aa0e5c30-51a5-449b-8e1a-99e8c99f7578	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:00:16.294614
a9fd474d-f7ba-48ae-bb82-f52d2554b3e2	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:00:16.299954
423883fd-161c-4073-8eb3-33396d0be200	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:00:16.896288
ec174a27-d19e-4be7-bed0-0de3739b4364	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:00:16.896574
f59dbb42-a712-48d6-96d2-e376e2e41cd3	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:00:16.89745
663b9a01-1cf8-4d69-8aa0-c20d658f806c	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:00:16.900563
60df668c-8803-4d12-928a-e119e6d17266	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:00:16.909738
348936a9-ede4-4da9-8c3b-59b4bc3db774	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:01:20.387556
3df081cc-e6ab-4973-bbcd-4afe0de2381b	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:01:20.415456
987539e0-8fdd-4dbe-bb70-cf5e8f06a120	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:01:20.429945
dd4563c1-2c3d-4da6-9a96-a282523e6c1c	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:01:20.434494
3b24bb7d-69c3-4788-af2e-88da2ab59a03	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:01:20.448378
9c989d58-9db3-484c-8b33-c4ff25c9dd1a	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:29:11.416652
2f87f5bc-de54-40cf-aaa3-3739104cc343	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:29:11.454749
d14176f0-d563-421c-a7d9-8b6b9a92f8c6	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:29:11.47293
09d5e8e3-f5a9-4d42-b593-9d5c1a119c85	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:29:11.47063
e35fc24c-68a4-49a4-b561-c8443f2ef325	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:29:11.496587
ebfad87a-123f-4d46-bf2a-0a5ffb11f148	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:30:36.49876
084a6733-496b-4c1f-96d3-a1639cdffe1f	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:30:36.532229
99d2a08f-7bab-45ea-b118-e65834ded68a	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:30:36.54288
fb5d80ba-fefb-4e0c-8d0d-93277ba60aef	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:30:36.557981
539dd034-8a47-450f-a911-02e02861a30b	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:30:36.668717
b08f3b26-c4f6-4606-b0fb-3a7d06b8e23b	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:40:13.160919
a8c1c947-689e-4008-8453-e6d86573b320	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:40:13.192622
a2c16575-d02f-49a7-84e7-3be99b222dca	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:40:13.207531
a6d74e76-66fd-463b-8538-db29c49e782f	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:40:13.221188
68b53168-dc4e-4a84-ac21-49e3549ec1ef	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 08:40:13.328983
b44ec241-0840-4168-81a5-eaeaa5716c70	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 09:13:16.291093
c02c1dda-de59-4a51-9f7b-5743dd34c68f	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 09:13:16.325367
8ea0e4e8-8c51-4dbf-8b80-aa44d19401e2	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 09:13:16.337928
fefc8287-b409-4e51-a9ef-4057f902f9ce	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 09:13:16.34342
1349e45d-6ea9-4ad8-a1bc-e88010af49dc	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 09:13:16.35859
5ef5f91b-27ad-4f39-b2a6-01eae111126d	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 09:28:34.894765
9ff56d08-6319-48cc-8cac-d54e7aba9511	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 09:28:34.925071
5055426c-0254-42c3-ba5a-3227864bbb27	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 09:28:34.942859
c05002f1-1871-452e-9031-98067a1188a4	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 09:28:34.942976
0b287d3d-8ab6-4666-a2a2-eacdd0f151b7	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 09:28:34.977916
1541ea65-4a96-434b-b00a-96f6808dcb4e	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 09:49:34.608441
0fe2a874-0332-4d7c-a73f-3775866996b8	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 09:49:34.648537
a3bc11a0-bde6-447a-9517-5f332781cca1	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 09:49:34.672175
8096f289-33b9-472a-9f5f-a32d5b280eb2	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 09:49:34.67234
4a670949-279a-4f24-a384-428079dc5acc	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 09:49:34.723758
0699c8ce-6f2b-46e2-91a9-65213ea7a37b	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:14:49.821818
a33f9c6c-e515-49ca-b9d8-eaa869733030	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:14:49.830462
f393040c-6284-415c-b0c9-f04ee17a6b52	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:14:49.847465
1e9dc9cf-d830-4b34-9dc6-3802cfe12ba3	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:14:49.858653
b65e95fb-2b0f-4eb6-82cf-287868a1107e	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:14:49.868155
d73c69ec-636e-4bc9-8692-fede7e5ef9ea	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:14:51.588867
5d3ea7b7-a76d-47ed-8590-20f502a36ef9	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:14:51.589792
66f4d722-848c-4e31-bcec-bef1ed2177fa	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:14:51.667602
b378b5cf-20a7-4ea8-b8bd-6ab6bbd70e95	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:14:51.679082
fab81678-a126-4837-8dbc-c9454c8f447c	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:14:51.870388
75e472f6-35d0-4450-b075-9870046d024d	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:19:14.003255
45f43cac-6d34-44f4-98c7-6b35ee509198	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:19:14.012282
9a313e7c-be9f-4370-a6be-832574bb0743	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:19:14.033555
83993498-9e3f-4339-afa2-ee396258303d	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:19:14.047157
6845a313-8ca0-4133-b991-8d98e294071f	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:19:14.177093
426af926-5196-4a81-99e8-d655244697fe	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:21:52.241511
40045042-08ef-49da-8814-8921607954bc	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:21:52.275478
b216304c-2852-489a-8eba-016ad1c42a3e	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:21:52.291251
c95ad96a-c73b-472b-a57d-aa97e0b41f37	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:21:52.304034
b827ba00-38d8-432e-8e9e-2c2c67558da3	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-17 10:21:52.384156
a1392673-e43f-4d3c-8257-6de11884796e	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-18 07:59:54.647038
e4e6018f-da17-4d82-8515-77ff7b325615	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-19 07:09:41.531231
c4c4b2f6-2500-4580-9765-859f75ccd83f	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-19 07:28:54.210229
08d28c28-6cfa-4237-928d-f6c89b34b004	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-19 12:53:59.127704
1f99f75c-4a1a-45b7-9ba0-d200b8be3273	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-11-20 23:13:01.837848
96ed1bdd-90be-433b-9ce8-63e1a421eb35	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-20 23:13:09.803325
aeb0585d-382c-43f1-bf2a-224b54d5c6b8	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-20 23:13:09.809193
7bb7763d-1fb0-4b82-8ede-0e6985c28d3f	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-20 23:13:09.809794
d0ddf8e7-9348-41e0-9a25-5eeb4345deb1	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-20 23:13:09.831834
15b7b31e-96f0-4e59-8a88-9414f4d1d3c3	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-20 23:13:09.85345
19ce24a1-997e-4294-a8b0-bf325c40ee3b	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-20 23:13:48.256628
da781975-34a7-4098-9ddb-6b3bd86993ce	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-20 23:13:48.275975
f9c3b4d1-26e0-48a5-ba3f-35f87e18c071	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-20 23:13:48.290103
1591abfc-86db-4d5d-8cee-86b0c9998186	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-20 23:13:48.314577
8132e121-c9d0-4c33-8fd5-6526f967619a	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-20 23:13:48.405984
2d8ac2fc-655d-46e2-b62a-547768418804	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-24 07:26:43.039572
86380bd4-6399-4152-8f42-bd4b04ac4225	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-24 07:26:43.082466
5ad2de73-6ebe-4d1d-bdcd-4c998356c127	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-24 07:26:43.082251
1bf6311d-d12a-4f98-8c0e-9b989f678ac3	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-24 07:26:43.082634
fe1c7e31-d47d-48b6-8a19-0575c1defb4c	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-11-24 07:26:43.104561
51fc166f-fc14-467e-97d6-26bc31b41b0e	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-24 07:26:48.262312
f6afa529-5b59-4388-96da-bd7c507cd46b	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-11-24 07:26:48.264627
06f8b4cc-59e6-483d-a098-e1674d9536bb	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-01 07:40:19.743172
f14a6903-b9b1-4cba-bc3b-ef9f53968a68	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-02 08:26:28.677054
dbe82e2d-ccd2-4f17-90cf-4e13a61c5e71	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-02 08:26:28.681511
8aa083b4-fb4e-4044-ab3b-59c57995a3e8	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-02 08:26:28.681267
e5b053d3-5d94-46bc-89e6-df47b78f33d1	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-02 08:26:28.723014
c475646c-f9a6-4e14-b8b1-892b8799675b	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-02 08:26:28.723146
b89d3432-0ae7-4a0b-9a57-24eaf37cd8d8	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-02 08:26:40.997153
243f81d5-547d-4ad4-9c57-3451da4e356e	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-02 08:26:46.420225
94be576b-51cc-4847-a808-7a1d327d73c7	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-02 08:26:46.420912
0479cb6d-25b3-4976-9d05-fd5d5200fe0a	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-02 08:26:46.42111
35db6923-6a75-4309-a40c-6b88380adf09	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-02 08:26:46.50072
21f24061-c8ac-4261-80e2-c618dc324692	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-02 08:26:46.515607
1a4a8cdb-d3aa-422a-bab2-525e9450b881	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-02 08:26:52.280572
65868b54-95e5-4287-9778-61551a95ced4	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-02 08:26:52.281926
c1ef2104-9a28-4a5a-9aa8-6aa1e13e9500	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 08:59:26.829901
12479169-fa64-4142-8fab-be8cba73ee0a	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 08:59:26.83285
17484170-e205-4f11-bbec-2e8d447ab0b3	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 08:59:26.834207
ed683607-6e40-4277-96c3-974605920521	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 08:59:26.829718
73d50a1c-72de-44b3-8707-782ac0ca85fc	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 08:59:26.837114
3fd29985-f6c0-4e01-a462-f233b7d24ef2	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 08:59:26.845912
3b828329-8704-4352-82bf-f6110eea2c68	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 08:59:26.878071
82cec739-0d58-41ac-b950-b70f55feefc3	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 08:59:26.919981
d847d083-580e-4f9f-a9de-65b8cdd6b839	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 08:59:26.922647
1c309283-6adc-4104-b434-2999c53c4cea	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 08:59:26.923209
a422fe0b-9eb8-41c2-a9f6-a27b95873a62	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 08:59:26.923522
a852d24a-2ea3-420c-9204-d45a43638b31	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 08:59:26.923032
ed715759-31ee-4a80-a2ed-88ed313bd664	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 08:59:26.954949
5b61c709-6a0e-479f-9f36-ee87e997440b	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 09:55:59.961252
2db3b2c1-b30c-404f-a577-eb7e13546d29	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 09:55:59.968898
3cd206ad-05bf-40f4-bc6a-87d66bb3fb5d	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 09:56:00.003452
081fe253-9a71-4610-9977-bbd08bc268c8	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 09:56:00.011915
5d3988c5-6c24-4030-9945-8fe347a1c658	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 09:56:00.065047
b7fcda43-65f1-4294-9167-03bf2d08bb07	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 09:56:26.803804
439b8ea3-bca6-46df-bf13-c7e957852367	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 09:56:26.825125
fc386bb4-112d-4fa8-9f1d-d27d4c08d824	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 09:56:26.835843
0c383767-7e56-4497-a7b1-92b3c6be7086	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 09:56:26.844959
0d307ee3-7ed3-4388-946b-19005b2134f9	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 09:56:26.864028
76abc0fb-3b10-4da1-9216-28febfb0da1a	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 09:56:27.273658
d627b6c9-bacb-4170-99cc-92dbeacd6896	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 09:56:27.273985
18b5fe04-bc25-4f03-b601-bf08f6004bde	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 09:56:27.360088
feea31bd-7733-48ab-9b82-c29682108630	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 09:59:32.853666
68e03517-27e8-4e3c-b5c6-57ef8f5937e4	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 09:59:32.901183
57ca178a-008a-41ab-b277-a689b7a622ab	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 09:59:32.922505
0b15060a-2d24-42a4-a363-799ee9e7925c	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 09:59:32.956923
59676355-f7aa-4b18-a7b1-a2ebdefeb073	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 09:59:33.092811
f8d5e3aa-a238-45ee-96cc-493e12c20025	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 11:02:05.870894
f5711f02-be19-4f43-8345-b926a8cb1246	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 11:02:05.879478
e76d9199-fddc-48d5-be02-32c9652e5500	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 11:02:05.898014
ce5d0857-c7c4-48f1-9ec0-6f598874b8d1	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 11:02:05.91397
4f70002c-f055-4dec-b3d1-7788a04da36b	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 11:02:05.914083
c5cc17ae-09da-469c-8770-2661ae1d97e0	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 11:02:07.916844
bb2f5e84-c44c-4deb-a2ed-933b37541713	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 11:02:07.921182
6d5f3c45-ac23-4771-bc2e-c34a9318de78	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 11:02:09.836973
9645ffa7-85c5-41b1-985a-2503a96b1550	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 11:02:09.83675
729cf5fd-dde8-4120-980d-e83e5a68c3b7	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 11:02:13.456847
d5364c04-f6a1-46ed-b939-f556f56973c2	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 11:02:13.455654
469d6060-657b-4d0d-be6e-fa9036287af6	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 11:02:13.457172
1bbdfe82-765c-411f-97d4-0d5e7e614753	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 11:02:13.534527
54ba45b4-534c-4157-a1ab-2ddaac2b98a0	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 11:02:13.538569
c12e9ad3-3c96-4728-ab14-2af816f110e2	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 12:28:57.019139
09198893-690f-4d7e-a7b5-0beea0133143	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 12:28:57.024794
d937cdf7-285d-4935-afd0-80b889e4a2da	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 12:28:57.049112
2bad82c7-5479-4e81-9c2e-adc1a27fa51b	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 12:28:57.049235
543c44ba-7dc5-4142-8a53-e9c421265ff6	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 12:28:57.239104
53052b28-6de2-4534-9d42-fc63deb46f58	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 12:29:00.883739
783523c2-3070-4d01-83ce-89bde7e4be18	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 12:29:00.883886
1eadd94b-c83a-4855-bc29-d601afe2a8fd	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 12:29:02.520651
49fcda83-b88e-41e1-82b3-b90e8ce8c7e0	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 12:29:02.521098
0931fdee-024a-4ac8-9862-22d4f5e9d621	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 12:29:02.521556
df9f32c9-8e25-4aee-a06a-ada3101e5553	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 12:29:02.585903
fa64e2c0-be09-456e-a49f-8590217a35f3	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 12:29:02.595427
62395bc0-2b06-43eb-bb45-28e92b1db6a5	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 12:29:04.371916
a4874cd9-a8fb-4c43-b94b-0014bd1fcfd7	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 12:59:16.254319
1f6a88f5-3d16-4be5-832d-16f049cc155a	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 12:59:16.259881
06d98f0a-fee4-4277-afce-6ae576ef5070	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 12:59:19.315426
fd9d81db-4163-4af1-9e2a-28809d36cab5	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 12:59:19.319542
06f1cb95-1c4e-4826-98a8-e4177502d8d2	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 12:59:19.905827
6fb29567-dcf6-4375-81ba-1f7a33c9f285	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 12:59:19.905612
bbcc61c6-20d9-4b8f-8107-e0b499cb4cd1	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 12:59:38.633553
9621fd42-ddf6-4342-b103-02b1ffcc96ed	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 12:59:38.654715
c00980ca-5a22-41fd-b9bf-71f3dad23cd6	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:01:26.860299
41513f30-e32d-4585-aecb-f5fece6c45ae	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:01:26.881468
1584f199-a39e-40b6-9daa-9bbb0012e8ae	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:05:20.56707
8b1bfcd9-52ee-4463-9728-5895900e7f45	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:05:20.571777
fd3c728b-691b-41d0-900d-3bc8af5c5a90	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:05:33.773319
32457ab3-c082-41dc-9cf5-e95e3b16c6e4	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:05:33.800425
f9f40c22-83ef-4e3e-9b48-c2e133de7f69	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:05:33.81597
7c9a0b97-4f7f-469b-bae1-03f35c40cc46	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:05:33.836678
ee7ec35c-6866-4221-b72f-f266b13dfe51	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:05:33.859164
0f07d3d9-0f75-4746-9677-7c865bc41629	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:05:33.875872
5aa4d4fe-4bce-409e-a8ef-3139c561100a	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:05:47.081601
e4cfee22-5871-4a94-8cb6-5d9694d8a8c0	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:05:47.084802
ab2a961e-1a82-4a6b-bc03-f1753e5bf7d2	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:13:43.635388
fe3c5c09-0134-461e-93dc-68bc473ccd58	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:13:43.639331
8575d716-18b0-4671-aaef-35f186dbde24	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 13:13:58.976926
6962ccc5-32d1-4e29-a270-f7e098fbab5c	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 13:13:59.003387
6dbffba5-8b11-4956-9d9c-d95dbed2f752	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 13:14:54.523318
afe5a087-6e90-4293-b572-a7f3cb3fc07a	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 13:14:54.527047
2a8798ea-9e2e-49a1-9819-0914246378f5	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 13:39:50.5043
c9821628-bba5-4761-a525-5adb5eaab816	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 13:39:50.529607
e2f1d286-7e09-4a01-b625-70ed8a45052b	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 13:39:52.455198
d0a8b69e-6028-46cb-b8ba-941932c6dc5a	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 13:39:52.455099
4f72be70-66fa-49a7-89ab-daed6e3b089d	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 13:39:55.105605
01d7ac2e-2852-4fd9-9890-925d11c0e9d9	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 13:39:55.105783
8e413941-1ba8-4ef5-ab34-ea59fb040264	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:39:59.871232
605bd813-767d-4ba9-aa1e-d37877273c23	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:39:59.871416
ca309785-acf0-4f80-a4b1-0983f4261427	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:39:59.871692
375f0940-7a23-463c-aa5c-3857111cbf92	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:39:59.893497
0ee9daf2-0c07-44bc-a6c5-d146a9b8bcaa	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:39:59.893644
2fc5f9b9-0b41-4942-8ad3-d9e68c90e330	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:39:59.896554
3ddbd3b9-6505-4a68-a21c-e8417005ba57	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:39:59.943891
5e4984bd-62bc-4104-a263-984d64686fa1	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:40:08.288829
4110a3c7-5367-4bbe-a516-dee37eefdc29	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:40:08.289675
2dcdfdfa-fbbd-4fee-ad5f-94870063319d	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:40:08.308601
d5bdb25b-b2a5-47d7-9f08-7a62895c4dab	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:40:11.745313
4c901b59-6f2d-44f6-8737-206238c2a749	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:40:11.746041
01eb061d-482f-4f2c-be43-b6facc0a9811	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:40:11.746629
45b6cbd8-165c-4d78-842f-14f2cfb21d39	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:41:18.977802
f238108c-1ebc-47e3-9635-0bbb86ab8d1e	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:41:19.003234
c15e7570-3691-48ed-9569-1834337372a4	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:41:19.02154
281ed918-a8ff-4532-b772-487838cc6bcd	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:41:19.0405
c7abc7a7-749c-42ce-aec8-2e0d94650bb6	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:41:19.040193
3b7f57a1-aa6b-4a56-aa58-098f01a5e92e	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:41:19.054065
49929b76-4d96-4168-9fae-6b6d4ca2cf32	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:41:19.159937
95929a8e-dc8c-424b-bc7e-dea567ef7e6a	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:07.329774
4e943326-76ea-49fd-8469-354061749a5c	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:07.359293
7ec06882-960b-412c-8309-da3c6ef6dfd7	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:07.380743
1046f80b-7fff-4e37-980a-31484b4597f1	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:07.380668
ed7a30f1-817c-4c5f-af9b-6ada365e0ab0	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:07.400673
84a4580b-a67f-4779-aac7-75c54d7e3a04	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:07.411202
df0fa1bd-1508-44e3-9770-dadd9d537cbe	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:07.428648
45f8f8c2-e356-4621-bddd-3663a7bb5372	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 13:44:09.070814
26fc5bc9-d80a-4ad1-8e74-1a379d72ac43	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 13:44:09.074425
200fc92f-15dc-4cef-bd25-022becce4aef	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:44:12.386941
eb8a7739-b6e3-463f-bed7-8b1cc6c872b8	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:44:12.386835
637d69a4-c446-4c29-a8eb-4873e0f99d6b	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 13:44:12.386693
f1bfa4da-c8c5-4a50-ae05-0e8f0d96892c	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:22.380148
a95638c6-a614-43ba-ae25-b918f9f5a54f	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:22.380684
dccbbed7-7c1e-4628-bb1c-cb2b6ba5d17d	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:22.38247
9676690e-f95b-4053-9038-cd4793aa5fe8	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:22.404343
7ef51094-3e7b-40dd-99ab-8fa73604c0e2	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:22.407183
4b9f73cd-0101-4bd1-bb59-e2218e3d378c	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:22.417365
43c55d8a-46be-4a42-ae70-7d8094356411	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:22.429298
bcb3f1b4-13cf-4052-8a40-36c1ddc16eec	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:47.466676
d9dec729-d9a0-4947-b745-56487416428b	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:47.489151
525b6690-d4ff-4add-96f8-8f8d5f60d1a2	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:47.503945
9ad06300-2fe1-498c-b2fa-277a2cbbe51c	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:47.519394
b8ba01f3-3e39-415a-9f9d-9b3208813e08	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:47.518827
e71c2006-ffb9-4b67-a162-4bb27ef5b2be	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:47.534699
670adbe6-a952-401f-ab96-450f236b834b	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:44:47.541736
7b02feb6-851e-4500-84a6-7edbe8dd76ed	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 13:44:52.605333
95f61045-9fd7-44c0-8cf2-0960145677e7	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	ad4800fd-c13f-4d2a-8558-cae29f052ea0	Vu	2025-12-03 13:44:52.608686
9749f03f-d212-4cae-a618-67423357fb1b	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:45:29.308851
9f3828a6-afdf-4905-9494-f20467852610	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:45:29.333281
d2ed4f66-57ab-466d-9f08-960c4b958757	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:45:29.350861
f9e941c3-4d6f-494d-85f6-f10ca2bee812	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:45:29.370116
56966398-5638-4f22-b530-d436cec56f24	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:45:29.369776
96dca50b-43e5-4e45-8ca9-f3cc34dc1591	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:45:29.396793
a2a77c90-0036-4e80-9d25-0af0ddaea6ca	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:45:29.4034
d927cd55-93fb-44be-9e95-8e713efff4c4	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:46:55.190206
447ca967-44cd-4317-8b5a-f5d05dced6bf	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:46:55.21697
15f73228-38b4-424b-a674-2e6daa90e7d9	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:46:55.232512
be9afc24-d299-4bc0-9b32-9b17d9d7ce31	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:46:55.253315
15746d06-1737-4657-9e0f-60a4b9bb752f	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:46:55.276287
6a0d4f3d-470a-4720-af26-4c3f856cf01e	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:46:55.353928
01ec5ed0-f58d-4efe-83f8-6b676a78ae31	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:46:55.365217
e1399089-d97c-49c7-aae5-651982421e4a	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:47:51.353016
473e7aa9-23dd-4b5e-8ce6-04357b8fd9d0	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:47:51.386921
f7d46583-8135-4a11-b9c8-d65d6b38c819	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:47:51.405403
e1f8e423-f368-4939-a2eb-d8db8af22beb	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:47:51.417867
61bce655-44e9-47c5-b4a3-e2404e6c1e25	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:47:51.429109
f04716fc-0324-4e8d-adce-dbffac9a4380	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:47:51.438923
afe0c215-012b-4c55-a946-a5f0f5e8b5c4	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:47:51.438751
43e1d618-c45f-4fe7-a451-c1a32804288a	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:39.442158
174ab4d6-ce1e-4325-84ce-688c31899323	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:39.451946
debf2720-6677-4b50-b10b-91e75d6492b9	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:39.471042
c9a0985f-89d0-4fb4-8236-c9fc85993323	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:39.488734
d9b87f1a-2fdf-4630-812a-e4c421ce8a98	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:39.511419
ef7545bf-1226-42c7-b064-5ec3e800b768	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:39.48028
5b6f1458-2df4-4097-9cee-2af9a0449b37	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:39.501653
c2e6d438-1565-4c94-b9d4-6883c7ef1edb	eba2ca88-d053-41ea-93f6-37ab1b44309c	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:56.802404
54f8d00c-4eca-48d3-b3be-69e325c3b598	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:56.83291
61e57529-a581-42f9-917c-1105f65fa7ed	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:56.849468
43ee5372-6e5d-40f8-9077-eb7d2699f46a	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:56.870355
d27b4e91-82b6-4a0b-bacb-6f3417ede1f3	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:56.870203
9eca773f-a457-4d09-a774-1637f6c7e2a2	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:56.879933
895212e6-580d-439e-8c1e-115ec4c6f1d9	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:56.89401
e0aa1727-10fb-48c2-8d8e-587aca57483b	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:56.905592
f5ff34e9-37be-4ccf-b78d-7c30e95db972	eba2ca88-d053-41ea-93f6-37ab1b44309c	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:59.126115
17ac734e-6567-4b7b-96c4-1414268594fc	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:59.12664
a9588250-e012-4dc6-b787-7b4f14b2a815	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:59.126499
ca0afb9f-2bfe-4938-8671-c924a318a76e	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:59.127265
27031d57-f1f9-4d92-a771-afe59744d2fd	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:59.159329
315b333c-a9e0-4475-b928-1c1985437644	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:59.159141
03f8bd16-5638-4a38-ae8f-4fa47b9ea42b	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:59.211818
3d83915a-d69d-4df7-8fd4-3a1acb493155	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:50:59.218725
844a0813-d3ee-4a48-8173-23e6c83e16b7	eba2ca88-d053-41ea-93f6-37ab1b44309c	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:51:06.111206
b0353fd4-6b2c-44e4-91b8-8fb44082c8f1	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:51:06.111042
8a9c55e0-c884-480c-9893-3775fe9fdf44	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:51:06.134523
a8e6b46f-d6e8-4418-bacb-046d81fb7862	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:51:06.135821
c2ea2683-6173-4dda-b613-8a93d8ac9b7b	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:51:06.15184
8e5fbab1-7f36-4bcb-93b0-11a78851f55e	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:51:06.153196
c1293867-535b-4e3a-8948-83cb3af688ed	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:51:06.173893
be979d9b-d04f-4e4d-a759-32f2aed8da24	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:51:06.178998
b5a17104-41f9-4a5a-a2cd-00ad35d8d521	eba2ca88-d053-41ea-93f6-37ab1b44309c	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:54:50.841287
de0206b3-4238-4587-95fb-1bbcceac1bd0	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:54:50.853102
3ac32a41-f049-48f8-8983-a3e1c372ac96	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:54:50.875337
b70b4e3d-6055-4b45-a920-2846dca2447f	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:54:50.881815
d6a668e6-6fe8-45ec-829a-26885da4078c	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:54:50.893695
7a0e4db8-2f6e-4ce4-bce3-8c77ec18cefb	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:54:50.90279
a6408925-6963-47af-8c01-2004d7c3561c	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:54:50.913365
1aacb97c-0bcc-4363-81aa-66e8eca8cd66	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 13:54:50.920816
6258e645-300d-4c35-b87a-7e650b2fe7f0	eba2ca88-d053-41ea-93f6-37ab1b44309c	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 14:08:01.33706
bfdbff61-e4e6-4b16-9740-1a373e8ee8bd	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 14:08:01.335333
2e9391e0-45ef-4fe6-b3c7-da570590a3dd	a63da118-2cdc-44d7-ad88-c87e304a6706	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 14:08:01.356982
6bdc3bfe-85ed-484e-a63c-1623fed101d7	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	e80eca21-e374-453c-8a52-51667058f8a3	Vu	2025-12-03 14:08:01.357953
3e0fa640-bafd-4cf1-9b79-1fbc478c7be2	eba2ca88-d053-41ea-93f6-37ab1b44309c	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 14:08:03.031961
597db7b5-6bb1-4a8e-b8ff-61f1255f3146	c884d8fd-bf28-4e58-adc1-46c942cb07dd	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 14:08:03.032166
ee283b0e-41cf-4171-92c3-357360d9cfe2	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 14:08:03.049327
fedda94f-c36d-44ef-aa6a-2e3afa5b43a7	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 14:08:03.05871
da15ee42-8291-42be-9157-375394b0f073	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 14:08:03.07004
5547e047-cc92-4276-994b-04eb8baab6cf	9f10dccc-280a-44ce-b2a4-2be5e51b28cc	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 14:08:03.134758
a2b858a3-2a83-4329-9f4b-d4463b08155f	fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 14:08:03.14918
5776ba64-9709-4095-adf5-f620367acd07	1c42946d-594f-4b90-a350-e00c08244d80	VIEWED	5a1ab543-b2e1-445e-942d-d6ec24a576e5	Vu	2025-12-03 14:08:03.155693
c2aca6bd-d374-4df5-9e63-29d3edb3bdcf	88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 14:48:42.24786
8b8d48da-7a73-4451-ac6f-dcd6831a5a9b	c008bc44-7ac7-4388-b600-91d993a416e4	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 14:48:42.267936
3a6fa137-1e9f-4645-a781-b427937a3b44	3cb1231f-25df-45d0-8e6e-fa36321401ce	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 14:48:42.288773
963b4662-1e0d-4d5d-be28-341222fa78d2	092f6964-dc38-4b37-81d4-edb1f0d00c82	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 14:48:42.3067
c1c8ecdc-f948-4519-98c7-39a1d914b81d	c3077fb6-6765-4c91-a5a8-192187a76b0a	VIEWED	70c000ea-a3b2-400b-bb35-d419066b6183	Vu	2025-12-03 14:48:42.321719
\.


--
-- TOC entry 3655 (class 0 OID 17829)
-- Dependencies: 242
-- Data for Name: signalisations_views; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.signalisations_views (signalisation_id, viewer_id, viewed_at) FROM stdin;
c3077fb6-6765-4c91-a5a8-192187a76b0a	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-11-05 10:03:10.040615
fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-11-05 10:16:45.170276
1c42946d-594f-4b90-a350-e00c08244d80	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-11-05 10:16:45.176427
88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-11-05 10:16:45.27486
3cb1231f-25df-45d0-8e6e-fa36321401ce	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-11-05 10:16:45.399539
092f6964-dc38-4b37-81d4-edb1f0d00c82	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-11-05 10:16:45.40011
88042a9d-9e90-4fe3-9bb2-d05d67ef8b9c	70c000ea-a3b2-400b-bb35-d419066b6183	2025-11-05 10:16:56.373556
3cb1231f-25df-45d0-8e6e-fa36321401ce	70c000ea-a3b2-400b-bb35-d419066b6183	2025-11-05 10:16:56.400247
092f6964-dc38-4b37-81d4-edb1f0d00c82	70c000ea-a3b2-400b-bb35-d419066b6183	2025-11-05 10:16:56.415559
c3077fb6-6765-4c91-a5a8-192187a76b0a	70c000ea-a3b2-400b-bb35-d419066b6183	2025-11-05 10:16:56.436816
c008bc44-7ac7-4388-b600-91d993a416e4	70c000ea-a3b2-400b-bb35-d419066b6183	2025-11-05 10:16:56.442535
fd8d2c28-cdcc-4af4-a733-a45a458f2c2a	ad4800fd-c13f-4d2a-8558-cae29f052ea0	2025-11-05 10:17:14.936303
c008bc44-7ac7-4388-b600-91d993a416e4	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-11-05 10:18:38.987533
a63da118-2cdc-44d7-ad88-c87e304a6706	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-11-10 11:03:30.613263
1c42946d-594f-4b90-a350-e00c08244d80	e80eca21-e374-453c-8a52-51667058f8a3	2025-11-10 11:07:35.364408
a63da118-2cdc-44d7-ad88-c87e304a6706	e80eca21-e374-453c-8a52-51667058f8a3	2025-11-10 11:07:35.368592
9f10dccc-280a-44ce-b2a4-2be5e51b28cc	ad4800fd-c13f-4d2a-8558-cae29f052ea0	2025-12-03 12:59:38.62603
9f10dccc-280a-44ce-b2a4-2be5e51b28cc	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-12-03 13:05:33.771635
c884d8fd-bf28-4e58-adc1-46c942cb07dd	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-12-03 13:39:59.941201
c884d8fd-bf28-4e58-adc1-46c942cb07dd	e80eca21-e374-453c-8a52-51667058f8a3	2025-12-03 13:40:08.28834
eba2ca88-d053-41ea-93f6-37ab1b44309c	5a1ab543-b2e1-445e-942d-d6ec24a576e5	2025-12-03 13:50:56.800556
eba2ca88-d053-41ea-93f6-37ab1b44309c	e80eca21-e374-453c-8a52-51667058f8a3	2025-12-03 14:08:01.334901
\.


--
-- TOC entry 3665 (class 0 OID 26143)
-- Dependencies: 253
-- Data for Name: suggestion_attachments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.suggestion_attachments (id, suggestion_id, file_path, file_name, uploaded_by, created_at) FROM stdin;
\.


--
-- TOC entry 3667 (class 0 OID 26184)
-- Dependencies: 255
-- Data for Name: suggestion_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.suggestion_history (id, suggestion_id, changed_by, old_status, new_status, comment, created_at) FROM stdin;
33e97a7c-7c3c-4288-9b06-8b3afad26d63	08e52cfe-3503-4faf-8f56-75cb13e4b345	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	under_review	تم إنشاء الاقتراح	2025-12-01 09:06:33.677679
eb6c580e-272b-4430-8306-3006f8b252d8	08e52cfe-3503-4faf-8f56-75cb13e4b345	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	under_review	accepted	ok	2025-12-01 09:07:25.209337
12aa4cdd-71f0-4921-8407-073aef04a7dd	062d54ae-5c0c-4b88-b17b-9c6957aa366f	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	under_review	تم إنشاء الاقتراح	2025-12-01 09:08:04.968341
cfa3e9ee-ea5d-42f6-8386-0fbc4ab55f54	062d54ae-5c0c-4b88-b17b-9c6957aa366f	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	under_review	rejected	\N	2025-12-01 09:11:43.585976
f3d70c6a-2d33-4448-b67d-06a94f662a74	a5ce7749-8360-43b5-b1d8-62e3ce544283	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	under_review	تم إنشاء الاقتراح	2025-12-03 07:27:55.265729
\.


--
-- TOC entry 3666 (class 0 OID 26163)
-- Dependencies: 254
-- Data for Name: suggestion_messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.suggestion_messages (id, suggestion_id, sender_id, sender_role, body, created_at) FROM stdin;
\.


--
-- TOC entry 3668 (class 0 OID 26204)
-- Dependencies: 256
-- Data for Name: suggestion_notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.suggestion_notifications (id, suggestion_id, recipient_id, recipient_user_id, message, title, is_read, created_at) FROM stdin;
0a3c25a4-7d82-42d8-99f5-14c83799004b	08e52cfe-3503-4faf-8f56-75cb13e4b345	\N	35ab1996-5661-468b-8368-f4ebf68d01cb	تم تسجيل اقتراح جديد: ty	ty	f	2025-12-01 09:06:33.690557
d8aea7c2-2f41-4423-ad95-6ceef16c0041	08e52cfe-3503-4faf-8f56-75cb13e4b345	\N	8674a215-f103-4559-8f96-c55514a50e40	تم تسجيل اقتراح جديد: ty	ty	f	2025-12-01 09:06:33.703002
ae507aaf-7586-427b-b6b3-6b5e0d839378	08e52cfe-3503-4faf-8f56-75cb13e4b345	\N	f2de5462-7c21-4e9c-b070-283c28429007	تم تسجيل اقتراح جديد: ty	ty	f	2025-12-01 09:06:33.704449
64562723-5617-4d4e-9392-513785ef8e1b	08e52cfe-3503-4faf-8f56-75cb13e4b345	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	تم إرسال اقتراحك: ty	ty	f	2025-12-01 09:06:33.705772
fd83f694-2ac6-4929-88ac-fb8945bdf4f6	08e52cfe-3503-4faf-8f56-75cb13e4b345	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	تم تحديث حالة اقتراحك: مقبول	تحديث الاقتراح	f	2025-12-01 09:07:25.211456
2f441149-a9df-48bc-b385-c77cd0559731	062d54ae-5c0c-4b88-b17b-9c6957aa366f	\N	35ab1996-5661-468b-8368-f4ebf68d01cb	تم تسجيل اقتراح جديد: g	g	f	2025-12-01 09:08:04.976165
1d885a23-f3a5-4080-9a0b-41161c99c507	062d54ae-5c0c-4b88-b17b-9c6957aa366f	\N	8674a215-f103-4559-8f96-c55514a50e40	تم تسجيل اقتراح جديد: g	g	f	2025-12-01 09:08:04.98263
ed0d84f9-4346-4940-8046-a1c866a876c1	062d54ae-5c0c-4b88-b17b-9c6957aa366f	\N	f2de5462-7c21-4e9c-b070-283c28429007	تم تسجيل اقتراح جديد: g	g	f	2025-12-01 09:08:04.984013
f3d62838-05fb-44bb-bf73-4794b576608b	062d54ae-5c0c-4b88-b17b-9c6957aa366f	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	تم إرسال اقتراحك: g	g	f	2025-12-01 09:08:04.985335
975803a9-c558-412c-90b0-28d40b829f3d	062d54ae-5c0c-4b88-b17b-9c6957aa366f	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	تم تحديث حالة اقتراحك: مرفوض	تحديث الاقتراح	f	2025-12-01 09:11:43.597102
e78c6987-d90b-4662-93c5-8c865a5aa3c7	a5ce7749-8360-43b5-b1d8-62e3ce544283	\N	35ab1996-5661-468b-8368-f4ebf68d01cb	تم تسجيل اقتراح جديد: tt	tt	f	2025-12-03 07:27:55.28298
65f0f5e2-06d9-4aae-ad13-104c4f5ff1ea	a5ce7749-8360-43b5-b1d8-62e3ce544283	\N	8674a215-f103-4559-8f96-c55514a50e40	تم تسجيل اقتراح جديد: tt	tt	f	2025-12-03 07:27:55.301427
47a28f82-ea8a-49b7-9b60-ab2dcf638448	a5ce7749-8360-43b5-b1d8-62e3ce544283	\N	f2de5462-7c21-4e9c-b070-283c28429007	تم تسجيل اقتراح جديد: tt	tt	f	2025-12-03 07:27:55.302899
6e34ca16-470f-4a58-87a3-32fc15f75843	a5ce7749-8360-43b5-b1d8-62e3ce544283	ad4800fd-c13f-4d2a-8558-cae29f052ea0	\N	تم إرسال اقتراحك: tt	tt	f	2025-12-03 07:27:55.304223
\.


--
-- TOC entry 3663 (class 0 OID 26093)
-- Dependencies: 251
-- Data for Name: suggestion_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.suggestion_types (id, code, name, created_at) FROM stdin;
d1de2bea-e74a-4cd9-abd4-17698b97e426	IMPROVEMENT	تحسينات	2025-11-30 22:30:26.907996
9fb32ff3-9093-4478-8a4f-4c4d89a7010a	PROCESS	عمليات	2025-11-30 22:30:26.907996
b95499e3-ae46-41a6-b8e6-5809b5f52803	TRAINING	تدريب	2025-11-30 22:30:26.907996
489c6df2-3cf8-4f11-b458-e906f8241c12	TECHNOLOGY	تقنية	2025-11-30 22:30:26.907996
7f6426b2-8360-4ed7-805b-6ffb19c1e71c	COMMUNICATION	تواصل	2025-11-30 22:30:26.907996
47cd6416-66f8-4492-9bba-4a3af5018a42	FACILITIES	مرافق	2025-11-30 22:30:26.907996
b9a4e856-8dd1-4de6-a747-b059097e465e	POLICY	سياسات	2025-11-30 22:30:26.907996
22a68c4f-5e56-4794-b081-d4c3ecc5b380	GENERAL	عامة	2025-11-30 22:30:26.907996
\.


--
-- TOC entry 3664 (class 0 OID 26104)
-- Dependencies: 252
-- Data for Name: suggestions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.suggestions (id, employee_id, type_id, title, description, category, department_id, status, director_comment, handled_by, redirected_to, created_at, reviewed_at, decision_at) FROM stdin;
08e52cfe-3503-4faf-8f56-75cb13e4b345	ad4800fd-c13f-4d2a-8558-cae29f052ea0	d1de2bea-e74a-4cd9-abd4-17698b97e426	ty	t	tt	fd201bb6-67ee-43ff-b3ba-77abe18e864c	accepted	ok	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	\N	2025-12-01 09:06:33.66624	2025-12-01 09:07:25.207032	2025-12-01 09:07:25.207032
062d54ae-5c0c-4b88-b17b-9c6957aa366f	ad4800fd-c13f-4d2a-8558-cae29f052ea0	9fb32ff3-9093-4478-8a4f-4c4d89a7010a	g	g	g	fd201bb6-67ee-43ff-b3ba-77abe18e864c	rejected	\N	8335ce70-8d9f-47f7-b2a3-c8fd18cd0ecf	\N	2025-12-01 09:08:04.95826	2025-12-01 09:11:43.574261	2025-12-01 09:11:43.574261
a5ce7749-8360-43b5-b1d8-62e3ce544283	ad4800fd-c13f-4d2a-8558-cae29f052ea0	489c6df2-3cf8-4f11-b458-e906f8241c12	tt	t	t	e5d42083-11c3-40c7-906c-cfe0a5cd0f71	under_review	\N	\N	\N	2025-12-03 07:27:55.261399	\N	\N
\.


--
-- TOC entry 3443 (class 2606 OID 26070)
-- Name: complaint_attachments complaint_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_attachments
    ADD CONSTRAINT complaint_attachments_pkey PRIMARY KEY (id);


--
-- TOC entry 3436 (class 2606 OID 26029)
-- Name: complaint_history complaint_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_history
    ADD CONSTRAINT complaint_history_pkey PRIMARY KEY (id);


--
-- TOC entry 3433 (class 2606 OID 26009)
-- Name: complaint_messages complaint_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_messages
    ADD CONSTRAINT complaint_messages_pkey PRIMARY KEY (id);


--
-- TOC entry 3439 (class 2606 OID 26050)
-- Name: complaint_notifications complaint_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_notifications
    ADD CONSTRAINT complaint_notifications_pkey PRIMARY KEY (id);


--
-- TOC entry 3425 (class 2606 OID 25968)
-- Name: complaint_types complaint_types_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_types
    ADD CONSTRAINT complaint_types_code_key UNIQUE (code);


--
-- TOC entry 3427 (class 2606 OID 25966)
-- Name: complaint_types complaint_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_types
    ADD CONSTRAINT complaint_types_pkey PRIMARY KEY (id);


--
-- TOC entry 3429 (class 2606 OID 25982)
-- Name: complaints complaints_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaints
    ADD CONSTRAINT complaints_pkey PRIMARY KEY (id);


--
-- TOC entry 3412 (class 2606 OID 17783)
-- Name: signal_type_responsibles signal_type_responsibles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signal_type_responsibles
    ADD CONSTRAINT signal_type_responsibles_pkey PRIMARY KEY (type_id, employee_id);


--
-- TOC entry 3407 (class 2606 OID 17777)
-- Name: signal_types signal_types_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signal_types
    ADD CONSTRAINT signal_types_code_key UNIQUE (code);


--
-- TOC entry 3409 (class 2606 OID 17775)
-- Name: signal_types signal_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signal_types
    ADD CONSTRAINT signal_types_pkey PRIMARY KEY (id);


--
-- TOC entry 3418 (class 2606 OID 17810)
-- Name: signalisations signalisations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signalisations
    ADD CONSTRAINT signalisations_pkey PRIMARY KEY (id);


--
-- TOC entry 3423 (class 2606 OID 17854)
-- Name: signalisations_status_history signalisations_status_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signalisations_status_history
    ADD CONSTRAINT signalisations_status_history_pkey PRIMARY KEY (id);


--
-- TOC entry 3421 (class 2606 OID 17834)
-- Name: signalisations_views signalisations_views_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signalisations_views
    ADD CONSTRAINT signalisations_views_pkey PRIMARY KEY (signalisation_id, viewer_id);


--
-- TOC entry 3456 (class 2606 OID 26151)
-- Name: suggestion_attachments suggestion_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestion_attachments
    ADD CONSTRAINT suggestion_attachments_pkey PRIMARY KEY (id);


--
-- TOC entry 3462 (class 2606 OID 26192)
-- Name: suggestion_history suggestion_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestion_history
    ADD CONSTRAINT suggestion_history_pkey PRIMARY KEY (id);


--
-- TOC entry 3459 (class 2606 OID 26172)
-- Name: suggestion_messages suggestion_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestion_messages
    ADD CONSTRAINT suggestion_messages_pkey PRIMARY KEY (id);


--
-- TOC entry 3466 (class 2606 OID 26213)
-- Name: suggestion_notifications suggestion_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestion_notifications
    ADD CONSTRAINT suggestion_notifications_pkey PRIMARY KEY (id);


--
-- TOC entry 3446 (class 2606 OID 26103)
-- Name: suggestion_types suggestion_types_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestion_types
    ADD CONSTRAINT suggestion_types_code_key UNIQUE (code);


--
-- TOC entry 3448 (class 2606 OID 26101)
-- Name: suggestion_types suggestion_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestion_types
    ADD CONSTRAINT suggestion_types_pkey PRIMARY KEY (id);


--
-- TOC entry 3453 (class 2606 OID 26114)
-- Name: suggestions suggestions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestions
    ADD CONSTRAINT suggestions_pkey PRIMARY KEY (id);


--
-- TOC entry 3444 (class 1259 OID 26081)
-- Name: idx_complaint_attachments_complaint; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_complaint_attachments_complaint ON public.complaint_attachments USING btree (complaint_id, created_at DESC);


--
-- TOC entry 3437 (class 1259 OID 26040)
-- Name: idx_complaint_history_complaint; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_complaint_history_complaint ON public.complaint_history USING btree (complaint_id, created_at DESC);


--
-- TOC entry 3434 (class 1259 OID 26020)
-- Name: idx_complaint_messages_complaint; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_complaint_messages_complaint ON public.complaint_messages USING btree (complaint_id, created_at);


--
-- TOC entry 3440 (class 1259 OID 26061)
-- Name: idx_complaint_notifications_recipient; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_complaint_notifications_recipient ON public.complaint_notifications USING btree (recipient_id, is_read, created_at DESC);


--
-- TOC entry 3441 (class 1259 OID 26087)
-- Name: idx_complaint_notifications_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_complaint_notifications_user ON public.complaint_notifications USING btree (recipient_user_id, is_read, created_at DESC);


--
-- TOC entry 3430 (class 1259 OID 25998)
-- Name: idx_complaints_employee; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_complaints_employee ON public.complaints USING btree (employee_id, created_at DESC);


--
-- TOC entry 3431 (class 1259 OID 25999)
-- Name: idx_complaints_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_complaints_status ON public.complaints USING btree (status, created_at DESC);


--
-- TOC entry 3410 (class 1259 OID 17799)
-- Name: idx_signal_type_responsibles_employee; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_signal_type_responsibles_employee ON public.signal_type_responsibles USING btree (employee_id);


--
-- TOC entry 3413 (class 1259 OID 17827)
-- Name: idx_signalisations_created_by; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_signalisations_created_by ON public.signalisations USING btree (created_by, created_at DESC);


--
-- TOC entry 3414 (class 1259 OID 25957)
-- Name: idx_signalisations_localisation_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_signalisations_localisation_id ON public.signalisations USING btree (localisation_id);


--
-- TOC entry 3415 (class 1259 OID 17828)
-- Name: idx_signalisations_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_signalisations_status ON public.signalisations USING btree (is_treated, created_at DESC);


--
-- TOC entry 3416 (class 1259 OID 17826)
-- Name: idx_signalisations_type_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_signalisations_type_created ON public.signalisations USING btree (type_id, created_at DESC);


--
-- TOC entry 3419 (class 1259 OID 17845)
-- Name: idx_signalisations_views_viewer; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_signalisations_views_viewer ON public.signalisations_views USING btree (viewer_id);


--
-- TOC entry 3454 (class 1259 OID 26162)
-- Name: idx_suggestion_attachments_suggestion; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_suggestion_attachments_suggestion ON public.suggestion_attachments USING btree (suggestion_id, created_at DESC);


--
-- TOC entry 3460 (class 1259 OID 26203)
-- Name: idx_suggestion_history_suggestion; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_suggestion_history_suggestion ON public.suggestion_history USING btree (suggestion_id, created_at DESC);


--
-- TOC entry 3457 (class 1259 OID 26183)
-- Name: idx_suggestion_messages_suggestion; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_suggestion_messages_suggestion ON public.suggestion_messages USING btree (suggestion_id, created_at);


--
-- TOC entry 3463 (class 1259 OID 26229)
-- Name: idx_suggestion_notifications_recipient; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_suggestion_notifications_recipient ON public.suggestion_notifications USING btree (recipient_id, is_read, created_at DESC);


--
-- TOC entry 3464 (class 1259 OID 26230)
-- Name: idx_suggestion_notifications_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_suggestion_notifications_user ON public.suggestion_notifications USING btree (recipient_user_id, is_read, created_at DESC);


--
-- TOC entry 3449 (class 1259 OID 26142)
-- Name: idx_suggestions_department; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_suggestions_department ON public.suggestions USING btree (department_id);


--
-- TOC entry 3450 (class 1259 OID 26140)
-- Name: idx_suggestions_employee; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_suggestions_employee ON public.suggestions USING btree (employee_id, created_at DESC);


--
-- TOC entry 3451 (class 1259 OID 26141)
-- Name: idx_suggestions_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_suggestions_status ON public.suggestions USING btree (status, created_at DESC);


--
-- TOC entry 3489 (class 2606 OID 26071)
-- Name: complaint_attachments complaint_attachments_complaint_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_attachments
    ADD CONSTRAINT complaint_attachments_complaint_id_fkey FOREIGN KEY (complaint_id) REFERENCES public.complaints(id) ON DELETE CASCADE;


--
-- TOC entry 3490 (class 2606 OID 26076)
-- Name: complaint_attachments complaint_attachments_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_attachments
    ADD CONSTRAINT complaint_attachments_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.employees(id);


--
-- TOC entry 3484 (class 2606 OID 26035)
-- Name: complaint_history complaint_history_changed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_history
    ADD CONSTRAINT complaint_history_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES public.employees(id);


--
-- TOC entry 3485 (class 2606 OID 26030)
-- Name: complaint_history complaint_history_complaint_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_history
    ADD CONSTRAINT complaint_history_complaint_id_fkey FOREIGN KEY (complaint_id) REFERENCES public.complaints(id) ON DELETE CASCADE;


--
-- TOC entry 3482 (class 2606 OID 26010)
-- Name: complaint_messages complaint_messages_complaint_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_messages
    ADD CONSTRAINT complaint_messages_complaint_id_fkey FOREIGN KEY (complaint_id) REFERENCES public.complaints(id) ON DELETE CASCADE;


--
-- TOC entry 3483 (class 2606 OID 26015)
-- Name: complaint_messages complaint_messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_messages
    ADD CONSTRAINT complaint_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- TOC entry 3486 (class 2606 OID 26051)
-- Name: complaint_notifications complaint_notifications_complaint_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_notifications
    ADD CONSTRAINT complaint_notifications_complaint_id_fkey FOREIGN KEY (complaint_id) REFERENCES public.complaints(id) ON DELETE CASCADE;


--
-- TOC entry 3487 (class 2606 OID 26056)
-- Name: complaint_notifications complaint_notifications_recipient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_notifications
    ADD CONSTRAINT complaint_notifications_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES public.employees(id);


--
-- TOC entry 3488 (class 2606 OID 26082)
-- Name: complaint_notifications complaint_notifications_recipient_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_notifications
    ADD CONSTRAINT complaint_notifications_recipient_user_id_fkey FOREIGN KEY (recipient_user_id) REFERENCES public.users(id);


--
-- TOC entry 3478 (class 2606 OID 26088)
-- Name: complaints complaints_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaints
    ADD CONSTRAINT complaints_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- TOC entry 3479 (class 2606 OID 25983)
-- Name: complaints complaints_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaints
    ADD CONSTRAINT complaints_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- TOC entry 3480 (class 2606 OID 25993)
-- Name: complaints complaints_handled_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaints
    ADD CONSTRAINT complaints_handled_by_fkey FOREIGN KEY (handled_by) REFERENCES public.employees(id);


--
-- TOC entry 3481 (class 2606 OID 25988)
-- Name: complaints complaints_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaints
    ADD CONSTRAINT complaints_type_id_fkey FOREIGN KEY (type_id) REFERENCES public.complaint_types(id) ON DELETE RESTRICT;


--
-- TOC entry 3467 (class 2606 OID 17794)
-- Name: signal_type_responsibles signal_type_responsibles_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signal_type_responsibles
    ADD CONSTRAINT signal_type_responsibles_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.employees(id) ON DELETE SET NULL;


--
-- TOC entry 3468 (class 2606 OID 17789)
-- Name: signal_type_responsibles signal_type_responsibles_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signal_type_responsibles
    ADD CONSTRAINT signal_type_responsibles_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- TOC entry 3469 (class 2606 OID 17784)
-- Name: signal_type_responsibles signal_type_responsibles_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signal_type_responsibles
    ADD CONSTRAINT signal_type_responsibles_type_id_fkey FOREIGN KEY (type_id) REFERENCES public.signal_types(id) ON DELETE CASCADE;


--
-- TOC entry 3470 (class 2606 OID 17816)
-- Name: signalisations signalisations_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signalisations
    ADD CONSTRAINT signalisations_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.employees(id) ON DELETE RESTRICT;


--
-- TOC entry 3471 (class 2606 OID 25952)
-- Name: signalisations signalisations_localisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signalisations
    ADD CONSTRAINT signalisations_localisation_id_fkey FOREIGN KEY (localisation_id) REFERENCES public.localisations(id) ON DELETE SET NULL;


--
-- TOC entry 3476 (class 2606 OID 17860)
-- Name: signalisations_status_history signalisations_status_history_changed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signalisations_status_history
    ADD CONSTRAINT signalisations_status_history_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES public.employees(id);


--
-- TOC entry 3477 (class 2606 OID 17855)
-- Name: signalisations_status_history signalisations_status_history_signalisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signalisations_status_history
    ADD CONSTRAINT signalisations_status_history_signalisation_id_fkey FOREIGN KEY (signalisation_id) REFERENCES public.signalisations(id) ON DELETE CASCADE;


--
-- TOC entry 3472 (class 2606 OID 17821)
-- Name: signalisations signalisations_treated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signalisations
    ADD CONSTRAINT signalisations_treated_by_fkey FOREIGN KEY (treated_by) REFERENCES public.employees(id) ON DELETE SET NULL;


--
-- TOC entry 3473 (class 2606 OID 17811)
-- Name: signalisations signalisations_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signalisations
    ADD CONSTRAINT signalisations_type_id_fkey FOREIGN KEY (type_id) REFERENCES public.signal_types(id) ON DELETE RESTRICT;


--
-- TOC entry 3474 (class 2606 OID 17835)
-- Name: signalisations_views signalisations_views_signalisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signalisations_views
    ADD CONSTRAINT signalisations_views_signalisation_id_fkey FOREIGN KEY (signalisation_id) REFERENCES public.signalisations(id) ON DELETE CASCADE;


--
-- TOC entry 3475 (class 2606 OID 17840)
-- Name: signalisations_views signalisations_views_viewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.signalisations_views
    ADD CONSTRAINT signalisations_views_viewer_id_fkey FOREIGN KEY (viewer_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- TOC entry 3496 (class 2606 OID 26152)
-- Name: suggestion_attachments suggestion_attachments_suggestion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestion_attachments
    ADD CONSTRAINT suggestion_attachments_suggestion_id_fkey FOREIGN KEY (suggestion_id) REFERENCES public.suggestions(id) ON DELETE CASCADE;


--
-- TOC entry 3497 (class 2606 OID 26157)
-- Name: suggestion_attachments suggestion_attachments_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestion_attachments
    ADD CONSTRAINT suggestion_attachments_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.employees(id);


--
-- TOC entry 3500 (class 2606 OID 26198)
-- Name: suggestion_history suggestion_history_changed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestion_history
    ADD CONSTRAINT suggestion_history_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES public.employees(id);


--
-- TOC entry 3501 (class 2606 OID 26193)
-- Name: suggestion_history suggestion_history_suggestion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestion_history
    ADD CONSTRAINT suggestion_history_suggestion_id_fkey FOREIGN KEY (suggestion_id) REFERENCES public.suggestions(id) ON DELETE CASCADE;


--
-- TOC entry 3498 (class 2606 OID 26178)
-- Name: suggestion_messages suggestion_messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestion_messages
    ADD CONSTRAINT suggestion_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- TOC entry 3499 (class 2606 OID 26173)
-- Name: suggestion_messages suggestion_messages_suggestion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestion_messages
    ADD CONSTRAINT suggestion_messages_suggestion_id_fkey FOREIGN KEY (suggestion_id) REFERENCES public.suggestions(id) ON DELETE CASCADE;


--
-- TOC entry 3502 (class 2606 OID 26219)
-- Name: suggestion_notifications suggestion_notifications_recipient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestion_notifications
    ADD CONSTRAINT suggestion_notifications_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES public.employees(id);


--
-- TOC entry 3503 (class 2606 OID 26224)
-- Name: suggestion_notifications suggestion_notifications_recipient_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestion_notifications
    ADD CONSTRAINT suggestion_notifications_recipient_user_id_fkey FOREIGN KEY (recipient_user_id) REFERENCES public.users(id);


--
-- TOC entry 3504 (class 2606 OID 26214)
-- Name: suggestion_notifications suggestion_notifications_suggestion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestion_notifications
    ADD CONSTRAINT suggestion_notifications_suggestion_id_fkey FOREIGN KEY (suggestion_id) REFERENCES public.suggestions(id) ON DELETE CASCADE;


--
-- TOC entry 3491 (class 2606 OID 26125)
-- Name: suggestions suggestions_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestions
    ADD CONSTRAINT suggestions_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- TOC entry 3492 (class 2606 OID 26115)
-- Name: suggestions suggestions_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestions
    ADD CONSTRAINT suggestions_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- TOC entry 3493 (class 2606 OID 26130)
-- Name: suggestions suggestions_handled_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestions
    ADD CONSTRAINT suggestions_handled_by_fkey FOREIGN KEY (handled_by) REFERENCES public.employees(id);


--
-- TOC entry 3494 (class 2606 OID 26135)
-- Name: suggestions suggestions_redirected_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestions
    ADD CONSTRAINT suggestions_redirected_to_fkey FOREIGN KEY (redirected_to) REFERENCES public.departments(id);


--
-- TOC entry 3495 (class 2606 OID 26120)
-- Name: suggestions suggestions_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggestions
    ADD CONSTRAINT suggestions_type_id_fkey FOREIGN KEY (type_id) REFERENCES public.suggestion_types(id) ON DELETE SET NULL;


-- Completed on 2025-12-07 19:35:32

--
-- PostgreSQL database dump complete
--

