-- ==========================================================================
-- SCRIPT:      00_init_db.sql
-- OBJECTIVE:   Initialize the Cascadia Lake data warehouse database.
-- DATABASE:    cascadia_db
-- ==========================================================================

-- Drop active connections to allow clean teardown if database exists
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'cascadia_db'
  AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS cascadia_db;

-- Create database inheriting host cluster defaults with UTF-8 encoding
CREATE DATABASE cascadia_db
    WITH 
    ENCODING = 'UTF8'
    TEMPLATE = template0;