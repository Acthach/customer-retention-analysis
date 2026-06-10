-- analysis queries
-- these feed the dashboard and the README findings. each one answers
-- a business question, not just "group by something"

-- 1. baseline churn rate
SELECT ROUND(AVG(churned::INT) * 100, 1) AS churn_pct,
       COUNT(*) AS customers
FROM churn_labels;


-- 2. churn by contract type. the classic "month-to-month bleeds customers" cut
SELECT c.contract_name,
       COUNT(*) AS customers,
       ROUND(AVG(l.churned::INT) * 100, 1) AS churn_pct,
       ROUND(SUM(s.total_spend) FILTER (WHERE l.churned), 0) AS spend_lost
FROM subscriptions s
JOIN contract_types c ON c.contract_type_id = s.contract_type_id
JOIN churn_labels l   ON l.customer_id = s.customer_id
GROUP BY c.contract_name, c.months
ORDER BY c.months;


-- 3. tenure cohort retention curve. this is the money chart for the dashboard
SELECT WIDTH_BUCKET(s.tenure_months, 0, 60, 12) AS bucket,
       MIN(s.tenure_months) || '-' || MAX(s.tenure_months) AS tenure_range,
       COUNT(*) AS customers,
       ROUND(AVG(l.churned::INT) * 100, 1) AS churn_pct
FROM subscriptions s
JOIN churn_labels l ON l.customer_id = s.customer_id
GROUP BY bucket
ORDER BY bucket;


-- 4. support calls vs churn. expect a sharp elbow somewhere
SELECT a.support_calls,
       COUNT(*) AS customers,
       ROUND(AVG(l.churned::INT) * 100, 1) AS churn_pct
FROM customer_activity a
JOIN churn_labels l ON l.customer_id = a.customer_id
GROUP BY a.support_calls
ORDER BY a.support_calls;


-- 5. revenue at risk by plan: how much spend walked out the door
SELECT p.plan_name,
       ROUND(SUM(s.total_spend), 0) AS total_spend,
       ROUND(SUM(s.total_spend) FILTER (WHERE l.churned), 0) AS churned_spend,
       ROUND(100.0 * SUM(s.total_spend) FILTER (WHERE l.churned)
             / NULLIF(SUM(s.total_spend), 0), 1) AS pct_at_risk
FROM subscriptions s
JOIN plan_types p   ON p.plan_type_id = s.plan_type_id
JOIN churn_labels l ON l.customer_id = s.customer_id
GROUP BY p.plan_name
ORDER BY churned_spend DESC;


-- 6. risk segments with a window function. ranks customers by spend within
-- contract type and flags the high-value high-risk ones, good talking point
WITH scored AS (
    SELECT s.customer_id,
           c.contract_name,
           s.total_spend,
           a.support_calls,
           a.payment_delay_days,
           l.churned,
           NTILE(4) OVER (PARTITION BY c.contract_name ORDER BY s.total_spend) AS spend_quartile
    FROM subscriptions s
    JOIN contract_types c    ON c.contract_type_id = s.contract_type_id
    JOIN customer_activity a ON a.customer_id = s.customer_id
    JOIN churn_labels l      ON l.customer_id = s.customer_id
)
SELECT contract_name,
       spend_quartile,
       COUNT(*) AS customers,
       ROUND(AVG(churned::INT) * 100, 1) AS churn_pct,
       ROUND(AVG(support_calls), 1) AS avg_support_calls,
       ROUND(AVG(payment_delay_days), 1) AS avg_pay_delay
FROM scored
GROUP BY contract_name, spend_quartile
ORDER BY contract_name, spend_quartile;


-- 7. demographic cut: churn by gender x age band
SELECT cu.gender,
       CASE WHEN cu.age < 30 THEN '18-29'
            WHEN cu.age < 45 THEN '30-44'
            WHEN cu.age < 60 THEN '45-59'
            ELSE '60+' END AS age_band,
       COUNT(*) AS customers,
       ROUND(AVG(l.churned::INT) * 100, 1) AS churn_pct
FROM customers cu
JOIN churn_labels l ON l.customer_id = cu.customer_id
GROUP BY cu.gender, age_band
ORDER BY cu.gender, age_band;
