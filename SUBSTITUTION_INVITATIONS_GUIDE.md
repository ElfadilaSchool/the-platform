# Substitution Invitations Setup Guide

## The Problem

Your `substitution_requests` table has data, but employees can't see any invitations in the "Pending Extra Hours" tab. This is because:

1. **`substitution_requests`** - Contains requests from teachers who need coverage
2. **`substitution_invitations`** - Contains invitations sent to specific employees to cover those requests

**The system was missing the code to create invitations from requests!**

## The Solution

I've added:
1. ✅ New API endpoints to create invitations
2. ✅ A utility script to generate invitations from existing requests
3. ✅ Auto-invite functionality for future requests

## Quick Fix - Generate Invitations Now

Run this command to automatically create invitations for all existing substitution requests:

```bash
node generate-substitution-invitations.js
```

This will:
- Find all substitution requests without invitations
- Automatically invite all colleagues in the same department
- Skip requests that already have invitations

**Output example:**
```
🔍 Checking for substitution requests without invitations...

📊 Found 3 substitution request(s)

📅 Request: John Doe - 2025-03-15 (09:00-11:00)
   Existing invitations: 0
   👥 Found 5 potential substitute(s):
      ✓ Jane Smith
      ✓ Bob Johnson
      ✓ Alice Williams
      ✓ Charlie Brown
      ✓ Diana Prince
   ✅ Created 5 invitation(s) for this request

🎉 Total invitations created: 15
✅ Done! Employees can now see these invitations in the "Pending Extra Hours" tab.
```

## How to Use the New API Endpoints

### 1. Auto-Invite All Department Colleagues

```javascript
// Automatically invite all colleagues in the same department
await API.autoInviteSubstitution(requestId);
```

### 2. Manual Invitation to Specific Employees

```javascript
// Invite specific employees by their IDs
await API.createSubstitutionInvitations(requestId, [employeeId1, employeeId2, employeeId3]);
```

### 3. Get All Substitution Requests

```javascript
// Get all requests
const requests = await API.getSubstitutionRequests();

// Get only approved requests
const approvedRequests = await API.getSubstitutionRequests('approved');
```

## For Future Requests

When a new substitution request is created, you should:

1. **Option A - Auto-invite (Recommended):**
   - Call `/api/substitutions/requests/:requestId/auto-invite` 
   - This invites all colleagues in the same department

2. **Option B - Manual selection:**
   - Let admin select specific employees
   - Call `/api/substitutions/requests/:requestId/create-invitations`

## What Employees See Now

After running the script, employees will see invitations in:

**Submit Exception → Pending Extra Hours tab → Substitution Invitations section**

Example display:
```
📅 2025-03-15 09:00 - 11:00
Duration: 2.0 hours (120 minutes)
[Accept] [Deny]
```

When they accept:
- The invitation status changes to "accepted"
- They can later mark it as "Taught" when completed
- Or "Drop" if they need to cancel

## Technical Details

### New Backend Endpoints

1. `GET /api/substitutions/requests`
   - Lists all substitution requests
   - Shows count of invitations per request

2. `POST /api/substitutions/requests/:requestId/auto-invite`
   - Auto-invites all department colleagues
   - Skips the requester
   - Only invites active employees

3. `POST /api/substitutions/requests/:requestId/create-invitations`
   - Body: `{ candidate_employee_ids: [id1, id2, ...] }`
   - Creates invitations for specific employees

### Database Schema

**substitution_requests:**
- `id`, `employee_id`, `date`, `start_time`, `end_time`, `minutes`, `status`

**substitution_invitations:**
- `id`, `request_id`, `candidate_employee_id`, `date`, `start_time`, `end_time`, `minutes`, `status`, `responded_at`

The invitations table references requests via `request_id`.

## Troubleshooting

**Q: I ran the script but still see no invitations**
- Check if employees are in the same department
- Verify employee status is 'active'
- Check database: `SELECT * FROM substitution_invitations;`

**Q: Can I run the script multiple times?**
- Yes! It skips requests that already have invitations

**Q: How do I create invitations for new requests?**
- Call the auto-invite API endpoint after creating a request
- Or add it to your request creation workflow

## Need Help?

Check the logs:
```bash
# In attendance-service directory
node attendance-server.js
# Watch for "Load invitations error" or "Auto-invite error"
```

Query the database:
```sql
-- See all requests
SELECT * FROM substitution_requests;

-- See all invitations
SELECT * FROM substitution_invitations;

-- See requests without invitations
SELECT sr.*, COUNT(si.id) as inv_count
FROM substitution_requests sr
LEFT JOIN substitution_invitations si ON sr.id = si.request_id
GROUP BY sr.id
HAVING COUNT(si.id) = 0;
```

