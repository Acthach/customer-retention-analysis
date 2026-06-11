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

Baseline churn is 56.7% across 440,832 customers, which is abnormally high for any
real subscription business and the first hint this dataset is synthetic.

**Contract type is deterministic.** Every monthly-contract customer churned, all
87,104 of them, taking roughly $48M in spend with them. Quarterly and Annual sit
nearly identical at ~46%, with no gradient between them. Real data would not look
like this.

**Support calls are the strongest behavioral signal.** Churn holds flat around 30%
through 2 calls, climbs to 42% at 3 and 58% at 4, jumps to 95% at 5, and is exactly
100% at 6 or more. If this were a real business, 5 calls would be the intervention
trigger: by call 6 the customer is already gone.

**Low spenders fall off a cliff.** Within Quarterly and Annual contracts, the bottom
spend quartile churns at 91.4% versus roughly 31% for everyone above it. It is a
cliff, not a slope, and the same customers also average more support calls and
longer payment delays.

**Tenure barely matters.** Churn hovers between 54% and 64% across every tenure
bucket from new customers to 5-year veterans. Real businesses show loyalty curves;
this one does not, another synthetic tell.

**Demographics carry hard rules too.** Every customer 60+ churned, both genders.
Below 60, women churn 15 to 20 points higher than men in every age band (55% vs 37%
for ages 30 to 44).

Roughly 48% of total customer spend, about $135M, walked out the door, spread almost
evenly across Basic, Standard, and Premium plans.

Something to notice is that this is synthetic data The natural next step is rerunning this pipeline against a real-world dataset like IBM's Telco churn data, where the signals are noisy and the modeling actually gets hard.

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
