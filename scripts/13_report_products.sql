/* 
======================================================================================
Product Report
======================================================================================
Purpose:
	- This report consolidates key product metrics and behaviors.

Highlights:
	1. Gathers essential fields such as product name , category , sub-category and cost.
	2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
	3. Aggregates product-level metrics:
		- total order 
		- total sales
		- total quantity sold
		- total customer (unique)
		- lifespan (in months)
	4. Calculates valuable KPIs:
		- recency (months since last sale)
		- average order revenue (AOR)
		- average monthly revenue
*/

-- =============================================================================
-- Create Report: gold.report_products
-- =============================================================================
IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
    DROP VIEW gold.report_products;
GO

CREATE VIEW gold.report_products AS
WITH SSE AS(
SELECT 
f.customer_key,
f.order_date,
f.order_number,
f.sales_amount,
f.quantity,
p.product_key,
p.product_name,
p.category,
p.subcategory,
p.cost
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p 
ON f.product_key = p.product_key
WHERE order_date IS NOT NULL -- only consider valid sales dates
)
, product_aggregation AS (
SELECT 
product_key,
product_name,
category,
subcategory,
cost,
COUNT(DISTINCT order_number) AS total_orders,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(sales_amount) AS total_sales,
SUM(quantity) AS total_quantity,
MAX(order_date) AS last_order_date,
DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan,
ROUND(AVG(CAST(sales_amount AS FLOAT)/NULLIF(quantity,0)),1) AS average_selling_price
FROM SSE
GROUP BY product_key, product_name, category, subcategory, cost )


SELECT 
product_key,
product_name,
category,
subcategory,
cost,
CASE WHEN total_sales < 450000 THEN 'LOW-PERFORMANCE'
	 WHEN total_sales BETWEEN 450000 AND 900000 THEN 'MID-RANGE'
	 WHEN total_sales > 900000 THEN 'HIGH-PERFORMANCE'
	 END AS segment_revenue,
last_order_date,
DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency,
total_orders,
total_sales,
total_quantity,
lifespan,
average_selling_price,
-- average order rvenue AOR
CASE WHEN total_orders = 0 THEN 0
	 ELSE total_sales/total_orders
	 END AS average_order_revenue,

-- average monthly spend
CASE WHEN lifespan = 0 THEN total_sales
	 ELSE total_sales/ lifespan
	 END AS average_monthly_spend
FROM product_aggregation
