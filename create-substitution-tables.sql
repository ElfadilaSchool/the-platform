-- Create substitution tables for auto-substitution system
-- Run this in your PostgreSQL database if the tables don't exist

-- 1. Create substitution_requests table
CREATE TABLE IF NOT EXISTS substitution_requests (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    exception_id uuid REFERENCES attendance_exceptions(id) ON DELETE CASCADE,
    date date NOT NULL,
    start_time time NOT NULL,
    end_time time NOT NULL,
    minutes integer NOT NULL,
    status varchar(20) DEFAULT 'pending' NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT substitution_requests_status_check CHECK (status IN ('pending', 'approved', 'cancelled'))
);

-- 2. Create substitution_invitations table
CREATE TABLE IF NOT EXISTS substitution_invitations (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    request_id uuid NOT NULL REFERENCES substitution_requests(id) ON DELETE CASCADE,
    candidate_employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    date date NOT NULL,
    start_time time NOT NULL,
    end_time time NOT NULL,
    minutes integer NOT NULL,
    status varchar(20) DEFAULT 'pending' NOT NULL,
    responded_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT substitution_invitations_status_check CHECK (status IN ('pending', 'accepted', 'denied', 'taught', 'dropped')),
    CONSTRAINT substitution_invitations_unique UNIQUE (request_id, candidate_employee_id, date, start_time)
);

-- 3. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_substitution_requests_employee ON substitution_requests(absent_employee_id);
CREATE INDEX IF NOT EXISTS idx_substitution_requests_date ON substitution_requests(date);
CREATE INDEX IF NOT EXISTS idx_substitution_requests_status ON substitution_requests(status);

CREATE INDEX IF NOT EXISTS idx_substitution_invitations_candidate ON substitution_invitations(candidate_employee_id);
CREATE INDEX IF NOT EXISTS idx_substitution_invitations_request ON substitution_invitations(request_id);
CREATE INDEX IF NOT EXISTS idx_substitution_invitations_status ON substitution_invitations(status);
CREATE INDEX IF NOT EXISTS idx_substitution_invitations_date ON substitution_invitations(date);

-- 4. Add comments for documentation
COMMENT ON TABLE substitution_requests IS 'Requests for teacher substitution when someone is absent';
COMMENT ON TABLE substitution_invitations IS 'Invitations sent to potential substitute teachers';

COMMENT ON COLUMN substitution_requests.employee_id IS 'The teacher who is absent and needs coverage';
COMMENT ON COLUMN substitution_requests.exception_id IS 'Links to the approved leave/holiday exception';
COMMENT ON COLUMN substitution_requests.minutes IS 'Total minutes of coverage needed';

COMMENT ON COLUMN substitution_invitations.candidate_employee_id IS 'The teacher being invited to substitute';
COMMENT ON COLUMN substitution_invitations.status IS 'pending, accepted, denied, taught, dropped';
COMMENT ON COLUMN substitution_invitations.responded_at IS 'When the teacher responded to the invitation';
COMMENT ON COLUMN substitution_invitations.completed_at IS 'When the substitution was completed (marked as taught)';

-- 5. Verify tables were created
SELECT 
    'substitution_requests' as table_name, 
    COUNT(*) as record_count 
FROM substitution_requests
UNION ALL
SELECT 
    'substitution_invitations' as table_name, 
    COUNT(*) as record_count 
FROM substitution_invitations;
