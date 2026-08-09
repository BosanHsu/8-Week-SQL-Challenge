# Case Study #2 — Pizza Runner

This repository documents my solutions to Case Study #2 of the
[8 Week SQL Challenge](https://8weeksqlchallenge.com/case-study-2/).

Pizza Runner combines pizza delivery with an Uber-style runner model. This case
study uses customer, delivery, recipe, and topping data to examine order volume,
delivery performance, and pizza customizations.

## Table of Contents

- [Dataset](#dataset)
- [Dataset Setup](#dataset-setup)
- [Entity Relationship](#entity-relationship)
- [SQL Skills Practiced](#sql-skills-practiced)
- [A. Pizza Metrics](#a-pizza-metrics)
- [B. Runner and Customer Experience](#b-runner-and-customer-experience)
- [Key Findings](#key-findings)
- [Notes and Reflections](#notes-and-reflections)
- [Repository Files](#repository-files)

## Dataset

Run [`schema.sql`](./schema.sql) to create the `pizza_runner` schema and its six
tables.

| Table | Description |
| --- | --- |
| `runners` | Runner IDs and registration dates |
| `customer_orders` | One row per pizza, including exclusions and extras |
| `runner_orders` | Runner assignment, pickup, distance, duration, and cancellation |
| `pizza_names` | Pizza ID and name lookup |
| `pizza_recipes` | Standard topping IDs for each pizza |
| `pizza_toppings` | Topping ID and name lookup |

## Dataset Setup

From `psql`, load the dataset and then run the solutions:

```text
\i schema.sql
\i query.sql
```

The current script uses `CREATE SCHEMA pizza_runner` without first dropping the
schema, so rerunning it when the schema exists will produce an error.

## Entity Relationship

```text
runners.runner_id        → runner_orders.runner_id
runner_orders.order_id   → customer_orders.order_id
pizza_names.pizza_id     → customer_orders.pizza_id
pizza_recipes.pizza_id   → customer_orders.pizza_id
```

The recipe, exclusion, and extra columns contain comma-separated IDs that map to
`pizza_toppings.topping_id`. These are logical relationships; the schema does not
declare foreign-key constraints.

## SQL Skills Practiced

- Aggregate functions and conditional aggregation
- `COUNT(DISTINCT ...)`, joins, and CTEs
- Window functions with `RANK()`
- Data exploration with `SELECT DISTINCT`
- Handling SQL `NULL`, the string `'null'`, and empty strings
- Extracting hour and day values from timestamps
- Cleaning text fields with `REGEXP_REPLACE()` and `NULLIF()`
- Interval calculations with `EXTRACT(EPOCH ...)`
- Unit conversion for delivery speed

## A. Pizza Metrics

### 1. How many pizzas were ordered?

```sql
SELECT COUNT(*) AS pizza_ordered
FROM pizza_runner.customer_orders;
```

| pizza_ordered |
| ---: |
| 14 |

Each row of `customer_orders` represents one pizza.

### 2. How many unique customer orders were made?

```sql
SELECT COUNT(DISTINCT order_id) AS unique_orders
FROM pizza_runner.customer_orders;
```

| unique_orders |
| ---: |
| 10 |

### 3. How many successful orders were delivered by each runner?

```sql
SELECT runner_id, COUNT(*) AS order_delivered
FROM pizza_runner.runner_orders
WHERE pickup_time != 'null'
GROUP BY runner_id
ORDER BY runner_id;
```

| runner_id | order_delivered |
| ---: | ---: |
| 1 | 4 |
| 2 | 3 |
| 3 | 1 |

### 4. How many of each type of pizza was delivered?

```sql
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
```

| pizza_id | pizza_name | number_of_pizza |
| ---: | --- | ---: |
| 1 | Meatlovers | 9 |
| 2 | Vegetarian | 3 |

### 5. How many Vegetarian and Meatlovers pizzas were ordered by each customer?

```sql
SELECT
    cus_ord.customer_id,
    SUM(CASE WHEN cus_ord.pizza_id = 1 THEN 1 ELSE 0 END) AS Meatlovers,
    SUM(CASE WHEN cus_ord.pizza_id = 2 THEN 1 ELSE 0 END) AS Vegetarian
FROM pizza_runner.customer_orders AS cus_ord
JOIN pizza_runner.pizza_names
    ON cus_ord.pizza_id = pizza_names.pizza_id
GROUP BY cus_ord.customer_id
ORDER BY cus_ord.customer_id;
```

| customer_id | meatlovers | vegetarian |
| ---: | ---: | ---: |
| 101 | 2 | 1 |
| 102 | 2 | 1 |
| 103 | 3 | 1 |
| 104 | 3 | 0 |
| 105 | 0 | 1 |

### 6. What was the maximum number of pizzas delivered in a single order?

```sql
WITH pizza_ordered_counts AS (
    SELECT cus_ord.order_id, COUNT(*) AS pizza_ordered
    FROM pizza_runner.customer_orders AS cus_ord
    JOIN pizza_runner.runner_orders AS run_ord
        ON cus_ord.order_id = run_ord.order_id
    WHERE run_ord.pickup_time != 'null'
    GROUP BY cus_ord.order_id
),
pizza_ordered_rank AS (
    SELECT
        order_id,
        pizza_ordered,
        RANK() OVER (ORDER BY pizza_ordered DESC) AS order_rank
    FROM pizza_ordered_counts
)
SELECT order_id, pizza_ordered, order_rank
FROM pizza_ordered_rank
WHERE order_rank = 1;
```

| order_id | pizza_ordered | order_rank |
| ---: | ---: | ---: |
| 4 | 3 | 1 |

### 7. For each customer, how many delivered pizzas had at least one change and how many had no changes?

Before writing the `CASE` conditions, first inspect the values actually stored in
both customization columns:

```sql
SELECT DISTINCT extras
FROM pizza_runner.customer_orders;

SELECT DISTINCT exclusions
FROM pizza_runner.customer_orders;
```

The inspection reveals three different representations of no customization:
SQL `NULL`, the text value `'null'`, and an empty string `''`.

| distinct `extras` values | distinct `exclusions` values |
| --- | --- |
| SQL `NULL` | SQL `NULL` |
| `'null'` | `'null'` |
| `''` | `''` |
| `'1'` | `'4'` |
| `'1, 4'` | `'2, 6'` |
| `'1, 5'` | |

> **Important reflection:** I initially forgot this inspection step, which makes
> it easy to miss one of the null-like values. SQL `NULL`, `'null'`, and `''` may
> look similar in displayed results, but they behave differently in comparisons.
> Always use `SELECT DISTINCT` to inspect the raw values before defining cleaning
> rules or `CASE` conditions.

```sql
SELECT
    cus_ord.customer_id,
    SUM(
        CASE
            WHEN (exclusions != 'null' AND exclusions != '')
              OR (extras != 'null' AND extras != '')
                THEN 1
            ELSE 0
        END
    ) AS changes,
    SUM(
        CASE
            WHEN (exclusions IS NULL OR exclusions = 'null' OR exclusions = '')
             AND (extras IS NULL OR extras = 'null' OR extras = '')
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
```

| customer_id | changes | no_changes |
| ---: | ---: | ---: |
| 101 | 0 | 2 |
| 102 | 0 | 3 |
| 103 | 3 | 0 |
| 104 | 2 | 1 |
| 105 | 1 | 0 |

### 8. How many delivered pizzas had both exclusions and extras?

```sql
SELECT
    SUM(
        CASE
            WHEN (exclusions != 'null' AND exclusions != '')
             AND (extras != 'null' AND extras != '')
                THEN 1
            ELSE 0
        END
    ) AS both_change_pizza
FROM pizza_runner.customer_orders AS cus_ord
JOIN pizza_runner.runner_orders AS run_ord
    ON cus_ord.order_id = run_ord.order_id
WHERE run_ord.pickup_time != 'null';
```

| both_change_pizza |
| ---: |
| 1 |

### 9. What was the total volume of pizzas ordered for each hour of the day?

```sql
SELECT
    EXTRACT(HOUR FROM order_date) AS "hour",
    COUNT(*) AS volume
FROM pizza_runner.customer_orders AS cus_ord
GROUP BY EXTRACT(HOUR FROM order_date)
ORDER BY EXTRACT(HOUR FROM order_date);
```

| hour | volume |
| ---: | ---: |
| 11 | 1 |
| 12 | 2 |
| 13 | 3 |
| 18 | 3 |
| 19 | 1 |
| 21 | 3 |
| 23 | 1 |

### 10. What was the volume of orders for each day of the week?

```sql
SELECT
    EXTRACT(DOW FROM order_date) AS "day",
    COUNT(*) AS volume
FROM pizza_runner.customer_orders AS cus_ord
GROUP BY EXTRACT(DOW FROM order_date)
ORDER BY EXTRACT(DOW FROM order_date);
```

| day | volume |
| ---: | ---: |
| 3 | 5 |
| 4 | 3 |
| 5 | 1 |
| 6 | 5 |

PostgreSQL uses `0` for Sunday through `6` for Saturday, so these values represent
Wednesday through Saturday.

## B. Runner and Customer Experience

### 1. How many runners signed up for each one-week period?

The weekly periods begin on 2021-01-01.

```sql
WITH week_list AS (
    SELECT
        registration_date,
        ((registration_date - '2021-01-01'::DATE) / 7) + 1 AS week
    FROM pizza_runner.runners
)
SELECT
    week,
    CASE
        WHEN week IS NOT NULL
            THEN '2021-01-01'::DATE + (week - 1) * 7
    END AS week_start_date,
    COUNT(*) AS registered_runner
FROM week_list
GROUP BY week
ORDER BY week;
```

| week | week_start_date | registered_runner |
| ---: | --- | ---: |
| 1 | 2021-01-01 | 2 |
| 2 | 2021-01-08 | 1 |
| 3 | 2021-01-15 | 1 |

PostgreSQL subtracts one `DATE` from another to return the number of elapsed days.
Dividing that integer by 7 uses integer division, and adding 1 makes the first
seven-day period week 1.

### 2. What was the average time in minutes it took each runner to arrive at Pizza Runner HQ to pick up an order?

```sql
WITH distinct_order AS (
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
```

| runner_id | average_pickup_minutes |
| ---: | ---: |
| 1 | 14.3291666666666667 |
| 2 | 20.0111111166666667 |
| 3 | 10.4666666666666667 |

`EPOCH` converts the averaged interval to total seconds; dividing by 60 returns
total minutes. This is safer than extracting only the minute component, which
would omit the hour component of intervals longer than one hour.

### 3. Is there a relationship between the number of pizzas and how long the order takes to prepare?

```sql
WITH pizza_numbers AS (
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
```

| num_of_pizza | average_pickup_minutes |
| ---: | ---: |
| 1 | 12.3566666666666667 |
| 2 | 18.3750000000000000 |
| 3 | 29.2833333333333333 |

The observed pickup wait increases with the number of pizzas. However, the data
does not include the actual time at which food preparation finished. The interval
from ordering to pickup may also include the runner's travel time to the store,
so it is only a proxy for preparation time rather than a pure preparation metric.

### 4. What was the average distance travelled for each customer?

The raw `distance` and `duration` columns contain inconsistent units and text.
`REGEXP_REPLACE(..., '[^0-9.]', '', 'g')` removes everything except digits and
decimal points, while `NULLIF(..., '')` converts an empty result to SQL `NULL`
before the value is cast to `NUMERIC`.

```sql
WITH updated_runner_order AS (
    SELECT
        order_id,
        runner_id,
        NULLIF(
            REGEXP_REPLACE(distance, '[^0-9.]', '', 'g'), ''
        )::NUMERIC AS updated_distance,
        NULLIF(
            REGEXP_REPLACE(duration, '[^0-9.]', '', 'g'), ''
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
```

| customer_id | avg_distance |
| ---: | ---: |
| 101 | 20.00 |
| 102 | 16.73 |
| 103 | 23.40 |
| 104 | 10.00 |
| 105 | 25.00 |

Distances are measured in kilometres.

### 5. What was the difference between the longest and shortest delivery times for all orders?

```sql
WITH updated_runner_order AS (
    SELECT
        order_id,
        runner_id,
        NULLIF(
            REGEXP_REPLACE(distance, '[^0-9.]', '', 'g'), ''
        )::NUMERIC AS updated_distance,
        NULLIF(
            REGEXP_REPLACE(duration, '[^0-9.]', '', 'g'), ''
        )::NUMERIC AS updated_duration
    FROM pizza_runner.runner_orders
    WHERE pickup_time != 'null'
)
SELECT
    MAX(updated_duration) - MIN(updated_duration) AS max_diff_duration
FROM updated_runner_order AS run_ord;
```

| max_diff_duration |
| ---: |
| 30 |

The difference between the longest and shortest successful delivery durations
was 30 minutes.

### 6. What was the average speed for each runner for each delivery, and is there a trend?

```sql
WITH updated_runner_order AS (
    SELECT
        order_id,
        runner_id,
        NULLIF(
            REGEXP_REPLACE(distance, '[^0-9.]', '', 'g'), ''
        )::NUMERIC AS updated_distance,
        NULLIF(
            REGEXP_REPLACE(duration, '[^0-9.]', '', 'g'), ''
        )::NUMERIC AS updated_duration
    FROM pizza_runner.runner_orders
    WHERE pickup_time != 'null'
)
SELECT
    run_ord.order_id,
    run_ord.runner_id,
    ROUND(
        AVG(run_ord.updated_distance / (run_ord.updated_duration / 60)), 2
    ) AS avg_speed,
    MAX(run_ord.updated_distance) AS distance,
    COUNT(*) AS pizza_num
FROM updated_runner_order AS run_ord
JOIN pizza_runner.customer_orders AS cus_ord
    ON cus_ord.order_id = run_ord.order_id
GROUP BY run_ord.order_id, run_ord.runner_id
ORDER BY avg_speed;
```

| order_id | runner_id | avg_speed | distance | pizza_num |
| ---: | ---: | ---: | ---: | ---: |
| 4 | 2 | 35.10 | 23.4 | 3 |
| 1 | 1 | 37.50 | 20 | 1 |
| 5 | 3 | 40.00 | 10 | 1 |
| 3 | 1 | 40.20 | 13.4 | 2 |
| 2 | 1 | 44.44 | 20 | 1 |
| 10 | 1 | 60.00 | 10 | 2 |
| 7 | 2 | 60.00 | 25 | 1 |
| 8 | 2 | 93.60 | 23.4 | 1 |

Speed is measured in kilometres per hour. The eight successful deliveries do not
show a clear or consistent relationship between speed, distance, and pizza count.
For example, two deliveries covering 23.4 km had very different speeds of 35.10
and 93.60 km/h. Orders containing one or two pizzas also appear across both lower
and higher speeds. With such a small dataset, no reliable trend can be concluded.

### 7. What is the successful delivery percentage for each runner?

```sql
WITH success_test AS (
    SELECT
        runner_id,
        CASE WHEN pickup_time != 'null' THEN 1 END AS succeeded
    FROM pizza_runner.runner_orders AS run_ord
)
SELECT
    runner_id,
    (SUM(succeeded)::FLOAT / COUNT(*)::FLOAT) * 100 AS succeed_rate
FROM success_test
GROUP BY runner_id
ORDER BY runner_id;
```

| runner_id | succeed_rate |
| ---: | ---: |
| 1 | 100 |
| 2 | 75 |
| 3 | 50 |

This solution treats an order as successfully delivered when `pickup_time` is
not the text value `'null'`.

## Key Findings

- Customers placed 10 unique orders containing 14 pizzas.
- Eight orders were successfully delivered: runner 1 delivered 4, runner 2
  delivered 3, and runner 3 delivered 1.
- The delivered pizzas included 9 Meatlovers and 3 Vegetarian pizzas.
- Order 4 was the largest delivered order, containing 3 pizzas.
- Customer 103 changed every delivered pizza; customers 101 and 102 made no changes.
- Only one delivered pizza had both exclusions and extras.
- The busiest observed hours were 13:00, 18:00, and 21:00, with 3 pizzas each.
- Runner registrations were highest in the first week, when 2 runners signed up.
- Runner 3 had the shortest average pickup wait at about 10.47 minutes; runner 2
  had the longest at about 20.01 minutes.
- Average pickup wait rose from about 12.36 minutes for one pizza to 29.28 minutes
  for three pizzas, although this interval is not a pure preparation-time measure.
- Customer 105 had the longest average delivery distance at 25 km, while customer
  104 had the shortest at 10 km.
- Delivery speeds ranged from 35.10 to 93.60 km/h, with no clear trend by distance
  or number of pizzas in the eight successful deliveries.
- Runner 1 completed 100% of assigned deliveries, compared with 75% for runner 2
  and 50% for runner 3.

## Notes and Reflections

### A. Pizza Metrics

- Question A7 demonstrates why raw categorical values should be inspected with
  `SELECT DISTINCT` before writing conditional logic.
- `pickup_time` is currently text, so successful deliveries are identified with
  `pickup_time != 'null'`. Cleaning textual nulls and casting this column to a
  timestamp would make later analysis safer.
- Question A10 currently uses `COUNT(*)`, which counts pizza rows. To interpret
  “orders” as unique orders, use `COUNT(DISTINCT order_id)` instead.
- The `pizza_names` join in question A5 is not required for the current output.

### B. Runner and Customer Experience

- Question B6 is analysed at the individual-order level. The
  dataset is too small to support a reliable trend between speed, distance, and
  pizza count.

## Repository Files

- [`schema.sql`](./schema.sql) creates the schema, tables, and sample data.
- [`query.sql`](./query.sql) contains the Pizza Metrics and Runner Experience queries.
- [`README.md`](./README.md) documents the questions, solutions, results, and reflections.

## Environment

- Database: PostgreSQL 18
- SQL dialect: PostgreSQL
- Results checked with [DB Fiddle](https://www.db-fiddle.com/f/wdLiobXtqtw8BXPs3NQ11Y/4)

## Credits

The dataset and questions were created by
[Danny Ma](https://www.datawithdanny.com/) for the
[8 Week SQL Challenge](https://8weeksqlchallenge.com/).
