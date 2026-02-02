-- Database Views for Director Statistics Dashboard
-- Run this SQL in pgAdmin to create the missing views

-- 1. Critical Alerts View
CREATE OR REPLACE VIEW public.critical_alerts AS
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

-- 2. Department Performance Detail View
CREATE OR REPLACE VIEW public.department_performance_detail AS
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

-- 3. Director Dashboard View
CREATE OR REPLACE VIEW public.director_dashboard AS
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

-- 4. Top Contributors View
CREATE OR REPLACE VIEW public.top_contributors AS
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

-- 5. Trend Analysis View
CREATE OR REPLACE VIEW public.trend_analysis AS
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

-- Grant permissions (adjust if needed)
ALTER VIEW public.critical_alerts OWNER TO postgres;
ALTER VIEW public.department_performance_detail OWNER TO postgres;
ALTER VIEW public.director_dashboard OWNER TO postgres;
ALTER VIEW public.top_contributors OWNER TO postgres;
ALTER VIEW public.trend_analysis OWNER TO postgres;
