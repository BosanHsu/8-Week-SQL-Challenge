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
FROM pizza_runner.customer_orders;-- 先檢查 SQL NULL、字串 'null' 與空字串，避免 CASE 條件疏漏

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

-- B. Runner and Customer Experience
---- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

WITH week_list AS
(
  	SELECT
  		registration_date,
    	((registration_date - '2021-01-01'::DATE) / 7) + 1 AS week
  	FROM pizza_runner.runners
)

SELECT
	week,
    CASE
    	WHEN week IS NOT NULL
        THEN '2021-01-01'::DATE + (week - 1)* 7
        END
        AS week_start_date,
    COUNT(*) AS registered_runner
FROM week_list
GROUP BY week
ORDER BY week;

-- PostgreSQL 的 DATE 相減會得到相差天數。
-- SQL Server 可使用 DATEDIFF(day, start_date, end_date)。
-- Spark SQL / Databricks 可使用 DATEDIFF(end_date, start_date)。
-- 此處將相差天數除以 7；因為兩邊都是整數，所以 PostgreSQL 會使用整數除法，再加 1 得到週次。

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

WITH distinct_order AS
(
    SELECT DISTINCT
        cus_ord.order_id,
        cus_ord.order_date
    FROM pizza_runner.customer_orders AS cus_ord
)

SELECT
    run_ord.runner_id,
    EXTRACT(
        EPOCH FROM AVG(
            run_ord.pickup_time::TIMESTAMP - dis_ord.order_date::TIMESTAMP
        )
    ) / 60 AS average_pickup_minutes
FROM distinct_order AS dis_ord
JOIN pizza_runner.runner_orders AS run_ord
    ON dis_ord.order_id = run_ord.order_id
WHERE run_ord.pickup_time != 'null'
GROUP BY run_ord.runner_id
ORDER BY run_ord.runner_id;

-- EPOCH 會把 interval 轉成總秒數，除以 60 後得到總分鐘數。
-- 若使用 EXTRACT(MINUTE FROM interval)，只會取得 interval 的分鐘欄位；超過 1 小時時會漏掉小時部分。

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?

WITH pizza_numbers AS
(
    SELECT
  		order_id,
        COUNT(*) AS num_of_pizza,
  		MAX(cus_ord.order_date) AS order_date
    FROM pizza_runner.customer_orders AS cus_ord
  	GROUP BY order_id
)

SELECT
    num_of_pizza,
    EXTRACT(
        EPOCH FROM AVG(
            run_ord.pickup_time::TIMESTAMP - pizza_num.order_date::TIMESTAMP
        )
    ) / 60 AS average_pickup_minutes
FROM pizza_numbers AS pizza_num
JOIN pizza_runner.runner_orders AS run_ord
    ON pizza_num.order_id = run_ord.order_id
WHERE run_ord.pickup_time != 'null'
GROUP BY num_of_pizza
ORDER BY num_of_pizza;

-- 資料沒有提供實際的餐點完成時間，因此以「下單到 runner 取餐」的時間差作為準備時間的近似值。
-- 這段時間也可能包含 runner 前往店家的時間，所以只能觀察 pizza 數量與取餐等待時間的關聯，不能視為純準備時間。

-- 4. What was the average distance travelled for each customer?

-- PostgreSQL 可使用 REGEXP_REPLACE(column, '[^0-9.]', '', 'g') 移除數字及小數點以外的字元。
-- 'g' 是 REGEXP_REPLACE() 的 global flag，表示取代所有符合項目；若省略，則只取代第一個符合項目。
-- PostgreSQL 可搭配 NULLIF(..., '')::NUMERIC，將空字串轉成 NULL，再轉成數值型別。

-- SQL Server 可以使用 REPLACE() 移除固定文字，例如 km、minutes、mins。
-- SQL Server 可搭配 TRY_CONVERT(DECIMAL(10,2), value)，轉換失敗時會回傳 NULL，不會直接報錯。

-- Spark SQL / Databricks 可以使用 regexp_replace(column, r'[^0-9.]', '') 移除非數字與小數點的字元。
-- Spark SQL / Databricks 可搭配 CAST(NULLIF(..., '') AS DECIMAL(10,2)) 將清理後的字串轉成數值。

-- PostgreSQL：
-- NULLIF(REGEXP_REPLACE(distance, '[^0-9.]', '', 'g'), '')::NUMERIC

-- SQL Server：
-- TRY_CONVERT(DECIMAL(10,2), REPLACE(REPLACE(distance, 'km', ''), ' ', ''))

-- Spark SQL / Databricks：
-- CAST(NULLIF(regexp_replace(distance, r'[^0-9.]', ''), '') AS DECIMAL(10,2))

-- [^0-9.] 代表「不是數字 0-9，也不是小數點 .」的所有字元。
-- REGEXP_REPLACE 將這些非數值字元取代成空字串，因此 '23.4 km' → '23.4'。
-- NULLIF(value, '') 可將清理後的空字串轉成 NULL，例如 'null' → '' → NULL。
 
WITH updated_runner_order AS
(
    SELECT
  		order_id,
  		runner_id,
        NULLIF(
        	REGEXP_REPLACE(
            	distance, '[^0-9.]', '', 'g'
            ), ''
        )::NUMERIC AS updated_distance,
        NULLIF(
        	REGEXP_REPLACE(
            	duration, '[^0-9.]', '', 'g'
            ), ''
        )::NUMERIC AS updated_duration
    FROM pizza_runner.runner_orders
  	WHERE pickup_time != 'null'
)

SELECT
	customer_id,
    ROUND(AVG(run_ord.updated_distance), 2) AS avg_distance
FROM pizza_runner.customer_orders AS cus_ord
JOIN updated_runner_order AS run_ord
ON cus_ord.order_id = run_ord.order_id
GROUP BY customer_id
ORDER BY customer_id;

-- 5. What was the difference between the longest and shortest delivery times for all orders?

WITH updated_runner_order AS
(
    SELECT
  		order_id,
  		runner_id,
        NULLIF(
        	REGEXP_REPLACE(
            	distance, '[^0-9.]', '', 'g'
            ), ''
        )::NUMERIC AS updated_distance,
        NULLIF(
        	REGEXP_REPLACE(
            	duration, '[^0-9.]', '', 'g'
            ), ''
        )::NUMERIC AS updated_duration
    FROM pizza_runner.runner_orders
  	WHERE pickup_time != 'null'
)

SELECT
	MAX(updated_duration) - MIN(updated_duration) AS max_diff_duration
FROM updated_runner_order AS run_ord;

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?

WITH updated_runner_order AS
(
    SELECT
  		order_id,
  		runner_id,
        NULLIF(
        	REGEXP_REPLACE(
            	distance, '[^0-9.]', '', 'g'
            ), ''
        )::NUMERIC AS updated_distance,
        NULLIF(
        	REGEXP_REPLACE(
            	duration, '[^0-9.]', '', 'g'
            ), ''
        )::NUMERIC AS updated_duration
    FROM pizza_runner.runner_orders
  	WHERE pickup_time != 'null'
)

SELECT
	runner_id,
    ROUND(AVG(updated_distance/(updated_duration/60)), 2) AS avg_speed
FROM updated_runner_order AS run_ord
GROUP BY runner_id
ORDER BY runner_id;

-- 單位為 km/h。
-- 注意：題目要求查看每位 runner 的每次配送，但目前查詢會彙總成每位 runner 的平均速度。
-- 若要分析趨勢，可保留 order_id 層級，再比較距離、pizza 數量與配送速度。

-- 7. What is the successful delivery percentage for each runner?
-- 此處以 pickup_time 不是字串 'null' 作為成功配送的判斷條件。

WITH success_test AS
(
    SELECT
        runner_id,
  		CASE WHEN pickup_time != 'null' THEN 1 END AS succeeded
    FROM pizza_runner.runner_orders AS run_ord
)

SELECT
	runner_id,
    (SUM(succeeded)::FLOAT/COUNT(*)::FLOAT)*100 AS succeed_rate
FROM success_test
GROUP BY runner_id
ORDER BY runner_id;
