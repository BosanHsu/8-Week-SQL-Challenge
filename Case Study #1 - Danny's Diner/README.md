# Case Study #1 — Danny's Diner

This repository documents my solutions to Case Study #1 of the
[8 Week SQL Challenge](https://8weeksqlchallenge.com/case-study-1/).

Danny's Diner is a small Japanese restaurant that sells sushi, curry, and ramen.
The goal of this case study is to use the restaurant's sales, menu, and membership
data to better understand customer behavior, spending patterns, and the performance
of its loyalty program.

## Table of Contents

- [Dataset](#dataset)
- [Dataset Setup](#dataset-setup)
- [Entity Relationship](#entity-relationship)
- [SQL Skills Practiced](#sql-skills-practiced)
- [Case Study Questions](#case-study-questions)
- [Bonus Questions](#bonus-questions)
- [Key Findings](#key-findings)
- [Notes and Reflections](#notes-and-reflections)
- [Repository Files](#repository-files)

## Dataset

The dataset is not created automatically. Before running the solutions, the sample
data must be added to a PostgreSQL database by running [`schema.sql`](./schema.sql).
The setup script creates the `dannys_diner` schema and the following three tables.

### `sales`

Records every item purchased by each customer.

| Column | Description |
| --- | --- |
| `customer_id` | Unique identifier for each customer |
| `order_date` | Date of the purchase |
| `product_id` | Identifier of the purchased menu item |

### `menu`

Contains the name and price of each menu item.

| Column | Description |
| --- | --- |
| `product_id` | Unique identifier for each product |
| `product_name` | Name of the menu item |
| `price` | Price of the menu item |

### `members`

Records the date on which each customer joined the loyalty program.

| Column | Description |
| --- | --- |
| `customer_id` | Unique identifier for each member |
| `join_date` | Date the customer joined the program |

## Dataset Setup

Run `schema.sql` before running any of the case study queries. The script first
removes an existing `dannys_diner` schema and then recreates the schema, tables,
and sample records used in this case study.

```sql
DROP SCHEMA IF EXISTS dannys_diner CASCADE;
CREATE SCHEMA dannys_diner;
```

From the `psql` command line, the dataset can be loaded with:

```text
\i schema.sql
```

After the dataset has been created, run the solutions with:

```text
\i query.sql
```

> **Note:** `DROP SCHEMA ... CASCADE` deletes the existing `dannys_diner` schema
> and all objects inside it. Do not run the setup script against a schema containing
> data that needs to be preserved.

## Entity Relationship

```text
sales.product_id  → menu.product_id
sales.customer_id → members.customer_id
```

## SQL Skills Practiced

- Aggregate functions: `SUM()` and `COUNT()`
- Counting unique values with `COUNT(DISTINCT ...)`
- `INNER JOIN` and `LEFT JOIN`
- Common table expressions (CTEs)
- Conditional logic with `CASE`
- Window functions: `RANK()` and `DENSE_RANK()`
- Date filtering and date-range calculations
- Handling tied rankings and customers without membership records

## Case Study Questions

### 1. What is the total amount each customer spent at the restaurant?

```sql
SELECT
    sales.customer_id,
    SUM(menu.price) AS total_spent
FROM dannys_diner.sales AS sales
JOIN dannys_diner.menu AS menu
    ON sales.product_id = menu.product_id
GROUP BY sales.customer_id
ORDER BY sales.customer_id;
```

| customer_id | total_spent |
| --- | ---: |
| A | 76 |
| B | 74 |
| C | 36 |

### 2. How many days has each customer visited the restaurant?

```sql
SELECT
    sales.customer_id,
    COUNT(DISTINCT sales.order_date) AS visits
FROM dannys_diner.sales AS sales
GROUP BY sales.customer_id;
```

| customer_id | visits |
| --- | ---: |
| A | 4 |
| B | 6 |
| C | 2 |

### 3. What was the first item from the menu purchased by each customer?

```sql
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
            PARTITION BY sales.customer_id
            ORDER BY sales.order_date
        ) AS order_rank
    FROM dannys_diner.sales AS sales
    JOIN dannys_diner.menu AS menu
        ON sales.product_id = menu.product_id
) AS purchase_rank
WHERE purchase_rank.order_rank = 1
ORDER BY customer_id;
```

| customer_id | product_name | order_date |
| --- | --- | --- |
| A | curry | 2021-01-01 |
| A | sushi | 2021-01-01 |
| B | curry | 2021-01-01 |
| C | ramen | 2021-01-01 |

### 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

```sql
WITH purchased_time_list AS (
    SELECT
        menu.product_name,
        COUNT(menu.product_name) AS purchased_times,
        RANK() OVER (
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
```

| product_name | purchased_times |
| --- | ---: |
| ramen | 8 |

### 5. Which item was the most popular for each customer?

```sql
WITH purchased_times_list AS (
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
purchased_rank_list AS (
    SELECT
        *,
        RANK() OVER (
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
```

| customer_id | product_name | purchased_times |
| --- | --- | ---: |
| A | ramen | 3 |
| B | sushi | 2 |
| B | curry | 2 |
| B | ramen | 2 |
| C | ramen | 3 |

### 6. Which item was purchased first by the customer after they became a member?

```sql
WITH member_purchase AS (
    SELECT
        sales.customer_id,
        menu.product_name,
        sales.order_date,
        members.join_date,
        RANK() OVER (
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
```

| customer_id | product_name | order_date | join_date |
| --- | --- | --- | --- |
| A | curry | 2021-01-07 | 2021-01-07 |
| B | sushi | 2021-01-11 | 2021-01-09 |

### 7. Which item was purchased just before the customer became a member?

```sql
WITH before_member_purchase AS (
    SELECT
        sales.customer_id,
        menu.product_name,
        sales.order_date,
        members.join_date,
        RANK() OVER (
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
```

| customer_id | product_name | order_date | join_date |
| --- | --- | --- | --- |
| A | sushi | 2021-01-01 | 2021-01-07 |
| A | curry | 2021-01-01 | 2021-01-07 |
| B | sushi | 2021-01-04 | 2021-01-09 |

### 8. What are the total items and amount spent for each member before they became a member?

```sql
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
```

| customer_id | total_items | total_spent |
| --- | ---: | ---: |
| A | 2 | 25 |
| B | 3 | 40 |

### 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier, how many points would each customer have?

```sql
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
```

| customer_id | total_points |
| --- | ---: |
| A | 860 |
| B | 940 |
| C | 360 |

### 10. In the first week after a customer joins the program (including their join date), they earn 2x points on all items, not just sushi. How many points do customers A and B have at the end of January?

```sql
WITH points_list AS (
    SELECT
        sales.customer_id,
        sales.order_date,
        CASE
            WHEN sales.order_date BETWEEN members.join_date
                                      AND members.join_date + 6
                THEN menu.price * 10 * 2
            WHEN menu.product_name = 'sushi'
                THEN menu.price * 10 * 2
            ELSE menu.price * 10
        END AS member_points
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
WHERE customer_id IN ('A', 'B')
    AND order_date BETWEEN '2021-01-01' AND '2021-01-31'
GROUP BY customer_id
ORDER BY customer_id;
```

| customer_id | total_points |
| --- | ---: |
| A | 1370 |
| B | 820 |

## Bonus Questions

### Bonus 1. Recreate the customer order table with membership status

The expected output contains `customer_id`, `order_date`, `product_name`, `price`,
and a `member` column showing whether the customer was a member on the order date.

```sql
SELECT
    sales.customer_id,
    sales.order_date,
    menu.product_name,
    menu.price,
    CASE
        WHEN sales.order_date >= members.join_date THEN 'Y'
        ELSE 'N'
    END AS member
FROM dannys_diner.sales AS sales
JOIN dannys_diner.menu AS menu
    ON sales.product_id = menu.product_id
LEFT JOIN dannys_diner.members AS members
    ON sales.customer_id = members.customer_id
ORDER BY sales.customer_id, sales.order_date, menu.product_name;
```

| customer_id | order_date | product_name | price | member |
| --- | --- | --- | ---: | --- |
| A | 2021-01-01 | curry | 15 | N |
| A | 2021-01-01 | sushi | 10 | N |
| A | 2021-01-07 | curry | 15 | Y |
| A | 2021-01-10 | ramen | 12 | Y |
| A | 2021-01-11 | ramen | 12 | Y |
| A | 2021-01-11 | ramen | 12 | Y |
| B | 2021-01-01 | curry | 15 | N |
| B | 2021-01-02 | curry | 15 | N |
| B | 2021-01-04 | sushi | 10 | N |
| B | 2021-01-11 | sushi | 10 | Y |
| B | 2021-01-16 | ramen | 12 | Y |
| B | 2021-02-01 | ramen | 12 | Y |
| C | 2021-01-01 | ramen | 12 | N |
| C | 2021-01-01 | ramen | 12 | N |
| C | 2021-01-07 | ramen | 12 | N |

### Bonus 2. Rank each member's purchases while leaving non-member purchases unranked

Danny wants member purchases ranked by order date. Purchases made before a customer
became a member should have a `NULL` ranking.

```sql
WITH member_boolean AS (
    SELECT
        sales.customer_id,
        sales.order_date,
        menu.product_name,
        menu.price,
        CASE
            WHEN sales.order_date >= members.join_date THEN 'Y'
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
        WHEN member = 'Y' THEN
            DENSE_RANK() OVER (
                PARTITION BY customer_id, member
                ORDER BY order_date
            )
    END AS order_rank
FROM member_boolean
ORDER BY customer_id, order_date, product_name;
```

| customer_id | order_date | product_name | price | member | order_rank |
| --- | --- | --- | ---: | --- | ---: |
| A | 2021-01-01 | curry | 15 | N | NULL |
| A | 2021-01-01 | sushi | 10 | N | NULL |
| A | 2021-01-07 | curry | 15 | Y | 1 |
| A | 2021-01-10 | ramen | 12 | Y | 2 |
| A | 2021-01-11 | ramen | 12 | Y | 3 |
| A | 2021-01-11 | ramen | 12 | Y | 3 |
| B | 2021-01-01 | curry | 15 | N | NULL |
| B | 2021-01-02 | curry | 15 | N | NULL |
| B | 2021-01-04 | sushi | 10 | N | NULL |
| B | 2021-01-11 | sushi | 10 | Y | 1 |
| B | 2021-01-16 | ramen | 12 | Y | 2 |
| B | 2021-02-01 | ramen | 12 | Y | 3 |
| C | 2021-01-01 | ramen | 12 | N | NULL |
| C | 2021-01-01 | ramen | 12 | N | NULL |
| C | 2021-01-07 | ramen | 12 | N | NULL |

## Key Findings

- Customer A spent **$76**, customer B spent **$74**, and customer C spent **$36**.
- Customer B visited the restaurant on the most unique days: **6 days**.
- Ramen was the most frequently purchased item, with **8 purchases** in total.
- Ramen was the most popular item for customers A and C.
- Customer B purchased all three menu items equally often.
- Before becoming members, customer A spent **$25** and customer B spent **$40**.
- Under the January loyalty rules, customer A earned **1,370 points** and customer B earned **820 points**.

## Repository Files

- [`schema.sql`](./schema.sql) creates the schema, tables, and sample data.
- [`query.sql`](./query.sql) contains all case study and bonus queries.
- [`README.md`](./README.md) documents the questions, solutions, results, and reflections.

## Environment

- Database: PostgreSQL
- SQL dialect: PostgreSQL

## Credits

The dataset and questions were created by
[Danny Ma](https://www.datawithdanny.com/) for the
[8 Week SQL Challenge](https://8weeksqlchallenge.com/).
