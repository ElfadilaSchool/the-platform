// Simple script to set test token for debugging
// Run this in the browser console or include it in the HTML

function setTestToken() {
    localStorage.setItem('token', 'test-token');
    localStorage.setItem('user', JSON.stringify({
        id: 'test-user-id',
        username: 'test-user',
        role: 'admin'
    }));
    console.log('Test token set successfully');
    console.log('Token:', localStorage.getItem('token'));
    console.log('User:', JSON.parse(localStorage.getItem('user')));
}

// Auto-set token if not already set
if (!localStorage.getItem('token')) {
    setTestToken();
}
