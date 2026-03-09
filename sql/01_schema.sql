-- ===============================================
-- MSDS459 – Week 6 – Checkpoint B
-- PostgreSQL schema for Healthcare KG
-- ===============================================

CREATE SCHEMA IF NOT EXISTS kg;

-- =========================
-- 1) Core entities
-- =========================

-- Companies (from companies.csv)
CREATE TABLE IF NOT EXISTS kg.company (
  company_id   SERIAL PRIMARY KEY,
  ticker       TEXT NOT NULL UNIQUE,
  name         TEXT NOT NULL,
  exchange     TEXT,
  sector       TEXT,
  subsector    TEXT,
  country      TEXT,
  aliases      TEXT,
  created_at   TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_company_name ON kg.company(name);


-- FDA regulatory documents (from fda_docs.jsonl)
CREATE TABLE IF NOT EXISTS kg.regulatory_doc (
  doc_id       SERIAL PRIMARY KEY,
  source       TEXT DEFAULT 'FDA',
  url          TEXT NOT NULL UNIQUE,
  title        TEXT,
  fetched_at   TIMESTAMPTZ,
  http_status  INT,
  relevance    INT,
  text         TEXT,
  text_len     INT,
  raw_json     JSONB,
  created_at   TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_regdoc_title ON kg.regulatory_doc(title);
CREATE INDEX IF NOT EXISTS idx_regdoc_fetched_at ON kg.regulatory_doc(fetched_at);
CREATE INDEX IF NOT EXISTS idx_regdoc_raw_json_gin ON kg.regulatory_doc USING GIN (raw_json);


-- News articles (optional, from gdelt_articles.jsonl)
CREATE TABLE IF NOT EXISTS kg.news_article (
  article_id    SERIAL PRIMARY KEY,
  source        TEXT DEFAULT 'GDELT',
  url           TEXT NOT NULL UNIQUE,
  title         TEXT,
  seendate      TIMESTAMPTZ,
  domain        TEXT,
  source_country TEXT,
  language      TEXT,
  tone          DOUBLE PRECISION,
  query         TEXT,
  raw_json      JSONB,
  created_at    TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_news_seendate ON kg.news_article(seendate);
CREATE INDEX IF NOT EXISTS idx_news_domain ON kg.news_article(domain);
CREATE INDEX IF NOT EXISTS idx_news_raw_json_gin ON kg.news_article USING GIN (raw_json);


-- Trading day dimension
CREATE TABLE IF NOT EXISTS kg.trading_day (
  trading_day_id SERIAL PRIMARY KEY,
  date           DATE NOT NULL UNIQUE
);


-- Yahoo Finance price points (one row per ticker per day)
CREATE TABLE IF NOT EXISTS kg.price_point (
  price_id     SERIAL PRIMARY KEY,
  ticker       TEXT NOT NULL,
  date         DATE NOT NULL,
  open         DOUBLE PRECISION,
  high         DOUBLE PRECISION,
  low          DOUBLE PRECISION,
  close        DOUBLE PRECISION,
  adj_close    DOUBLE PRECISION,
  volume       DOUBLE PRECISION,
  raw_json     JSONB,
  created_at   TIMESTAMP DEFAULT NOW(),
  UNIQUE (ticker, date)
);

CREATE INDEX IF NOT EXISTS idx_price_ticker ON kg.price_point(ticker);
CREATE INDEX IF NOT EXISTS idx_price_date ON kg.price_point(date);


-- =========================
-- 2) Bridge tables (graph edges)
-- =========================

-- (RegulatoryDoc)-[:MENTIONS]->(Company)
CREATE TABLE IF NOT EXISTS kg.regdoc_mentions_company (
  doc_id     INT REFERENCES kg.regulatory_doc(doc_id) ON DELETE CASCADE,
  company_id INT REFERENCES kg.company(company_id) ON DELETE CASCADE,
  mention    TEXT,          -- what matched: alias / ticker / name
  PRIMARY KEY (doc_id, company_id)
);

-- (NewsArticle)-[:MENTIONS]->(Company)
CREATE TABLE IF NOT EXISTS kg.news_mentions_company (
  article_id INT REFERENCES kg.news_article(article_id) ON DELETE CASCADE,
  company_id INT REFERENCES kg.company(company_id) ON DELETE CASCADE,
  mention    TEXT,
  PRIMARY KEY (article_id, company_id)
);

-- (Company)-[:HAS_PRICE]->(PricePoint) and (PricePoint)-[:ON_DAY]->(TradingDay)

CREATE TABLE IF NOT EXISTS kg.company_has_price (
  company_id INT REFERENCES kg.company(company_id) ON DELETE CASCADE,
  price_id   INT REFERENCES kg.price_point(price_id) ON DELETE CASCADE,
  PRIMARY KEY (company_id, price_id)
);




-- End of schema
