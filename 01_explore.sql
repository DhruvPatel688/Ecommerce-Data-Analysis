-- ============================================================================
-- STEP 1: DATA EXPLORATION & PROFILING (01_explore.sql)
-- Source: bigquery-public-data.thelook_ecommerce
-- ============================================================================

-- 1. Schema & Column Metadata Verification (INFORMATION_SCHEMA)
SELECT
  table_name,
  ordinal_position,
  column_name,
  data_type
FROM `bigquery-public-data.thelook_ecommerce.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name IN ('orders', 'order_items', 'products', 'users')
ORDER BY table_name, ordinal_position;


-- 2. Baseline Row Counts & Date Boundaries Across Core Tables
SELECT
  'orders' AS table_name,
  COUNT(*) AS row_count,
  MIN(DATE(created_at)) AS min_date,
  MAX(DATE(created_at)) AS max_date
FROM `bigquery-public-data.thelook_ecommerce.orders`
UNION ALL
SELECT
  'order_items' AS table_name,
  COUNT(*) AS row_count,
  MIN(DATE(created_at)) AS min_date,
  MAX(DATE(created_at)) AS max_date
FROM `bigquery-public-data.thelook_ecommerce.order_items`
UNION ALL
SELECT
  'users' AS table_name,
  COUNT(*) AS row_count,
  MIN(DATE(created_at)) AS min_date,
  MAX(DATE(created_at)) AS max_date
FROM `bigquery-public-data.thelook_ecommerce.users`
UNION ALL
SELECT
  'products' AS table_name,
  COUNT(*) AS row_count,
  CAST(NULL AS DATE) AS min_date,
  CAST(NULL AS DATE) AS max_date
FROM `bigquery-public-data.thelook_ecommerce.products`
ORDER BY table_name;


-- 3. Products Dimension Profile (Primary Key Uniqueness & Pricing Sanity Checks)
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT id) AS distinct_ids,
  COUNT(DISTINCT category) AS distinct_categories,
  COUNT(DISTINCT department) AS distinct_departments,
  ROUND(MIN(cost), 2) AS min_cost,
  ROUND(MAX(cost), 2) AS max_cost,
  ROUND(MIN(retail_price), 2) AS min_retail_price,
  ROUND(MAX(retail_price), 2) AS max_retail_price,
  COUNTIF(cost <= 0) AS non_positive_cost_rows,
  COUNTIF(retail_price <= 0) AS non_positive_retail_rows,
  COUNTIF(cost > retail_price) AS inverted_margin_rows
FROM `bigquery-public-data.thelook_ecommerce.products`;


-- 4. Order Item Lifecycle & Timestamp Population by Status
SELECT
  status,
  COUNT(*) AS total_items,
  COUNT(shipped_at) AS has_shipped_at,
  COUNT(delivered_at) AS has_delivered_at,
  COUNT(returned_at) AS has_returned_at
FROM `bigquery-public-data.thelook_ecommerce.order_items`
GROUP BY status
ORDER BY total_items DESC;


-- 5. Header vs. Line-Item Grain & Status Consistency (orders vs. order_items)
WITH item_summary AS (
  SELECT
    order_id,
    COUNT(*) AS actual_item_count,
    COUNT(DISTINCT status) AS distinct_item_statuses,
    MIN(status) AS sample_item_status
  FROM `bigquery-public-data.thelook_ecommerce.order_items`
  GROUP BY order_id
)
SELECT
  COUNT(*) AS total_orders,
  COUNTIF(s.order_id IS NULL) AS orders_without_items,
  COUNTIF(o.num_of_item != s.actual_item_count) AS item_count_mismatches,
  COUNTIF(s.distinct_item_statuses > 1) AS mixed_status_orders,
  COUNTIF(o.status != s.sample_item_status) AS header_vs_item_status_mismatches
FROM `bigquery-public-data.thelook_ecommerce.orders` o
LEFT JOIN item_summary s
  ON o.order_id = s.order_id;
