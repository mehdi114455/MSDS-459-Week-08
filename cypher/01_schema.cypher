// ===============================================
// MSDS459 - Week 6 - Healthcare Knowledge Graph
// Property Graph Schema for Memgraph
// ===============================================


// ===============================================
// 1) Constraints / Indexes
// ===============================================

// Unique identifiers
CREATE CONSTRAINT ON (c:Company) ASSERT c.ticker IS UNIQUE;
CREATE CONSTRAINT ON (d:RegulatoryDoc) ASSERT d.url IS UNIQUE;
CREATE CONSTRAINT ON (td:TradingDay) ASSERT td.date IS UNIQUE;

// Helpful indexes
CREATE INDEX ON :Company(name);
CREATE INDEX ON :RegulatoryDoc(title);
CREATE INDEX ON :PricePoint(ticker);
CREATE INDEX ON :PricePoint(date);


// ===============================================
// 2) Conceptual Node Labels
// ===============================================

// Company
// {ticker, name, exchange, sector, subsector, country}

// RegulatoryDoc (FDA)
// {url, title, fetched_at, relevance, text_len}

// NewsArticle (GDELT)
// {url, title, seendate, sourceCountry, domain, tone}

// TradingDay
// {date}

// PricePoint
// {ticker, date, open, high, low, close, volume}

// Metric (optional future use)
// {name, description, unit}


// ===============================================
// 3) Relationship Types
// ===============================================

// (RegulatoryDoc)-[:MENTIONS]->(Company)
// (NewsArticle)-[:MENTIONS]->(Company)
// (Company)-[:HAS_PRICE]->(PricePoint)
// (PricePoint)-[:ON_DAY]->(TradingDay)
// (RegulatoryDoc)-[:IMPACTS]->(Company)    // optional future edge
// (Company)-[:BELONGS_TO]->(:Sector)       // optional future expansion


// ===============================================
// 4) Minimal Example Graph Slice
// ===============================================

// --- Company ---
MERGE (c:Company {ticker: "PFE"})
  ON CREATE SET
    c.name = "Pfizer Inc.",
    c.exchange = "NYSE",
    c.sector = "Healthcare",
    c.subsector = "Pharmaceuticals",
    c.country = "USA";

// --- Regulatory Document ---
MERGE (d:RegulatoryDoc {url: "https://www.fda.gov/example-pfe-recall"})
  ON CREATE SET
    d.title = "FDA Issues Recall for Pfizer Product",
    d.fetched_at = datetime(),
    d.relevance = 5,
    d.text_len = 4200;

// --- Link document to company ---
MERGE (d)-[:MENTIONS]->(c);

// --- Trading Day ---
MERGE (td:TradingDay {date: date("2025-01-15")});

// --- Price Point ---
MERGE (p:PricePoint {ticker: "PFE", date: date("2025-01-15")})
  ON CREATE SET
    p.open = 30.25,
    p.high = 31.10,
    p.low = 29.95,
    p.close = 30.80,
    p.volume = 45000000;

// --- Connect price to company and date ---
MERGE (c)-[:HAS_PRICE]->(p);
MERGE (p)-[:ON_DAY]->(td);


// ===============================================
// End of Schema
// ===============================================
