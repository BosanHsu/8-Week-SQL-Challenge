SELECT *
FROM pizza_runner.runners;

SELECT *
FROM pizza_runner.customer_orders;

SELECT *
FROM pizza_runner.runner_orders;

SELECT *
FROM pizza_runner.pizza_names;

SELECT *
FROM pizza_runner.pizza_recipes;

SELECT *
FROM pizza_runner.pizza_toppings;

-- A. Pizza Metrics
---- 1. How many pizzas were ordered?

SELECT COUNT(*) AS pizza_ordered
FROM pizza_runner.customer_orders;

---- 2. How many unique customer orders were made?

SELECT COUNT(DISTINCT order_id) AS unique_orders
FROM pizza_runner.customer_orders;

---- 3. How many successful orders were delivered by each runner?

SELECT runner_id, COUNT(*) AS order_delivered
FROM pizza_runner.runner_orders
WHERE pickup_time != 'null'
GROUP BY runner_id
ORDER BY runner_id;

---- 4. How many of each type of pizza was delivered?

SELECT
	cus_ord.pizza_id,
    pizza_names.pizza_name,
    COUNT(*) AS number_of_pizza
FROM pizza_runner.customer_orders AS cus_ord
JOIN pizza_runner.runner_orders AS run_ord
ON cus_ord.order_id = run_ord.order_id
JOIN pizza_runner.pizza_names
ON cus_ord.pizza_id = pizza_names.pizza_id
WHERE run_ord.pickup_time != 'null'
GROUP BY cus_ord.pizza_id, pizza_names.pizza_name
ORDER BY cus_ord.pizza_id;

---- 5. How many Vegetarian and Meatlovers were ordered by each customer?

SELECT
	cus_ord.customer_id,
    SUM(CASE WHEN cus_ord.pizza_id = 1 THEN 1 ELSE 0 END) AS Meatlovers,
    SUM(CASE WHEN cus_ord.pizza_id = 2 THEN 1 ELSE 0 END) AS Vegetarian
FROM pizza_runner.customer_orders AS cus_ord
JOIN pizza_runner.pizza_names
ON cus_ord.pizza_id = pizza_names.pizza_id
GROUP BY cus_ord.customer_id
ORDER BY cus_ord.customer_id;

---- 6. What was the maximum number of pizzas delivered in a single order?

WITH pizza_ordered_counts AS
(
	SELECT
	cus_ord.order_id,
	COUNT(*) AS pizza_ordered
FROM pizza_runner.customer_orders AS cus_ord
JOIN pizza_runner.runner_orders AS run_ord
ON cus_ord.order_id = run_ord.order_id
WHERE run_ord.pickup_time != 'null'
GROUP BY cus_ord.order_id
),

pizza_ordered_rank AS
(
	SELECT
        order_id,
  		pizza_ordered,
        RANK() OVER(
        	ORDER BY pizza_ordered DESC
        	) AS order_rank
    FROM pizza_ordered_counts
)

SELECT
	order_id,
    pizza_ordered,
    order_rank
FROM pizza_ordered_rank
WHERE order_rank = 1;

---- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

SELECT DISTINCT extras
FROM pizza_runner.customer_orders;
SELECT DISTINCT exclusions
FROM pizza_runner.customer_orders;--我忘記這一步 要記得 review codes提醒我之前忘記這步

SELECT
	cus_ord.customer_id,
    SUM(
    	CASE
      		WHEN
      			(exclusions != 'null' AND
                exclusions != '') OR
      			(extras != 'null' AND
                extras != '')
      		THEN 1
      		ELSE 0
      	END
	) AS changes,
    SUM(
    	CASE
      		WHEN
      			(exclusions IS NULL OR
      			exclusions = 'null' OR
                exclusions = '') AND
      			(extras IS NULL OR
      			extras = 'null' OR
                extras = '')
      		THEN 1
      		ELSE 0
      	END
	) AS no_changes
FROM pizza_runner.customer_orders AS cus_ord
JOIN pizza_runner.runner_orders AS run_ord
ON cus_ord.order_id = run_ord.order_id
WHERE run_ord.pickup_time != 'null'
GROUP BY cus_ord.customer_id
ORDER BY cus_ord.customer_id;

---- 8. How many pizzas were delivered that had both exclusions and extras?
SELECT
    SUM(
    	CASE
      		WHEN
      			(exclusions != 'null' AND
                exclusions != '') AND
      			(extras != 'null' AND
                extras != '')
      		THEN 1
      		ELSE 0
      	END
	) AS both_change_pizza
FROM pizza_runner.customer_orders AS cus_ord
JOIN pizza_runner.runner_orders AS run_ord
ON cus_ord.order_id = run_ord.order_id
WHERE run_ord.pickup_time != 'null';

---- 9. What was the total volume of pizzas ordered for each hour of the day?

SELECT
	EXTRACT(HOUR FROM order_date) AS "hour",
    COUNT(*) AS volume
FROM pizza_runner.customer_orders AS cus_ord
GROUP BY EXTRACT(HOUR FROM order_date)
ORDER BY EXTRACT(HOUR FROM order_date);

---- 10. What was the volume of orders for each day of the week?

SELECT
	EXTRACT(DOW FROM order_date) AS "day",
    COUNT(*) AS volume
FROM pizza_runner.customer_orders AS cus_ord
GROUP BY EXTRACT(DOW FROM order_date)
ORDER BY EXTRACT(DOW FROM order_date);
