# 📘 MSDS 459 — Knowledge Engineering
**Course:** MSDS 459 - Knowledge Engineering  
**Term:** Winter 2026  
**Student:** Syed Mehdi

## Healthcare Knowledge Graph Project (Checkpoint C)

This repository has the implementation for Checkpoint C of the MSDS 459 Knowledge Engineering course project.  

The Objective of this checkpoint is to design and implement a hybrid knowledge graph datase.

The dataset integrates:

- Public healthcare companies  
- FDA regulatory documents  
- GDELT news articles  
- Historical stock price data  

---

## Repository Structure
    .
    ├── Dockerfile.loader
    ├── README.md
    ├── cypher
    │   ├── 01_schema.cypher
    │   └── 02_queries.cypher
    ├── data
    │   ├── companies.csv
    │   ├── financial
    │   │   └── yahoo
    │   │       ├── ABBV.csv
    │   │       ├── AMGN.csv
    │   │       ├── BIIB.csv
    │   │       .
    │   │       .
    │   │       .
    │   │       └── summary.csv
    │   ├── news
    │   │   ├── gdelt_articles.jsonl
    │   │   └── gdelt_articles_failures.json
    │   └── regulatory
    │       └── fda_docs.jsonl
    ├── docker-compose.yml
    ├── requirements.txt
    ├── scripts
    │   ├── export_to_memgraph.py
    │   └── load_postgres.py
    └── sql
        ├── 01_schema.sql
        └── 02_queries.sql


---

## Prerequisites

Install:

- **Docker Desktop** (Mac/Windows)  
→ https://www.docker.com/products/docker-desktop/

Check installation:

```bash
docker --version
docker compose version
```


## Setup & Run Instructions
```bash
git clone <https://github.com/mehdi114455/MSDS-459-Week-08.git>
cd msds459-healthcare-kg
```

## Start Docker Environment

docker compose up -d

This starts:

- Memgraph container (healthcare_memgraph)
- Memgraph Lab UI (healthcare_memgraph_lab)
- Loader container (healthcare_loader)

---

## Load Data into PostgreSQL

Create the Schema
```bash
docker exec -it healthcare_postgres psql -U kguser -d healthcare_kg -f /sql/01_schema.sql
```
Run Loader Script
```bash
docker exec -it healthcare_loader python scripts/load_postgres.py
```
To Check
```bash
SELECT COUNT(*) FROM kg.company;
SELECT COUNT(*) FROM kg.regulatory_doc;
SELECT COUNT(*) FROM kg.news_article;
SELECT COUNT(*) FROM kg.price_point;
```

## Export Data to Memgraph

To Export Data
```bash
docker exec -it healthcare_loader python scripts/export_to_memgraph.py
```
Expected output: Export to Memgraph complete.


### Open Memgraph Lab
Open on a web browser:
http://localhost:3000

Connect using:
Host: memgraph
Port: 7687
Authentication: None

---
## Sample Queries

### PostgreSQL Queries

Run (on Terminal)
```bash
docker exec -it healthcare_postgres psql -U kguser -d healthcare_kg
```
Then you can run the sample quries in 'sql/02_queries.sql'

### Memgraph Queries

Once the Web UI is connected on the browser you can run the sample queries in 'cypher/02_queries.cypher'

