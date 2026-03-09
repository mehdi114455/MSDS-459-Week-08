// =========================================================
// MSDS 459 - Checkpoint C
// Healthcare Knowledge Graph Project
// Memgraph / Cypher Example Queries
// =========================================================

// 1. Node counts by label
MATCH (n)
RETURN labels(n)[0] AS label, count(*) AS cnt
ORDER BY cnt DESC;


// 2. Relationship counts by type
MATCH ()-[r]->()
RETURN type(r) AS rel, count(*) AS cnt
ORDER BY cnt DESC;


// 3. Companies mentioned most by FDA regulatory documents
MATCH (d:RegulatoryDoc)-[:MENTIONS]->(c:Company)
RETURN c.ticker, c.name, count(d) AS fda_mentions
ORDER BY fda_mentions DESC, c.ticker;


// 4. Companies mentioned most in news articles
MATCH (n:NewsArticle)-[:MENTIONS]->(c:Company)
RETURN c.ticker, c.name, count(n) AS news_mentions
ORDER BY news_mentions DESC, c.ticker;


// 5. Most connected companies overall
MATCH (c:Company)
RETURN
    c.ticker,
    c.name,
    size((c)<-[:MENTIONS]-()) + size((c)-[:HAS_PRICE]->()) AS degree
ORDER BY degree DESC, c.ticker;


// 6. Number of price points connected to each company
MATCH (c:Company)-[:HAS_PRICE]->(p:PricePoint)
RETURN c.ticker, c.name, count(p) AS price_points
ORDER BY price_points DESC, c.ticker;


// 7. Traverse from a company to its recent price points
MATCH (c:Company {ticker:"BMY"})-[:HAS_PRICE]->(p:PricePoint)
RETURN c.ticker, p.date, p.close, p.volume
ORDER BY p.date DESC
LIMIT 20;


// 8. Graph output: regulatory docs mentioning one company
MATCH p = (d:RegulatoryDoc)-[:MENTIONS]->(c:Company {ticker:"BMY"})
RETURN p
LIMIT 10;


// 9. Graph output: all mention edges to one company
MATCH p = (n)-[:MENTIONS]->(c:Company {ticker:"BMY"})
RETURN p
LIMIT 15;


// 10. Compare regulatory and news connectivity for each company
MATCH (c:Company)
OPTIONAL MATCH (d:RegulatoryDoc)-[:MENTIONS]->(c)
WITH c, count(d) AS fda_mentions
OPTIONAL MATCH (n:NewsArticle)-[:MENTIONS]->(c)
RETURN
    c.ticker,
    c.name,
    fda_mentions,
    count(n) AS news_mentions,
    fda_mentions + count(n) AS total_mentions
ORDER BY total_mentions DESC, c.ticker;