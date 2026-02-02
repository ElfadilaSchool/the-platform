# 📧 Invitations Management System - Complete Guide

## 🎯 Overview

The new **Sent Invitations** tab provides comprehensive management of all substitution invitations sent to teachers. This admin interface allows you to track, filter, and manage invitations with full visibility into the substitution process.

## 🚀 Features

### ✅ **Complete Invitation Tracking**
- **Date & Time**: When the substitution is needed
- **Absent Teacher**: Who needs coverage
- **Invited Teacher**: Who was invited to substitute
- **Duration**: How long the substitution is for
- **Status**: Current state of the invitation
- **Response Date**: When the teacher responded
- **Actions**: Delete invitations when needed

### ✅ **Advanced Filtering**
- **Status Filter**: Pending, Accepted, Taught, Denied, Dropped
- **Date Filter**: Filter by specific date
- **Teacher Filter**: Filter by specific teacher
- **Real-time Updates**: Filters apply instantly

### ✅ **Statistics Dashboard**
- **Pending**: Invitations waiting for response
- **Accepted**: Invitations accepted by teachers
- **Taught**: Completed substitutions
- **Denied**: Rejected invitations

### ✅ **Pagination**
- **10 items per page** (configurable)
- **Navigation controls** for large datasets
- **Item count display** showing current range

### ✅ **Manual Management**
- **Delete invitations** that are no longer needed
- **Automatic removal** from teacher's view when deleted
- **Protection** against deleting accepted/taught invitations

## 🖥️ How to Use

### **1. Access the Interface**

1. Go to **Submit Exception** page
2. Click on the **"Sent Invitations"** tab
3. You'll see the complete invitations management interface

### **2. View Invitations**

The main table shows all invitations with:
- **Date & Time**: `2025-01-15` `09:00 - 11:00`
- **Absent Teacher**: `John Doe`
- **Invited Teacher**: `Jane Smith`
- **Duration**: `2.0h (120m)`
- **Status**: Color-coded badges
- **Response Date**: `2025-01-14` or `-` if pending
- **Actions**: Delete button (trash icon)

### **3. Filter Invitations**

Use the filter controls at the top:

**Status Filter:**
- `All Status` - Show all invitations
- `Pending` - Show only pending invitations
- `Accepted` - Show only accepted invitations
- `Taught` - Show only completed substitutions
- `Denied` - Show only denied invitations
- `Dropped` - Show only dropped invitations

**Date Filter:**
- Select a specific date to see invitations for that day
- Leave empty to show all dates

**Teacher Filter:**
- Select a specific teacher to see their invitations
- Leave empty to show all teachers

**Refresh Button:**
- Click to reload all data from the server

### **4. Manage Invitations**

**Delete Invitations:**
1. Click the trash icon (🗑️) next to any invitation
2. Confirm the deletion in the popup
3. The invitation will be removed from both admin and teacher views

**Note**: You cannot delete:
- ✅ **Accepted** invitations (teacher has committed)
- ✅ **Taught** invitations (work has been completed)

You can delete:
- ❌ **Pending** invitations (no response yet)
- ❌ **Denied** invitations (teacher declined)
- ❌ **Dropped** invitations (teacher dropped after accepting)

### **5. Monitor Statistics**

The statistics cards show real-time counts:
- **Blue Card**: Pending invitations
- **Green Card**: Accepted invitations  
- **Gray Card**: Taught (completed) invitations
- **Red Card**: Denied invitations

## 🔧 Technical Details

### **API Endpoints**

**Get All Invitations:**
```
GET /api/substitutions/invitations/all
Query Parameters:
- status: Filter by status
- date: Filter by date (YYYY-MM-DD)
- teacher_id: Filter by teacher ID
- page: Page number (default: 1)
- limit: Items per page (default: 50)
```

**Delete Invitation:**
```
DELETE /api/substitutions/invitations/:id
```

**Get Statistics:**
```
GET /api/substitutions/invitations/stats
```

### **Database Schema**

The system uses these tables:
- `substitution_requests` - The original substitution requests
- `substitution_invitations` - Individual invitations sent to teachers
- `employees` - Teacher information

### **Status Flow**

```
Pending → Accepted → Taught
   ↓         ↓
 Denied   Dropped → Pending
```

## 🚨 Troubleshooting

### **No Invitations Showing**

1. **Check if substitution system is working:**
   ```bash
   node test-substitution-fix.js
   ```

2. **Check if tables exist:**
   ```sql
   SELECT COUNT(*) FROM substitution_invitations;
   ```

3. **Check if invitations were created:**
   ```sql
   SELECT si.*, sr.date, sr.start_time, sr.end_time
   FROM substitution_invitations si
   JOIN substitution_requests sr ON si.request_id = sr.id
   ORDER BY si.created_at DESC;
   ```

### **Filters Not Working**

1. **Check browser console** for JavaScript errors
2. **Verify API endpoints** are responding:
   ```bash
   curl -H "Authorization: Bearer YOUR_TOKEN" \
        http://localhost:3001/api/substitutions/invitations/all
   ```

### **Delete Not Working**

1. **Check invitation status** - only pending/denied/dropped can be deleted
2. **Check authentication** - ensure you're logged in as admin
3. **Check network** - ensure API calls are reaching the server

## 📊 Example Scenarios

### **Scenario 1: Teacher Takes Leave**

1. Teacher submits leave request for `2025-01-15`
2. Admin approves the request
3. System automatically creates substitution request
4. System finds teachers with no schedule for that time
5. System sends invitations to all matching teachers
6. Admin can see all invitations in "Sent Invitations" tab
7. Teachers respond (accept/deny)
8. Admin can track responses and completed work

### **Scenario 2: Managing Overdue Invitations**

1. Admin opens "Sent Invitations" tab
2. Filters by "Pending" status
3. Sees invitations that haven't been responded to
4. Can delete old invitations that are no longer relevant
5. Teachers will no longer see deleted invitations

### **Scenario 3: Tracking Substitution Coverage**

1. Admin filters by "Accepted" status
2. Sees which teachers have committed to substitutions
3. Can monitor if they've marked work as "Taught"
4. Can track completion rates and teacher availability

## 🎉 Benefits

- **Full Visibility**: See all substitution activity in one place
- **Easy Management**: Filter, sort, and manage invitations efficiently
- **Real-time Updates**: Statistics and data update automatically
- **Teacher Protection**: Can't accidentally delete committed work
- **Audit Trail**: Complete history of all substitution activities
- **Performance**: Paginated data loads quickly even with many invitations

## 🔄 Integration

This system integrates seamlessly with:
- **Auto-Substitution System**: Automatically creates invitations
- **Teacher Interface**: Teachers see invitations in "Pending Extra Hours"
- **Exception System**: Triggered by approved leave/holiday requests
- **Overtime System**: Completed substitutions create overtime records

The invitations management system provides the missing piece for complete substitution workflow management! 🎯

