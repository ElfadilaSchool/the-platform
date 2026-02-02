# 🎓 Automatic Teacher Substitution System - Complete Guide

## 📋 Overview

This system automatically finds substitute teachers when a teacher takes leave. It intelligently matches:
- ✅ Institution/Branch
- ✅ Teaching Level (with Preschool ↔ Primary flexibility)
- ✅ Available time slots in timetables
- ✅ Partial coverage (multiple teachers can split the coverage)

---

## 🔄 How It Works - Step by Step

### 1️⃣ **Teacher Submits Leave Request**
A teacher submits a Leave Request or Holiday Assignment exception:
- Select "LeaveRequest" or "HolidayAssignment" type
- Choose date range
- Submit the request

### 2️⃣ **Admin/Manager Approves**
When the leave request is **approved**:
- ✨ System automatically triggers the substitution matcher
- Checks if employee is a teacher (position contains "teacher")
- If not a teacher, skips substitution
- If teacher, proceeds to find substitutes

### 3️⃣ **System Finds Matching Substitutes**
The auto-matcher:

**Step A - Get Absent Teacher Info:**
- Retrieves their timetable
- Gets institution/branch
- Gets teaching level
- Calculates all time slots they'll miss

**Step B - Find Candidates:**
- Searches for all teachers in matching institution
- Matches teaching level (preschool can cover primary and vice versa)
- Only includes active teachers

**Step C - Check Availability:**
- For each candidate, loads their timetable
- Finds slots where they're FREE (no conflicts)
- Can match partial slots (e.g., absent teacher has 8 hours, 4 teachers cover 2 hours each)

**Step D - Create Invitations:**
- Sends invitations to each candidate
- Each invitation is for specific time slots they can cover
- Multiple teachers can receive invitations for different slots

### 4️⃣ **Teachers Receive Invitations**
Substitute candidates see invitations in:
**Submit Exception → Pending Extra Hours → Substitution Invitations**

Example:
```
📅 2025-03-15 09:00 - 11:00
⏱️  Duration: 2.0 hours (120 minutes)
[Accept] [Deny]
```

### 5️⃣ **Teacher Workflow**

#### **Option A: Accept Invitation**
1. Click **[Accept]**
2. Status changes to "accepted"
3. Other teachers see this slot is now occupied
4. You now see: **[Drop]** and **[Mark Taught]** buttons

#### **Option B: Deny Invitation**
1. Click **[Deny]**
2. Slot remains available to others
3. You won't see it anymore

#### **Option C: Drop After Accepting**
1. If you accepted but can't do it anymore
2. Click **[Drop]**
3. Slot becomes available to others again
4. Status returns to "pending"

#### **Option D: Mark as Taught (Final Step)**
1. After you've taught the class
2. Click **[Mark Taught]**
3. System automatically:
   - ✅ Creates an approved overtime request
   - ✅ Adds hours to `employee_overtime_hours`
   - ✅ Updates your monthly summary
   - ✅ Shows hours on your overtime tab

---

## 🎯 Matching Rules

### Institution Matching
- Must match exactly
- Example: "Branch A" teachers only see "Branch A" invitations

### Level Matching (Flexible)
- **Preschool** teachers can cover **Primary** and vice versa
- **Other levels** must match exactly
- Examples:
  - Preschool teacher absent → Primary teachers invited
  - Primary teacher absent → Preschool teachers invited
  - Secondary teacher absent → Only secondary teachers invited

### Timetable Matching
- System checks if candidate is FREE at that time
- If candidate has a scheduled class → NOT invited
- If candidate has free time → Invited
- Supports partial matching:
  - Teacher absent 2 days → Some cover day 1, others cover day 2
  - Teacher absent 6 hours → Can be split among 3 teachers (2h each)

---

## 📊 Database Tables

### `substitution_requests`
Created when a teacher's leave is approved:
```sql
- id (uuid)
- employee_id (teacher who is absent)
- exception_id (linked to the approved exception)
- date, start_time, end_time, minutes
- status
```

### `substitution_invitations`
One per candidate per time slot:
```sql
- id (uuid)
- request_id (links to substitution_requests)
- candidate_employee_id (teacher being invited)
- date, start_time, end_time, minutes
- status (pending/accepted/denied/taught)
- responded_at, completed_at
```

### `overtime_requests` & `employee_overtime_hours`
Automatically created when invitation is marked "taught":
```sql
overtime_requests:
- employee_id, date, requested_hours
- status = 'Approved' (auto-approved)
- description = 'Substitution coverage: [details]'

employee_overtime_hours:
- employee_id, date, hours
- description = 'Substitution: [time range]'
```

---

## 🖥️ Frontend UI

### For Employees (Teachers)

**Location:** Submit Exception → Pending Extra Hours tab

**Section 1: My Extra Hours Requests**
- Your overtime requests you submitted
- Can delete pending ones

**Section 2: Substitution Invitations**
- Invitations you've received
- Filters: Pending, Accepted, Taught

**Invitation Display:**
```
┌───────────────────────────────────────────────────┐
│ 📅 2025-03-15 09:00 - 11:00                      │
│ ⏱️  Duration: 2.0 hours (120 minutes)             │
│                        [Accept] [Deny]            │
└───────────────────────────────────────────────────┘

After Accepting:
┌───────────────────────────────────────────────────┐
│ 📅 2025-03-15 09:00 - 11:00                      │
│ ⏱️  Duration: 2.0 hours (120 minutes)             │
│ ✓ You Accepted     [Drop] [Mark Taught]          │
└───────────────────────────────────────────────────┘

After Teaching:
┌───────────────────────────────────────────────────┐
│ 📅 2025-03-15 09:00 - 11:00                      │
│ ⏱️  Duration: 2.0 hours (120 minutes)             │
│ 🎓 Taught (2.0h added to overtime)                │
└───────────────────────────────────────────────────┘
```

---

## 🔧 API Endpoints

### Get My Invitations
```javascript
GET /api/substitutions/invitations/mine?status=pending
// Returns invitations for current employee
```

### Respond to Invitation
```javascript
POST /api/substitutions/invitations/:id/respond
Body: { action: "accept" | "deny" | "drop" | "taught" }

// Returns updated invitation with new status
```

### Get Substitution Requests (Admin)
```javascript
GET /api/substitutions/requests?status=pending
// Returns all substitution requests
```

---

## ⚙️ Configuration Requirements

### 1. Timetables Must Be Set Up
- Each teacher must have a timetable assigned
- Timetables define when they teach
- Use: **Timetable Library** page

### 2. Employee Data Required
- `institution` field must be filled
- `education_level` should indicate teaching level
- `position` must contain "teacher" (case-insensitive)

### 3. Exception Types
- System only processes: `LeaveRequest` and `HolidayAssignment`
- Other exception types don't trigger substitution

---

## 🐛 Troubleshooting

### No Invitations Generated?

**Check 1: Is the employee a teacher?**
```sql
SELECT e.first_name, e.last_name, p.name as position
FROM employees e
JOIN positions p ON e.position_id = p.id
WHERE e.id = 'employee-id';
```
Position must contain "teacher"

**Check 2: Does the teacher have a timetable?**
```sql
SELECT et.*, t.name as timetable_name
FROM employee_timetables et
JOIN timetables t ON et.timetable_id = t.id
WHERE et.employee_id = 'employee-id'
  AND et.effective_from <= CURRENT_DATE
  AND (et.effective_to IS NULL OR et.effective_to >= CURRENT_DATE);
```

**Check 3: Are there matching candidates?**
```sql
SELECT e.id, e.first_name, e.last_name, e.institution, e.education_level
FROM employees e
JOIN positions p ON e.position_id = p.id
WHERE e.institution = 'your-institution'
  AND p.name ILIKE '%teacher%'
  AND e.id != 'absent-teacher-id';
```

**Check 4: Check server logs**
```bash
# In attendance-service directory
tail -f attendance-server.log | grep "AUTO-SUB"
```

Look for:
- `[AUTO-SUB] Processing exception...`
- `[AUTO-SUB] Found X potential substitute teacher(s)`
- `[AUTO-SUB] Successfully created X invitation(s)`

### Invitations Not Showing?

**Check database:**
```sql
SELECT si.*, e.first_name, e.last_name
FROM substitution_invitations si
JOIN employees e ON si.candidate_employee_id = e.id
WHERE si.candidate_employee_id = 'your-employee-id'
ORDER BY si.date DESC;
```

**Check frontend console:**
- Open browser DevTools → Console
- Look for "Invitations load error"
- Check API response

### Taught Button Not Working?

**Check console for errors:**
- Look for "Failed to respond to invitation"
- Verify employee_id matches invitation.candidate_employee_id

**Check database constraints:**
```sql
-- Verify overtime tables exist
SELECT * FROM overtime_requests LIMIT 1;
SELECT * FROM employee_overtime_hours LIMIT 1;
SELECT * FROM employee_monthly_summaries LIMIT 1;
```

---

## 📈 Benefits

✅ **Automatic** - No manual matching needed
✅ **Fair Distribution** - Splits coverage among available teachers  
✅ **Flexible** - Partial time slot matching
✅ **Accurate** - Based on actual timetables
✅ **Transparent** - Teachers see exactly what they're covering
✅ **Integrated** - Automatically adds to overtime

---

## 🚀 Next Steps

1. **Set up timetables** for all teachers
2. **Test with a leave request**:
   - Create a leave request as a teacher
   - Approve it as admin
   - Check console logs for auto-sub messages
   - Check if invitations appear for other teachers
3. **Accept an invitation** as another teacher
4. **Mark it taught** and verify overtime was added

---

## 📞 Support

If you encounter issues:
1. Check server logs: `grep "AUTO-SUB\|INVITATION-RESPOND" attendance-server.log`
2. Verify timetables are assigned correctly
3. Check that employees have proper institution/level data
4. Test with simple scenarios first (single day, single teacher)

---

**Congratulations! Your automatic substitution system is ready! 🎉**

