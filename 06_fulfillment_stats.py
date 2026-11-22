from google.colab import auth
from google.cloud import bigquery
import pandas as pd
import numpy as np
from scipy import stats

# 1. Authenticate with your Google account (uses your Sandbox BigQuery project)
auth.authenticate_user()
PROJECT_ID = "fedex-515502"  # <-- REPLACE WITH YOUR PROJECT ID
client = bigquery.Client(project=PROJECT_ID)

# 2. Query star schema (fact_orders + dim_products)
query = """
SELECT
  f.order_item_id,
  f.status,
  f.hours_to_ship,
  f.is_shipped_within_24h,
  f.gross_revenue,
  p.department,
  p.distribution_center_id
FROM `ecommerce_warehouse.fact_orders` f
JOIN `ecommerce_warehouse.dim_products` p
  ON f.product_id = p.product_id
WHERE f.hours_to_ship IS NOT NULL
"""
df = client.query(query).to_dataframe()
print(f"Loaded {len(df):,} shipped order items from BigQuery.\n")

# 3. Hypothesis Test 1: Do Returned items take longer to ship than non-returned shipped items?
returned = df[df["status"] == "Returned"]["hours_to_ship"]
kept = df[df["status"].isin(["Shipped", "Complete"])]["hours_to_ship"]

t_stat, p_val_t = stats.ttest_ind(returned, kept, equal_var=False)
u_stat, p_val_u = stats.mannwhitneyu(returned, kept, alternative="two-sided")

def ci_95(series):
    mean = series.mean()
    se = stats.sem(series)
    margin = se * stats.t.ppf(0.975, len(series) - 1)
    return round(mean, 2), round(mean - margin, 2), round(mean + margin, 2)

print("--- TEST 1: Shipping Speed (Returned vs. Non-Returned) ---")
print(f"Returned (n={len(returned):,}): Mean = {ci_95(returned)[0]}h (95% CI: {ci_95(returned)[1]}h - {ci_95(returned)[2]}h)")
print(f"Kept     (n={len(kept):,}): Mean = {ci_95(kept)[0]}h (95% CI: {ci_95(kept)[1]}h - {ci_95(kept)[2]}h)")
print(f"Welch's t-test p-value = {p_val_t:.4f} | Mann-Whitney U p-value = {p_val_u:.4f}\n")

# 4. Hypothesis Test 2: Shipping SLA across Distribution Centers
dc_summary = (
    df.groupby("distribution_center_id")
    .agg(
        shipped_items=("order_item_id", "count"),
        mean_hours=("hours_to_ship", "mean"),
        median_hours=("hours_to_ship", "median"),
        pct_24h=("is_shipped_within_24h", "mean"),
    )
    .round({"mean_hours": 2, "median_hours": 2, "pct_24h": 4})
)
dc_summary["pct_24h"] = (dc_summary["pct_24h"] * 100).round(2)
groups = [g["hours_to_ship"].values for _, g in df.groupby("distribution_center_id")]
f_stat, p_val_anova = stats.f_oneway(*groups)

print("--- TEST 2: Fulfillment Speed by Distribution Center ---")
print(dc_summary.sort_values("mean_hours", ascending=False))
print(f"\nOne-way ANOVA across Distribution Centers: F = {f_stat:.4f}, p-value = {p_val_anova:.4f}")
