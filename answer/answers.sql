-- 課題１：　店舗売上とオンライン売上の合算による売上合計額と販売数量合計の計算
SELECT
  SUM(quantity) AS total_quantity,
  SUM(amount) AS total_amount
FROM
(
  SELECT quantity, amount FROM store_sales
  UNION ALL
  SELECT quantity, amount FROM online_sales
) AS combined_sales;

------------------------------------------------------------

-- 課題２：　店舗またはオンラインで一度も購入したことがない顧客を見つける
SELECT c.customer_id, c.customer_name
FROM customers c
LEFT JOIN store_sales ss ON c.customer_id = ss.customer_id
LEFT JOIN online_sales os ON c.customer_id = os.customer_id
WHERE ss.customer_id IS NULL AND os.customer_id IS NULL;

------------------------------------------------------------

-- 課題３：　売上額を３つのカテゴリに分類し、店舗売上とオンライン売上を合算した各カテゴリの売上件数をカウント
SELECT
  sales_category,
  COUNT(*) AS sales_count
FROM (
  SELECT
    CASE
      WHEN amount >= 10000 THEN '高'
      WHEN amount >= 5000 THEN '中'
      ELSE '低'
    END AS sales_category
  FROM store_sales
  UNION ALL
  SELECT
    CASE
      WHEN amount >= 10000 THEN '高'
      WHEN amount >= 5000 THEN '中'
      ELSE '低'
    END AS sales_category
  FROM online_sales
) AS categorized_sales
GROUP BY sales_category
ORDER BY
  CASE sales_category
    WHEN '高' THEN 1
    WHEN '中' THEN 2
    WHEN '低' THEN 3
  END;

------------------------------------------------------------

-- 課題４：　各従業員の名前と直属の上司を一覧で表示
SELECT
  e.employee_name AS employee,
  COALESCE(m.employee_name, 'N/A') AS manager
FROM
  employees e
LEFT JOIN employees m ON e.manager_id = m.employee_id;

------------------------------------------------------------

-- 課題５：　2022-01-01以降に採用された従業員による売上をすべて見つける
SELECT *
FROM store_sales
WHERE employee_id IN (
    SELECT employee_id
    FROM employees
    WHERE hire_date >= '2022-01-01'
);

------------------------------------------------------------

-- 課題６：　店舗売上とオンライン売上を合算し、それを商品ごとに集計して、商品ごとの売上額でランキングをつける
WITH combined_sales AS (
  SELECT product_id, amount FROM store_sales
  UNION ALL
  SELECT product_id, amount FROM online_sales
),
sales_summary AS (
  SELECT
    p.category,
    p.product_id,
    SUM(cs.amount) AS total_amount
  FROM
    combined_sales cs
  JOIN
    products p ON cs.product_id = p.product_id
  GROUP BY
    p.category,
    p.product_id
)
SELECT
  category,
  product_id,
  total_amount,
  RANK() OVER (PARTITION BY category ORDER BY total_amount DESC) AS sales_rank
FROM
  sales_summary
ORDER BY
  category,
  sales_rank;

------------------------------------------------------------

-- 課題７：　CTEを使い、店舗売上とオンライン売上を1つのテーブルとして合算する。その後、この合算テーブルを使って都道府県ごとの総売上額を集計する。
WITH combined_sales AS (
  SELECT customer_id, amount FROM store_sales
  UNION ALL
  SELECT customer_id, amount FROM online_sales
)
SELECT
  c.prefecture,
  SUM(cs.amount) AS total_sales
FROM
  combined_sales cs
  JOIN customers c ON cs.customer_id = c.customer_id
GROUP BY
  c.prefecture
ORDER BY
  total_sales DESC;

------------------------------------------------------------

-- 課題８：　顧客ごとの総売上額を含む派生テーブルを作成。その後、customersテーブルと結合し、総売上額が最も高い顧客の名前を見つける。
SELECT
  c.customer_name,
  sales_summary.total_amount
FROM (
  SELECT
    customer_id,
    SUM(amount) AS total_amount
  FROM (
    SELECT customer_id, amount FROM store_sales
    UNION ALL
    SELECT customer_id, amount FROM online_sales
  ) AS combined_sales
  GROUP BY customer_id
) AS sales_summary
JOIN customers c ON sales_summary.customer_id = c.customer_id
ORDER BY sales_summary.total_amount DESC
LIMIT 1;

------------------------------------------------------------

-- 課題９：　ウィンドウ関数を使って、各店舗の売上の累積額を計算する。
WITH daily_sales AS (
  SELECT
    store_id,
    sale_date,
    SUM(amount) AS daily_amount
  FROM
    store_sales
  GROUP BY
    store_id,
    sale_date
)
SELECT
  store_id,
  sale_date,
  daily_amount,
  SUM(daily_amount) OVER (
    PARTITION BY store_id
    ORDER BY sale_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS cumulative_amount
FROM
  daily_sales
ORDER BY
  store_id,
  sale_date;

------------------------------------------------------------

-- 課題１０：　各商品のカテゴリにおいて、男女のうち総購入額が高い方の性別と、その総額を求める。
WITH combined_sales AS (
  SELECT customer_id, product_id, amount FROM store_sales
  UNION ALL
  SELECT customer_id, product_id, amount FROM online_sales
),
sales_with_info AS (
  SELECT
    cs.amount,
    c.gender,
    p.category
  FROM
    combined_sales cs
    JOIN customers c ON cs.customer_id = c.customer_id
    JOIN products p ON cs.product_id = p.product_id
),
category_gender_sales AS (
  SELECT
    category,
    gender,
    SUM(amount) AS total_amount
  FROM sales_with_info
  GROUP BY category, gender
),
ranked_sales AS (
  SELECT
    *,
    RANK() OVER (PARTITION BY category ORDER BY total_amount DESC) AS rnk
  FROM category_gender_sales
)
SELECT
  category,
  gender,
  total_amount
FROM ranked_sales
WHERE rnk = 1
ORDER BY category;