-- Add calculation_method column to salary_payments table
-- This stores which method (algerian or worked_days) was used when marking salary as paid

ALTER TABLE salary_payments 
ADD COLUMN IF NOT EXISTS calculation_method VARCHAR(20) DEFAULT 'algerian';

-- Add comment to explain the column
COMMENT ON COLUMN salary_payments.calculation_method IS 'The calculation method used: algerian (Base - Deductions) or worked_days (Worked Days × Daily Rate)';


