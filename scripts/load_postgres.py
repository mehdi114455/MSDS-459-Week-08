import os
import json
import glob
import pandas as pd
import psycopg2
from psycopg2.extras import Json

DB_CONFIG = {
    "host": "postgres",
    "dbname": "healthcare_kg",
    "user": "kguser",
    "password": "kgpass",
    "port": 5432,
}

BASE = "/app/data"

def get_conn():
    return psycopg2.connect(**DB_CONFIG)

def load_companies(cur):
    path = os.path.join(BASE, "companies.csv")
    df = pd.read_csv(path)

    for _, row in df.iterrows():
        cur.execute("""
            INSERT INTO kg.company (ticker, name, exchange, sector, subsector, country, aliases)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (ticker) DO NOTHING
        """, (
            str(row.get("ticker", "")).strip(),
            str(row.get("company_name", "")).strip(),
            row.get("exchange"),
            row.get("sector"),
            row.get("subsector"),
            row.get("country"),
            row.get("aliases"),
        ))

def load_fda_docs(cur):
    path = os.path.join(BASE, "regulatory", "fda_docs.jsonl")
    if not os.path.exists(path):
        return

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            rec = json.loads(line)
            cur.execute("""
                INSERT INTO kg.regulatory_doc
                (source, url, title, fetched_at, http_status, relevance, text, text_len, raw_json)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (url) DO NOTHING
            """, (
                rec.get("source", "FDA"),
                rec.get("url"),
                rec.get("title"),
                rec.get("fetched_at"),
                rec.get("http_status"),
                rec.get("relevance"),
                rec.get("text"),
                len(rec.get("text", "")),
                Json(rec),
            ))

def load_news(cur):
    path = os.path.join(BASE, "news", "gdelt_articles.jsonl")
    if not os.path.exists(path):
        return

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            rec = json.loads(line)
            cur.execute("""
                INSERT INTO kg.news_article
                (source, url, title, seendate, domain, source_country, language, tone, query, raw_json)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (url) DO NOTHING
            """, (
                rec.get("source", "GDELT"),
                rec.get("url"),
                rec.get("title"),
                rec.get("seendate"),
                rec.get("domain"),
                rec.get("sourcecountry"),
                rec.get("language"),
                rec.get("tone"),
                rec.get("query"),
                Json(rec),
            ))

def load_prices(cur):
    yahoo_dir = os.path.join(BASE, "financial", "yahoo")
    for csv_path in glob.glob(os.path.join(yahoo_dir, "*.csv")):
        ticker = os.path.basename(csv_path).replace(".csv", "")
        if ticker.lower() == "summary":
            continue

        df = pd.read_csv(csv_path)

        # normalize column names (just in case)
        df.columns = [str(c).strip() for c in df.columns]

        if "Date" not in df.columns:
            print(f"Skipping {csv_path}: no Date column")
            continue

        # keep only rows with valid dates
        df["Date"] = pd.to_datetime(df["Date"], errors="coerce").dt.date
        df = df[df["Date"].notna()].copy()

        # convert numeric columns safely
        numeric_cols = ["Open", "High", "Low", "Close", "Adj Close", "Volume"]
        for col in numeric_cols:
            if col in df.columns:
                df[col] = pd.to_numeric(df[col], errors="coerce")

        for _, row in df.iterrows():
            cur.execute("""
                INSERT INTO kg.price_point
                (ticker, date, open, high, low, close, adj_close, volume, raw_json)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (ticker, date) DO NOTHING
            """, (
                ticker,
                row["Date"],
                None if pd.isna(row.get("Open")) else float(row.get("Open")),
                None if pd.isna(row.get("High")) else float(row.get("High")),
                None if pd.isna(row.get("Low")) else float(row.get("Low")),
                None if pd.isna(row.get("Close")) else float(row.get("Close")),
                None if pd.isna(row.get("Adj Close")) else float(row.get("Adj Close")),
                None if pd.isna(row.get("Volume")) else int(row.get("Volume")),
                Json({
                    k: (None if pd.isna(v) else str(v))
                    for k, v in row.to_dict().items()
                }),
            ))

def build_company_has_price(cur):
    cur.execute("""
        INSERT INTO kg.company_has_price (company_id, price_id)
        SELECT c.company_id, p.price_id
        FROM kg.company c
        JOIN kg.price_point p ON c.ticker = p.ticker
        ON CONFLICT DO NOTHING
    """)

def build_regdoc_mentions(cur):
    cur.execute("SELECT company_id, ticker, name, aliases FROM kg.company")
    companies = cur.fetchall()

    cur.execute("SELECT doc_id, text, raw_json FROM kg.regulatory_doc")
    docs = cur.fetchall()

    for doc_id, text, raw_json in docs:
        mentions = []
        if raw_json and isinstance(raw_json, dict):
            mentions = raw_json.get("mentions", []) or []

        for company_id, ticker, name, aliases in companies:
            candidate_terms = [ticker, name]
            if aliases:
                candidate_terms.extend([a.strip() for a in aliases.split(";") if a.strip()])

            matched = None
            for term in candidate_terms:
                if term in mentions:
                    matched = term
                    break

            if matched:
                cur.execute("""
                    INSERT INTO kg.regdoc_mentions_company (doc_id, company_id, mention)
                    VALUES (%s, %s, %s)
                    ON CONFLICT DO NOTHING
                """, (doc_id, company_id, matched))

def build_news_mentions(cur):
    cur.execute("""
        INSERT INTO kg.news_mentions_company (article_id, company_id, mention)
        SELECT n.article_id,
               c.company_id,
               n.raw_json->>'ticker' AS mention
        FROM kg.news_article n
        JOIN kg.company c
          ON n.raw_json->>'ticker' = c.ticker
        WHERE n.raw_json->>'ticker' IS NOT NULL
        ON CONFLICT DO NOTHING
    """)

def main():
    conn = get_conn()
    conn.autocommit = False
    cur = conn.cursor()

    load_companies(cur)
    load_fda_docs(cur)
    load_news(cur)
    load_prices(cur)
    build_company_has_price(cur)
    build_regdoc_mentions(cur)
    build_news_mentions(cur)

    conn.commit()
    cur.close()
    conn.close()
    print("PostgreSQL load complete.")

if __name__ == "__main__":
    main()