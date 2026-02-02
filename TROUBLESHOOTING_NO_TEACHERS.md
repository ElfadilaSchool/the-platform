# Troubleshooting: "No Teachers Found" in Charts

## Quick Fix

**Both errors are now fixed!** Clear your browser cache and refresh:

1. **Press:** `Ctrl + Shift + Delete` (Windows/Linux) or `Cmd + Shift + Delete` (Mac)
2. **Clear:** Cached images and files
3. **Refresh:** `Ctrl + F5` (hard refresh)

## What Was Fixed

### Issue 1: "exports is not defined" ✅ FIXED
**Found in TWO files:**
- `frontend/components/api.js`
- `frontend/assets/js/translations.js`

**Solution Applied:**
```javascript
// OLD CODE (caused error):
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { ... };
}

// NEW CODE (browser-safe):
if (typeof module !== 'undefined' && typeof module.exports !== 'undefined') {
    try {
        module.exports = { ... };
    } catch (e) {
        // Ignore errors in browser
    }
}
```

### Issue 2: Charts Using Wrong Fields ✅ FIXED

**Chart now uses correct database fields:**

**Institution Chart (Doughnut):**
- ✅ Uses `institution` field (was using non-existent `school` or `institute`)

**Teacher Salary Chart (Bar):**
- ✅ Filters by `position_name` field containing "teacher", "enseignant", or "prof"
- ✅ Groups by `education_level` field (what they teach)
- ✅ Added debug logging to show all position names if no teachers found

## Debugging Steps

### Step 1: Check Console Logs

After refreshing, open Console (F12) and look for:

```javascript
// Should see:
Loaded employees: 15
Sample employee data: { 
  id: "...", 
  position_name: "Teacher", 
  institution: "School A",
  education_level: "Primary",
  base_salary: 50000
}

Updating charts with data...
Teachers found: 8 out of 15 employees
Department chart updated: { labels: ["School A", "School B"], values: [...] }
Salary chart updated: { teacherCount: 8, labels: ["Primary"], values: [...] }
```

### Step 2: If Still Showing "No Teachers"

The console will now show you **all position names** in your system:

```javascript
Teachers found: 0 out of 15 employees
All position names in system: ["Manager", "Secretary", "Driver", ...]
```

**This tells you:**
- What position names exist in your database
- Why teachers aren't being found
- What to look for in the filter

### Step 3: Adjust Filter if Needed

If your position names are different (e.g., "Professeur", "Maître", "Instructeur"), you can add them:

**File:** `frontend/pages/hr-dashboard.html`

**Find this code around line 1168:**
```javascript
const teachers = dashboardData.employees.filter(emp => {
    const position = (emp.position_name || '').toLowerCase();
    return position.includes('teacher') || 
           position.includes('enseignant') || 
           position.includes('prof');
});
```

**Add your position names:**
```javascript
const teachers = dashboardData.employees.filter(emp => {
    const position = (emp.position_name || '').toLowerCase();
    return position.includes('teacher') || 
           position.includes('enseignant') || 
           position.includes('prof') ||
           position.includes('professeur') ||  // Add yours
           position.includes('maître') ||      // Add yours
           position.includes('instructeur');   // Add yours
});
```

## Expected Behavior

### With Teachers in Database:
✅ Institution chart shows salary breakdown by institution
✅ Teacher chart shows teachers grouped by education_level
✅ Console shows: "Teachers found: X out of Y employees"

### Without Teachers in Database:
✅ Institution chart still works (all employees)
✅ Teacher chart shows "No Teachers Found" with helpful message
✅ Console lists all position names to help you identify teachers

## Common Issues

### Issue: Console shows "All position names: []"
**Problem:** Employees don't have positions assigned
**Solution:** 
1. Go to employee management
2. Assign positions to employees
3. Make sure positions include "Teacher" in the name

### Issue: Console shows position names but none match
**Problem:** Position names are in a different language/format
**Solution:** Add those names to the filter (see Step 3 above)

### Issue: Charts still blank
**Problem:** Browser cache not cleared
**Solution:** 
1. Close ALL browser tabs for the site
2. Clear cache again (Ctrl + Shift + Delete)
3. Hard refresh (Ctrl + F5)

### Issue: Employees have no salary data
**Problem:** Salary chart shows 0 values
**Solution:**
1. Check employee_compensations table has base_salary
2. Verify salaries are not null
3. Check console for actual salary values

## Database Check

If charts still don't work, verify your database:

```sql
-- Check employee data
SELECT 
    id,
    first_name,
    last_name,
    position_id,
    institution,
    education_level
FROM employees
LIMIT 5;

-- Check positions
SELECT p.id, p.name
FROM positions p
WHERE LOWER(p.name) LIKE '%teacher%'
   OR LOWER(p.name) LIKE '%enseignant%'
   OR LOWER(p.name) LIKE '%prof%';

-- Check employees with positions
SELECT 
    e.first_name,
    e.last_name,
    p.name as position_name,
    e.institution,
    e.education_level,
    ec.base_salary
FROM employees e
LEFT JOIN positions p ON e.position_id = p.id
LEFT JOIN employee_compensations ec ON e.id = ec.employee_id
WHERE p.name IS NOT NULL;
```

## What the Console Should Show

**Successful Chart Update:**
```
Loaded employees: 15
Sample employee data: { position_name: "Teacher", ... }
Initializing charts...
Department chart initialized successfully
Salary chart initialized successfully
Updating charts with data...
{ employeeCount: 15, hasDepartmentChart: true, hasSalaryChart: true }
Teachers found: 8 out of 15 employees
Department chart updated: { labels: ["School A", "School B"], values: [200000, 350000] }
Salary chart updated: { teacherCount: 8, labels: ["Primary", "Secondary"], values: [120000, 80000] }
```

**If No Teachers:**
```
Loaded employees: 15
Teachers found: 0 out of 15 employees
All position names in system: ["Manager", "Secretary", "Accountant", "Driver"]
No teacher data available. Check that employees have position_name containing "teacher"
```

## Files Modified

1. ✅ `frontend/components/api.js` - Fixed exports error
2. ✅ `frontend/assets/js/translations.js` - Fixed exports error  
3. ✅ `frontend/pages/hr-dashboard.html` - Fixed chart field names + added debugging

---

**Last Updated:** October 21, 2025
**Status:** All errors fixed, charts should work after cache clear

