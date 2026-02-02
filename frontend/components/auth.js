// Simple authentication component for testing

// Mock authentication for testing
function checkAuth() {
    // For testing, we'll set a mock token
    if (!localStorage.getItem('authToken')) {
        localStorage.setItem('authToken', 'mock-token-' + Date.now());
    }
    return true;
}

function getToken() {
    return localStorage.getItem('token') || 'mock-token';
}

function setToken(token) {
    localStorage.setItem('token', token);
}

function removeToken() {
    localStorage.removeItem('token');
}

function logout() {
    removeToken();
    window.location.href = '../index.html';
}

// Setup logout button
document.addEventListener('DOMContentLoaded', function() {
    const logoutBtn = document.getElementById('logoutBtn');
    if (logoutBtn) {
        logoutBtn.addEventListener('click', logout);
    }
});

