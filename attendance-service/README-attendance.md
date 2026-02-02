# Attendance Service

A comprehensive attendance management system built with Node.js, Express, and PostgreSQL, featuring master attendance logs, detailed daily views, exception handling, and export capabilities.

## Features

### 📊 Master Monthly Attendance Log
- **Overview Dashboard**: Complete monthly statistics for all employees
- **Advanced Filtering**: Filter by year, month, department, validation status, and employee search
- **Statistics Cards**: Total employees, validated records, pending validation, missing punches
- **Bulk Operations**: Bulk validation, clear late/early minutes, clear missing punches
- **Export**: CSV/XLSX export with validation flags and source information
- **Settings**: Configure grace periods, calculation toggles, and system defaults

### 👤 Daily Attendance Page
- **Employee Details**: Individual employee monthly detailed view with summary statistics
- **Daily Table**: Shows only scheduled days with complete shift information
- **Edit Functionality**: Override missing punches, mark justified absences, validate records
- **Side Panels**: Manage wage changes and overtime requests with full CRUD operations
- **Real-time Calculations**: Late/early minutes with configurable grace periods
- **Audit Trail**: Complete history of changes and overrides

### ⏰ Exception Management
- **Extra Hours Requests**: Employee-facing form to submit overtime/extra hours
- **Approval Workflow**: Admin interface to approve/decline overtime requests
- **File Attachments**: Support for documentation uploads (5MB limit)
- **Status Tracking**: Real-time status updates and notifications
- **Monthly Statistics**: Summary of overtime requests by status

### 🛠 System Features
- **Dual Data Sources**: Calculated vs Validated data with proper source flagging
- **Name Matching**: Advanced employee name matching between raw punches and employee records
- **Currency Support**: Algerian Dinar (DZD) formatting with ar-DZ locale
- **Responsive Design**: Clean, soft theme consistent across all pages
- **Real-time Feedback**: Toast notifications, confirmation modals, loading states
- **Transactional Operations**: Atomic validation and bulk operations

## Database Schema

The system uses an existing PostgreSQL database with the following key tables:

- `employees`: Employee master data
- `raw_punches`: Raw punch data (last name + first name format)
- `attendance_punches`: Processed punches linked to employee IDs
- `comprehensive_monthly_statistics`: Combined view of validated and calculated data
- `employee_monthly_summaries`: Validated attendance storage
- `overtime_requests`: Employee overtime/extra hours requests
- `attendance_exceptions`: Exception requests system
- `employee_salary_adjustments`: Wage changes tracking
- `attendance_settings`: System configuration
- `audit_logs`: Comprehensive audit trail

## Installation

1. **Clone and Setup**
   ```bash
   # Install dependencies
   npm install

   # Create environment file
   cp .env.example .env
   # Edit .env with your database credentials
   ```

2. **Database Setup**
   ```bash
   # Create PostgreSQL database
   createdb attendance_db
   
   # Import the schema
   psql -d attendance_db -f current.sql
   ```

3. **Environment Configuration**
   Edit `.env` file with your settings:
   ```env
   DB_HOST=localhost
   DB_PORT=5432
   DB_NAME=attendance_db
   DB_USER=postgres
   DB_PASSWORD=your_password
   PORT=3000
   ```

4. **Start the Server**
   ```bash
   # Development mode with auto-reload
   npm run dev
   
   # Production mode
   npm start
   ```

## Usage

### Access Points

- **Master Attendance Log**: `http://localhost:3000/master`
- **Daily Attendance**: `http://localhost:3000/daily`
- **Submit Exception**: `http://localhost:3000/submit-exception`
- **Manage Exceptions**: `http://localhost:3000/exceptions`

### API Endpoints

#### Core Attendance
- `GET /api/attendance/monthly` - Monthly attendance data with filtering
- `GET /api/attendance/daily/:employeeId` - Daily records for employee
- `POST /api/attendance/daily/save` - Save day record overrides
- `POST /api/attendance/validate/employee/:employeeId` - Validate employee month
- `POST /api/attendance/validate/bulk` - Bulk validation
- `POST /api/attendance/recalculate/employee/:employeeId` - Recalculate month

#### Overtime & Exceptions
- `POST /api/attendance/overtime/submit` - Submit overtime request
- `GET /api/attendance/overtime/my-requests` - Employee's requests
- `POST /api/attendance/overtime/approve/:requestId` - Approve request
- `POST /api/attendance/overtime/decline/:requestId` - Decline request

#### Settings & Configuration
- `GET /api/attendance/settings` - Get system settings
- `PUT /api/attendance/settings` - Update system settings
- `GET /api/attendance/years` - Available years for filtering

#### Export
- `GET /api/attendance/export` - Export attendance data as CSV/XLSX

### Key Calculations

#### Presence Rule
- A scheduled day counts as **Present** if:
  - At least one punch exists for that day, OR
  - An approved exception indicates presence
- Days without scheduled shifts are excluded from totals

#### Late/Early Calculation
- **Late Minutes** = max(0, actual_entry - scheduled_entry - grace_minutes)
- **Early Minutes** = max(0, scheduled_exit - actual_exit - grace_minutes)
- Grace period is configurable in system settings

#### Multiple Intervals
- **Entry Time**: First IN punch of the first interval
- **Exit Time**: Last OUT punch of the last interval
- Intermediate punches are not used in main calculations

## Configuration

### System Settings
Access via the Settings modal in the Master page or API endpoint:

- **Grace Minutes**: Late/early tolerance (default: 5 minutes)
- **Count Late/Early**: Toggle to include/exclude late/early in statistics
- **Default Work Hours**: Standard work hours per day (default: 8)
- **Auto-validation**: Automatic validation settings

### File Uploads
- **Maximum File Size**: 5MB
- **Supported Formats**: Images (JPEG, PNG, GIF), Documents (PDF, DOC, DOCX, TXT)
- **Storage Location**: `uploads/` directory

## Architecture

### Frontend
- **HTML Pages**: Clean, responsive design with soft theme
- **JavaScript API Client**: Comprehensive API wrapper with error handling
- **Real-time Updates**: Toast notifications and modal confirmations
- **Form Validation**: Client-side and server-side validation

### Backend
- **Express.js Server**: RESTful API with proper error handling
- **PostgreSQL Integration**: Optimized queries with connection pooling
- **File Upload Support**: Multer with type and size validation
- **Audit Logging**: Complete operation tracking

### Data Flow
1. **Raw Data**: Raw punches from time clocks
2. **Calculation**: Processed using timetables and exceptions
3. **Validation**: Final approval and storage in validated tables
4. **Override**: Admin corrections with audit trails

## Security

- **Input Validation**: All inputs validated and sanitized
- **File Upload Security**: Type and size restrictions
- **SQL Injection Prevention**: Parameterized queries
- **Error Handling**: No sensitive information in error messages
- **Audit Trail**: Complete operation logging

## Troubleshooting

### Common Issues

1. **Database Connection Error**
   - Check database credentials in `.env`
   - Ensure PostgreSQL is running
   - Verify database exists and schema is imported

2. **File Upload Fails**
   - Check file size (max 5MB)
   - Verify file type is supported
   - Ensure uploads directory exists and is writable

3. **Employee Name Matching Issues**
   - System automatically handles different name formats
   - Raw punches use "last name + first name" format
   - Employee table uses separate first_name/last_name fields

### Debug Mode
Set `NODE_ENV=development` in `.env` for detailed error messages and stack traces.

## Development

### Project Structure
```
attendance-service/
├── attendance-server.js      # Main server file
├── attendance-routes.js      # Core attendance API routes
├── attendance-extra-routes.js # Extended features routes
├── attendance-export-routes.js # Export functionality
├── attendance-api.js         # Frontend API client
├── attendance-master.html    # Master attendance log page
├── daily-attendance.html     # Daily attendance detail page
├── submit-exception.html     # Exception submission form
├── exceptions.html          # Exception management (existing)
├── exceptions-routes.js     # Exception API routes (existing)
├── current.sql             # Database schema
├── package.json           # Dependencies and scripts
└── README-attendance.md   # This file
```

### Adding Features
1. Add API routes to appropriate route file
2. Update frontend API client
3. Add UI components to HTML pages
4. Test thoroughly with real data

## License

MIT License - See LICENSE file for details.

## Support

For issues or questions:
1. Check this README for common solutions
2. Review the database schema in `current.sql`
3. Check server logs for detailed error messages
4. Verify all dependencies are installed correctly