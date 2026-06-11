-- dashboard extract: one flat row per customer, everything tableau needs.
-- joins the phase 1 tables with the phase 3 model scores.
-- run: psql -d churn -f sql/04_dashboard_extract.sql
-- output lands in data/dashboard_extract.csv

CREATE OR REPLACE VIEW dashboard_extract AS
SELECT cu.customer_id,
       cu.age,
       CASE WHEN cu.age < 30 THEN '18-29'
            WHEN cu.age < 45 THEN '30-44'
            WHEN cu.age < 60 THEN '45-59'
            ELSE '60+' END AS age_band,
       cu.gender,
       p.plan_name,
       c.contract_name,
       c.months                AS contract_months,
       s.tenure_months,
       s.total_spend,
       ROUND(s.total_spend / GREATEST(s.tenure_months, 1), 2) AS spend_per_month,
       a.usage_frequency,
       a.support_calls,
       a.payment_delay_days,
       a.last_interaction_days,
       (a.support_calls >= 5)  AS high_support,
       l.churned,
       m.churn_prob,
       m.risk_band
FROM customers cu
JOIN subscriptions s      ON s.customer_id = cu.customer_id
JOIN plan_types p         ON p.plan_type_id = s.plan_type_id
JOIN contract_types c     ON c.contract_type_id = s.contract_type_id
JOIN customer_activity a  ON a.customer_id = cu.customer_id
JOIN churn_labels l       ON l.customer_id = cu.customer_id
LEFT JOIN model_scores m  ON m.customer_id = cu.customer_id;

-- export. \copy runs client-side so it writes wherever you launched psql from
\copy (SELECT * FROM dashboard_extract) TO 'data/dashboard_extract.csv' WITH (FORMAT csv, HEADER true)
