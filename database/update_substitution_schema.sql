-- Update substitution invitation schema to support new features
-- This adds the 'disabled' status and creates a history table

-- 1. Update the status constraint to include 'disabled'
ALTER TABLE substitution_invitations 
DROP CONSTRAINT IF EXISTS substitution_invitations_status_check;

ALTER TABLE substitution_invitations 
ADD CONSTRAINT substitution_invitations_status_check 
CHECK (status IN ('pending', 'accepted', 'denied', 'taught', 'dropped', 'disabled'));

-- 2. Create substitution history table for tracking completed substitutions
CREATE TABLE IF NOT EXISTS substitution_history (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    invitation_id uuid NOT NULL REFERENCES substitution_invitations(id) ON DELETE CASCADE,
    request_id uuid NOT NULL REFERENCES substitution_requests(id) ON DELETE CASCADE,
    substitute_employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    absent_employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    date date NOT NULL,
    start_time time NOT NULL,
    end_time time NOT NULL,
    minutes integer NOT NULL,
    status varchar(20) NOT NULL, -- 'completed', 'no_show'
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT substitution_history_status_check CHECK (status IN ('completed', 'no_show'))
);

-- 3. Create indexes for the history table
CREATE INDEX IF NOT EXISTS idx_substitution_history_substitute ON substitution_history(substitute_employee_id);
CREATE INDEX IF NOT EXISTS idx_substitution_history_absent ON substitution_history(absent_employee_id);
CREATE INDEX IF NOT EXISTS idx_substitution_history_date ON substitution_history(date);
CREATE INDEX IF NOT EXISTS idx_substitution_history_status ON substitution_history(status);

-- 4. Add comments for documentation
COMMENT ON TABLE substitution_history IS 'History of completed substitution work for tracking and reporting';
COMMENT ON COLUMN substitution_history.substitute_employee_id IS 'The teacher who completed the substitution';
COMMENT ON COLUMN substitution_history.absent_employee_id IS 'The teacher who was absent and needed coverage';
COMMENT ON COLUMN substitution_history.status IS 'completed = substitution was taught, no_show = teacher accepted but did not show up';
COMMENT ON COLUMN substitution_history.completed_at IS 'When the substitution was actually completed';

-- 5. Verify the changes
SELECT 
    'substitution_invitations' as table_name, 
    COUNT(*) as record_count 
FROM substitution_invitations
UNION ALL
SELECT 
    'substitution_history' as table_name, 
    COUNT(*) as record_count 
FROM substitution_history;
