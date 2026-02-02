// Attendance Service API Client
// Extends the existing API object with attendance-specific methods

// Ensure API object exists
if (typeof API === 'undefined') {
    window.API = {};
}

// Authentication token management (should be handled by auth.js)
const getAuthToken = () => {
    return localStorage.getItem('token') || sessionStorage.getItem('token');
};

// Determine API base URL with sensible defaults for dev
if (typeof window !== 'undefined' && !window.API_BASE_URL) {
    // If running via Live Server (550x), point directly to attendance service
    if (location.hostname === '127.0.0.1' || location.hostname === 'localhost') {
        window.API_BASE_URL = 'http://localhost:3000'; // Direct connection to attendance service
        console.log('API_BASE_URL set to:', window.API_BASE_URL);
    }
}

let makeApiCall = async (url, options = {}) => {
    const token = getAuthToken();
    const baseUrl = typeof API_BASE_URL !== 'undefined' ? API_BASE_URL : window.API_BASE_URL;
    const fullUrl = url.startsWith('http') ? url : `${baseUrl}${url}`;

    console.log('makeApiCall - baseUrl:', baseUrl);
    console.log('makeApiCall - url:', url);
    console.log('makeApiCall - fullUrl:', fullUrl);
    console.log('makeApiCall - token:', token ? 'present' : 'missing');

    const config = {
        headers: {
            'Content-Type': 'application/json',
            ...(token && { 'Authorization': `Bearer ${token}` }),
            ...options.headers
        },
        ...options
    };

    try {
        const response = await fetch(fullUrl, config);

        if (response.status === 401) {
            // Handle unauthorized - use authManager for proper logout and redirect
            if (typeof window.authManager !== 'undefined') {
                window.authManager.logout();
            } else {
                // Fallback: redirect to frontend login
                window.location.href = '/frontend/index.html';
            }
            return;
        }

        // Some 404s from Live Server return HTML; only parse JSON when appropriate
        const contentType = response.headers.get('content-type') || '';
        const data = contentType.includes('application/json') ? await response.json() : await response.text();

        if (!response.ok) {
            const message = typeof data === 'string' && data.startsWith('<!DOCTYPE')
                ? `HTTP ${response.status}`
                : (data.error || `HTTP ${response.status}`);
            throw new Error(message);
        }

        return data;
    } catch (error) {
        console.error('API call error:', error);
        throw error;
    }
};

// ============================================================================
// MASTER ATTENDANCE LOG API METHODS
// ============================================================================

API.getMonthlyAttendance = async (params = {}) => {
    const queryString = new URLSearchParams(params).toString();
    return await makeApiCall(`/api/attendance/monthly?${queryString}`);
};

API.getAvailableYears = async () => {
    return await makeApiCall('/api/attendance/years');
};

API.validateEmployeeMonth = async (employeeId, year, month) => {
    return await makeApiCall(`/api/attendance/validate/employee/${employeeId}`, {
        method: 'POST',
        body: JSON.stringify({ year: parseInt(year), month: parseInt(month) })
    });
};

API.bulkValidateEmployees = async (params) => {
    return await makeApiCall('/api/attendance/validate/bulk', {
        method: 'POST',
        body: JSON.stringify(params)
    });
};

API.bulkClearLate = async (params) => {
    return await makeApiCall('/api/attendance/bulk/clear-late', {
        method: 'POST',
        body: JSON.stringify(params)
    });
};

API.bulkClearEarly = async (params) => {
    return await makeApiCall('/api/attendance/bulk/clear-early', {
        method: 'POST',
        body: JSON.stringify(params)
    });
};

API.bulkClearMissingPunches = async (params) => {
    return await makeApiCall('/api/attendance/bulk/clear-missing', {
        method: 'POST',
        body: JSON.stringify(params)
    });
};

// ============================================================================
// DAILY ATTENDANCE API METHODS
// ============================================================================

API.getEmployeeDailyAttendance = async (employeeId, year, month) => {
    // Get user's timezone
    const userTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    return await makeApiCall(`/api/attendance/daily/${employeeId}?year=${year}&month=${month}&timezone=${encodeURIComponent(userTimezone)}`);
};

API.getEmployeeDetails = async (employeeId) => {
    return await makeApiCall(`/api/attendance/employee/${employeeId}`);
};

API.getCurrentEmployee = async () => {
    return await makeApiCall('/api/attendance/current-employee');
};

API.saveDayRecord = async (data) => {
    return await makeApiCall('/api/attendance/daily/save', {
        method: 'POST',
        body: JSON.stringify(data)
    });
};

API.revertDayToCalculated = async (employeeId, date) => {
    return await makeApiCall(`/api/attendance/daily/revert/${employeeId}/${date}`, {
        method: 'POST'
    });
};

API.recalculateEmployeeMonth = async (employeeId, year, month) => {
    return await makeApiCall(`/api/attendance/recalculate/employee/${employeeId}`, {
        method: 'POST',
        body: JSON.stringify({ year: parseInt(year), month: parseInt(month) })
    });
};

// ============================================================================
// WAGE CHANGES API METHODS
// ============================================================================

API.getEmployeeWageChanges = async (employeeId, year, month) => {
    let url = `/api/attendance/wage-changes/employee/${employeeId}`;
    if (year && month) {
        url += `?year=${year}&month=${month}`;
    }
    return await makeApiCall(url);
};

API.createWageChange = async (data) => {
    return await makeApiCall('/api/attendance/wage-changes', {
        method: 'POST',
        body: JSON.stringify(data)
    });
};

API.updateWageChange = async (id, data) => {
    return await makeApiCall(`/api/attendance/wage-changes/${id}`, {
        method: 'PUT',
        body: JSON.stringify(data)
    });
};

API.deleteWageChange = async (id) => {
    return await makeApiCall(`/api/attendance/wage-changes/${id}`, {
        method: 'DELETE'
    });
};

// ============================================================================
// OVERTIME/EXCEPTION REQUESTS API METHODS
// ============================================================================

API.submitOvertimeRequest = async (data) => {
    return await makeApiCall('/api/attendance/overtime/submit', {
        method: 'POST',
        body: JSON.stringify(data)
    });
};

API.getMyOvertimeRequests = async (params = {}) => {
    const queryString = new URLSearchParams(params).toString();
    return await makeApiCall(`/api/attendance/overtime/my-requests?${queryString}`);
};

API.getMyMonthlyOvertimeStats = async (year, month) => {
    return await makeApiCall(`/api/attendance/overtime/my-stats/${year}/${month}`);
};

API.getEmployeeOvertimeRequests = async (employeeId, year, month) => {
    let url = `/api/attendance/overtime/employee/${employeeId}`;
    if (year && month) {
        url += `?year=${year}&month=${month}`;
    }
    return await makeApiCall(url);
};

// Recorded overtime hours (from employee_overtime_hours)
API.getEmployeeOvertimeHours = async (employeeId, year, month) => {
    let url = `/api/attendance/overtime-hours/employee/${employeeId}`;
    if (year && month) {
        url += `?year=${year}&month=${month}`;
    }
    return await makeApiCall(url);
};

API.getOvertimeRequestDetails = async (requestId) => {
    return await makeApiCall(`/api/overtime/${requestId}`);
};

API.createOvertimeRequest = async (data) => {
    return await makeApiCall('/api/attendance/overtime/submit', {
        method: 'POST',
        body: JSON.stringify(data)
    });
};

API.updateOvertimeRequest = async (id, data) => {
    return await makeApiCall(`/api/overtime/${id}`, {
        method: 'PUT',
        body: JSON.stringify(data)
    });
};

API.approveOvertimeRequest = async (id) => {
    return await makeApiCall(`/api/attendance/overtime/approve/${id}`, {
        method: 'POST'
    });
};

API.declineOvertimeRequest = async (id) => {
    return await makeApiCall(`/api/attendance/overtime/decline/${id}`, {
        method: 'POST'
    });
};

API.deleteOvertimeRequest = async (id) => {
    return await makeApiCall(`/api/attendance/overtime/${id}`, {
        method: 'DELETE'
    });
};

API.addOvertimeAdmin = async (data) => {
    // Normalize payload: backend expects 'hours'; UI may send 'requested_hours'
    const payload = { ...data };
    if (payload.hours == null && payload.requested_hours != null) {
        payload.hours = payload.requested_hours;
        delete payload.requested_hours;
    }
    return await makeApiCall('/api/attendance/overtime/add-admin', {
        method: 'POST',
        body: JSON.stringify(payload)
    });
};

// ============================================================================
// SETTINGS API METHODS
// ============================================================================

API.getAttendanceSettings = async () => {
    return await makeApiCall('/api/attendance/settings');
};

API.updateAttendanceSettings = async (settings) => {
    return await makeApiCall('/api/attendance/settings', {
        method: 'PUT',
        body: JSON.stringify(settings)
    });
};

// ============================================================================
// UTILITY API METHODS
// ============================================================================

API.getDepartments = async () => {
    return await makeApiCall('/api/attendance/departments');
};

API.matchEmployeeNames = async (names) => {
    return await makeApiCall('/api/attendance/match-employees', {
        method: 'POST',
        body: JSON.stringify({ employee_names: names })
    });
};

API.processRawPunches = async () => {
    return await makeApiCall('/api/attendance/process-raw-punches', {
        method: 'POST'
    });
};

// ============================================================================
// EXISTING EXCEPTION API METHODS (from exceptions-routes.js)
// ============================================================================

API.getPendingExceptions = async (params = {}) => {
    const queryString = new URLSearchParams(params).toString();
    return await makeApiCall(`/api/exceptions/pending?${queryString}`);
};

API.getExceptionHistory = async (params = {}) => {
    const queryString = new URLSearchParams(params).toString();
    return await makeApiCall(`/api/exceptions/history?${queryString}`);
};

API.getExceptionDetails = async (exceptionId) => {
    return await makeApiCall(`/api/exceptions/${exceptionId}`);
};

API.approveException = async (exceptionId, comments = '') => {
    return await makeApiCall(`/api/exceptions/approve/${exceptionId}`, {
        method: 'POST',
        body: JSON.stringify({ comments })
    });
};

API.rejectException = async (exceptionId, comments = '') => {
    return await makeApiCall(`/api/exceptions/reject/${exceptionId}`, {
        method: 'POST',
        body: JSON.stringify({ comments })
    });
};

API.createExceptionRequest = async (data) => {
    const userTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    return await makeApiCall('/api/exceptions/request', {
        method: 'POST',
        headers: {
            'x-user-timezone': userTimezone
        },
        body: JSON.stringify(data)
    });
};

// ============================================================================
// HELPER FUNCTIONS FOR CALCULATIONS
// ============================================================================

API.calculateWorkingDays = (year, month, weekdays = [1, 2, 3, 4, 5]) => {
    const startDate = moment([year, month - 1, 1]);
    const endDate = moment(startDate).endOf('month');
    let workingDays = 0;

    for (let d = moment(startDate); d.isSameOrBefore(endDate); d.add(1, 'day')) {
        if (weekdays.includes(d.day())) {
            workingDays++;
        }
    }

    return workingDays;
};

API.calculateLateMinutes = async (actualTime, scheduledTime, graceMinutes = null) => {
    if (!actualTime || !scheduledTime) return 0;

    // If graceMinutes not provided, fetch from settings
    if (graceMinutes === null) {
        try {
            const settings = await API.getAttendanceSettings();
            graceMinutes = settings.success && settings.settings ?
                settings.settings.grace_period_lateness_minutes || 15 : 15;
        } catch (error) {
            console.warn('Failed to fetch grace period settings, using default:', error);
            graceMinutes = 15;
        }
    }

    const actual = moment(actualTime, 'HH:mm');
    const scheduled = moment(scheduledTime, 'HH:mm');
    const diffMinutes = actual.diff(scheduled, 'minutes');

    return Math.max(0, diffMinutes - graceMinutes);
};

API.calculateEarlyMinutes = async (actualTime, scheduledTime, graceMinutes = null) => {
    if (!actualTime || !scheduledTime) return 0;

    // If graceMinutes not provided, fetch from settings
    if (graceMinutes === null) {
        try {
            const settings = await API.getAttendanceSettings();
            graceMinutes = settings.success && settings.settings ?
                settings.settings.grace_period_early_departure_minutes || 15 : 15;
        } catch (error) {
            console.warn('Failed to fetch grace period settings, using default:', error);
            graceMinutes = 15;
        }
    }

    const actual = moment(actualTime, 'HH:mm');
    const scheduled = moment(scheduledTime, 'HH:mm');
    const diffMinutes = scheduled.diff(actual, 'minutes');

    return Math.max(0, diffMinutes - graceMinutes);
};

// ============================================================================
// EXPORT FUNCTIONALITY
// ============================================================================

API.exportAttendanceData = async (params = {}) => {
    try {
        const queryString = new URLSearchParams(params).toString();
        const response = await fetch(`/api/attendance/export?${queryString}`, {
            headers: {
                'Authorization': `Bearer ${getAuthToken()}`
            }
        });

        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || 'Export failed');
        }

        if (params.format === 'csv') {
            // Handle CSV download
            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = `attendance-export-${moment().format('YYYY-MM-DD')}.csv`;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            window.URL.revokeObjectURL(url);

            return { success: true, message: 'CSV export completed' };
        } else {
            // Handle XLSX (JSON response for client-side processing)
            const data = await response.json();
            return data;
        }
    } catch (error) {
        console.error('Export error:', error);
        throw error;
    }
};

// ============================================================================
// CLIENT-SIDE XLSX GENERATION (if needed)
// ============================================================================

API.generateXLSX = (data, headers, filename) => {
    // This would require a library like SheetJS (xlsx)
    // For now, we'll convert to CSV as fallback
    console.log('XLSX generation not implemented, falling back to CSV');

    const csvRows = [headers.join(',')];
    data.forEach(row => {
        const csvRow = headers.map(header => {
            const value = row[header.toLowerCase().replace(/\s+/g, '_')] || '';
            return typeof value === 'string' ? `"${value}"` : value;
        });
        csvRows.push(csvRow.join(','));
    });

    const csvContent = csvRows.join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename.replace('.xlsx', '.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.URL.revokeObjectURL(url);
};

// ============================================================================
// PENDING CASES MANAGEMENT API METHODS (NEW)
// ============================================================================

API.getPendingCases = async (params = {}) => {
    const queryString = new URLSearchParams(params).toString();
    return await makeApiCall(`/api/attendance/pending?${queryString}`);
};

API.treatPendingCase = async (employeeId, date, action, reason = '', deductionAmount = 0) => {
    return await makeApiCall('/api/attendance/pending/treat', {
        method: 'POST',
        body: JSON.stringify({
            employeeId,
            date,
            action, // 'full_day', 'half_day', or 'refuse'
            reason,
            deductionAmount
        })
    });
};

API.checkMonthValidation = async (year, month, department = null) => {
    let url = `/api/attendance/validation/check/${year}/${month}`;
    if (department) {
        url += `?department=${department}`;
    }
    return await makeApiCall(url);
};

API.checkEmployeeMonthValidation = async (employeeId, year, month) => {
    return await makeApiCall(`/api/attendance/validation/check/employee/${employeeId}/${year}/${month}`);
};

API.getPendingStats = async (params = {}) => {
    const queryString = new URLSearchParams(params).toString();
    return await makeApiCall(`/api/attendance/pending/stats?${queryString}`);
};

// ============================================================================
// ERROR HANDLING AND UTILITIES
// ============================================================================

API.handleApiError = (error) => {
    console.error('API Error:', error);

    if (error.message.includes('401') || error.message.includes('Unauthorized')) {
        // Use authManager for proper logout and redirect
        if (typeof window.authManager !== 'undefined') {
            window.authManager.logout();
        } else {
            // Fallback: redirect to frontend login
            window.location.href = '/frontend/index.html';
        }
        return;
    }

    // Show user-friendly error message
    const message = error.message || 'An unexpected error occurred';

    if (typeof showToast === 'function') {
        showToast('error', message);
    } else {
        alert(`Error: ${message}`);
    }
};

// Enhanced date formatting utilities
API.formatDate = (dateString, format = 'short') => {
    if (!dateString) return '';

    const date = new Date(dateString);

    switch (format) {
        case 'full':
            return date.toLocaleDateString('en-US', {
                weekday: 'long',
                year: 'numeric',
                month: 'long',
                day: 'numeric'
            });
        case 'medium':
            return date.toLocaleDateString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric'
            });
        case 'short':
        default:
            return date.toLocaleDateString('en-US', {
                month: 'short',
                day: 'numeric'
            });
    }
};

API.formatDateTime = (dateTimeString) => {
    if (!dateTimeString) return '';
    return new Date(dateTimeString).toLocaleString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
};

API.formatTime = (timeString, format24Hour = false) => {
    if (!timeString) return '';

    const time = new Date(`2000-01-01 ${timeString}`);

    return time.toLocaleTimeString('en-US', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: !format24Hour
    });
};

API.formatCurrency = (amount, currency = 'DZD') => {
    return new Intl.NumberFormat('en-US', {
        style: 'decimal',
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    }).format(amount || 0) + ' DA';
};

// ============================================================================
// VALIDATION HELPERS
// ============================================================================

API.validateTimeFormat = (timeString) => {
    const timeRegex = /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/;
    return timeRegex.test(timeString);
};

API.validateDateRange = (startDate, endDate) => {
    const start = new Date(startDate);
    const end = new Date(endDate);
    return start <= end;
};

API.validateHours = (hours, min = 0, max = 24) => {
    const numHours = parseFloat(hours);
    return !isNaN(numHours) && numHours >= min && numHours <= max;
};

// ============================================================================
// BATCH OPERATIONS
// ============================================================================

API.batchOperation = async (operation, items, batchSize = 10) => {
    const results = [];
    const errors = [];

    for (let i = 0; i < items.length; i += batchSize) {
        const batch = items.slice(i, i + batchSize);

        try {
            const batchResults = await Promise.allSettled(
                batch.map(item => operation(item))
            );

            batchResults.forEach((result, index) => {
                if (result.status === 'fulfilled') {
                    results.push(result.value);
                } else {
                    errors.push({
                        item: batch[index],
                        error: result.reason.message
                    });
                }
            });
        } catch (error) {
            batch.forEach(item => {
                errors.push({
                    item,
                    error: error.message
                });
            });
        }
    }

    return {
        success: errors.length === 0,
        results,
        errors,
        total: items.length,
        successful: results.length,
        failed: errors.length
    };
};

// ============================================================================
// DEBUGGING AND DEVELOPMENT HELPERS
// ============================================================================

API.debug = {
    enableLogging: (enable = true) => {
        window.API_DEBUG = enable;
    },

    log: (...args) => {
        if (window.API_DEBUG) {
            console.log('[API Debug]', ...args);
        }
    },

    getLastResponse: () => {
        return window.API_LAST_RESPONSE;
    }
};

// Store last response for debugging
const originalMakeApiCall = makeApiCall;
makeApiCall = async (...args) => {
    try {
        const response = await originalMakeApiCall(...args);
        if (window.API_DEBUG) {
            window.API_LAST_RESPONSE = response;
            console.log('[API Response]', response);
        }
        return response;
    } catch (error) {
        if (window.API_DEBUG) {
            console.error('[API Error]', error);
        }
        throw error;
    }
};

console.log('Attendance API client loaded successfully');