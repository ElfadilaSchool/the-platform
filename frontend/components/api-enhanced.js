// Enhanced API utility for Master Attendance Log System
// Extends the existing API with new attendance management endpoints

class AttendanceAPI {
    constructor() {
        this.baseURL = '/api';
    }

    // Helper method for making requests
    async request(endpoint, method = 'GET', body = null, params = null) {
        try {
            let url = `${this.baseURL}${endpoint}`;
            
            if (params) {
                const searchParams = new URLSearchParams();
                Object.keys(params).forEach(key => {
                    if (params[key] !== null && params[key] !== undefined && params[key] !== '') {
                        searchParams.append(key, params[key]);
                    }
                });
                url += `?${searchParams}`;
            }

            const options = {
                method,
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${AuthManager.getToken()}`
                }
            };

            if (body && method !== 'GET') {
                options.body = JSON.stringify(body);
            }

            const response = await fetch(url, options);
            
            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || `HTTP ${response.status}`);
            }

            return await response.json();
        } catch (error) {
            console.error(`API request error [${method} ${endpoint}]:`, error);
            throw error;
        }
    }

    // Master Attendance Log endpoints
    async getMonthlyStatistics(params) {
        return this.request('/attendance-master/monthly-statistics', 'GET', null, params);
    }

    async bulkValidateEmployees(data) {
        return this.request('/attendance-master/bulk-validate', 'POST', data);
    }

    async exportMonthlyStatistics(params) {
        // Handle file download separately
        const searchParams = new URLSearchParams();
        Object.keys(params).forEach(key => {
            if (params[key] !== null && params[key] !== undefined && params[key] !== '') {
                searchParams.append(key, params[key]);
            }
        });

        const response = await fetch(`${this.baseURL}/attendance-master/export-monthly-statistics?${searchParams}`, {
            headers: {
                'Authorization': `Bearer ${AuthManager.getToken()}`
            }
        });

        if (!response.ok) {
            throw new Error('Export failed');
        }

        return response.blob();
    }

    async getAttendanceSettings(departmentId = null) {
        const params = departmentId ? { departmentId } : null;
        return this.request('/attendance-master/settings', 'GET', null, params);
    }

    async updateAttendanceSettings(settings) {
        return this.request('/attendance-master/settings', 'PUT', settings);
    }

    async getAnalyticsSummary(month, year) {
        return this.request('/attendance-master/analytics/monthly-summary', 'GET', null, { month, year });
    }

    // Employee Details endpoints
    async getEmployeeMonthlyDetails(employeeId, month, year) {
        return this.request(`/attendance-details/employee/${employeeId}/monthly-details`, 'GET', null, { month, year });
    }

    async validateEmployee(employeeId, data) {
        return this.request(`/attendance-details/employee/${employeeId}/validate`, 'POST', data);
    }

    async recalculateEmployee(employeeId, data) {
        return this.request(`/attendance-details/employee/${employeeId}/recalculate`, 'POST', data);
    }

    async performEmployeeBulkAction(employeeId, actionData) {
        return this.request(`/attendance-details/employee/${employeeId}/bulk-actions`, 'POST', actionData);
    }

    // Wage Changes endpoints
    async addWageChange(employeeId, data) {
        return this.request(`/attendance-details/employee/${employeeId}/wage-changes`, 'POST', data);
    }

    async updateWageChange(employeeId, wageChangeId, data) {
        return this.request(`/attendance-details/employee/${employeeId}/wage-changes/${wageChangeId}`, 'PUT', data);
    }

    async deleteWageChange(employeeId, wageChangeId) {
        return this.request(`/attendance-details/employee/${employeeId}/wage-changes/${wageChangeId}`, 'DELETE');
    }

    // Overtime Hours endpoints
    async addOvertimeHours(employeeId, data) {
        return this.request(`/attendance-details/employee/${employeeId}/overtime-hours`, 'POST', data);
    }

    async updateOvertimeHours(employeeId, overtimeId, data) {
        return this.request(`/attendance-details/employee/${employeeId}/overtime-hours/${overtimeId}`, 'PUT', data);
    }

    async deleteOvertimeHours(employeeId, overtimeId) {
        return this.request(`/attendance-details/employee/${employeeId}/overtime-hours/${overtimeId}`, 'DELETE');
    }

    // Overtime Requests endpoints
    async getOvertimeRequests(params) {
        return this.request('/exceptions/overtime', 'GET', null, params);
    }

    async submitOvertimeRequest(data) {
        return this.request('/exceptions/overtime/request', 'POST', data);
    }

    async approveOvertimeRequest(requestId, data = {}) {
        return this.request(`/exceptions/overtime/approve/${requestId}`, 'POST', data);
    }

    async declineOvertimeRequest(requestId, data = {}) {
        return this.request(`/exceptions/overtime/decline/${requestId}`, 'POST', data);
    }

    async getOvertimeRequestDetails(requestId) {
        return this.request(`/exceptions/overtime/${requestId}`, 'GET');
    }

    // Exception endpoints (existing)
    async getPendingExceptions(params) {
        return this.request('/exceptions/pending', 'GET', null, params);
    }

    async getExceptionHistory(params) {
        return this.request('/exceptions/history', 'GET', null, params);
    }

    async getExceptionDetails(exceptionId) {
        return this.request(`/exceptions/${exceptionId}`, 'GET');
    }

    async approveException(exceptionId, data = {}) {
        return this.request(`/exceptions/approve/${exceptionId}`, 'POST', data);
    }

    async rejectException(exceptionId, data = {}) {
        return this.request(`/exceptions/reject/${exceptionId}`, 'POST', data);
    }

    async submitException(data) {
        return this.request('/exceptions/request', 'POST', data);
    }

    // Departments endpoint
    async getDepartments() {
        return this.request('/attendance-master/departments');
    }
}

// Create global API instance
window.AttendanceAPI = new AttendanceAPI();

// Extend existing API object if it exists
if (window.API) {
    Object.assign(window.API, {
        // Add shortcuts to the new API methods
        getMonthlyStatistics: (params) => window.AttendanceAPI.getMonthlyStatistics(params),
        getEmployeeMonthlyDetails: (employeeId, month, year) => window.AttendanceAPI.getEmployeeMonthlyDetails(employeeId, month, year),
        bulkValidateEmployees: (data) => window.AttendanceAPI.bulkValidateEmployees(data),
        exportMonthlyStatistics: (params) => window.AttendanceAPI.exportMonthlyStatistics(params),
        getAttendanceSettings: (departmentId) => window.AttendanceAPI.getAttendanceSettings(departmentId),
        updateAttendanceSettings: (settings) => window.AttendanceAPI.updateAttendanceSettings(settings),
        getDepartments: () => window.AttendanceAPI.getDepartments(),
        
        // Overtime requests
        getOvertimeRequests: (params) => window.AttendanceAPI.getOvertimeRequests(params),
        submitOvertimeRequest: (data) => window.AttendanceAPI.submitOvertimeRequest(data),
        approveOvertimeRequest: (requestId, data) => window.AttendanceAPI.approveOvertimeRequest(requestId, data),
        declineOvertimeRequest: (requestId, data) => window.AttendanceAPI.declineOvertimeRequest(requestId, data),
        getOvertimeRequestDetails: (requestId) => window.AttendanceAPI.getOvertimeRequestDetails(requestId)
    });
} else {
    // Create API object if it doesn't exist
    window.API = window.AttendanceAPI;
}