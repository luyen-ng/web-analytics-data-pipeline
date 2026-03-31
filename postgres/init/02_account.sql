-- =============================================================================
-- BI read-only user provisioning
-- Goal: allow Power BI (or other BI tools) to read gold and bronze data with SELECT privileges, but not silver (which is intermediate/dirty).
-- Idempotent and safe to re-run.
-- =============================================================================

-- 1) Create or reset the login role (rotate password if it already exists)
DO 
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bi_reader') THEN
        CREATE ROLE bi_reader LOGIN PASSWORD 'bi_reader_password';
    ELSE
        ALTER ROLE bi_reader WITH PASSWORD 'bi_reader_password';
    END IF;
END
$$;

-- 2) Base connect privileges to the database
GRANT CONNECT ON DATABASE db TO bi_reader;

-- 3a) Remove any existing schema-level and table-level privileges for bi_reader (to ensure idempotency)
REVOKE USAGE ON SCHEMA public FROM bi_reader;
REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM bi_reader;
REVOKE USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public FROM bi_reader;

REVOKE USAGE ON SCHEMA silver FROM bi_reader;
REVOKE SELECT ON ALL TABLES IN SCHEMA silver FROM bi_reader;
REVOKE USAGE, SELECT ON ALL SEQUENCES IN SCHEMA silver FROM bi_reader;

-- 3b) Grant USAGE and SELECT on bronze and gold schemas
GRANT USAGE ON SCHEMA bronze TO bi_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA bronze TO bi_reader;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA bronze TO bi_reader;

GRANT USAGE ON SCHEMA gold TO bi_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA gold TO bi_reader;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA gold TO bi_reader;

-- 4a) Future-proofing: ensure bi_reader gets SELECT privileges on any new tables/sequences in bronze and gold
ALTER DEFAULT PRIVILEGES IN SCHEMA bronze GRANT SELECT ON TABLES TO bi_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA bronze GRANT USAGE, SELECT ON SEQUENCES TO bi_reader;

ALTER DEFAULT PRIVILEGES IN SCHEMA gold GRANT SELECT ON TABLES TO bi_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA gold GRANT USAGE, SELECT ON SEQUENCES TO bi_reader;

-- 4b) Ensure bi_reader does NOT get privileges on new tables in silver and public
ALTER DEFAULT PRIVILEGES IN SCHEMA silver REVOKE SELECT ON TABLES FROM bi_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA silver REVOKE USAGE, SELECT ON SEQUENCES FROM bi_reader;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT ON TABLES FROM bi_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE USAGE, SELECT ON SEQUENCES FROM bi_reader;

-- 5) QoL: make name resolution predictable for bi_reader by setting search_path
ALTER ROLE bi_reader SET search_path TO gold, bronze;

-- Operational notes:
-- - Rotate 'bi_reader_password' via secret management.
-- - Ensure the role that creates objects in each schema runs the ALTER DEFAULT PRIVILEGES.
-- - If Row-Level Security (RLS) is enableds on any target tables, define SELECT policies for bi_read.