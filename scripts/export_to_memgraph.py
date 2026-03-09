import psycopg2
import mgclient
from datetime import date, datetime

PG_CONFIG = {
    "host": "postgres",
    "dbname": "healthcare_kg",
    "user": "kguser",
    "password": "kgpass",
    "port": 5432,
}

def pg_conn():
    return psycopg2.connect(**PG_CONFIG)

def mg_conn():
    return mgclient.connect(host="memgraph", port=7687)

def clean_value(v):
    if isinstance(v, (datetime, date)):
        return v.isoformat()
    return v

def main():
    pg = pg_conn()
    pc = pg.cursor()

    mg = mg_conn()
    mc = mg.cursor()

    # reset graph
    mc.execute("MATCH (n) DETACH DELETE n")

    # Companies
    pc.execute("SELECT company_id, ticker, name, sector, subsector, country FROM kg.company")
    for company_id, ticker, name, sector, subsector, country in pc.fetchall():
        mc.execute("""
            CREATE (:Company {
                company_id: $company_id,
                ticker: $ticker,
                name: $name,
                sector: $sector,
                subsector: $subsector,
                country: $country
            })
        """, {
            "company_id": company_id,
            "ticker": ticker,
            "name": name,
            "sector": sector,
            "subsector": subsector,
            "country": country
        })

    # Regulatory docs
    pc.execute("SELECT doc_id, url, title, fetched_at, relevance FROM kg.regulatory_doc")
    for doc_id, url, title, fetched_at, relevance in pc.fetchall():
        mc.execute("""
            CREATE (:RegulatoryDoc {
                doc_id: $doc_id,
                url: $url,
                title: $title,
                fetched_at: $fetched_at,
                relevance: $relevance
            })
        """, {
            "doc_id": doc_id,
            "url": url,
            "title": title,
            "fetched_at": clean_value(fetched_at),
            "relevance": relevance
        })

    # News articles
    pc.execute("SELECT article_id, url, title, seendate, domain, tone FROM kg.news_article")
    for article_id, url, title, seendate, domain, tone in pc.fetchall():
        mc.execute("""
            CREATE (:NewsArticle {
                article_id: $article_id,
                url: $url,
                title: $title,
                seendate: $seendate,
                domain: $domain,
                tone: $tone
            })
        """, {
            "article_id": article_id,
            "url": url,
            "title": title,
            "seendate": clean_value(seendate),
            "domain": domain,
            "tone": tone
        })

    # Price points
    pc.execute("SELECT price_id, ticker, date, close, volume FROM kg.price_point")
    for price_id, ticker, dt, close, volume in pc.fetchall():
        mc.execute("""
            CREATE (:PricePoint {
                price_id: $price_id,
                ticker: $ticker,
                date: $date,
                close: $close,
                volume: $volume
            })
        """, {
            "price_id": price_id,
            "ticker": ticker,
            "date": clean_value(dt),
            "close": close,
            "volume": volume
        })

    # RegDoc -> Company
    pc.execute("""
        SELECT doc_id, company_id, mention
        FROM kg.regdoc_mentions_company
    """)
    for doc_id, company_id, mention in pc.fetchall():
        mc.execute("""
            MATCH (d:RegulatoryDoc {doc_id: $doc_id}),
                  (c:Company {company_id: $company_id})
            CREATE (d)-[:MENTIONS {mention: $mention}]->(c)
        """, {
            "doc_id": doc_id,
            "company_id": company_id,
            "mention": mention
        })

    # NewsArticle -> Company
    pc.execute("""
        SELECT article_id, company_id, mention
        FROM kg.news_mentions_company
    """)
    for article_id, company_id, mention in pc.fetchall():
        mc.execute("""
            MATCH (a:NewsArticle {article_id: $article_id}),
                  (c:Company {company_id: $company_id})
            CREATE (a)-[:MENTIONS {mention: $mention}]->(c)
        """, {
            "article_id": article_id,
            "company_id": company_id,
            "mention": mention
        })

    # Company -> PricePoint
    pc.execute("""
        SELECT company_id, price_id
        FROM kg.company_has_price
    """)
    for company_id, price_id in pc.fetchall():
        mc.execute("""
            MATCH (c:Company {company_id: $company_id}),
                  (p:PricePoint {price_id: $price_id})
            CREATE (c)-[:HAS_PRICE]->(p)
        """, {
            "company_id": company_id,
            "price_id": price_id
        })

    mg.commit()
    mc.close()
    mg.close()
    pc.close()
    pg.close()

    print("Export to Memgraph complete.")

if __name__ == "__main__":
    main()