/* ========================================
   EL FADILA SCHOOL - UI THEME JAVASCRIPT
   نظام المكونات الموحد - الوظائف
   من main.js - Production Code
   ======================================== */

// ========================================
// 1. COLLAPSIBLE SIDEBAR (من main.js)
// ========================================

/**
 * Get navigation sections based on user role
 * Production code from main.js
 */
function getSidebarNavSectionsByRole(role) {
    const normalizedRole = role ? String(role).trim() : '';

    switch (normalizedRole) {
        case 'Director':
            return [
                {
                    name: 'nav.my_space',
                    items: [
                        { href: 'index.html', icon: 'fa-chart-line', label: 'لوحة التحكم' },
                        { href: 'index.html', icon: 'fa-tasks', label: 'إدارة المهام' },
                        { href: 'index.html', icon: 'fa-chart-bar', label: 'التقارير' },
                        { href: 'index.html', icon: 'fa-exclamation-circle', label: 'الشكاوى' }
                    ]
                },
                {
                    name: 'nav.account',
                    items: [
                        { href: '#', icon: 'fa-sign-out-alt', label: 'تسجيل الخروج', action: 'logout' }
                    ]
                }
            ];
        case 'HR_Manager':
        case 'HR Manager':
        case 'admin':
            return [
                {
                    name: 'nav.dashboard',
                    items: [
                        { href: 'index.html', icon: 'fa-tachometer-alt', label: 'لوحة التحكم' }
                    ]
                },
                {
                    name: 'nav.management',
                    items: [
                        { href: 'index.html', icon: 'fa-users', label: 'إدارة الموظفين' },
                        { href: 'index.html', icon: 'fa-sitemap', label: 'الهيكل التنظيمي' },
                        { href: 'index.html', icon: 'fa-clock', label: 'الحضور' }
                    ]
                },
                {
                    name: 'nav.account',
                    items: [
                        { href: '#', icon: 'fa-sign-out-alt', label: 'تسجيل الخروج', action: 'logout' }
                    ]
                }
            ];
        case 'Employee':
            return [
                {
                    name: 'nav.main',
                    items: [
                        { href: 'index.html', icon: 'fa-tachometer-alt', label: 'لوحة التحكم' },
                        { href: 'index.html', icon: 'fa-tasks', label: 'المهام' },
                        { href: 'index.html', icon: 'fa-chart-bar', label: 'التقارير' },
                        { href: 'index.html', icon: 'fa-user', label: 'الملف الشخصي' }
                    ]
                },
                {
                    name: 'nav.account',
                    items: [
                        { href: '#', icon: 'fa-sign-out-alt', label: 'تسجيل الخروج', action: 'logout' }
                    ]
                }
            ];
        default:
            return [
                {
                    name: 'nav.main',
                    items: [
                        { href: 'index.html', icon: 'fa-home', label: 'الرئيسية' }
                    ]
                }
            ];
    }
}

/**
 * Initialize the collapsible sidebar
 * Production code from main.js with full functionality
 */
function initializeCollapsibleSidebar() {
    // Check if already exists
    if (document.getElementById('collapsibleSidebar')) return;

    // Get user role (default to demo mode)
    const role = localStorage.getItem('userRole') || 'Director';

    // Get navigation sections based on role
    const navigationSections = getSidebarNavSectionsByRole(role);

    // Determine RTL/LTR
    const isRTL = document.documentElement.getAttribute('dir') === 'rtl' || document.body.classList.contains('rtl');
    const sidebarPosition = isRTL ? 'right-0' : 'left-0';
    const sidebarMargin = isRTL ? 'mr-3' : 'ml-3';

    // Logo path
    const logoPath = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"%3E%3Ccircle cx="50" cy="50" r="45" fill="%233b82f6"/%3E%3Ctext x="50" y="65" font-size="40" text-anchor="middle" fill="white" font-family="Arial, sans-serif" font-weight="bold"%3EEF%3C/text%3E%3C/svg%3E';

    // Build sidebar HTML
    let sidebarHTML = `
    <div id="collapsibleSidebar" class="fixed ${sidebarPosition} top-0 h-screen bg-white shadow-lg z-50 w-16 transition-all duration-300 overflow-hidden" style="box-shadow: 0 10px 40px rgba(0,0,0,0.1);">
      <!-- Logo Section -->
      <div class="border-b border-gray-200" style="height: 80px; min-height: 80px; display: flex; align-items: center; justify-content: center; padding: 0 1rem;">
        <div class="flex items-center justify-center" style="width: 100%;">
          <div class="flex-shrink-0">
            <div class="w-12 h-12 flex items-center justify-center bg-gray-50 rounded-lg border border-gray-200">
              <img src="${logoPath}" alt="EL FADILA SCHOOL" class="h-10 w-10 object-contain rounded-lg">
            </div>
          </div>
          <div class="${sidebarMargin} overflow-hidden hidden">
            <h1 class="school-title text-lg font-bold text-gray-900 whitespace-nowrap hidden transition-opacity duration-300">EL FADILA SCHOOL</h1>
            <p class="school-subtitle text-sm text-gray-500 whitespace-nowrap hidden transition-opacity duration-300">نظام إدارة الموارد البشرية</p>
          </div>
        </div>
      </div>

      <!-- Navigation -->
      <nav class="flex-1 overflow-y-auto py-4" style="scrollbar-width: none; -ms-overflow-style: none;">`;

    // Add navigation sections
    if (navigationSections && navigationSections.length > 0) {
        let isFirstItem = true; // Track first item for default active state

        navigationSections.forEach((section, si) => {
            if (si > 0) sidebarHTML += `<div class="border-t border-gray-200 mx-4 my-2"></div>`;
            sidebarHTML += `<div class="nav-section px-2">`;

            section.items.forEach((item, itemIndex) => {
                // Only mark first item as active, skip logout
                const isActive = isFirstItem && item.action !== 'logout';
                if (isActive) isFirstItem = false; // Mark that we've set the first active

                const activeClass = isActive ? 'nav-active' : '';
                const actionAttr = item.action ? `data-action="${item.action}"` : '';
                const labelMargin = isRTL ? 'mr-3' : 'ml-3';

                sidebarHTML += `
                <a href="${item.href}" class="nav-item flex items-center px-3 py-3 mx-2 rounded-lg transition-all duration-200 ${activeClass} hover:bg-blue-50 group" ${actionAttr}>
                  <div class="flex-shrink-0 w-5 text-center">
                    <i class="fas ${item.icon} text-gray-600 group-hover:text-blue-600 transition-colors duration-200"></i>
                  </div>
                  <span class="nav-label ${labelMargin} text-gray-700 group-hover:text-blue-600 font-medium whitespace-nowrap opacity-0 invisible transition-all duration-300">
                    ${item.label}
                  </span>
                </a>
                `;
            });
            sidebarHTML += `</div>`;
        });
    }

    sidebarHTML += '</nav></div>';

    // Insert sidebar into DOM
    document.body.insertAdjacentHTML('afterbegin', sidebarHTML);

    // Add body padding
    if (isRTL) {
        document.body.style.paddingRight = '4rem';
        document.body.style.paddingLeft = '0';
    } else {
        document.body.style.paddingLeft = '4rem';
        document.body.style.paddingRight = '0';
    }

    // Initialize sidebar behavior
    handleSidebarNavigation();
}

/**
 * Handle sidebar hover interactions and navigation
 * Production code from main.js
 */
function handleSidebarNavigation() {
    const sidebar = document.getElementById('collapsibleSidebar');
    if (!sidebar) return;

    let isExpanded = false;

    // Expand on hover
    sidebar.addEventListener('mouseenter', () => {
        isExpanded = true;
        sidebar.classList.remove('w-16');
        sidebar.classList.add('w-64');

        // Show labels
        document.querySelectorAll('.nav-label').forEach(label => {
            label.classList.remove('opacity-0', 'invisible');
            label.classList.add('opacity-100', 'visible');
        });

        // Show title and subtitle
        const titleContainer = sidebar.querySelector('.overflow-hidden.hidden');
        if (titleContainer) titleContainer.classList.remove('hidden');

        const title = sidebar.querySelector('.school-title');
        if (title) title.classList.remove('hidden');

        const subtitle = sidebar.querySelector('.school-subtitle');
        if (subtitle) subtitle.classList.remove('hidden');
    });

    // Collapse on leave
    sidebar.addEventListener('mouseleave', () => {
        isExpanded = false;
        sidebar.classList.remove('w-64');
        sidebar.classList.add('w-16');

        // Hide labels
        document.querySelectorAll('.nav-label').forEach(label => {
            label.classList.remove('opacity-100', 'visible');
            label.classList.add('opacity-0', 'invisible');
        });

        // Hide title and subtitle
        const titleContainer = sidebar.querySelector('.overflow-hidden');
        if (titleContainer) titleContainer.classList.add('hidden');

        const title = sidebar.querySelector('.school-title');
        if (title) title.classList.add('hidden');

        const subtitle = sidebar.querySelector('.school-subtitle');
        if (subtitle) subtitle.classList.add('hidden');
    });

    // Handle navigation clicks
    const sidebarItems = document.querySelectorAll(".nav-item");
    sidebarItems.forEach((item) => {
        item.addEventListener("click", function (e) {
            // Handle logout action
            if (this.getAttribute("data-action") === "logout") {
                e.preventDefault();
                if (confirm("هل أنت متأكد من تسجيل الخروج؟")) {
                    localStorage.clear();
                    window.location.href = 'index.html';
                }
                return;
            }

            // Handle normal navigation
            const href = this.getAttribute("href");
            if (href && href !== "#" && !href.startsWith("javascript:")) {
                // Update active state
                sidebarItems.forEach(i => i.classList.remove("nav-active"));
                this.classList.add("nav-active");
            }
        });
    });
}

// ========================================
// 2. TOAST NOTIFICATIONS
// ========================================

/**
 * Show a toast notification
 * @param {string} type - 'success' or 'error'
 * @param {string} title - Toast title (optional)
 * @param {string} message - Toast message (optional)
 */
function showToast(type = 'success', title = '', message = '') {
    const toastContainer = document.getElementById('toastRoot') || createToastContainer();

    // Default messages
    const defaults = {
        success: {
            title: title || 'نجاح',
            message: message || 'تمت العملية بنجاح',
            icon: 'fa-check-circle'
        },
        error: {
            title: title || 'خطأ',
            message: message || 'حدث خطأ ما',
            icon: 'fa-times-circle'
        }
    };

    const config = defaults[type] || defaults.success;

    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerHTML = `
        <div class="toast-icon">
            <i class="fas ${config.icon}"></i>
        </div>
        <div class="toast-content">
            <div class="toast-title">${config.title}</div>
            ${config.message ? `<div class="toast-body">${config.message}</div>` : ''}
        </div>
        <button class="toast-close" aria-label="Close">
            <i class="fas fa-times"></i>
        </button>
    `;

    // Add close button handler
    const closeBtn = toast.querySelector('.toast-close');
    closeBtn.addEventListener('click', () => {
        toast.style.animation = 'toast-out 200ms ease-out';
        setTimeout(() => toast.remove(), 200);
    });

    toastContainer.appendChild(toast);

    // Auto remove after 3 seconds
    setTimeout(() => {
        if (toast.parentElement) {
            toast.style.animation = 'toast-out 200ms ease-out';
            setTimeout(() => toast.remove(), 200);
        }
    }, 3000);
}

/**
 * Create toast container if it doesn't exist
 */
function createToastContainer() {
    let container = document.getElementById('toastRoot');
    if (!container) {
        container = document.createElement('div');
        container.id = 'toastRoot';
        container.className = 'toast-container';
        container.setAttribute('aria-live', 'polite');
        container.setAttribute('aria-atomic', 'true');
        document.body.appendChild(container);
    }
    return container;
}

// ========================================
// 3. UTILITY FUNCTIONS
// ========================================

/**
 * Format date to Arabic locale
 */
function formatDate(dateString) {
    if (!dateString) return '';
    const date = new Date(dateString);
    return date.toLocaleDateString('ar-SA', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
    });
}

/**
 * Format date and time to Arabic locale
 */
function formatDateTime(dateString) {
    if (!dateString) return '';
    const date = new Date(dateString);
    return date.toLocaleString('ar-SA', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

/**
 * Debounce function for search inputs
 */
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

/**
 * Toggle element visibility
 */
function toggleElement(elementId) {
    const element = document.getElementById(elementId);
    if (element) {
        element.classList.toggle('hidden');
    }
}

/**
 * Show element
 */
function showElement(elementId) {
    const element = document.getElementById(elementId);
    if (element) {
        element.classList.remove('hidden');
    }
}

/**
 * Hide element
 */
function hideElement(elementId) {
    const element = document.getElementById(elementId);
    if (element) {
        element.classList.add('hidden');
    }
}

// ========================================
// 4. INITIALIZATION
// ========================================

/**
 * Initialize the theme on page load
 */
document.addEventListener('DOMContentLoaded', function () {
    // Initialize sidebar
    initializeCollapsibleSidebar();

    // Set current date in header if element exists
    const currentDateElement = document.getElementById('currentDate');
    if (currentDateElement) {
        currentDateElement.textContent = formatDate(new Date());
    }

    // Initialize any tooltips or other components
    console.log('✅ UI Theme initialized successfully');
});

// ========================================
// 5. EXPORT FUNCTIONS (for use in other files)
// ========================================

// Make functions available globally
window.UITheme = {
    showToast,
    formatDate,
    formatDateTime,
    debounce,
    toggleElement,
    showElement,
    hideElement,
    initializeCollapsibleSidebar
};

// Log initialization
console.log('🎨 EL FADILA UI Theme loaded (Production Code from main.js)');
