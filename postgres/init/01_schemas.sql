-- =============================================================================
-- Schema layout for ELT pipeline (executed at cluster bootstrap by Postgres'
-- entrypoint when placed under /docker-entrypoint-initdb.d/ in the image/container).
-- Purpose of each schema:
--   bronze             → immutable(ish) landings from source systems; minimal shaping only.
--   silver             → cleaned/validated/intermediate transforms ready for modeling.
--   gold               → star/snowflake marts, semantic views, and BI-serving tables.
-- Power BI (read-only) should query *gold* only.
-- =============================================================================

create schema if not exists bronze;
create schema if not exists silver;
create schema if not exists gold;

-- =============================================================================
-- Create tables in the bronze schema. These are the raw landings from source systems.
-- =============================================================================
create table if not exists bronze.customers (
    customer_id UUID primary key,
    company_name TEXT,
    country TEXT,
    industry TEXT,
    company_size TEXT,
    signup_date TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    is_churned BOOLEAN
);

create table if not exists bronze.payments (
    payment_id UUID primary key,
    customer_id UUID,
    product TEXT,
    amount NUMERIC,
    currency TEXT,
    status TEXT,
    refunded_amount NUMERIC,
    fee NUMERIC,
    payment_method TEXT,
    country TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);

create index if not exists idx_bronze_payments_created on bronze.payments (created_at);

create table if not exists bronze.sessions (
    session_id UUID primary key,
    customer_id UUID,
    source TEXT,
    medium TEXT,
    campaign TEXT,
    device TEXT,
    country TEXT,
    pageviews INT,
    session_duration_s INT,
    bounced INT, -- 1 if bounced, 0 if not, preserved as ingested
    converted INT,
    session_start TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);

create index if not exists idx_bronze_sessionsstart on bronze.sessions (session_start);