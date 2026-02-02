// Simple Navigation System - Bypasses authentication redirect issues
class SimpleNavigation {
    constructor() {
        this.init();
    }

    init() {
        // Wait for DOM to be ready
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => this.setupNavigation());
        } else {
            this.setupNavigation();
        }
    }

    setupNavigation() {
        // Remove existing navigation handlers
        const sidebarItems = document.querySelectorAll('.sidebar-item');
        
        sidebarItems.forEach(item => {
            // Clone the element to remove all existing event listeners
            const newItem = item.cloneNode(true);
            item.parentNode.replaceChild(newItem, item);
            
            // Add new click handler
            newItem.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                
                const href = newItem.getAttribute('href');
                if (href && href !== '#' && !href.startsWith('javascript:')) {
                    console.log('Navigating to:', href);
                    
                    // Update active state
                    this.updateActiveState(newItem);
                    
                    // Navigate immediately
                    window.location.href = href;
                }
            });
        });
        
        console.log('Simple navigation system initialized');
    }

    updateActiveState(clickedItem) {
        // Remove active class from all items
        document.querySelectorAll('.sidebar-item').forEach(item => {
            item.classList.remove('active', 'text-blue-600');
            item.classList.add('text-gray-700', 'hover:text-blue-600');
        });
        
        // Add active class to clicked item
        clickedItem.classList.remove('text-gray-700', 'hover:text-blue-600');
        clickedItem.classList.add('active', 'text-blue-600');
    }

    getPagesBasePath() {
        // If we're already inside /pages/, hrefs are relative
        const path = window.location.pathname.replace(/\\/g, '/');
        if (path.includes('/pages/')) return '';
        // Otherwise, we assume index at /frontend/index.html
        // and pages are at /frontend/pages/
        return 'frontend/pages/';
    }

    // No-op: we respect existing page navbars; no auto-injection
    ensureGlobalNav() { return; }
}

// Initialize simple navigation
const simpleNav = new SimpleNavigation();

// Override the existing handleNavigation function
window.handleNavigation = function() {
    console.log('handleNavigation called - using simple navigation instead');
    // Do nothing - simple navigation handles this
};

// Prevent auth redirects on navigation
window.addEventListener('beforeunload', function() {
    // Clear any pending redirects
    if (window.redirectTimeout) {
        clearTimeout(window.redirectTimeout);
    }
});

