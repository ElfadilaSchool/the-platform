-- Add half_days column to employee_monthly_summaries table
-- This stores the count of half-day treated pending cases

ALTER TABLE employee_monthly_summaries 
ADD COLUMN IF NOT EXISTS half_days numeric(5,2) DEFAULT 0;

-- Add comment to explain the column
COMMENT ON COLUMN employee_monthly_summaries.half_days IS 'Count of days treated as half-day (pending cases treated as half_day). These days are counted in total_worked_days but paid at 0.5x daily rate.';

