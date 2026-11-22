-- Overall KPI Scorecard Numbers (save these exact figures!)
SELECT
  MIN(order_date) AS min_order_date,
  MAX(order_date) AS max_order_date,
  COUNT(*) AS total_line_items,
  COUNT(DISTINCT order_id) AS total_orders,
  COUNT(DISTINCT CASE WHEN NOT is_cancelled_or_returned THEN order_id END) AS valid_orders,
  ROUND(SUM(gross_revenue), 2) AS total_gross_revenue,
  ROUND(SUM(net_revenue), 2) AS total_net_revenue,
  ROUND(SUM(gross_revenue) - SUM(net_revenue), 2) AS total_leakage_revenue,
  ROUND(AVG(hours_to_ship), 2) AS avg_hours_to_ship,
  ROUND(COUNTIF(is_shipped_within_24h) * 100.0 / NULLIF(COUNT(hours_to_ship), 0), 2) AS pct_shipped_24h,
  ROUND(COUNTIF(is_shipped_within_48h) * 100.0 / NULLIF(COUNT(hours_to_ship), 0), 2) AS pct_shipped_48h
FROM `ecommerce_warehouse.fact_orders`;

SELECT
  d.year_month,
  COUNT(f.hours_to_ship) AS shipped_items,
  ROUND(AVG(f.hours_to_ship), 2) AS avg_hours_to_ship,
  ROUND(COUNTIF(f.is_shipped_within_24h) * 100.0 / NULLIF(COUNT(f.hours_to_ship), 0), 2) AS pct_within_24h,
  ROUND(COUNTIF(f.is_shipped_within_48h) * 100.0 / NULLIF(COUNT(f.hours_to_ship), 0), 2) AS pct_within_48h
FROM `ecommerce_warehouse.fact_orders` f
JOIN `ecommerce_warehouse.dim_dates` d
  ON f.order_date = d.date_day
WHERE f.hours_to_ship IS NOT NULL
GROUP BY d.year_month
ORDER BY d.year_month DESC
LIMIT 12;

SELECT
  status,
  COUNT(DISTINCT order_id) AS distinct_orders,
  COUNT(*) AS line_items,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_items,
  ROUND(SUM(gross_revenue), 2) AS gross_revenue_impact,
  ROUND(SUM(net_revenue), 2) AS recognized_net_revenue,
  ROUND(SUM(gross_revenue - net_revenue), 2) AS leaked_revenue
FROM `ecommerce_warehouse.fact_orders`
GROUP BY status
ORDER BY line_items DESC;

SELECT
  c.buyer_segment,
  COUNT(DISTINCT f.user_id) AS active_customers,
  COUNT(DISTINCT f.order_id) AS distinct_orders,
  ROUND(SUM(f.net_revenue), 2) AS net_revenue,
  ROUND(SUM(f.net_revenue) * 100.0 / SUM(SUM(f.net_revenue)) OVER(), 2) AS pct_net_revenue_share
FROM `ecommerce_warehouse.fact_orders` f
JOIN `ecommerce_warehouse.dim_customers` c
  ON f.user_id = c.user_id
WHERE NOT f.is_cancelled_or_returned
GROUP BY c.buyer_segment
ORDER BY net_revenue DESC;


SELECT
  p.product_id,
  p.product_name,
  p.category,
  p.brand,
  COUNT(*) AS units_sold,
  ROUND(SUM(f.net_revenue), 2) AS net_revenue,
  ROUND(SUM(f.net_revenue - f.unit_cost), 2) AS net_gross_profit
FROM `ecommerce_warehouse.fact_orders` f
JOIN `ecommerce_warehouse.dim_products` p
  ON f.product_id = p.product_id
WHERE NOT f.is_cancelled_or_returned
GROUP BY p.product_id, p.product_name, p.category, p.brand
ORDER BY net_revenue DESC
LIMIT 10;


CREATE OR REPLACE VIEW `ecommerce_warehouse.vw_dashboard_orders` AS
SELECT
  f.order_item_id,
  f.order_id,
  f.order_date,
  d.year_month,
  d.day_name,
  f.status,
  f.is_cancelled_or_returned,
  f.gross_revenue,
  f.net_revenue,
  f.gross_revenue - f.net_revenue AS leaked_revenue,
  f.unit_cost,
  f.net_revenue - IF(f.is_cancelled_or_returned, 0, f.unit_cost) AS net_gross_profit,
  f.hours_to_ship,
  CAST(f.is_shipped_within_24h AS INT64) AS shipped_24h_flag,
  CAST(f.is_shipped_within_48h AS INT64) AS shipped_48h_flag,
  c.user_id,
  c.buyer_segment,
  c.country AS customer_country,
  c.traffic_source,
  p.product_id,
  p.product_name,
  p.category,
  p.brand,
  p.department,
  p.distribution_center_id
FROM `ecommerce_warehouse.fact_orders` f
JOIN `ecommerce_warehouse.dim_dates` d
  ON f.order_date = d.date_day
LEFT JOIN `ecommerce_warehouse.dim_customers` c
  ON f.user_id = c.user_id
LEFT JOIN `ecommerce_warehouse.dim_products` p
  ON f.product_id = p.product_id;
