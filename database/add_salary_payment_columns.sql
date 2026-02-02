-- Add missing columns to salary_payments table
ALTER TABLE salary_payments
ADD COLUMN amount numeric(10,2),
ADD COLUMN currency character varying(3) DEFAULT 'DA';

-- Update existing records to have default values
UPDATE salary_payments
SET amount = 0, currency = 'DA'
WHERE amount IS NULL;
