use gdb023
/*Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region*/

select distinct Market as List_of_Markets 
from dim_customer
where customer='Atliq Exclusive' and region='APAC'
/*What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields, unique_products_2020 unique_products_2021 percentage_chg*/
WITH unique_products AS (
  SELECT
    COUNT(DISTINCT CASE WHEN YEAR(date) = 2020 THEN product_code END) AS unique_products_2020,
    COUNT(DISTINCT CASE WHEN YEAR(date) = 2021 THEN product_code END) AS unique_products_2021
 FROM fact_sales_monthly
)
SELECT
  unique_products_2020,
  unique_products_2021,
  ROUND(((unique_products_2021 - unique_products_2020) / unique_products_2020) * 100, 2) AS percentage_chg
FROM unique_products;

/*Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. The final output contains 2 fields, segment product_count*/

select Segment, count(distinct(product)) as Product_Count from dim_product
group by segment
order by Product_Count desc

/*Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields, segment product_count_2020 product_count_2021 difference*/

WITH product_counts AS (
    SELECT p.segment, 
           COUNT(DISTINCT CASE WHEN f.fiscal_year = 2020 THEN f.product_code END) AS product_count_2020,
           COUNT(DISTINCT CASE WHEN f.fiscal_year = 2021 THEN f.product_code END) AS product_count_2021
    FROM fact_sales_monthly f
    JOIN dim_product p ON f.product_code = p.product_code
    WHERE f.fiscal_year IN (2020, 2021)
    GROUP BY p.segment
)
SELECT segment, product_count_2020, product_count_2021, (product_count_2021 - product_count_2020) AS difference
FROM product_counts
ORDER BY difference DESC
LIMIT 1;

/*Get the products that have the highest and lowest manufacturing costs. The final output should contain these fields, product_code product manufacturing_cost*/
SELECT p.product_code, p.product, mc.manufacturing_cost
FROM dim_product p
JOIN fact_manufacturing_cost mc ON p.product_code = mc.product_code
WHERE mc.manufacturing_cost = (
    SELECT MAX(manufacturing_cost)
    FROM fact_manufacturing_cost
) OR mc.manufacturing_cost = (
    SELECT MIN(manufacturing_cost)
    FROM fact_manufacturing_cost
);

/*Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. The final output contains these fields, customer_code customer average_discount_percentage*/

SELECT c.customer_code, c.customer, ROUND(AVG(p.pre_invoice_discount_pct), 2) AS average_discount_percentage
FROM fact_pre_invoice_deductions p
JOIN dim_customer c ON p.customer_code = c.customer_code
WHERE p.fiscal_year = 2021 AND c.market = 'India'
GROUP BY c.customer_code, c.customer
ORDER BY average_discount_percentage DESC
LIMIT 5;
/*Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . This analysis helps to get an idea of low and high-performing months and take strategic decisions. The final report contains these columns: Month Year Gross sales Amount*/

SELECT MONTH(sm.date) AS Month, YEAR(sm.date) AS Year, ROUND(SUM(gp.gross_price * sm.sold_quantity), 2) AS Gross_sales_amount
FROM fact_sales_monthly sm
JOIN dim_customer c ON sm.customer_code = c.customer_code
JOIN fact_gross_price gp ON sm.product_code = gp.product_code
WHERE c.customer = 'Atliq Exclusive'
GROUP BY MONTH(sm.date), YEAR(sm.date)
ORDER BY YEAR(sm.date), MONTH(sm.date);

/*In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the total_sold_quantity, Quarter total_sold_quantity*/

WITH sales_quarters AS (
    SELECT 
        CASE 
            WHEN MONTH(date) BETWEEN 1 AND 3 THEN 'Q1'
            WHEN MONTH(date) BETWEEN 4 AND 6 THEN 'Q2'
            WHEN MONTH(date) BETWEEN 7 AND 9 THEN 'Q3'
            ELSE 'Q4'
        END AS Quarter,
        SUM(sold_quantity) AS total_sold_quantity
    FROM fact_sales_monthly
    WHERE YEAR(date) = 2020
    GROUP BY Quarter
)
SELECT Quarter, total_sold_quantity
FROM sales_quarters
ORDER BY total_sold_quantity DESC
LIMIT 1;

/* Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? The final output contains these fields, channel gross_sales_mln percentage*/
WITH channel_sales AS (
    SELECT c.channel, 
           SUM(gp.gross_price * sm.sold_quantity) AS gross_sales_mln,
           SUM(SUM(gp.gross_price * sm.sold_quantity)) OVER () AS total_sales_mln
    FROM fact_sales_monthly sm
    JOIN dim_customer c ON sm.customer_code = c.customer_code
    JOIN fact_gross_price gp ON sm.product_code = gp.product_code
    WHERE sm.fiscal_year = 2021
    GROUP BY c.channel
)
SELECT channel, 
       ROUND(gross_sales_mln / total_sales_mln * 100, 2) AS percentage
FROM channel_sales
ORDER BY gross_sales_mln DESC
LIMIT 1;

/*Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? The final output contains these fields, division product_code*/

WITH product_rank AS (
    SELECT 
        division,
        sm.product_code,
        product,
        SUM(sold_quantity) AS total_sold_quantity,
        RANK() OVER (PARTITION BY division ORDER BY SUM(sold_quantity) DESC) AS rank_order
    FROM fact_sales_monthly sm
    JOIN dim_product p ON sm.product_code = p.product_code
    WHERE sm.fiscal_year = 2021
    GROUP BY division, sm.product_code, product
)
SELECT division, product_code, product, total_sold_quantity, rank_order
FROM product_rank
WHERE rank_order <= 3
ORDER BY division, rank_order;

