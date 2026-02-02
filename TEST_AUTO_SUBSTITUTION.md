# 🧪 How to Test Auto-Substitution System

## Quick Test - 5 Minutes

### **Test 1: Check Prerequisites**

```bash
# In attendance-service directory
cd attendance-service

# Run the test SQL queries
psql -U postgres -d hr_operations -f ../test-auto-substitution.sql
```

**What to look for:**
- ✅ At least 2-3 teachers show up
- ✅ Teachers have `institution` and `education_level` filled
- ✅ Teachers have timetables assigned
- ✅ Tables exist (substitution_requests, substitution_invitations)

---

### **Test 2: Start Server with Logging**

```bash
# Start the attendance service
node attendance-server.js

# In another terminal, watch the logs
tail -f attendance-server.log | grep -E "AUTO-SUB|INVITATION-RESPOND|EXCEPTION-APPROVAL"
```

---

### **Test 3: Create & Approve a Leave Request**

#### **Step A: Create Leave Request (as Teacher)**

1. **Open browser**: http://localhost:5500/pages/submit-exception.html
2. **Fill form**:
   - Employee: (Your teacher account)
   - Exception Type: **Leave Request**
   - Date: Tomorrow's date
   - Leave Type: Annual Leave
   - Reason: "Testing auto-substitution"
3. **Click Submit**

#### **Step B: Approve the Request (as Admin)**

1. **Go to**: http://localhost:5500/pages/exceptions.html
2. **Find your pending request**
3. **Click Approve**

#### **Step C: Watch the Console Output**

You should see:
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

**✅ SUCCESS INDICATOR:** You see "Successfully created X invitation(s)" with X > 0

---

### **Test 4: Check Database**

```sql
-- Check if substitution request was created
SELECT * FROM substitution_requests 
ORDER BY created_at DESC 
LIMIT 1;

-- Check if invitations were created
SELECT 
    si.id,
    si.date,
    si.start_time,
    si.end_time,
    si.minutes,
    si.status,
    e.first_name || ' ' || e.last_name AS candidate_name
FROM substitution_invitations si
JOIN employees e ON si.candidate_employee_id = e.id
ORDER BY si.created_at DESC
LIMIT 10;
```

**✅ SUCCESS INDICATOR:** You see rows in both tables

---

### **Test 5: Check Invitations in UI**

1. **Login as a different teacher** (not the one who requested leave)
2. **Go to**: Submit Exception → **Pending Extra Hours** tab
3. **Scroll down to**: "Substitution Invitations" section

**✅ SUCCESS INDICATOR:** You see invitation cards like:

```
┌────────────────────────────────────────┐
│ 📅 2025-03-16 09:00 - 11:00           │
│ ⏱️  Duration: 2.0 hours (120 minutes)  │
│                    [Accept] [Deny]     │
└────────────────────────────────────────┘
```

---

### **Test 6: Test the Workflow**

#### **Accept Invitation**
1. Click **[Accept]** button
2. Check console logs:
   ```
   🔄 [INVITATION-RESPOND] Action: accept by user user-123
   ✓ [INVITATION-RESPOND] Invitation accepted
   ```
3. **Buttons change to**: [Drop] [Mark Taught]

#### **Mark as Taught**
1. Click **[Mark Taught]** button
2. Check console logs:
   ```
   🔄 [INVITATION-RESPOND] Action: taught by user user-123
   ✓ [INVITATION-RESPOND] Marked as taught, 2.00 hours added to overtime
   ```
3. Check your overtime:
   ```sql
   SELECT * FROM overtime_requests 
   WHERE employee_id = 'your-employee-id'
   ORDER BY created_at DESC
   LIMIT 1;
   
   SELECT * FROM employee_overtime_hours
   WHERE employee_id = 'your-employee-id'
   ORDER BY date DESC
   LIMIT 1;
   ```

**✅ SUCCESS INDICATOR:** Overtime records created with correct hours

---

## 🔍 Troubleshooting Tests

### ❌ **Test Fails: No invitations created**

**Check 1: Is employee a teacher?**
```sql
SELECT e.first_name, e.last_name, p.name as position
FROM employees e
JOIN positions p ON e.position_id = p.id
WHERE e.id = 'employee-who-requested-leave';
```
→ Position must contain "teacher"

**Check 2: Does teacher have timetable?**
```sql
SELECT et.*, t.name
FROM employee_timetables et
JOIN timetables t ON et.timetable_id = t.id
WHERE et.employee_id = 'employee-id'
  AND et.effective_from <= CURRENT_DATE
  AND (et.effective_to IS NULL OR et.effective_to >= CURRENT_DATE);
```
→ Must return at least 1 row

**Check 3: Check console for errors**
Look for:
- "⚠️  [AUTO-SUB] No timetable found for absent teacher"
- "❌ [AUTO-SUB] Error generating substitutions"

---

### ❌ **Test Fails: Invitations exist in DB but don't show in UI**

**Check 1: Browser console**
```
F12 → Console tab
Look for: "Invitations load error"
```

**Check 2: API endpoint**
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:3000/api/substitutions/invitations/mine?status=pending
```

**Check 3: Clear cache**
- Hard refresh: Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)

---

### ❌ **Test Fails: "Taught" doesn't add overtime**

**Check logs for errors:**
```bash
grep "INVITATION-RESPOND" attendance-server.log | tail -20
```

**Check if employee_monthly_summaries exists:**
```sql
SELECT * FROM employee_monthly_summaries LIMIT 1;
```

If table doesn't exist, run:
```bash
psql -U postgres -d hr_operations -f ../database/add_missing_tables.sql
```

---

## 📊 Success Criteria Checklist

After running all tests, you should have:

- [x] Console shows "Successfully created X invitation(s)"
- [x] Database has rows in `substitution_requests`
- [x] Database has rows in `substitution_invitations`
- [x] UI shows invitations in "Pending Extra Hours" tab
- [x] Can accept/deny invitations
- [x] "Taught" creates overtime records
- [x] Overtime shows in employee's overtime tab

**If all checked ✅ → System is working perfectly!**

---

## 🎯 Real-World Test Scenario

### Scenario: Teacher John takes 2 days off

1. **John (Teacher A)** submits leave: March 15-16
2. **Admin approves** the leave
3. **System finds**:
   - Mary (Teacher B) - Free on March 15, 9-11am
   - Bob (Teacher C) - Free on March 15, 2-4pm
   - Alice (Teacher D) - Free on March 16, all day
4. **Invitations sent**:
   - Mary gets: "March 15, 9-11am (2h)"
   - Bob gets: "March 15, 2-4pm (2h)"
   - Alice gets: "March 16, 9-11am (2h)" and "March 16, 2-4pm (2h)"
5. **Mary accepts** her slot → Shows as accepted
6. **Bob denies** his slot → Removed from his view
7. **Alice accepts both** her slots
8. **After teaching**, Alice clicks "Taught" on both → Gets 4 hours overtime

**Expected Result:**
- March 15, 9-11: Covered by Mary ✅
- March 15, 2-4: Still pending (Bob denied) ⚠️
- March 16, 9-11 & 2-4: Covered by Alice ✅

---

## 🚀 Quick Verification Command

Run this one-liner to check everything:

```bash
echo "=== CHECKING AUTO-SUBSTITUTION SYSTEM ===" && \
psql -U postgres -d hr_operations -c "SELECT COUNT(*) as teacher_count FROM employees e JOIN positions p ON e.position_id = p.id WHERE p.name ILIKE '%teacher%';" && \
psql -U postgres -d hr_operations -c "SELECT COUNT(*) as with_timetable FROM employee_timetables WHERE effective_from <= CURRENT_DATE AND (effective_to IS NULL OR effective_to >= CURRENT_DATE);" && \
psql -U postgres -d hr_operations -c "SELECT COUNT(*) as substitution_requests FROM substitution_requests;" && \
psql -U postgres -d hr_operations -c "SELECT COUNT(*) as invitations FROM substitution_invitations;" && \
echo "=== If all counts > 0, system is set up! ==="
```

---

## 📞 Still Not Working?

1. **Check server logs**: `grep ERROR attendance-server.log`
2. **Verify tables exist**: Run `test-auto-substitution.sql`
3. **Test simple case**: One teacher, one day, one slot
4. **Check browser console**: Look for API errors

**Need more help?** Check `AUTO_SUBSTITUTION_SYSTEM_GUIDE.md` for detailed debugging.

