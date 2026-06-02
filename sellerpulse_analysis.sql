-- =====================================================================
-- SellerPulse — Seller Activation & Churn Analysis (SQL layer)
-- Dialect: SQLite. Re-expresses the pandas analysis in SQL.
-- Tables expected: orders, items, sellers, reviews, products, cat
-- (loaded from the Olist Brazilian E-Commerce dataset CSVs)
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. sale_events: one row per (seller, order) = one sale.
--    Ranks each seller's sales and computes days since their first sale.
--    Concepts: JOIN, GROUP BY, ROW_NUMBER(), MIN() OVER, date math.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS sale_events;
CREATE VIEW sale_events AS
WITH sales AS (
    SELECT  i.seller_id,
            i.order_id,
            o.order_purchase_timestamp AS sale_ts
    FROM items i
    JOIN orders o ON o.order_id = i.order_id
    WHERE o.order_status <> 'unavailable'
      AND o.order_purchase_timestamp IS NOT NULL
    GROUP BY i.seller_id, i.order_id              -- collapse multi-item orders
),
ranked AS (
    SELECT  seller_id,
            order_id,
            DATE(sale_ts) AS sale_date,
            ROW_NUMBER() OVER (PARTITION BY seller_id ORDER BY sale_ts) AS sale_rank,
            DATE(MIN(sale_ts) OVER (PARTITION BY seller_id)) AS first_sale_date
    FROM sales
)
SELECT  seller_id, order_id, sale_date, sale_rank, first_sale_date,
        CAST(julianday(sale_date) - julianday(first_sale_date) AS INT) AS days_since_first
FROM ranked;


-- ---------------------------------------------------------------------
-- 2. cohort_base: sellers with >= 90 days of observation window.
--    Excludes late-joiners so 90-day retention isn't understated.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS cohort_base;
CREATE VIEW cohort_base AS
WITH bounds AS (
    SELECT MAX(sale_date) AS dataset_end FROM sale_events
),
per_seller AS (
    SELECT  se.seller_id,
            se.first_sale_date,
            MAX(se.sale_date) AS last_sale_date,
            COUNT(DISTINCT se.order_id) AS total_sales,
            CAST(julianday((SELECT dataset_end FROM bounds))
                 - julianday(se.first_sale_date) AS INT) AS observable_days
    FROM sale_events se
    GROUP BY se.seller_id, se.first_sale_date
)
SELECT * FROM per_seller
WHERE observable_days >= 90;


-- ---------------------------------------------------------------------
-- 3. seller_flags: milestone flags per seller (conditional aggregation).
--    second_sale_30d is the headline churn driver.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS seller_flags;
CREATE VIEW seller_flags AS
SELECT
    cb.seller_id, cb.first_sale_date, cb.last_sale_date,
    cb.total_sales, cb.observable_days,
    MAX(CASE WHEN se.sale_rank >= 2 AND se.days_since_first <= 30 THEN 1 ELSE 0 END) AS second_sale_30d,
    MAX(CASE WHEN se.days_since_first > 30 AND se.days_since_first <= 90 THEN 1 ELSE 0 END) AS active_30_90,
    MAX(CASE WHEN se.sale_rank >= 5 THEN 1 ELSE 0 END) AS fifth_sale
FROM cohort_base cb
JOIN sale_events se ON se.seller_id = cb.seller_id
GROUP BY cb.seller_id, cb.first_sale_date, cb.last_sale_date,
         cb.total_sales, cb.observable_days;


-- ---------------------------------------------------------------------
-- 4. The activation funnel (one row per milestone).
-- ---------------------------------------------------------------------
SELECT 'Onboarded (1st sale)' AS stage, COUNT(*) AS sellers FROM seller_flags
UNION ALL
SELECT '2nd sale within 30d', SUM(second_sale_30d) FROM seller_flags
UNION ALL
SELECT 'Active in days 30-90', SUM(active_30_90) FROM seller_flags
UNION ALL
SELECT 'Reached 5th sale', SUM(fifth_sale) FROM seller_flags;


-- ---------------------------------------------------------------------
-- 5. Headline churn metric (~40.5%).
-- ---------------------------------------------------------------------
SELECT ROUND(100.0 * (1 - AVG(second_sale_30d)), 1) AS churn_before_2nd_pct
FROM seller_flags;


-- ---------------------------------------------------------------------
-- 6. Cohort retention by join month.
-- ---------------------------------------------------------------------
SELECT  strftime('%Y-%m', first_sale_date) AS cohort_month,
        COUNT(*) AS sellers,
        ROUND(100.0 * AVG(second_sale_30d), 1) AS pct_2nd_30d,
        ROUND(100.0 * AVG(active_30_90), 1)   AS pct_active_30_90,
        ROUND(100.0 * AVG(fifth_sale), 1)     AS pct_5th
FROM seller_flags
GROUP BY cohort_month
ORDER BY cohort_month;


-- ---------------------------------------------------------------------
-- 7. Worst dropoff categories (>= 30 sellers).
--    Picks each seller's primary category, then churn per category.
-- ---------------------------------------------------------------------
WITH item_cat AS (
    SELECT  i.seller_id,
            COALESCE(c.product_category_name_english, p.product_category_name, 'unknown') AS category
    FROM items i
    LEFT JOIN products p ON p.product_id = i.product_id
    LEFT JOIN cat c ON c.product_category_name = p.product_category_name
),
ranked_cat AS (
    SELECT  seller_id, category,
            ROW_NUMBER() OVER (PARTITION BY seller_id ORDER BY COUNT(*) DESC) AS rn
    FROM item_cat
    GROUP BY seller_id, category
),
primary_cat AS (
    SELECT seller_id, category FROM ranked_cat WHERE rn = 1
)
SELECT  pc.category,
        COUNT(*) AS sellers,
        ROUND(100.0 * (1 - AVG(sf.second_sale_30d)), 1) AS churn_before_2nd
FROM seller_flags sf
JOIN primary_cat pc ON pc.seller_id = sf.seller_id
GROUP BY pc.category
HAVING COUNT(*) >= 30
ORDER BY churn_before_2nd DESC;


-- ---------------------------------------------------------------------
-- 8. Health-score signals per seller (velocity, SLA, review, recency).
--    Final 0-100 normalization + weighting done in the Python notebook.
-- ---------------------------------------------------------------------
WITH bounds AS (SELECT MAX(sale_date) AS dataset_end FROM sale_events),
delivery AS (
    SELECT  i.seller_id,
            AVG(CASE WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
                     THEN 1.0 ELSE 0.0 END) AS delivery_sla
    FROM items i
    JOIN orders o ON o.order_id = i.order_id
    WHERE o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
    GROUP BY i.seller_id
),
review AS (
    SELECT i.seller_id, AVG(r.review_score) AS avg_review
    FROM items i
    JOIN reviews r ON r.order_id = i.order_id
    GROUP BY i.seller_id
)
SELECT  cb.seller_id,
        ROUND(cb.total_sales * 7.0 / MAX(cb.observable_days, 7), 3) AS velocity_per_week,
        ROUND(d.delivery_sla, 3) AS delivery_sla,
        ROUND(v.avg_review, 2)   AS avg_review,
        CAST(julianday((SELECT dataset_end FROM bounds))
             - julianday(cb.last_sale_date) AS INT) AS days_since_last
FROM cohort_base cb
LEFT JOIN delivery d ON d.seller_id = cb.seller_id
LEFT JOIN review   v ON v.seller_id = cb.seller_id;
