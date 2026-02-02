# Error Analysis: tasks.html Issues

## Error Summary

You're experiencing several errors when loading `tasks.html` through an iframe. Here's a breakdown of each error and how to fix them:

---

## 1. Socket.IO 404 Error

**Errors:**
```
GET http://127.0.0.1:5508/socket.io/socket.io.js net::ERR_ABORTED 404 (Not Found)
Refused to execute script from 'http://127.0.0.1:5508/socket.io/socket.io.js' 
because its MIME type ('text/html') is not executable
```

**Root Cause:**
- You're viewing the page through Live Server (port 5508)
- The script tag `<script src="/socket.io/socket.io.js"></script>` tries to load from the Live Server origin (127.0.0.1:5508), which doesn't have Socket.IO
- Socket.IO is served by your backend service on port 3020 (HR Tasks) or 3004 (Task Service)

**Fix:**
The code in `tasks.html` already has a fallback mechanism (lines 680-692) that dynamically loads Socket.IO from the correct backend. However, the initial script tag on line 401 causes the error.

**Solution:** Remove or comment out line 401 in `tasks.html`:
```html
<!-- <script src="/socket.io/socket.io.js"></script> -->
```

---

## 2. GET /employees 404 Error

**Error:**
```
GET http://localhost:3004/employees? 404 (Not Found)
getEmployees @ main.js:294
```

**Root Cause:**
- `hr_tasks/hr_tasks/public/main.js` line 23 calls `TaskAPI._request('/employees?...')` 
- This requests `http://localhost:3004/employees` (your Task Service backend)
- The Task Service DOES have an `/employees` endpoint (hr_tasks/hr_tasks/index.js line 577-607)
- However, there might be a conflict with authentication or the service isn't running

**Fix Options:**

**Option A:** Ensure the HR Tasks service (port 3020) is running:
```bash
cd hr_tasks/hr_tasks
TASK_SERVICE_PORT=3020 node index.js
```

**Option B:** The frontend might be hitting the wrong service. Check if the API_BASE is correctly set in `tasks.html` (line 466).

---

## 3. GET /tasks 401 Unauthorized

**Error:**
```
GET http://localhost:3004/tasks 401 (Unauthorized)
```

**Root Cause:**
- The request lacks proper authentication
- Looking at the code, `TaskAPI._request` on line 286-291 checks for `jwt_token` in localStorage
- Either the token is missing or invalid

**Fix:**
1. Ensure you're logged in before accessing tasks.html
2. Check if `localStorage.getItem('jwt_token')` returns a valid token
3. Verify the token hasn't expired

---

## 4. GET /api/instructions/employee/{id} 404

**Error:**
```
GET http://127.0.0.1:5508/api/instructions/employee/17eab49d-0e03-4c68-bfc4-69999f93c5f3 404 (Not Found)
```

**Root Cause:**
- The request is going to Live Server (127.0.0.1:5508) instead of the backend
- This endpoint should be hitting the HR Tasks backend

**Fix:**
Ensure the instructions route is properly registered in `hr_tasks/hr_tasks/index.js`. Looking at line 49, it's mounted at `/api/instructions`, and line 43 imports the instructions routes. Verify the route file exists.

---

## 5. Multiple Socket.IO Errors

**Additional Error:**
```
tasks.html?embed=1:691  GET http://127.0.0.1:5508/socket.io/socket.io.js net::ERR_ABORTED 404
```

This is the same as error #1 - it's the fallback mechanism trying to load Socket.IO.

---

## Quick Fix Checklist

1. **Fix Socket.IO Loading:**
   - Open `hr_tasks/hr_tasks/public/tasks.html`
   - Comment out or remove line 401: `<script src="/socket.io/socket.io.js"></script>`
   - The dynamic loading mechanism (lines 680-692) will handle it correctly

2. **Verify Services Are Running:**
   ```bash
   # Check which ports are in use
   netstat -ano | findstr :3004  # Task Service
   netstat -ano | findstr :3020  # HR Tasks Service
   ```

3. **Check Authentication:**
   - Open browser console
   - Run: `localStorage.getItem('jwt_token')`
   - If null or invalid, log in again

4. **Verify Backend Routes:**
   - HR Tasks Service should be running on port 3020
   - Check console output when starting the service

---

## Services Configuration

Based on your `start-services.sh`:
- **Task Service:** Port 3004
- **HR Tasks Service:** Port 3020 (TASK_SERVICE_PORT from .env, defaults to 3020)
- **Frontend:** Served via Live Server on port 5508

The HR Tasks service (`hr_tasks/hr_tasks/index.js`) serves the tasks.html page and provides all the API endpoints including Socket.IO.

---

## Recommended Approach

1. **Don't use Live Server for tasks.html**
   - Access it directly through the HR Tasks backend: `http://localhost:3020/`
   - Or use the frontend wrapper: `http://localhost:8080/pages/tasks.html`

2. **Or fix the iframe approach:**
   - The iframe in `frontend/pages/tasks.html` points to `../../hr_tasks/hr_tasks/public/tasks.html?embed=1`
   - This should work if you're running the HR Tasks service on port 3020
   - But accessing via Live Server causes all these issues

---

## Testing

After making the changes, test by:

1. Starting the HR Tasks service:
   ```bash
   cd hr_tasks/hr_tasks
   node index.js
   ```

2. Access directly: `http://localhost:3020/`

3. Or through frontend: Start your frontend server and access `http://localhost:8080/pages/tasks.html`

---

## Additional Notes

- The port mismatch (Live Server 5508 vs Backend 3004/3020) is the main cause
- Socket.IO needs to load from the same origin as the WebSocket connection
- The 401 error suggests missing/invalid authentication token
- The instructions endpoint might not be implemented or registered correctly






