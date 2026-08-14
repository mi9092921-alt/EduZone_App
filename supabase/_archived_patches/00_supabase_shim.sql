-- =============================================================================
-- Supabase-compatible local test shim.
--
-- This is NOT part of the app's schema. It exists only so the repo's real,
-- unmodified supabase/schema/*.sql files can be loaded against a plain local
-- Postgres 16 instance for automated security testing (doc 7 / Milestone G),
-- in an environment where the actual Supabase stack (GoTrue, PostgREST,
-- pg_net, realtime, etc.) is not reachable.
--
-- It reproduces, faithfully, the small number of primitives Supabase itself
-- injects into every project: the `anon` / `authenticated` / `service_role`
-- / `supabase_auth_admin` roles, and auth.uid() / auth.jwt() / auth.role(),
-- which read from Postgres GUCs (`request.jwt.claims`, `request.jwt.claim.*`)
-- exactly the way PostgREST populates them per-request in production. See
-- https://supabase.com/docs/guides/database/postgres/row-level-security
-- and the Custom Access Token Hook docs for the claim shapes assumed here.
-- =============================================================================

-- ─── Roles ───────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    CREATE ROLE supabase_auth_admin NOLOGIN NOINHERIT CREATEROLE;
  END IF;
  -- Supabase Studio / internal roles referenced by a couple of `TO` clauses
  -- in 09_rls.sql. Not otherwise used by anything under test here.
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dashboard_user') THEN
    CREATE ROLE dashboard_user NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_privileged_role') THEN
    CREATE ROLE supabase_privileged_role NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'postgres';
    GRANT anon TO authenticator;
    GRANT authenticated TO authenticator;
    GRANT service_role TO authenticator;
  END IF;
END
$$;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

CREATE SCHEMA IF NOT EXISTS test;
GRANT USAGE ON SCHEMA test TO anon, authenticated, service_role;

-- ─── auth schema ─────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS auth;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role, supabase_auth_admin;

-- Minimal auth.users — the real schema's public.users(id) FKs into this in
-- production Supabase projects.
CREATE TABLE IF NOT EXISTS auth.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text,
  raw_app_meta_data jsonb DEFAULT '{}'::jsonb,
  raw_user_meta_data jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- auth.uid() / auth.jwt() / auth.role(): identical semantics to what
-- PostgREST/Supabase set on every authenticated request — read from GUCs
-- set per-request. In production these GUCs come from the verified JWT;
-- here, tests set them explicitly via set_jwt_claims() below.
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')::uuid;
$$;

CREATE OR REPLACE FUNCTION auth.jwt() RETURNS jsonb
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(NULLIF(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb);
$$;

CREATE OR REPLACE FUNCTION auth.role() RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.role', true), '');
$$;

-- ─── Test helpers (test-harness only, not shipped) ────────────────────────

-- Simulates "this Postgres session is now authenticated as this user, with
-- this JWT payload" the way PostgREST would set it up per HTTP request.
--
-- NOTE: uses set_config(..., false) — SESSION-scoped, not transaction-local
-- (`true`). In real PostgREST, each request runs as one transaction so
-- transaction-local GUCs are the right choice there. Here, this whole test
-- script runs as many separate autocommitted statements over one psql
-- session, so session-scoped is what makes claims set in one statement
-- visible to the next.
CREATE OR REPLACE FUNCTION test.set_jwt_claims(p_claims jsonb) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claims', p_claims::text, false);
  PERFORM set_config('request.jwt.claim.role', COALESCE(p_claims ->> 'role', 'authenticated'), false);
END;
$$;

CREATE OR REPLACE FUNCTION test.clear_jwt_claims() RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claims', '', false);
  PERFORM set_config('request.jwt.claim.role', 'anon', false);
END;
$$;

GRANT EXECUTE ON FUNCTION test.set_jwt_claims(jsonb) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION test.clear_jwt_claims() TO anon, authenticated, service_role;

-- ─── Supabase Vault shim ───────────────────────────────────────────────────
-- private.get_kms_key() (used by the PII-encryption triggers on
-- public.users) reads the KMS key from vault.decrypted_secrets by design —
-- deliberately never hard-coded (see 07_functions.sql's own comment on
-- private.get_kms_key()). Real Supabase projects provide the `vault`
-- extension; this plain Postgres instance doesn't, so stub just enough of
-- its shape to let the trigger run in tests, seeded with a throwaway
-- test-only key.
CREATE SCHEMA IF NOT EXISTS vault;
CREATE TABLE IF NOT EXISTS vault.decrypted_secrets (
  name text PRIMARY KEY,
  decrypted_secret text
);
INSERT INTO vault.decrypted_secrets (name, decrypted_secret)
VALUES ('eduzone_kms_key', 'test-only-kms-key-not-for-production-32bytes!!')
ON CONFLICT (name) DO NOTHING;
GRANT USAGE ON SCHEMA vault TO anon, authenticated, service_role;
GRANT SELECT ON vault.decrypted_secrets TO anon, authenticated, service_role;
