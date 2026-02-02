-- Create day_status table for attendance calculations
CREATE TABLE IF NOT EXISTS day_status (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    date date NOT NULL,
    scheduled_minutes integer DEFAULT 0,
    worked_minutes integer DEFAULT 0,
    late_minutes integer DEFAULT 0,
    early_minutes integer DEFAULT 0,
    overtime_minutes integer DEFAULT 0,
    status character varying(20) DEFAULT 'Present',
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(employee_id, date)
);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_day_status_employee_date ON day_status(employee_id, date);
CREATE INDEX IF NOT EXISTS idx_day_status_date ON day_status(date);
