-- ADL ShareFlow — Initial DB setup
-- Run once by Docker on first boot (via docker-entrypoint-initdb.d)

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Seed default plans
-- (Actual tables created by Flask-Migrate / Alembic)
