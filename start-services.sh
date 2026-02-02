#!/bin/bash

# HR Operations Platform - Service Startup Script

echo "Starting HR Operations Platform..."

# Check if PostgreSQL is running
if ! pgrep -x "postgres" > /dev/null; then
    echo "Starting PostgreSQL..."
    sudo service postgresql start
    sleep 2
fi

# Create database if it doesn't exist
echo "Setting up database..."
sudo -u postgres psql -c "CREATE DATABASE hr_operations_platform;" 2>/dev/null || echo "Database already exists"

# Initialize database schema
echo "Initializing database schema..."
sudo -u postgres psql -d hr_operations_platform -f database/init.sql

# Start all microservices in the background
echo "Starting microservices..."

# Auth Service
cd auth-service
npm start &
AUTH_PID=$!
echo "Auth Service started (PID: $AUTH_PID)"
cd ..

# User Management Service
cd user-management-service
npm start &
USER_PID=$!
echo "User Management Service started (PID: $USER_PID)"
cd ..

# Department Service
cd department-service
npm start &
DEPT_PID=$!
echo "Department Service started (PID: $DEPT_PID)"
cd ..

# Task Service
cd task-service
npm start &
TASK_PID=$!
echo "Task Service started (PID: $TASK_PID)"
cd ..

# Meeting Service
cd meeting-service
npm start &
MEETING_PID=$!
echo "Meeting Service started (PID: $MEETING_PID)"
cd ..

# Payment Service
cd payment-service
npm start &
PAYMENT_PID=$!
echo "Payment Service started (PID: $PAYMENT_PID)"
cd ..

# Notification Service
cd notification-service
npm start &
NOTIFICATION_PID=$!
echo "Notification Service started (PID: $NOTIFICATION_PID)"
cd ..

# Attendance Service
cd attendance-service
npm start &
ATTENDANCE_PID=$!
echo "Attendance Service started (PID: $ATTENDANCE_PID)"
cd ..

# HR Tasks Service (independent app)
cd hr_tasks/hr_tasks
# Load root .env if present so HR Tasks inherits the same settings
set -a
[ -f ../.env ] && source ../.env || true
set +a
TASK_SERVICE_PORT=${TASK_SERVICE_PORT:-3020} node index.js &
HR_TASKS_PID=$!
echo "HR Tasks Service started on port 3020 (PID: $HR_TASKS_PID)"
cd ../..

# Request Service
cd request-service
npm start &
REQUEST_PID=$!
echo "Request Service started (PID: $REQUEST_PID)"
cd ..

# Salary Service
cd salary-service
export SALARY_SERVICE_PORT=3010
npm start &
SALARY_PID=$!
echo "Salary Service started on port 3010 (PID: $SALARY_PID)"
cd ..

# timetable Service
cd timetable-service
export TIMETABLE_SERVICE_PORT=3011
npm start &
TIMETABLE_PID=$!
echo "timetable Service started on port 3011 (PID: $TIMETABLE_PID)"
cd ..


# Start frontend server
echo "Starting frontend server..."
cd frontend
python3 -m http.server 8080 &
FRONTEND_PID=$!
echo "Frontend server started on port 8080 (PID: $FRONTEND_PID)"
cd ..

echo ""
echo "All services started successfully!"
echo ""
echo "Service URLs:"
echo "- Frontend: http://localhost:8080"
echo "- Auth Service: http://localhost:3001"
echo "- User Management: http://localhost:3002"
echo "- Department Service: http://localhost:3003"
echo "- Task Service: http://localhost:3004"
echo "- Meeting Service: http://localhost:3005"
echo "- Payment Service: http://localhost:3006"
echo "- Notification Service: http://localhost:3007"
echo "- Attendance Service: http://localhost:3008"
echo "- Request Service: http://localhost:3009"
echo "- Salary Service: http://localhost:3010"
echo "- timetable Service: http://localhost:3011"
echo "- HR Tasks Service: http://localhost:${TASK_SERVICE_PORT:-3020}"
echo ""
echo "Demo Login Credentials:"
echo "Username: admin"
echo "Password: password"
echo ""
echo "Press Ctrl+C to stop all services"

# Wait for interrupt signal
trap 'echo "Stopping all services..."; kill $AUTH_PID $USER_PID $DEPT_PID $TASK_PID $MEETING_PID $PAYMENT_PID $NOTIFICATION_PID $ATTENDANCE_PID $REQUEST_PID $SALARY_PID $TIMETABLE_PID $HR_TASKS_PID $FRONTEND_PID 2>/dev/null; exit' INT

# Keep script running
wait

