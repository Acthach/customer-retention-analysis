# load the kaggle csv into staging.churn_raw, then hand off to sql
# usage: python etl/load_data.py data/customer_churn_dataset-training-master.csv
#
# needs: pip install psycopg2-binary
# assumes a local postgres db called "churn", tweak DSN below if not

import csv
import io
import os
import sys

import psycopg2

# override with e.g. CHURN_DSN="dbname=churn host=localhost user=me password=..."
DSN = os.environ.get("CHURN_DSN", "dbname=churn")

# csv header -> staging column, also defines the column order for COPY
COLS = [
    "customer_id", "age", "gender", "tenure", "usage_frequency",
    "support_calls", "payment_delay", "subscription_type",
    "contract_length", "total_spend", "last_interaction", "churn",
]


def load(path):
    conn = psycopg2.connect(DSN)
    cur = conn.cursor()

    # stream the file through an in-memory buffer so we can skip the
    # header and not care about the kaggle column names ("Usage Frequency" etc)
    buf = io.StringIO()
    n = 0
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        next(reader)  # header
        w = csv.writer(buf)
        for row in reader:
            if len(row) != len(COLS):
                continue  # malformed line, skip it
            w.writerow(row)
            n += 1
    buf.seek(0)

    cur.execute("TRUNCATE staging.churn_raw")
    cur.copy_expert(
        f"COPY staging.churn_raw ({', '.join(COLS)}) FROM STDIN WITH (FORMAT csv, NULL '')",
        buf,
    )
    conn.commit()

    cur.execute("SELECT COUNT(*) FROM staging.churn_raw")
    print(f"read {n} rows from csv, staging now has {cur.fetchone()[0]}")

    cur.close()
    conn.close()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python etl/load_data.py <path to csv>")
    load(sys.argv[1])
    print("done. now run: psql -d churn -f sql/02_transform.sql")
