
-- Add created_at and updated_at columns to the attendance_overrides table
ALTER TABLE attendance_overrides
ADD COLUMN created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;

-- Create a trigger to automatically update the updated_at timestamp on row modification
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_attendance_overrides_modtime
BEFORE UPDATE ON attendance_overrides
FOR EACH ROW
EXECUTE PROCEDURE update_modified_column();
