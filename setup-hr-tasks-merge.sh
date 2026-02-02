#!/bin/bash

# This script merges HR Tasks schema and data into the platform DB.
# Requirements: psql, access to hr_operations_platform database, and hr_tasks/hr_tasks/data.sql.

set -euo pipefail

DB_NAME=${DB_NAME:-hr_operations_platform}

echo "Applying schema merge (database/merge_hr_tasks_into_platform.sql) to ${DB_NAME}..."
psql -d "$DB_NAME" -f database/merge_hr_tasks_into_platform.sql

echo "Creating temp schema hr_tasks_temp..."
psql -d "$DB_NAME" -c "CREATE SCHEMA IF NOT EXISTS hr_tasks_temp;"

echo "Importing HR Tasks dump into hr_tasks_temp from hr_tasks/hr_tasks/data.sql..."
if file hr_tasks/hr_tasks/data.sql | grep -qi "PostgreSQL custom database dump"; then
  echo "Detected custom dump format. Using pg_restore to emit SQL and remap search_path..."
  {
    echo "SET search_path = hr_tasks_temp, public;";
    echo "SET session_replication_role = replica;";
    pg_restore -f - --no-owner --no-privileges hr_tasks/hr_tasks/data.sql;
    echo "SET session_replication_role = DEFAULT;";
  } | psql -d "$DB_NAME"
else
  echo "Assuming plain SQL. Setting search_path and piping via psql..."
  {
    echo "SET search_path = hr_tasks_temp, public;";
    echo "SET session_replication_role = replica;";
    cat hr_tasks/hr_tasks/data.sql;
    echo "SET session_replication_role = DEFAULT;";
  } | psql -d "$DB_NAME"
fi

echo "Upserting HR Tasks data into public schema..."
psql -d "$DB_NAME" -f database/merge_hr_tasks_data.sql

echo "Cleaning up temp schema..."
psql -d "$DB_NAME" -c "DROP SCHEMA hr_tasks_temp CASCADE;" || true

echo "HR Tasks merge completed."


