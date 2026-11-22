[Ecommerce_Report.pdf](https://github.com/user-attachments/files/35227320/Ecommerce_Report.pdf): https://datastudio.google.com/reporting/296c1612-8d8e-4ad6-ad99-cf53784f9bbf

# E-Commerce Operations & Fulfillment Data Warehouse

An end-to-end cloud data warehouse, automated data quality framework, statistical root-cause analysis, and executive BI dashboard built on **Google BigQuery**, **Python**, and **Looker Studio** using Google's public `thelook_ecommerce` dataset.

---

## Executive Summary & Key Findings

To support operational decision-making across revenue, fulfillment SLA attainment, customer retention, and data governance, this project models raw transactional e-commerce tables into a partitioned and clustered star schema (`ecommerce_warehouse`) covering **22,449 order line items** across **15,419 orders** (`2026-09-23` to `2026-11-25`).

### Core Operational Insights
* **Revenue Leakage (25.18%):** Out of **$1,351,754.24** in gross order value, **$340,366.97** was lost to cancellations ($199,875.54; 14.94% of items) and returns ($140,491.43; ~10.24% of items), leaving **$1,011,387.27** in recognized net revenue across 11,532 valid orders.
* **Fulfillment SLA Bottleneck:** Average time-to-ship across valid shipments ($n = 10,035$) is **34.83 hours**, with only **36.62%** meeting a 24-hour SLA and **69.96%** meeting a 48-hour SLA.
* **Statistical Root-Cause Diagnosis (Python):**
  * **Shipping Latency vs. Returns:** Welch's two-sample t-test ($p = 0.4177$) and Mann-Whitney U test ($p = 0.4590$) confirmed no statistically significant difference in shipping time between returned items ($\mu = 34.44\text{h}$, 95% CI: $33.42\text{h}–35.47\text{h}$) and retained items ($\mu = 34.90\text{h}$, 95% CI: $34.46\text{h}–35.35\text{h}$). Return reduction efforts should target product sizing/listing accuracy rather than warehouse picking speed.
  * **Facility-Level Variance:** One-way ANOVA across all 10 distribution centers ($F = 0.6276, p = 0.7745$) showed uniform shipping averages ($33.76\text{h}–35.53\text{h}$), proving the 24-hour SLA miss is a **network-wide carrier cutoff/process bottleneck** rather than an isolated facility failure.
* **Customer Concentration:** One-time buyers ($5,723$ customers) generate **49.84%** ($504,041.32) of net revenue, 2–3 order customers ($3,564$) generate **42.99%** ($434,785.27), and 4+ order power buyers ($441$) generate **7.17%** ($72,560.68).

---

## Architecture & Pipeline Layers

```text
bigquery-public-data.thelook_ecommerce (Raw Source)
        │
        ▼  [01_explore.sql] Schema, grain & pricing validation
ecommerce_warehouse.stg_* (Staging Layer)
        │  - Standardized PKs (order_item_id, user_id, product_id)
        │  - Whitespace trimming & ingestion audit timestamps (ingested_at)
        │
        ▼  [03_star_schema.sql] Dimensional Modeling
ecommerce_warehouse (Star Schema)
  ├── fact_orders      (Grain: 1 row/order item | Partitioned by order_date, Clustered by status)
  ├── dim_dates        (Continuous date spine: 2019–2026)
  ├── dim_customers    (PII-free demographics + pre-computed buyer_segment tiers)
  └── dim_products     (Catalog attributes, unit_cost, retail_price, unit_margin)
        │
        ├──▶ [04_dq_checks.sql] ──▶ ecommerce_warehouse.dq_results (7 Automated Governance Checks)
        ├──▶ [06_fulfillment_stats.py] ──▶ Python Hypothesis Testing (Welch's t-test, Mann-Whitney U, ANOVA)
        └──▶ [05_analysis_and_view.sql] ──▶ vw_dashboard_orders ──▶ Looker Studio Executive Dashboard
