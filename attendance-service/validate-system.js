/**
 * System Validation Script
 * Tests all components of the attendance service to ensure proper integration
 */

const fs = require('fs');
const path = require('path');

console.log('╔══════════════════════════════════════════════════════════════╗');
console.log('║                ATTENDANCE SERVICE VALIDATION                 ║');
console.log('╚══════════════════════════════════════════════════════════════╝\n');

const colors = {
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  reset: '\x1b[0m'
};

const log = {
  success: (msg) => console.log(`${colors.green}✓${colors.reset} ${msg}`),
  error: (msg) => console.log(`${colors.red}✗${colors.reset} ${msg}`),
  warning: (msg) => console.log(`${colors.yellow}⚠${colors.reset} ${msg}`),
  info: (msg) => console.log(`${colors.blue}ℹ${colors.reset} ${msg}`)
};

let totalTests = 0;
let passedTests = 0;

function test(description, condition) {
  totalTests++;
  if (condition) {
    log.success(description);
    passedTests++;
    return true;
  } else {
    log.error(description);
    return false;
  }
}

// File existence tests
console.log('\n📁 File Structure Validation\n');

const requiredFiles = [
  'attendance-server.js',
  'attendance-routes.js', 
  'attendance-extra-routes.js',
  'attendance-export-routes.js',
  'attendance-api.js',
  'attendance-master.html',
  'daily-attendance.html',
  'submit-exception.html',
  'exceptions.html',
  'exceptions-routes.js',
  'current.sql',
  'package.json',
  '.env.example',
  'README-attendance.md'
];

requiredFiles.forEach(file => {
  test(`File exists: ${file}`, fs.existsSync(path.join(__dirname, file)));
});

// Package.json validation
console.log('\n📦 Package Configuration Validation\n');

try {
  const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  test('Package.json is valid JSON', true);
  test('Package has name field', packageJson.name === 'attendance-service');
  test('Package has main entry point', packageJson.main === 'attendance-server.js');
  test('Package has start script', packageJson.scripts && packageJson.scripts.start);
  test('Package has required dependencies', packageJson.dependencies && 
       packageJson.dependencies.express && 
       packageJson.dependencies.pg &&
       packageJson.dependencies.cors);
} catch (error) {
  test('Package.json is valid JSON', false);
  log.error(`Package.json error: ${error.message}`);
}

// HTML file validation
console.log('\n🌐 HTML File Validation\n');

const htmlFiles = [
  'attendance-master.html',
  'daily-attendance.html', 
  'submit-exception.html'
];

htmlFiles.forEach(filename => {
  try {
    const content = fs.readFileSync(filename, 'utf8');
    test(`${filename} contains DOCTYPE`, content.includes('<!DOCTYPE html>'));
    test(`${filename} has title tag`, content.includes('<title>'));
    test(`${filename} includes attendance-api.js`, content.includes('attendance-api.js'));
    test(`${filename} has proper HTML structure`, content.includes('<html') && content.includes('</html>'));
    
    // Check for specific components
    if (filename === 'attendance-master.html') {
      test(`${filename} has statistics cards`, content.includes('statistics-cards'));
      test(`${filename} has filter section`, content.includes('filters'));
      test(`${filename} has employee table`, content.includes('employeeTableBody'));
    }
    
    if (filename === 'daily-attendance.html') {
      test(`${filename} has employee header`, content.includes('employee-header'));
      test(`${filename} has daily table`, content.includes('dailyTableBody'));
      test(`${filename} has side panels`, content.includes('side-panel'));
    }
    
    if (filename === 'submit-exception.html') {
      test(`${filename} has exception form`, content.includes('exceptionForm'));
      test(`${filename} has file upload`, content.includes('type="file"'));
    }
    
  } catch (error) {
    test(`${filename} is readable`, false);
    log.error(`Error reading ${filename}: ${error.message}`);
  }
});

// JavaScript file validation
console.log('\n⚙️ JavaScript File Validation\n');

const jsFiles = [
  'attendance-server.js',
  'attendance-routes.js',
  'attendance-extra-routes.js', 
  'attendance-export-routes.js',
  'attendance-api.js'
];

jsFiles.forEach(filename => {
  try {
    const content = fs.readFileSync(filename, 'utf8');
    test(`${filename} is readable`, true);
    
    if (filename.includes('-routes.js')) {
      test(`${filename} exports router`, content.includes('module.exports') || content.includes('router'));
      test(`${filename} has route definitions`, content.includes('router.get') || content.includes('router.post'));
    }
    
    if (filename === 'attendance-server.js') {
      test(`${filename} creates Express app`, content.includes('express()'));
      test(`${filename} sets up CORS`, content.includes('cors'));
      test(`${filename} has database pool`, content.includes('Pool'));
      test(`${filename} listens on port`, content.includes('listen'));
    }
    
    if (filename === 'attendance-api.js') {
      test(`${filename} has API methods`, content.includes('getMonthlyAttendance') || content.includes('api'));
      test(`${filename} handles errors`, content.includes('catch') || content.includes('error'));
    }
    
  } catch (error) {
    test(`${filename} is readable`, false);
    log.error(`Error reading ${filename}: ${error.message}`);
  }
});

// SQL file validation
console.log('\n🗄️ Database Schema Validation\n');

try {
  const sqlContent = fs.readFileSync('current.sql', 'utf8');
  test('SQL file is readable', true);
  test('SQL has employee table', sqlContent.includes('employees'));
  test('SQL has raw_punches table', sqlContent.includes('raw_punches'));
  test('SQL has attendance_punches table', sqlContent.includes('attendance_punches'));
  test('SQL has comprehensive_monthly_statistics', sqlContent.includes('comprehensive_monthly_statistics'));
  test('SQL has overtime_requests table', sqlContent.includes('overtime_requests'));
  test('SQL has name matching function', sqlContent.includes('get_employee_name_match_condition'));
} catch (error) {
  test('SQL file is readable', false);
  log.error(`Error reading SQL file: ${error.message}`);
}

// Environment configuration validation
console.log('\n🔧 Configuration Validation\n');

test('.env.example exists', fs.existsSync('.env.example'));

if (fs.existsSync('.env.example')) {
  try {
    const envContent = fs.readFileSync('.env.example', 'utf8');
    test('.env.example has DB_HOST', envContent.includes('DB_HOST'));
    test('.env.example has DB_NAME', envContent.includes('DB_NAME'));
    test('.env.example has DB_USER', envContent.includes('DB_USER'));
    test('.env.example has DB_PASSWORD', envContent.includes('DB_PASSWORD'));
    test('.env.example has PORT', envContent.includes('PORT'));
  } catch (error) {
    test('.env.example is readable', false);
  }
}

// API endpoint structure validation
console.log('\n🔌 API Endpoint Validation\n');

try {
  const routesContent = fs.readFileSync('attendance-routes.js', 'utf8');
  const extraRoutesContent = fs.readFileSync('attendance-extra-routes.js', 'utf8');
  const exportRoutesContent = fs.readFileSync('attendance-export-routes.js', 'utf8');
  
  const allRoutes = routesContent + extraRoutesContent + exportRoutesContent;
  
  // Core endpoints
  test('Has monthly attendance endpoint', allRoutes.includes('/monthly'));
  test('Has daily attendance endpoint', allRoutes.includes('/daily'));
  test('Has validation endpoints', allRoutes.includes('/validate'));
  test('Has overtime endpoints', allRoutes.includes('/overtime'));
  test('Has export endpoints', allRoutes.includes('/export'));
  test('Has settings endpoints', allRoutes.includes('/settings'));
  
  // HTTP methods
  test('Has GET routes', allRoutes.includes('router.get'));
  test('Has POST routes', allRoutes.includes('router.post'));
  test('Has PUT routes', allRoutes.includes('router.put'));
  
} catch (error) {
  log.error(`Error validating API endpoints: ${error.message}`);
}

// Frontend integration validation
console.log('\n🎨 Frontend Integration Validation\n');

try {
  const apiContent = fs.readFileSync('attendance-api.js', 'utf8');
  
  test('API client has base URL configuration', apiContent.includes('baseURL') || apiContent.includes('BASE_URL'));
  test('API client has error handling', apiContent.includes('catch') && apiContent.includes('error'));
  test('API client has monthly attendance method', apiContent.includes('getMonthlyAttendance'));
  test('API client has daily attendance method', apiContent.includes('getDailyAttendance'));
  test('API client has validation methods', apiContent.includes('validate'));
  test('API client has overtime methods', apiContent.includes('overtime') || apiContent.includes('Overtime'));
  test('API client has export methods', apiContent.includes('export'));
  
} catch (error) {
  log.error(`Error validating frontend integration: ${error.message}`);
}

// Feature completeness validation
console.log('\n🚀 Feature Completeness Validation\n');

const masterContent = fs.existsSync('attendance-master.html') ? 
  fs.readFileSync('attendance-master.html', 'utf8') : '';
const dailyContent = fs.existsSync('daily-attendance.html') ? 
  fs.readFileSync('daily-attendance.html', 'utf8') : '';
const exceptionContent = fs.existsSync('submit-exception.html') ? 
  fs.readFileSync('submit-exception.html', 'utf8') : '';

// Master page features
test('Master page has filtering', masterContent.includes('filter'));
test('Master page has statistics cards', masterContent.includes('card') || masterContent.includes('statistic'));
test('Master page has bulk operations', masterContent.includes('bulk'));
test('Master page has export functionality', masterContent.includes('export'));
test('Master page has employee table', masterContent.includes('table') && masterContent.includes('employee'));

// Daily page features
test('Daily page has employee header', dailyContent.includes('employee-header') || dailyContent.includes('employee-info'));
test('Daily page has daily table', dailyContent.includes('daily') && dailyContent.includes('table'));
test('Daily page has edit functionality', dailyContent.includes('edit'));
test('Daily page has side panels', dailyContent.includes('panel') || dailyContent.includes('sidebar'));
test('Daily page has wage changes', dailyContent.includes('wage'));
test('Daily page has overtime section', dailyContent.includes('overtime'));

// Exception form features
test('Exception form has date input', exceptionContent.includes('type="date"'));
test('Exception form has hours input', exceptionContent.includes('hours'));
test('Exception form has file upload', exceptionContent.includes('type="file"'));
test('Exception form has description', exceptionContent.includes('description'));

// Print summary
console.log('\n' + '='.repeat(60));
console.log(`${colors.blue}VALIDATION SUMMARY${colors.reset}`);
console.log('='.repeat(60));
console.log(`Total Tests: ${totalTests}`);
console.log(`${colors.green}Passed: ${passedTests}${colors.reset}`);
console.log(`${colors.red}Failed: ${totalTests - passedTests}${colors.reset}`);

const successRate = ((passedTests / totalTests) * 100).toFixed(1);
console.log(`Success Rate: ${successRate}%`);

if (passedTests === totalTests) {
  console.log(`\n${colors.green}🎉 ALL TESTS PASSED! The attendance service is ready to use.${colors.reset}`);
} else if (successRate >= 90) {
  console.log(`\n${colors.yellow}⚠️ Most tests passed. Minor issues detected but system should work.${colors.reset}`);
} else if (successRate >= 70) {
  console.log(`\n${colors.yellow}⚠️ Some issues detected. Please review failed tests before deployment.${colors.reset}`);
} else {
  console.log(`\n${colors.red}❌ Significant issues detected. Please fix critical errors before using the system.${colors.reset}`);
}

console.log('\n' + '='.repeat(60));
console.log(`${colors.blue}NEXT STEPS${colors.reset}`);
console.log('='.repeat(60));
console.log('1. Run: ./start-attendance.sh (or npm install)');
console.log('2. Configure your .env file with database credentials');
console.log('3. Set up the database: psql -d attendance_db -f current.sql');
console.log('4. Start the server: npm run dev');
console.log('5. Access: http://localhost:3000/master');
console.log('='.repeat(60) + '\n');

// Exit with appropriate code
process.exit(passedTests === totalTests ? 0 : 1);