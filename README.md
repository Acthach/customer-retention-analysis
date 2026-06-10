# Customer Retention Analysis

End-to-end churn analysis: PostgreSQL data pipeline → SQL analysis → ML churn prediction → interactive dashboard.

**Dataset:** [Customer Churn Dataset](https://www.kaggle.com/datasets/muhammadshahidazeem/customer-churn-dataset) (~440k customers, subscription business)

## Architecture

```
kaggle csv ──> staging.churn_raw ──> normalized schema ──> analysis queries ──> dashboard
   (raw)        (load_data.py)        (02_transform.sql)    (03_analysis_*.sql)    (tableau/streamlit)
                                            │
                                            └──> feature extraction ──> churn model (XGBoost + SHAP)
```

## Schema

| Table | What it holds |
|---|---|
| `staging.churn_raw` | Raw CSV landing zone, all text |
| `customers` | Identity + demographics |
| `subscriptions` | Plan, contract, tenure, spend (FKs to lookup tables) |
| `customer_activity` | Usage frequency, support calls, payment delay, last interaction |
| `churn_labels` | Target variable, kept separate as in production pipelines |
| `plan_types`, `contract_types` | Lookups |

## Setup

```bash
createdb churn
psql -d churn -f sql/01_schema.sql
python etl/load_data.py data/customer_churn_dataset-training-master.csv
psql -d churn -f sql/02_transform.sql
```

The transform is rerunnable and handles duplicate/null customer IDs.

## Key findings

<!-- fill these in after running against the real data, with actual numbers:
- baseline churn rate
- churn by contract type + revenue lost
- tenure cohort curve
- support-call elbow
-->

## Model

<!-- phase 3: logistic regression baseline -> XGBoost, PR-AUC, SHAP, threshold-as-business-decision -->

## Dashboard

<!-- phase 4: link to Tableau Public / Streamlit app + screenshot -->
