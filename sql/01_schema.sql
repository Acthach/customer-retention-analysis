-- schema for customer retention project
-- pattern: raw csv -> staging -> normalized tables
-- run once: psql -d churn -f sql/01_schema.sql

CREATE SCHEMA IF NOT EXISTS staging;

-- staging table mirrors the kaggle csv exactly, all text so nothing
-- blows up on load. cleaning happens in the transform step, not here
DROP TABLE IF EXISTS staging.churn_raw;
CREATE TABLE staging.churn_raw (
    customer_id      TEXT,
    age              TEXT,
    gender           TEXT,
    tenure           TEXT,
    usage_frequency  TEXT,
    support_calls    TEXT,
    payment_delay    TEXT,
    subscription_type TEXT,
    contract_length  TEXT,
    total_spend      TEXT,
    last_interaction TEXT,
    churn            TEXT
);

-- ---------- lookups ----------

CREATE TABLE IF NOT EXISTS plan_types (
    plan_type_id  SMALLSERIAL PRIMARY KEY,
    plan_name     TEXT NOT NULL UNIQUE      -- Basic / Standard / Premium
);

CREATE TABLE IF NOT EXISTS contract_types (
    contract_type_id SMALLSERIAL PRIMARY KEY,
    contract_name    TEXT NOT NULL UNIQUE,  -- Monthly / Quarterly / Annual
    months           SMALLINT NOT NULL      -- handy for sorting + revenue math
);

-- ---------- core tables ----------

CREATE TABLE IF NOT EXISTS customers (
    customer_id BIGINT PRIMARY KEY,
    age         SMALLINT CHECK (age BETWEEN 18 AND 120),
    gender      TEXT CHECK (gender IN ('Male', 'Female'))
);

CREATE TABLE IF NOT EXISTS subscriptions (
    customer_id      BIGINT PRIMARY KEY REFERENCES customers(customer_id),
    plan_type_id     SMALLINT NOT NULL REFERENCES plan_types(plan_type_id),
    contract_type_id SMALLINT NOT NULL REFERENCES contract_types(contract_type_id),
    tenure_months    SMALLINT NOT NULL CHECK (tenure_months >= 0),
    total_spend      NUMERIC(10,2) NOT NULL CHECK (total_spend >= 0)
);

CREATE TABLE IF NOT EXISTS customer_activity (
    customer_id           BIGINT PRIMARY KEY REFERENCES customers(customer_id),
    usage_frequency       SMALLINT,   -- uses per month
    support_calls         SMALLINT,
    payment_delay_days    SMALLINT,
    last_interaction_days SMALLINT    -- days since last touch
);

-- labels live in their own table. in a real pipeline these show up
-- later/separately from the customer attributes, so model it that way
CREATE TABLE IF NOT EXISTS churn_labels (
    customer_id BIGINT PRIMARY KEY REFERENCES customers(customer_id),
    churned     BOOLEAN NOT NULL
);

-- indexes for the dashboard queries (joins are all on PKs already,
-- these cover the common group-bys)
CREATE INDEX IF NOT EXISTS idx_subs_plan     ON subscriptions(plan_type_id);
CREATE INDEX IF NOT EXISTS idx_subs_contract ON subscriptions(contract_type_id);
CREATE INDEX IF NOT EXISTS idx_subs_tenure   ON subscriptions(tenure_months);
