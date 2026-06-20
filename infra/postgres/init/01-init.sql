-- ─── Initial Database Setup ────────────────────────────────────────────────
-- This script runs automatically on the FIRST container start (fresh volume).
-- Add your schema, extensions, and seed data here.

-- Enable useful extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- TODO: Create your tables here. Example:
--
-- CREATE TABLE users (
--     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--     email VARCHAR(255) UNIQUE NOT NULL,
--     password_hash TEXT NOT NULL,
--     created_at TIMESTAMPTZ DEFAULT NOW(),
--     updated_at TIMESTAMPTZ DEFAULT NOW()
-- );
--
-- CREATE TABLE orders (
--     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--     user_id UUID REFERENCES users(id),
--     status VARCHAR(50) NOT NULL DEFAULT 'pending',
--     total_cents INTEGER NOT NULL,
--     created_at TIMESTAMPTZ DEFAULT NOW()
-- );
