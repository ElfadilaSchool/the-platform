#!/bin/bash

# Setup Script for Invitations Management System
# This script ensures all components are ready for the new invitations management feature

echo "🚀 Setting up Invitations Management System..."
echo ""

# 1. Check if database tables exist
echo "1️⃣ Checking database tables..."
if psql -d hr_operations -c "SELECT COUNT(*) FROM substitution_invitations;" > /dev/null 2>&1; then
    echo "   ✅ Substitution tables exist"
else
    echo "   ⚠️  Creating substitution tables..."
    psql -d hr_operations -f create-substitution-tables.sql
    if [ $? -eq 0 ]; then
        echo "   ✅ Tables created successfully"
    else
        echo "   ❌ Failed to create tables"
        exit 1
    fi
fi

# 2. Check if we have teachers
echo ""
echo "2️⃣ Checking for teachers..."
TEACHER_COUNT=$(psql -d hr_operations -t -c "SELECT COUNT(*) FROM employees e JOIN positions p ON e.position_id = p.id WHERE p.name ILIKE '%teacher%';" 2>/dev/null | tr -d ' ')
if [ "$TEACHER_COUNT" -gt 0 ]; then
    echo "   ✅ Found $TEACHER_COUNT teacher(s)"
else
    echo "   ⚠️  No teachers found. Please add teachers to test the system."
fi

# 3. Check if we have invitations
echo ""
echo "3️⃣ Checking for existing invitations..."
INVITATION_COUNT=$(psql -d hr_operations -t -c "SELECT COUNT(*) FROM substitution_invitations;" 2>/dev/null | tr -d ' ')
if [ "$INVITATION_COUNT" -gt 0 ]; then
    echo "   ✅ Found $INVITATION_COUNT invitation(s)"
else
    echo "   ℹ️  No invitations found. Create some by:"
    echo "      - Submitting leave requests for teachers"
    echo "      - Approving the requests"
    echo "      - Or run: node test-invitations-management.js"
fi

# 4. Test the API endpoints
echo ""
echo "4️⃣ Testing API endpoints..."
if curl -s http://localhost:3001/api/substitutions/invitations/stats > /dev/null 2>&1; then
    echo "   ✅ API endpoints are responding"
else
    echo "   ⚠️  API endpoints not responding. Make sure attendance service is running:"
    echo "      cd attendance-service && node attendance-server.js"
fi

# 5. Check frontend files
echo ""
echo "5️⃣ Checking frontend files..."
if [ -f "frontend/pages/submit-exception.html" ]; then
    echo "   ✅ Frontend file exists"
else
    echo "   ❌ Frontend file not found"
    exit 1
fi

if [ -f "frontend/components/api.js" ]; then
    echo "   ✅ API component exists"
else
    echo "   ❌ API component not found"
    exit 1
fi

# 6. Check backend files
echo ""
echo "6️⃣ Checking backend files..."
if [ -f "attendance-service/substitutions-routes.js" ]; then
    echo "   ✅ Substitution routes exist"
else
    echo "   ❌ Substitution routes not found"
    exit 1
fi

# 7. Run test script
echo ""
echo "7️⃣ Running test script..."
if [ -f "test-invitations-management.js" ]; then
    echo "   Running comprehensive test..."
    node test-invitations-management.js
else
    echo "   ⚠️  Test script not found"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Start the attendance service: cd attendance-service && node attendance-server.js"
echo "   2. Open the frontend: frontend/pages/submit-exception.html"
echo "   3. Click on the 'Sent Invitations' tab"
echo "   4. Test the new features!"
echo ""
echo "📚 Documentation:"
echo "   - INVITATIONS_MANAGEMENT_GUIDE.md - Complete usage guide"
echo "   - test-invitations-management.js - Test script"
echo "   - create-substitution-tables.sql - Database setup"

