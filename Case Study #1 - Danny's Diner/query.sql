SELECT *
FROM dannys_diner.sales;

SELECT *
FROM dannys_diner.menu;

SELECT *
FROM dannys_diner.members;

-- 1. What is the total amount each customer spent at the restaurant?
SELECT
	sales.customer_id,
	SUM(menu.price) AS total_spent
FROM dannys_diner.sales AS sales
JOIN dannys_diner.menu AS menu
ON sales.product_id = menu.product_id
GROUP BY sales.customer_id
ORDER BY sales.customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT
	sales.customer_id,
	COUNT(DISTINCT sales.order_date) AS visits
FROM dannys_diner.sales AS sales
GROUP BY sales.customer_id;

-- 3. What was the first item from the menu purchased by each customer?
SELECT DISTINCT
	purchase_rank.customer_id,
	purchase_rank.product_name,
    purchase_rank.order_date
FROM (
  SELECT
  	sales.customer_id,
	menu.product_name,
    sales.order_date,
    RANK() OVER (
      PARTITION BY
      	sales.customer_id
      ORDER BY
      	sales.order_date
    ) AS order_rank
  FROM dannys_diner.sales AS sales
  JOIN dannys_diner.menu AS menu
  ON sales.product_id = menu.product_id
 ) AS purchase_rank
WHERE purchase_rank.order_rank = 1
ORDER BY customer_id;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT
	menu.product_name,
    COUNT(menu.product_name) AS purchased_times
FROM dannys_diner.sales AS sales
JOIN dannys_diner.menu AS menu
ON sales.product_id = menu.product_id
GROUP BY menu.product_name
ORDER BY purchased_times DESC
LIMIT 1;

-- 5. Which item was the most popular for each customer?
WITH purchased_times_list AS
(
	SELECT
  		sales.customer_id,
  		menu.product_name,
  		COUNT(menu.product_name) AS purchased_times
  	FROM dannys_diner.sales AS sales
	JOIN dannys_diner.menu AS menu
	ON sales.product_id = menu.product_id
	GROUP BY
		sales.customer_id,
    	menu.product_name
),

purchased_rank_list AS
(
	SELECT
  		*,
  		RANK() OVER(
          	PARTITION BY customer_id
          	ORDER BY purchased_times DESC
          	) AS purchased_rank
  	FROM purchased_times_list
)

SELECT
	customer_id,
    product_name,
  	purchased_times
FROM purchased_rank_list
WHERE purchased_rank = 1;

