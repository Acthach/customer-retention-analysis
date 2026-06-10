-- transform: staging.churn_raw -> normalized tables
-- run after load_data.py has filled staging
-- psql -d churn -f sql/02_transform.sql

BEGIN;

-- wipe in FK order so this script is rerunnable
TRUNCATE churn_labels, customer_activity, subscriptions, customers CASCADE;

-- seed lookups from whatever's actually in the data
INSERT INTO plan_types (plan_name)
SELECT DISTINCT subscription_type
FROM staging.churn_raw
WHERE subscription_type IS NOT NULL
ON CONFLICT (plan_name) DO NOTHING;

INSERT INTO contract_types (contract_name, months)
SELECT DISTINCT contract_length,
       CASE contract_length
            WHEN 'Monthly'   THEN 1
            WHEN 'Quarterly' THEN 3
            WHEN 'Annual'    THEN 12
       END
FROM staging.churn_raw
WHERE contract_length IS NOT NULL
ON CONFLICT (contract_name) DO NOTHING;

-- dedupe guard: the kaggle file shouldn't have dupes but don't trust it.
-- also drop the handful of rows with null ids (the train csv has one)
WITH clean AS (
    SELECT DISTINCT ON (customer_id) *
    FROM staging.churn_raw
    WHERE customer_id IS NOT NULL AND customer_id <> ''
    ORDER BY customer_id
)
INSERT INTO customers (customer_id, age, gender)
SELECT customer_id::BIGINT,
       NULLIF(age, '')::NUMERIC::SMALLINT,
       NULLIF(gender, '')
FROM clean;

INSERT INTO subscriptions (customer_id, plan_type_id, contract_type_id, tenure_months, total_spend)
SELECT DISTINCT ON (r.customer_id)
       r.customer_id::BIGINT,
       p.plan_type_id,
       c.contract_type_id,
       r.tenure::NUMERIC::SMALLINT,
       r.total_spend::NUMERIC(10,2)
FROM staging.churn_raw r
JOIN plan_types p     ON p.plan_name = r.subscription_type
JOIN contract_types c ON c.contract_name = r.contract_length
WHERE r.customer_id IS NOT NULL AND r.customer_id <> ''
ORDER BY r.customer_id;

INSERT INTO customer_activity (customer_id, usage_frequency, support_calls, payment_delay_days, last_interaction_days)
SELECT DISTINCT ON (customer_id)
       customer_id::BIGINT,
       NULLIF(usage_frequency, '')::NUMERIC::SMALLINT,
       NULLIF(support_calls, '')::NUMERIC::SMALLINT,
       NULLIF(payment_delay, '')::NUMERIC::SMALLINT,
       NULLIF(last_interaction, '')::NUMERIC::SMALLINT
FROM staging.churn_raw
WHERE customer_id IS NOT NULL AND customer_id <> ''
ORDER BY customer_id;

INSERT INTO churn_labels (customer_id, churned)
SELECT DISTINCT ON (customer_id)
       customer_id::BIGINT,
       churn::NUMERIC::INT = 1
FROM staging.churn_raw
WHERE customer_id IS NOT NULL AND customer_id <> ''
  AND churn IS NOT NULL AND churn <> ''
ORDER BY customer_id;

COMMIT;

-- quick sanity check, eyeball these after running
SELECT 'customers' t, COUNT(*) FROM customers
UNION ALL SELECT 'subscriptions', COUNT(*) FROM subscriptions
UNION ALL SELECT 'activity', COUNT(*) FROM customer_activity
UNION ALL SELECT 'labels', COUNT(*) FROM churn_labels;
