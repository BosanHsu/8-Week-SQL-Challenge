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

WITH purchased_time_list AS
(
	SELECT
        menu.product_name,
        COUNT(menu.product_name) AS purchased_times,
  		RANK() OVER(
          	ORDER BY COUNT(menu.product_name) DESC
        ) AS purchased_rank
    FROM dannys_diner.sales AS sales
    JOIN dannys_diner.menu AS menu
    ON sales.product_id = menu.product_id
    GROUP BY menu.product_name
)

SELECT
	product_name,
    purchased_times
FROM purchased_time_list
WHERE purchased_rank = 1;
 

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

-- 6. Which item was purchased first by the customer after they became a member?

WITH member_purchase AS
(
	SELECT
  		sales.customer_id,
  		menu.product_name,
  		sales.order_date,
  		members.join_date,
  		RANK() OVER(
          	PARTITION BY sales.customer_id
          	ORDER BY sales.order_date
        	) AS purchase_date_rank
  	FROM dannys_diner.sales AS sales
  	JOIN dannys_diner.menu AS menu
  	ON sales.product_id = menu.product_id
  	JOIN dannys_diner.members AS members
  	ON sales.customer_id = members.customer_id
	WHERE sales.order_date >= members.join_date
)
 
SELECT
	customer_id,
  	product_name,
  	order_date,
  	join_date
FROM member_purchase
WHERE purchase_date_rank = 1
ORDER BY customer_id;
 
-- 7. Which item was purchased just before the customer became a member?

WITH before_member_purchase AS
(
	SELECT
  		sales.customer_id,
  		menu.product_name,
  		sales.order_date,
  		members.join_date,
  		RANK() OVER(
          	PARTITION BY sales.customer_id
          	ORDER BY sales.order_date DESC
        	) AS purchase_date_rank
  	FROM dannys_diner.sales AS sales
  	JOIN dannys_diner.menu AS menu
  	ON sales.product_id = menu.product_id
  	JOIN dannys_diner.members AS members
  	ON sales.customer_id = members.customer_id
  	WHERE sales.order_date < members.join_date
 )
 
 SELECT
 	customer_id,
  	product_name,
  	order_date,
  	join_date
 FROM before_member_purchase
 WHERE purchase_date_rank = 1
 ORDER BY customer_id;
 
-- 8. What is the total items and amount spent for each member before they became a member?

SELECT
	sales.customer_id,
	COUNT(menu.product_name) AS total_items,
	SUM(menu.price) AS total_spent
FROM dannys_diner.sales AS sales
JOIN dannys_diner.menu AS menu
ON sales.product_id = menu.product_id
JOIN dannys_diner.members AS members
ON sales.customer_id = members.customer_id
WHERE sales.order_date < members.join_date
GROUP BY sales.customer_id
ORDER BY sales.customer_id;

-- 9.If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

SELECT
	sales.customer_id,
  	SUM(
    	CASE
      		WHEN menu.product_name = 'sushi'
  				THEN menu.price * 10 * 2
  			ELSE menu.price * 10
  		END
    ) AS total_points
FROM dannys_diner.sales AS sales
JOIN dannys_diner.menu AS menu
ON sales.product_id = menu.product_id
GROUP BY sales.customer_id
ORDER BY sales.customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

WITH points_list AS
(
	SELECT
  		sales.customer_id,
  		sales.order_date,
  		(CASE
  			WHEN
         		sales.order_date BETWEEN members.join_date AND members.join_date + 6
  				THEN menu.price * 10 * 2
         	WHEN
         		menu.product_name = 'sushi'
         		THEN menu.price * 10 * 2
  			ELSE menu.price * 10
  		END) AS member_points			
  	FROM dannys_diner.sales AS sales
  	JOIN dannys_diner.menu AS menu
  	ON sales.product_id = menu.product_id
  	LEFT JOIN dannys_diner.members AS members
  	ON sales.customer_id = members.customer_id
)
 
SELECT
	customer_id,
  	SUM(member_points) AS total_points
FROM points_list
WHERE customer_id IN('A', 'B')
AND order_date BETWEEN '2021-01-01' AND '2021-01-31'
GROUP BY customer_id
ORDER BY customer_id;

-- Bounus:
-- Recreate the following table output using the available data:
-- customer_id	order_date	product_name	price	member

SELECT
	sales.customer_id,
    sales.order_date,
    menu.product_name,
  	menu.price,
  	(CASE
    	WHEN sales.order_date >= members.join_date
     	THEN 'Y'
     	ELSE 'N'
     END) AS member    
FROM dannys_diner.sales AS sales
JOIN dannys_diner.menu AS menu
ON sales.product_id = menu.product_id
LEFT JOIN dannys_diner.members AS members
ON sales.customer_id = members.customer_id
ORDER BY sales.customer_id, sales.order_date, menu.product_name;
    
-- Bonus #2:
-- Danny also requires further information about the ranking of customer products
-- He purposely does not need the ranking for non-member purchases.
-- So he expects null ranking values for the records when customers are not members yet.

WITH member_boolean AS
(
  SELECT
      sales.customer_id,
      sales.order_date,
      menu.product_name,
      menu.price,
      CASE
          WHEN sales.order_date >= members.join_date
          THEN 'Y'
          ELSE 'N'
          END AS member
  FROM dannys_diner.sales AS sales
  JOIN dannys_diner.menu AS menu
  ON sales.product_id = menu.product_id
  LEFT JOIN dannys_diner.members AS members
  ON sales.customer_id = members.customer_id
)

SELECT
	*,
    CASE
    	WHEN member = 'Y'
        THEN DENSE_RANK() OVER(
    		PARTITION BY
          		customer_id,
          		member
          	ORDER BY order_date
        )
        END AS order_rank
FROM member_boolean
ORDER BY customer_id, order_date, product_name;
