# Port Configuration Fix Summary

## Problem

The HR Tasks application was configured to use port **3004** (Task Service port) but actually runs on port **3020** (HR Tasks Service port). This caused all API requests to fail.

## Root Cause

Multiple files had hardcoded references to `http://localhost:3004` instead of `http://localhost:3020`.

## Files Fixed

### 1. hr_tasks/hr_tasks/public/main.js
- Changed `TASKS_API` constant from `http://localhost:3004` to `http://localhost:3020`
- Updated 2 fetch calls to use `TASKS_API` variable

### 2. hr_tasks/hr_tasks/public/tasks.html  
- Changed `window.API_BASE` default from `http://localhost:3004` to `http://localhost:3020`
- Changed Socket.IO fallback URL from `http://localhost:3004` to `http://localhost:3020`
- Replaced all 8 hardcoded `localhost:3004` references with `localhost:3020`

### 3. hr_tasks/hr_tasks/public/tsk.html
- Replaced 1 hardcoded `localhost:3004` reference with `localhost:3020`

## Verification

```bash
# Before: Found references to localhost:3004
grep "localhost:3004" hr_tasks/hr_tasks/public/

# After: No references to localhost:3004
✅ grep "localhost:3004" hr_tasks/hr_tasks/public/
# Result: No matches found

# After: All references point to localhost:3020
✅ grep "localhost:3020" hr_tasks/hr_tasks/public/
# Result: 40 matches across 16 files
```

## Service Architecture

Your HR Operations Platform uses:

- **Task Service** (generic): Port 3004
- **HR Tasks Service** (specific app): Port 3020 ← **This is what we fixed**

These are DIFFERENT services:
- Task Service = Microservice for general task management
- HR Tasks Service = Standalone application with its own frontend and backend

## Testing

After these changes, accessing `tasks.html` should:

1. ✅ Load Socket.IO from `http://localhost:3020/socket.io/socket.io.js`
2. ✅ Successfully fetch `/employees` from `http://localhost:3020/employees`
3. ✅ Successfully fetch `/tasks` from `http://localhost:3020/tasks`
4. ✅ Successfully fetch `/api/instructions/employee/{id}` from `http://localhost:3020/api/instructions/employee/{id}`
5. ✅ Connect to Socket.IO server on port 3020
6. ✅ All notifications work properly

## How to Run

**Start the HR Tasks service:**
```bash
cd hr_tasks/hr_tasks
node index.js
```

**Access the application:**
```
http://localhost:3020/
```

All errors should now be resolved! ✅






