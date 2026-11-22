-- ============================================================================
-- 1. DIMENSION: dim_dates
-- ============================================================================
CREATE OR REPLACE TABLE `ecommerce_warehouse.dim_dates` AS
SELECT
  date_day,
  EXTRACT(YEAR FROM date_day) AS year,
  EXTRACT(QUARTER FROM date_day) AS quarter,
  EXTRACT(MONTH FROM date_day) AS month,
  FORMAT_DATE('%B', date_day) AS month_name,
  FORMAT_DATE('%Y-%m', date_day) AS year_month,
  EXTRACT(DAY FROM date_day) AS day_of_month,
  EXTRACT(DAYOFWEEK FROM date_day) AS day_of_week, -- 1 = Sunday, 7 = Saturday
  FORMAT_DATE('%A', date_day) AS day_name,
  EXTRACT(DAYOFWEEK FROM date_day) IN (1, 7) AS is_weekend
FROM
  UNNEST(GENERATE_DATE_ARRAY('2019-01-01', '2026-12-31')) AS date_day;


-- ============================================================================
-- 2. DIMENSION: dim_customers (with pre-computed order frequency segments)
-- ============================================================================
CREATE OR REPLACE TABLE `ecommerce_warehouse.dim_customers` AS
WITH customer_order_stats AS (
  SELECT
    user_id,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT CASE WHEN status NOT IN ('Cancelled', 'Returned') THEN order_id END) AS valid_orders,
    DATE(MIN(created_at)) AS first_order_date,
    DATE(MAX(created_at)) AS last_order_date
  FROM `ecommerce_warehouse.stg_orders`
  GROUP BY user_id
)
SELECT
  u.user_id,
  u.age,
  u.gender,
  u.city,
  u.state,
  u.postal_code,
  u.country,
  u.traffic_source,
  DATE(u.created_at) AS signup_date,
  COALESCE(s.total_orders, 0) AS total_orders,
  COALESCE(s.valid_orders, 0) AS valid_orders,
  s.first_order_date,
  s.last_order_date,
  CASE
    WHEN COALESCE(s.valid_orders, 0) = 0 THEN '0 Valid Orders'
    WHEN s.valid_orders = 1 THEN '1 Order'
    WHEN s.valid_orders BETWEEN 2 AND 3 THEN '2-3 Orders'
    ELSE '4+ Orders'
  END AS buyer_segment
FROM `ecommerce_warehouse.stg_users` u
LEFT JOIN customer_order_stats s
  ON u.user_id = s.user_id;


-- ============================================================================
-- 3. DIMENSION: dim_products
-- ============================================================================
CREATE OR REPLACE TABLE `ecommerce_warehouse.dim_products` AS
SELECT
  product_id,
  product_name,
  category,
  brand,
  department,
  sku,
  distribution_center_id,
  ROUND(cost, 2) AS cost,
  ROUND(retail_price, 2) AS retail_price,
  ROUND(retail_price - cost, 2) AS unit_margin
FROM `ecommerce_warehouse.stg_products`;


-- ============================================================================
-- 4. FACT: fact_orders (Grain: 1 row per order line item)
-- ============================================================================
CREATE OR REPLACE TABLE `ecommerce_warehouse.fact_orders`
PARTITION BY order_date
CLUSTER BY status AS
SELECT
  oi.order_item_id,
  oi.order_id,
  oi.user_id,
  oi.product_id,
  DATE(oi.created_at) AS order_date,
  oi.created_at,
  oi.shipped_at,
  oi.delivered_at,
  oi.returned_at,
  oi.status,
  (oi.status IN ('Cancelled', 'Returned')) AS is_cancelled_or_returned,
  ROUND(oi.sale_price, 2) AS gross_revenue,
  CASE
    WHEN oi.status IN ('Cancelled', 'Returned') THEN 0.0
    ELSE ROUND(oi.sale_price, 2)
  END AS net_revenue,
  ROUND(p.cost, 2) AS unit_cost,
  CASE
    WHEN oi.shipped_at IS NOT NULL AND oi.shipped_at >= oi.created_at
    THEN ROUND(TIMESTAMP_DIFF(oi.shipped_at, oi.created_at, MINUTE) / 60.0, 2)
    ELSE NULL
  END AS hours_to_ship,
  CASE
    WHEN oi.shipped_at IS NOT NULL AND oi.shipped_at >= oi.created_at
    THEN (TIMESTAMP_DIFF(oi.shipped_at, oi.created_at, MINUTE) <= 24 * 60)
    ELSE NULL
  END AS is_shipped_within_24h,
  CASE
    WHEN oi.shipped_at IS NOT NULL AND oi.shipped_at >= oi.created_at
    THEN (TIMESTAMP_DIFF(oi.shipped_at, oi.created_at, MINUTE) <= 48 * 60)
    ELSE NULL
  END AS is_shipped_within_48h
FROM `ecommerce_warehouse.stg_order_items` oi
LEFT JOIN `ecommerce_warehouse.stg_products` p
  ON oi.product_id = p.product_id;


-- ============================================================================
-- 5. VERIFICATION: Row counts & revenue sanity check across Star Schema
-- ============================================================================
SELECT
  (SELECT COUNT(*) FROM `ecommerce_warehouse.dim_dates`) AS dim_dates_rows,
  (SELECT COUNT(*) FROM `ecommerce_warehouse.dim_customers`) AS dim_customers_rows,
  (SELECT COUNT(*) FROM `ecommerce_warehouse.dim_products`) AS dim_products_rows,
  (SELECT COUNT(*) FROM `ecommerce_warehouse.fact_orders`) AS fact_orders_rows,
  (SELECT ROUND(SUM(gross_revenue), 2) FROM `ecommerce_warehouse.fact_orders`) AS total_gross_revenue,
  (SELECT ROUND(SUM(net_revenue), 2) FROM `ecommerce_warehouse.fact_orders`) AS total_net_revenue;
