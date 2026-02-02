-- Delete all salary payments from the database
-- WARNING: This will permanently delete all payment records
-- Use only for testing purposes

DELETE FROM salary_payments;

-- Optional: Reset sequence if you're using auto-increment IDs
-- (Not needed for UUID-based IDs)

-- To see how many records were deleted, run this first:
-- SELECT COUNT(*) FROM salary_payments;


