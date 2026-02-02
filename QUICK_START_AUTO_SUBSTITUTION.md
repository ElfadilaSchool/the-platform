# 🚀 Quick Start - Auto Substitution System

## What I Built For You

A complete **automatic teacher substitution system** that:

1. ✅ **Triggers** when a teacher's leave request is approved
2. ✅ **Finds** matching substitute teachers based on:
   - Same institution/branch
   - Compatible level (preschool ↔ primary flexible)
   - Free time in their timetable
3. ✅ **Sends invitations** to available teachers
4. ✅ **Tracks workflow**: Accept → Drop → Taught
5. ✅ **Auto-adds overtime** when marked "taught"

---

## Files Created/Modified

### New Files:
1. **`attendance-service/auto-substitution-matcher.js`** - Core matching algorithm
2. **`AUTO_SUBSTITUTION_SYSTEM_GUIDE.md`** - Complete documentation
3. **`QUICK_START_AUTO_SUBSTITUTION.md`** - This file

### Modified Files:
1. **`attendance-service/exceptions-routes.js`** - Integrated auto-sub on approval
2. **`attendance-service/substitutions-routes.js`** - Enhanced invitation workflow
3. **`frontend/pages/submit-exception.html`** - Updated UI with new workflow
4. **`frontend/components/api.js`** - Added API methods

---

## Test It Right Now!

### Step 1: Create a Test Leave Request (as Teacher)

1. Go to **Submit Exception**
2. Fill in:
   - Type: **Leave Request**
   - Date: Tomorrow
   - Reason: Testing
3. Submit

### Step 2: Approve It (as Admin)

1. Go to **Exceptions** management page
2. Find the pending exception
3. Click **Approve**
4. Watch the console logs for:
   ```
   🔄 [EXCEPTION-APPROVAL] Triggering auto-substitution...
   🔍 [AUTO-SUB] Processing exception...
   ✓ [AUTO-SUB] Employee is a teacher...
   ✓ [AUTO-SUB] Found X potential substitute teacher(s)
   🎉 [AUTO-SUB] Successfully created X invitation(s)
   ```

### Step 3: Check Invitations (as Another Teacher)

1. Login as a different teacher
2. Go to **Submit Exception → Pending Extra Hours** tab
3. Scroll to **Substitution Invitations** section
4. You should see invitation(s) like:
   ```
   📅 2025-03-16 09:00 - 11:00
   ⏱️  Duration: 2.0 hours (120 minutes)
   [Accept] [Deny]
   ```

### Step 4: Accept and Mark Taught

1. Click **[Accept]**
2. Buttons change to: **[Drop]** and **[Mark Taught]**
3. Click **[Mark Taught]**
4. Check your **Pending Extra Hours** → **My Extra Hours Requests**
5. You should see an approved overtime entry with the hours!

---

## ⚠️ Important Prerequisites

### 1. Timetables Must Be Assigned
**Without timetables, the system can't find free slots!**

To assign timetables:
1. Go to **Timetable Library**
2. Create timetables with time intervals
3. Assign to employees

### 2. Employee Data Required
Check that employees have:
- `institution` field filled (e.g., "Main Branch")
- `education_level` set (e.g., "Preschool", "Primary")
- `position` contains "teacher" (case-insensitive)

Quick check:
```sql
SELECT id, first_name, last_name, institution, education_level, 
       (SELECT name FROM positions WHERE id = position_id) as position
FROM employees
WHERE position_id IN (SELECT id FROM positions WHERE name ILIKE '%teacher%')
LIMIT 10;
```

### 3. Active Status
Only teachers with `status = 'active'` (or NULL) receive invitations.

---

## Console Logs to Monitor

### When Approval Happens:
```
🔄 [EXCEPTION-APPROVAL] Triggering auto-substitution for exception abc-123
🔍 [AUTO-SUB] Processing exception abc-123 for employee def-456
✓ [AUTO-SUB] Employee is a teacher: John Doe
   Institution: Main Branch
   Level: Primary
   Absent period: 2025-03-16 to 2025-03-16
✓ [AUTO-SUB] Found timetable with 3 interval(s)
✓ [AUTO-SUB] Generated 3 time slot(s) to cover
✓ [AUTO-SUB] Found 5 potential substitute teacher(s)
✓ [AUTO-SUB] Created/updated substitution request: xyz-789
🎉 [AUTO-SUB] Successfully created 12 invitation(s)
```

### When Invitation Is Responded:
```
🔄 [INVITATION-RESPOND] Action: accept by user user-123 (employee emp-456)
   Invitation: 2025-03-16 09:00-11:00 (120 min)
✓ [INVITATION-RESPOND] Invitation accepted
```

### When Marked Taught:
```
🔄 [INVITATION-RESPOND] Action: taught by user user-123 (employee emp-456)
   Invitation: 2025-03-16 09:00-11:00 (120 min)
✓ [INVITATION-RESPOND] Marked as taught, 2.00 hours added to overtime
```

---

## Common Issues & Solutions

### ❌ No invitations created

**Possible reasons:**
1. Absent employee is not a teacher → Check position field
2. No timetable assigned → Assign timetable in Timetable Library
3. No matching teachers available → Check institution/level fields
4. All potential substitutes are busy at that time

**Solution:**
```bash
# Check logs
cd attendance-service
tail -f attendance-server.log | grep AUTO-SUB
```

### ❌ Invitations not showing

**Check:**
```sql
SELECT * FROM substitution_invitations 
WHERE candidate_employee_id = 'your-employee-id'
ORDER BY created_at DESC;
```

If rows exist but don't show in UI:
- Clear browser cache
- Check browser console for errors
- Verify API endpoint: `/api/substitutions/invitations/mine?status=pending`

### ❌ "Taught" button doesn't add overtime

**Check:**
1. Database constraints on overtime tables
2. Console logs for "INVITATION-RESPOND" errors
3. Verify employee_monthly_summaries table exists

---

## Next Steps

1. ✅ **Test the workflow** with a simple case
2. ✅ **Assign timetables** to all teachers
3. ✅ **Verify employee data** (institution, level, position)
4. ✅ **Train staff** on the new workflow
5. ✅ **Monitor logs** for the first few days

---

## Need Help?

See **`AUTO_SUBSTITUTION_SYSTEM_GUIDE.md`** for:
- Detailed algorithm explanation
- Database schema
- API documentation
- Advanced troubleshooting

---

**Ready to revolutionize your teacher coverage system! 🎉**

