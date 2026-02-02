# Troubleshooting: Daily Attendance Page Not Showing Pending Status

## 🔍 **Why You Don't See Changes Yet**

The daily attendance page gets its data from the backend API. If you don't see Pending status, it means one of these steps is missing:

## ✅ **Step-by-Step Checklist**

### 1. **Database Migration** ✅ 
```sql
-- Run this in your PostgreSQL database:
\i database/add_pending_status_minimal.sql
```

**Verify it worked:**
```sql
-- Check if column exists:
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'attendance_overrides' AND column_name = 'pending_status';

-- Should return: pending_status
```

### 2. **Restart Attendance Service** ⚠️ **MOST LIKELY MISSING**
```bash
# Stop the attendance service
# Then restart it to load the new API routes

# If using PM2:
pm2 restart attendance-service

# If running manually:
# Stop with Ctrl+C, then restart:
cd attendance-service
npm start
```

### 3. **Clear Browser Cache** ⚠️ **OFTEN FORGOTTEN**
- **Hard refresh**: `Ctrl+F5` (Windows) or `Cmd+Shift+R` (Mac)
- **Or clear cache**: Browser Settings → Clear browsing data → Cached files

### 4. **Check for Single Punch Data**
You need employees with **exactly 1 punch** on a day to see Pending status.

**Check if you have single punch cases:**
```sql
SELECT 
  employee_name,
  DATE(punch_time) as punch_date,
  COUNT(*) as punch_count
FROM raw_punches 
WHERE DATE(punch_time) >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY employee_name, DATE(punch_time)
HAVING COUNT(*) = 1
ORDER BY punch_date DESC;
```

If this returns **no rows**, you won't see any Pending status because there are no partial cases.

## 🔧 **Quick Test**

Run this test script to verify everything:

```bash
# Update the database credentials in test_pending_status.js first
node test_pending_status.js
```

## 🎯 **Expected Behavior**

Once everything is working, you should see:

### **Daily Attendance Page:**
- Days with **2+ punches** → Status: "Present" (green)
- Days with **1 punch** → Status: "Pending" (orange) 
- Days with **0 punches** → Status: "Absent" (red)

### **Master Attendance Page:**
- New **"Pending"** column with orange badges
- Clickable badges to manage pending cases

## 🚨 **Common Issues**

### **Issue 1: Service Not Restarted**
**Symptom:** No Pending column in master page, no Pending status in daily page
**Solution:** Restart attendance service

### **Issue 2: Browser Cache**
**Symptom:** Old UI without Pending column
**Solution:** Hard refresh or clear cache

### **Issue 3: No Single Punch Data**
**Symptom:** Everything looks normal but no Pending status visible
**Solution:** This is normal if all employees have complete attendance (0 or 2+ punches)

### **Issue 4: Database Migration Not Run**
**Symptom:** API errors in browser console
**Solution:** Run the database migration script

## 🔍 **Debug Steps**

### 1. **Check Browser Console**
Open Developer Tools (F12) → Console tab
Look for any red error messages when loading the daily attendance page.

### 2. **Check Network Tab**
Developer Tools → Network tab → Reload page
Look for the API call to `/api/attendance/daily/[employeeId]`
- **Status 200**: Good, check the response data
- **Status 404/500**: Service not running or database issue

### 3. **Check API Response**
In the Network tab, click on the daily attendance API call and check the response.
You should see `display_status: "Pending"` for single punch days.

### 4. **Verify Service is Running**
```bash
# Check if attendance service is running on port 3001 (or your port)
curl http://localhost:3001/api/attendance/pending/stats

# Should return JSON with pending statistics
```

## 📞 **Still Not Working?**

If you've followed all steps and still don't see changes:

1. **Check the exact error** in browser console
2. **Verify database connection** - can the service connect to DB?
3. **Check service logs** - any startup errors?
4. **Confirm port numbers** - is the service running on the expected port?

## 🎯 **Quick Fix Commands**

```bash
# 1. Database migration
psql -d your_database -f database/add_pending_status_minimal.sql

# 2. Restart service (adjust path as needed)
cd attendance-service
npm start

# 3. Test API
curl http://localhost:3001/api/attendance/pending/stats
```

The most common issue is **forgetting to restart the attendance service** after making backend changes. The service needs to restart to load the new API routes and database logic.
