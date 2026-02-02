-- Migration to add missing tables for monthly statistics functionality
-- This adds the tables that are referenced in the attendance service but missing from the main schema

-- Create employee_overtime_hours table
CREATE TABLE IF NOT EXISTS public.employee_overtime_hours (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    date date NOT NULL,
    hours numeric(5,2) NOT NULL,
    description text,
    created_by_user_id uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT employee_overtime_hours_pkey PRIMARY KEY (id),
    CONSTRAINT employee_overtime_hours_hours_check CHECK (((hours >= (0)::numeric) AND (hours <= (24)::numeric))),
    CONSTRAINT employee_overtime_hours_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE,
    CONSTRAINT employee_overtime_hours_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id)
);

-- Create employee_salary_adjustments table
CREATE TABLE IF NOT EXISTS public.employee_salary_adjustments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    adjustment_type character varying(20) NOT NULL,
    amount numeric(10,2) NOT NULL,
    description text,
    effective_date date NOT NULL,
    created_by_user_id uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT employee_salary_adjustments_pkey PRIMARY KEY (id),
    CONSTRAINT employee_salary_adjustments_adjustment_type_check CHECK (((adjustment_type)::text = ANY ((ARRAY['credit'::character varying, 'decrease'::character varying, 'raise'::character varying])::text[]))),
    CONSTRAINT employee_salary_adjustments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE,
    CONSTRAINT employee_salary_adjustments_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id)
);

-- Create employee_monthly_validations table
CREATE TABLE IF NOT EXISTS public.employee_monthly_validations (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    month integer NOT NULL,
    year integer NOT NULL,
    validated_by_user_id uuid NOT NULL,
    validated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    notes text,
    CONSTRAINT employee_monthly_validations_pkey PRIMARY KEY (id),
    CONSTRAINT employee_monthly_validations_unique_employee_month_year UNIQUE (employee_id, month, year),
    CONSTRAINT employee_monthly_validations_month_check CHECK (((month >= 1) AND (month <= 12))),
    CONSTRAINT employee_monthly_validations_year_check CHECK (((year >= 2020) AND (year <= 2100))),
    CONSTRAINT employee_monthly_validations_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE,
    CONSTRAINT employee_monthly_validations_validated_by_user_id_fkey FOREIGN KEY (validated_by_user_id) REFERENCES public.users(id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_employee_overtime_hours_employee_id ON public.employee_overtime_hours USING btree (employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_overtime_hours_employee_date ON public.employee_overtime_hours USING btree (employee_id, date);
CREATE INDEX IF NOT EXISTS idx_employee_overtime_hours_date ON public.employee_overtime_hours USING btree (date);

CREATE INDEX IF NOT EXISTS idx_employee_salary_adjustments_employee_id ON public.employee_salary_adjustments USING btree (employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_salary_adjustments_employee_date ON public.employee_salary_adjustments USING btree (employee_id, effective_date);
CREATE INDEX IF NOT EXISTS idx_employee_salary_adjustments_effective_date ON public.employee_salary_adjustments USING btree (effective_date);
CREATE INDEX IF NOT EXISTS idx_employee_salary_adjustments_type ON public.employee_salary_adjustments USING btree (adjustment_type);

CREATE INDEX IF NOT EXISTS idx_employee_monthly_validations_employee_id ON public.employee_monthly_validations USING btree (employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_monthly_validations_month_year ON public.employee_monthly_validations USING btree (month, year);
CREATE INDEX IF NOT EXISTS idx_employee_monthly_validations_validated_by ON public.employee_monthly_validations USING btree (validated_by_user_id);

-- Create triggers for updated_at columns
CREATE TRIGGER update_employee_overtime_hours_updated_at BEFORE UPDATE ON public.employee_overtime_hours FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_employee_salary_adjustments_updated_at BEFORE UPDATE ON public.employee_salary_adjustments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Add comments
COMMENT ON TABLE public.employee_overtime_hours IS 'Tracks overtime hours worked by employees on specific dates';
COMMENT ON COLUMN public.employee_overtime_hours.hours IS 'Number of overtime hours worked (0-24)';
COMMENT ON COLUMN public.employee_overtime_hours.description IS 'Optional description or reason for overtime';

COMMENT ON TABLE public.employee_salary_adjustments IS 'Employee-specific salary adjustments (credit, decrease, raise)';

COMMENT ON TABLE public.employee_monthly_validations IS 'Tracks validation status of employee monthly attendance data';
COMMENT ON COLUMN public.employee_monthly_validations.month IS 'Month (1-12)';
COMMENT ON COLUMN public.employee_monthly_validations.year IS 'Year (2020-2100)';
COMMENT ON COLUMN public.employee_monthly_validations.notes IS 'Optional validation notes';
