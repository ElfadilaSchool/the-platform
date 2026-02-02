# Enhanced Substitution Invitation System

## Overview

This enhanced substitution invitation system provides comprehensive management of teacher substitution requests with advanced features for single acceptance, history tracking, and role-based views.

## 🚀 New Features

### 1. Single Teacher Acceptance
- **Problem Solved**: Multiple teachers accepting the same substitution slot
- **Solution**: When one teacher accepts an invitation, all other pending invitations for the same slot become "disabled"
- **Benefit**: Prevents double-booking and ensures only one teacher covers each slot

### 2. Drop and Reactivation
- **Problem Solved**: Teachers accepting but then unable to fulfill their commitment
- **Solution**: Teachers can "drop" accepted invitations, which reactivates all other disabled invitations
- **Benefit**: Flexible management when circumstances change

### 3. Automatic Extra Hour Tracking
- **Problem Solved**: Manual tracking of substitution work hours
- **Solution**: When a teacher marks a substitution as "taught", hours are automatically added to their overtime record
- **Benefit**: Seamless integration with payroll and attendance systems

### 4. History Tracking
- **Problem Solved**: No record of completed substitution work
- **Solution**: All substitution work is tracked in a dedicated history table
- **Benefit**: Complete audit trail and reporting capabilities

### 5. Role-Based Views
- **Problem Solved**: Teachers seeing irrelevant invitation data
- **Solution**: Separate API endpoints for teacher and admin views
- **Benefit**: Cleaner interface and better user experience

## 📊 Database Schema

### Updated Tables

#### `substitution_invitations`
- **New Status**: Added `disabled` status for invitations that become unavailable
- **Status Flow**: `pending` → `accepted` (others become `disabled`) → `taught`/`dropped`

#### `substitution_history` (New Table)
- Tracks all completed substitution work
- Links substitute teacher, absent teacher, and work details
- Supports both `completed` and `no_show` statuses

## 🔄 Status Flow

```
Teacher View:
pending → accepted → taught
   ↓         ↓
 denied   dropped → pending (others reactivated)

Admin View:
All statuses visible including disabled, denied, taught
```

## 🛠 API Endpoints

### Teacher Endpoints

#### Get Teacher Invitations
```
GET /api/substitutions/invitations/teacher-view?status=pending|accepted|dropped
```
- Returns only invitations relevant to the teacher
- Filters out disabled, denied, and taught invitations

#### Respond to Invitation
```
POST /api/substitutions/invitations/:id/respond
Body: { "action": "accept|deny|drop|taught" }
```
- `accept`: Accepts invitation, disables others
- `deny`: Declines invitation
- `drop`: Drops accepted invitation, reactivates others
- `taught`: Marks as completed, adds to overtime hours

#### Get Personal History
```
GET /api/substitutions/history/:employeeId?status=completed|no_show&start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
```

### Admin Endpoints

#### Get All Invitations (Admin View)
```
GET /api/substitutions/invitations/admin-view?status=all&request_id=uuid
```
- Shows all invitations regardless of status
- Includes candidate and absent employee names

#### Get All History
```
GET /api/substitutions/history/all?status=completed|no_show&employee_id=uuid&start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
```

#### Mark No-Show
```
POST /api/substitutions/invitations/:id/mark-no-show
```
- Marks accepted invitation as no-show
- Adds to history with `no_show` status
- Reactivates other invitations

## 🎯 Use Cases

### Scenario 1: Normal Substitution Flow
1. Teacher A requests substitution for 2025-01-15
2. System creates invitations for Teachers B, C, D
3. Teacher B accepts → Teachers C, D invitations become disabled
4. Teacher B teaches the class → marks as "taught"
5. Hours automatically added to Teacher B's overtime
6. Substitution recorded in history

### Scenario 2: Drop and Reactivation
1. Teacher B accepts substitution
2. Teacher B realizes they can't make it
3. Teacher B drops the invitation
4. Teachers C, D invitations become pending again
5. Teacher C can now accept

### Scenario 3: No-Show Management
1. Teacher B accepts substitution
2. Teacher B doesn't show up
3. Admin marks as no-show
4. Other teachers can accept the slot
5. No-show recorded in history for reporting

## 🔧 Installation

### 1. Apply Database Updates
```bash
node apply-substitution-updates.js
```

### 2. Restart Services
```bash
# Restart the attendance service to load new routes
pm2 restart attendance-service
# or
node attendance-service/attendance-server.js
```

### 3. Verify Installation
```bash
# Check if new endpoints are working
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:3001/api/substitutions/invitations/teacher-view
```

## 📈 Benefits

### For Teachers
- ✅ Clear view of available substitution opportunities
- ✅ Automatic overtime tracking
- ✅ Personal history of substitution work
- ✅ Ability to drop commitments when needed

### For Administrators
- ✅ Complete oversight of all substitution activity
- ✅ No-show tracking and reporting
- ✅ Automatic hour calculations
- ✅ Comprehensive audit trail

### For the System
- ✅ Prevents double-booking
- ✅ Maintains data integrity
- ✅ Supports reporting and analytics
- ✅ Flexible and scalable architecture

## 🚨 Important Notes

### Status Management
- **Disabled invitations** are not visible to teachers
- **Only one teacher** can accept per substitution slot
- **Dropping** reactivates all other invitations for that slot
- **History records** are permanent and cannot be deleted

### Data Integrity
- All operations are wrapped in database transactions
- Automatic rollback on errors
- Comprehensive error handling and logging

### Performance
- Indexed queries for fast lookups
- Pagination on all list endpoints
- Optimized joins for complex queries

## 🔍 Troubleshooting

### Common Issues

#### "Another teacher has already accepted this substitution slot"
- This is expected behavior when trying to accept a slot that's already taken
- Check the admin view to see who accepted it

#### "Can only accept pending invitations"
- The invitation may have been disabled by another teacher's acceptance
- Check the current status in the admin view

#### "Can only drop accepted invitations"
- Only accepted invitations can be dropped
- Pending invitations should be denied instead

### Debug Queries

```sql
-- Check invitation statuses
SELECT status, COUNT(*) FROM substitution_invitations GROUP BY status;

-- Check history records
SELECT status, COUNT(*) FROM substitution_history GROUP BY status;

-- Find disabled invitations
SELECT * FROM substitution_invitations WHERE status = 'disabled';
```

## 📝 Future Enhancements

- Email notifications for status changes
- Mobile app integration
- Advanced reporting dashboard
- Integration with calendar systems
- Automated reminder system
- Performance analytics

---

*This enhanced system provides a robust, scalable solution for managing teacher substitutions with comprehensive tracking and reporting capabilities.*
