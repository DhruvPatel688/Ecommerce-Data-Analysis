CREATE OR REPLACE TABLE `ecommerce_warehouse.dq_results` AS

-- Check 1: Null keys in fact_orders
SELECT
  'fact_orders_null_keys' AS check_name,
  CURRENT_TIMESTAMP() AS checked_at,
  COUNT(*) AS rows_checked,
  COUNTIF(
    order_item_id IS NULL
    OR order_id IS NULL
    OR user_id IS NULL
    OR product_id IS NULL
    OR order_date IS NULL
  ) AS rows_failing,
  IF(COUNTIF(order_item_id IS NULL OR order_id IS NULL OR user_id IS NULL OR product_id IS NULL OR order_date IS NULL) = 0, 'PASS', 'FAIL') AS status,
  'Verifies primary key, foreign keys, and partition key are non-null' AS notes
FROM `ecommerce_warehouse.fact_orders`

UNION ALL

-- Check 2: Duplicate order_item_id in fact_orders
SELECT
  'fact_orders_duplicate_grain_key' AS check_name,
  CURRENT_TIMESTAMP() AS checked_at,
  COUNT(*) AS rows_checked,
  COUNT(*) - COUNT(DISTINCT order_item_id) AS rows_failing,
  IF(COUNT(*) - COUNT(DISTINCT order_item_id) = 0, 'PASS', 'FAIL') AS status,
  'Confirms 1-row-per-order-item grain with zero duplicate order_item_ids' AS notes
FROM `ecommerce_warehouse.fact_orders`

UNION ALL

-- Check 3: Orphan order_items (missing parent order, user, or product)
SELECT
  'stg_order_items_orphan_foreign_keys' AS check_name,
  CURRENT_TIMESTAMP() AS checked_at,
  COUNT(*) AS rows_checked,
  COUNTIF(o.order_id IS NULL OR u.user_id IS NULL OR p.product_id IS NULL) AS rows_failing,
  IF(COUNTIF(o.order_id IS NULL OR u.user_id IS NULL OR p.product_id IS NULL) = 0, 'PASS', 'FAIL') AS status,
  'Checks referential integrity against stg_orders, stg_users, and stg_products' AS notes
FROM `ecommerce_warehouse.stg_order_items` oi
LEFT JOIN `ecommerce_warehouse.stg_orders` o ON oi.order_id = o.order_id
LEFT JOIN `ecommerce_warehouse.stg_users` u ON oi.user_id = u.user_id
LEFT JOIN `ecommerce_warehouse.stg_products` p ON oi.product_id = p.product_id

UNION ALL

-- Check 4: Non-positive sale prices
SELECT
  'stg_order_items_non_positive_price' AS check_name,
  CURRENT_TIMESTAMP() AS checked_at,
  COUNT(*) AS rows_checked,
  COUNTIF(sale_price IS NULL OR sale_price <= 0) AS rows_failing,
  IF(COUNTIF(sale_price IS NULL OR sale_price <= 0) = 0, 'PASS', 'FAIL') AS status,
  'Flags any line items priced at <= $0.00' AS notes
FROM `ecommerce_warehouse.stg_order_items`

UNION ALL

-- Check 5: Shipped before created (time-travel fulfillment timestamps)
SELECT
  'stg_order_items_shipped_before_created' AS check_name,
  CURRENT_TIMESTAMP() AS checked_at,
  COUNT(*) AS rows_checked,
  COUNTIF(shipped_at IS NOT NULL AND shipped_at < created_at) AS rows_failing,
  IF(COUNTIF(shipped_at IS NOT NULL AND shipped_at < created_at) = 0, 'PASS', 'WARN') AS status,
  'Checks for impossible negative fulfillment durations (excluded from hours_to_ship)' AS notes
FROM `ecommerce_warehouse.stg_order_items`

UNION ALL

-- Check 6: Order item created before parent order header
SELECT
  'stg_order_items_created_before_order' AS check_name,
  CURRENT_TIMESTAMP() AS checked_at,
  COUNT(*) AS rows_checked,
  COUNTIF(oi.created_at < o.created_at) AS rows_failing,
  IF(COUNTIF(oi.created_at < o.created_at) = 0, 'PASS', 'WARN') AS status,
  'Checks whether line item timestamp precedes order header timestamp' AS notes
FROM `ecommerce_warehouse.stg_order_items` oi
JOIN `ecommerce_warehouse.stg_orders` o ON oi.order_id = o.order_id

UNION ALL

-- Check 7: Warehouse freshness (latest order_date)
SELECT
  'fact_orders_freshness' AS check_name,
  CURRENT_TIMESTAMP() AS checked_at,
  COUNT(*) AS rows_checked,
  IF(MAX(order_date) IS NULL, 1, 0) AS rows_failing,
  IF(MAX(order_date) IS NOT NULL, 'PASS', 'FAIL') AS status,
  CONCAT('Latest order_date in warehouse: ', CAST(MAX(order_date) AS STRING)) AS notes
FROM `ecommerce_warehouse.fact_orders`;

-- Display your Data Quality Audit Log
SELECT
  check_name,
  rows_checked,
  rows_failing,
  status,
  notes,
  checked_at
FROM `ecommerce_warehouse.dq_results`
ORDER BY check_name;
