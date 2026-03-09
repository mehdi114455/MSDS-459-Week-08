-- =========================================================
-- MSDS 459 - Checkpoint C
-- Healthcare Knowledge Graph Project
-- PostgreSQL Example Queries
-- =========================================================

-- 1. Row counts by core table
SELECT 'company' AS table_name, COUNT(*) AS row_count FROM kg.company
UNION ALL
SELECT 'regulatory_doc', COUNT(*) FROM kg.regulatory_doc
UNION ALL
SELECT 'news_article', COUNT(*) FROM kg.news_article
UNION ALL
SELECT 'price_point', COUNT(*) FROM kg.price_point
UNION ALL
SELECT 'regdoc_mentions_company', COUNT(*) FROM kg.regdoc_mentions_company
UNION ALL
SELECT 'news_mentions_company', COUNT(*) FROM kg.news_mentions_company
UNION ALL
SELECT 'company_has_price', COUNT(*) FROM kg.company_has_price
ORDER BY table_name;


-- 2. Companies mentioned most often in FDA regulatory documents
SELECT
    c.ticker,
    c.name,
    COUNT(*) AS fda_mentions
FROM kg.regdoc_mentions_company m
JOIN kg.company c
    ON m.company_id = c.company_id
GROUP BY c.ticker, c.name
ORDER BY fda_mentions DESC, c.ticker;


-- 3. Companies mentioned most often in news articles
SELECT
    c.ticker,
    c.name,
    COUNT(*) AS news_mentions
FROM kg.news_mentions_company m
JOIN kg.company c
    ON m.company_id = c.company_id
GROUP BY c.ticker, c.name
ORDER BY news_mentions DESC, c.ticker;


-- 4. Number of price points loaded per company
SELECT
    c.ticker,
    c.name,
    COUNT(*) AS price_points
FROM kg.company_has_price cp
JOIN kg.company c
    ON cp.company_id = c.company_id
GROUP BY c.ticker, c.name
ORDER BY price_points DESC, c.ticker;


-- 5. Average closing price by company
SELECT
    c.ticker,
    c.name,
    ROUND(AVG(p.close)::numeric, 2) AS avg_close
FROM kg.company c
JOIN kg.company_has_price cp
    ON c.company_id = cp.company_id
JOIN kg.price_point p
    ON cp.price_id = p.price_id
GROUP BY c.ticker, c.name
ORDER BY avg_close DESC;


-- 6. Latest available price date for each company
SELECT
    c.ticker,
    c.name,
    MAX(p.date) AS latest_price_date
FROM kg.company c
JOIN kg.company_has_price cp
    ON c.company_id = cp.company_id
JOIN kg.price_point p
    ON cp.price_id = p.price_id
GROUP BY c.ticker, c.name
ORDER BY latest_price_date DESC, c.ticker;


-- 7. Sample recent prices for one company (change ticker if needed)
SELECT
    c.ticker,
    p.date,
    p.open,
    p.high,
    p.low,
    p.close,
    p.volume
FROM kg.company c
JOIN kg.company_has_price cp
    ON c.company_id = cp.company_id
JOIN kg.price_point p
    ON cp.price_id = p.price_id
WHERE c.ticker = 'BMY'
ORDER BY p.date DESC
LIMIT 20;


-- 8. Top regulatory documents by relevance
SELECT
    doc_id,
    title,
    url,
    relevance,
    fetched_at
FROM kg.regulatory_doc
ORDER BY relevance DESC NULLS LAST, fetched_at DESC
LIMIT 10;


-- 9. Cross-source summary by company
SELECT
    c.ticker,
    c.name,
    COALESCE(fd.fda_mentions, 0) AS fda_mentions,
    COALESCE(nm.news_mentions, 0) AS news_mentions,
    COALESCE(pp.price_points, 0) AS price_points
FROM kg.company c
LEFT JOIN (
    SELECT company_id, COUNT(*) AS fda_mentions
    FROM kg.regdoc_mentions_company
    GROUP BY company_id
) fd
    ON c.company_id = fd.company_id
LEFT JOIN (
    SELECT company_id, COUNT(*) AS news_mentions
    FROM kg.news_mentions_company
    GROUP BY company_id
) nm
    ON c.company_id = nm.company_id
LEFT JOIN (
    SELECT company_id, COUNT(*) AS price_points
    FROM kg.company_has_price
    GROUP BY company_id
) pp
    ON c.company_id = pp.company_id
ORDER BY fda_mentions DESC, news_mentions DESC, price_points DESC, c.ticker;