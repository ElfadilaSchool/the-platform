-- Add unique constraint to employee_overtime_hours table for (employee_id, date)
-- This is needed for the ON CONFLICT clause in the approve overtime request route

ALTER TABLE public.employee_overtime_hours
ADD CONSTRAINT employee_overtime_hours_employee_date_unique
UNIQUE (employee_id, date);
