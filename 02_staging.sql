-- 1. Create your personal warehouse dataset in the US multi-region
CREATE SCHEMA IF NOT EXISTS `ecommerce_warehouse`
OPTIONS (
  location = 'US',
  description = 'Staging and star schema warehouse for e-commerce operations & fulfillment analytics'
);

-- 2. Stage orders
CREATE OR REPLACE TABLE `ecommerce_warehouse.stg_orders` AS
SELECT
  order_id,
  user_id,
  TRIM(status) AS status,
  TRIM(gender) AS gender,
  created_at,
  shipped_at,
  delivered_at,
  returned_at,
  num_of_item,
  CURRENT_TIMESTAMP() AS ingested_at
FROM `bigquery-public-data.thelook_ecommerce.orders`;

-- 3. Stage order_items (renaming id -> order_item_id)
CREATE OR REPLACE TABLE `ecommerce_warehouse.stg_order_items` AS
SELECT
  id AS order_item_id,
  order_id,
  user_id,
  product_id,
  inventory_item_id,
  TRIM(status) AS status,
  created_at,
  shipped_at,
  delivered_at,
  returned_at,
  sale_price,
  CURRENT_TIMESTAMP() AS ingested_at
FROM `bigquery-public-data.thelook_ecommerce.order_items`;

-- 4. Stage users (renaming id -> user_id, omitting user_geom)
CREATE OR REPLACE TABLE `ecommerce_warehouse.stg_users` AS
SELECT
  id AS user_id,
  TRIM(first_name) AS first_name,
  TRIM(last_name) AS last_name,
  TRIM(email) AS email,
  age,
  TRIM(gender) AS gender,
  TRIM(state) AS state,
  TRIM(postal_code) AS postal_code,
  TRIM(city) AS city,
  TRIM(country) AS country,
  latitude,
  longitude,
  TRIM(traffic_source) AS traffic_source,
  created_at,
  CURRENT_TIMESTAMP() AS ingested_at
FROM `bigquery-public-data.thelook_ecommerce.users`;

-- 5. Stage products (renaming id -> product_id and name -> product_name)
CREATE OR REPLACE TABLE `ecommerce_warehouse.stg_products` AS
SELECT
  id AS product_id,
  TRIM(name) AS product_name,
  TRIM(category) AS category,
  TRIM(brand) AS brand,
  TRIM(department) AS department,
  TRIM(sku) AS sku,
  distribution_center_id,
  cost,
  retail_price,
  CURRENT_TIMESTAMP() AS ingested_at
FROM `bigquery-public-data.thelook_ecommerce.products`;

-- 6. Verify all four staging tables loaded cleanly
SELECT 'stg_orders' AS table_name, COUNT(*) AS row_count FROM `ecommerce_warehouse.stg_orders`
UNION ALL
SELECT 'stg_order_items' AS table_name, COUNT(*) AS row_count FROM `ecommerce_warehouse.stg_order_items`
UNION ALL
SELECT 'stg_users' AS table_name, COUNT(*) AS row_count FROM `ecommerce_warehouse.stg_users`
UNION ALL
SELECT 'stg_products' AS table_name, COUNT(*) AS row_count FROM `ecommerce_warehouse.stg_products`
ORDER BY table_name;
