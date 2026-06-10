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
## Model

Three models, trained on 352k customers with a 20% stratified holdout (churn rate 56.7%).

| Model | ROC-AUC | PR-AUC |
|---|---|---|
| Logistic regression (baseline) | ___ | ___ |
| XGBoost, all features | 1.000 | 1.000 |
| XGBoost, behavioral features only | 0.961 | 0.978 |

The all-features model scoring a perfect 1.0 is not a win. The dataset is synthetic
with hard-coded rules: every monthly-contract customer churns, every customer 60+
churns, and churn hits exactly 100% at 6+ support calls. A model that memorizes
those rules has learned nothing a real business could use.

So the headline model is the behavioral one. It only sees what a retention team can
actually act on (support calls, payment delay, usage frequency, spend, tenure) and
still reaches a PR-AUC of 0.978. SHAP confirms support calls and payment delay carry
most of the signal, matching the EDA. Predicted scores are sharply bimodal, with
almost no customers in the uncertain middle. That is consistent with rule-driven
data generation, and it is the kind of thing worth noticing before trusting a score.

### Picking a threshold

AUC does not answer the question a business actually has: who do we spend retention
money on? With a simple cost model ($30 offer, 40% save rate, lost customers cost
their average spend of ~$620), the cost-optimal threshold lands at 0.12, flagging
75% of customers. That policy catches 97% of churners at the cost of sending offers
to some customers who would have stayed anyway (73% precision).

A threshold that low looks wrong until you check the economics: a $30 offer is cheap
insurance on a $620 customer when more than half the base churns. Raise the offer
cost or lower the save rate and the optimal threshold climbs sharply. That is the
point of this section. The cutoff is a business decision driven by offer economics,
not a default 0.5 from the model.
## Dashboard

<!-- phase 4: link to Tableau Public / Streamlit app + screenshot -->
