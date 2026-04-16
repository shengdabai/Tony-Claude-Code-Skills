# Full-Text Search Implementation

## Basic Full-Text Search Concepts

### Text Search Data Types

```sql
-- tsvector: Processed document (sorted, normalized, no duplicates)
SELECT to_tsvector('english', 'The quick brown fox jumps over the lazy dog');
-- 'brown':3 'dog':9 'fox':4 'jump':5 'lazi':8 'quick':2

-- tsquery: Search query
SELECT to_tsquery('english', 'fox & dog');
-- 'fox' & 'dog'

SELECT to_tsquery('english', 'jumping | running');
-- 'jump' | 'run'
```

### Basic Search
```sql
CREATE TABLE articles (
    id SERIAL PRIMARY KEY,
    title TEXT,
    content TEXT
);

-- Simple search
SELECT * FROM articles
WHERE to_tsvector('english', content) @@ to_tsquery('english', 'postgresql');

-- Search in multiple columns
SELECT * FROM articles
WHERE to_tsvector('english', title || ' ' || content)
    @@ to_tsquery('english', 'postgresql & performance');
```

## Creating Efficient Full-Text Search

### Method 1: Computed tsvector Column
```sql
-- Add tsvector column
ALTER TABLE articles ADD COLUMN search_vector tsvector;

-- Populate the column
UPDATE articles
SET search_vector = to_tsvector('english', coalesce(title, '') || ' ' || coalesce(content, ''));

-- Create GIN index
CREATE INDEX idx_articles_search ON articles USING gin(search_vector);

-- Query using the indexed column
SELECT * FROM articles
WHERE search_vector @@ to_tsquery('english', 'postgresql & performance');
```

### Method 2: Generated Column (PostgreSQL 12+)
```sql
CREATE TABLE articles (
    id SERIAL PRIMARY KEY,
    title TEXT,
    content TEXT,
    search_vector tsvector GENERATED ALWAYS AS (
        to_tsvector('english', coalesce(title, '') || ' ' || coalesce(content, ''))
    ) STORED
);

CREATE INDEX idx_articles_search ON articles USING gin(search_vector);

-- Automatically updates when title or content changes
INSERT INTO articles (title, content) VALUES
    ('PostgreSQL Tutorial', 'Learn how to use PostgreSQL effectively');

-- No need to manually update search_vector
```

### Method 3: Trigger-Based Update
```sql
ALTER TABLE articles ADD COLUMN search_vector tsvector;

-- Create trigger function
CREATE OR REPLACE FUNCTION articles_search_trigger() RETURNS trigger AS $$
BEGIN
    NEW.search_vector := to_tsvector('english',
        coalesce(NEW.title, '') || ' ' || coalesce(NEW.content, '')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER tsvector_update
    BEFORE INSERT OR UPDATE ON articles
    FOR EACH ROW
    EXECUTE FUNCTION articles_search_trigger();

CREATE INDEX idx_articles_search ON articles USING gin(search_vector);

-- Trigger automatically updates search_vector
INSERT INTO articles (title, content) VALUES
    ('PostgreSQL Tutorial', 'Learn how to use PostgreSQL effectively');
```

### Method 4: Expression Index
```sql
-- Create GIN index on expression
CREATE INDEX idx_articles_search ON articles
USING gin(to_tsvector('english', coalesce(title, '') || ' ' || coalesce(content, '')));

-- Query must use exact same expression
SELECT * FROM articles
WHERE to_tsvector('english', coalesce(title, '') || ' ' || coalesce(content, ''))
    @@ to_tsquery('english', 'postgresql');

-- Pro: No extra column needed
-- Con: Recomputes tsvector on every query (slower than stored column)
```

## Query Syntax

### AND, OR, NOT Operators
```sql
-- AND (&): Both terms must be present
SELECT * FROM articles
WHERE search_vector @@ to_tsquery('english', 'postgresql & performance');

-- OR (|): At least one term must be present
SELECT * FROM articles
WHERE search_vector @@ to_tsquery('english', 'postgresql | mysql');

-- NOT (!): Term must not be present
SELECT * FROM articles
WHERE search_vector @@ to_tsquery('english', 'postgresql & !mysql');

-- Grouping with parentheses
SELECT * FROM articles
WHERE search_vector @@ to_tsquery('english', '(postgresql | mysql) & performance');
```

### Phrase Search
```sql
-- <-> Adjacent words (in order)
SELECT * FROM articles
WHERE search_vector @@ to_tsquery('english', 'database <-> performance');

-- <N> Words with N-1 words between
SELECT * FROM articles
WHERE search_vector @@ to_tsquery('english', 'postgresql <2> performance');
-- Matches: "postgresql and performance", "postgresql database performance"
```

### Prefix Matching
```sql
-- Prefix search with :*
SELECT * FROM articles
WHERE search_vector @@ to_tsquery('english', 'postgr:*');
-- Matches: postgresql, postgres, etc.

-- Multiple prefix terms
SELECT * FROM articles
WHERE search_vector @@ to_tsquery('english', 'data:* & optim:*');
```

### User Input to tsquery
```sql
-- plainto_tsquery: Simple text to query (adds & between words)
SELECT plainto_tsquery('english', 'postgresql performance tuning');
-- 'postgresql' & 'performance' & 'tune'

-- phraseto_tsquery: Text to phrase query
SELECT phraseto_tsquery('english', 'postgresql performance');
-- 'postgresql' <-> 'performance'

-- websearch_to_tsquery: Web search syntax (PostgreSQL 11+)
SELECT websearch_to_tsquery('english', '"postgresql performance" -mysql OR sqlite');
-- 'postgresql' <-> 'performance' & !'mysql' | 'sqlite'
```

**Safe query construction:**
```sql
-- Good: Use plainto_tsquery for user input
SELECT * FROM articles
WHERE search_vector @@ plainto_tsquery('english', user_input);

-- Or websearch_to_tsquery for advanced users
SELECT * FROM articles
WHERE search_vector @@ websearch_to_tsquery('english', user_input);
```

## Ranking and Sorting Results

### Basic Ranking with ts_rank
```sql
-- ts_rank: Rank by term frequency
SELECT
    id,
    title,
    ts_rank(search_vector, query) AS rank
FROM articles,
     to_tsquery('english', 'postgresql & performance') AS query
WHERE search_vector @@ query
ORDER BY rank DESC;
```

### Advanced Ranking with ts_rank_cd
```sql
-- ts_rank_cd: Rank considering proximity and coverage
SELECT
    id,
    title,
    ts_rank_cd(search_vector, query) AS rank
FROM articles,
     to_tsquery('english', 'postgresql <-> performance') AS query
WHERE search_vector @@ query
ORDER BY rank DESC;
```

### Weighted Ranking
```sql
-- Assign weights to different fields
CREATE TABLE articles (
    id SERIAL PRIMARY KEY,
    title TEXT,
    content TEXT,
    search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(content, '')), 'B')
    ) STORED
);

CREATE INDEX idx_articles_search ON articles USING gin(search_vector);

-- Rank with weights (A=1.0, B=0.4, C=0.2, D=0.1)
SELECT
    id,
    title,
    ts_rank('{1.0, 0.4, 0.2, 0.1}', search_vector, query) AS rank
FROM articles,
     to_tsquery('english', 'postgresql') AS query
WHERE search_vector @@ query
ORDER BY rank DESC;
```

### Custom Ranking
```sql
-- Combine ts_rank with other factors
SELECT
    id,
    title,
    (
        ts_rank(search_vector, query) * 1000 +      -- Base relevance
        CASE WHEN title ILIKE '%postgresql%' THEN 100 ELSE 0 END +  -- Title boost
        EXTRACT(EPOCH FROM age(NOW(), created_at)) / 86400 * -0.1   -- Recency boost
    ) AS rank
FROM articles,
     to_tsquery('english', 'postgresql') AS query
WHERE search_vector @@ query
ORDER BY rank DESC;
```

## Highlighting Search Results

### ts_headline: Generate Snippets
```sql
SELECT
    id,
    title,
    ts_headline('english', content, query, 'MaxWords=50, MinWords=20') AS snippet
FROM articles,
     to_tsquery('english', 'postgresql & performance') AS query
WHERE search_vector @@ query;

-- Output example:
-- "...learn how <b>PostgreSQL</b> can improve <b>performance</b> through proper indexing..."
```

### Customizing Highlights
```sql
SELECT
    ts_headline(
        'english',
        content,
        query,
        'StartSel=<mark>, StopSel=</mark>, MaxWords=100, MinWords=50, MaxFragments=3'
    ) AS snippet
FROM articles,
     to_tsquery('english', 'postgresql') AS query
WHERE search_vector @@ query;
```

## Language Support

### Multiple Languages
```sql
-- Create language-specific columns
CREATE TABLE articles (
    id SERIAL PRIMARY KEY,
    title_en TEXT,
    content_en TEXT,
    title_es TEXT,
    content_es TEXT,
    search_vector_en tsvector GENERATED ALWAYS AS (
        to_tsvector('english', coalesce(title_en, '') || ' ' || coalesce(content_en, ''))
    ) STORED,
    search_vector_es tsvector GENERATED ALWAYS AS (
        to_tsvector('spanish', coalesce(title_es, '') || ' ' || coalesce(content_es, ''))
    ) STORED
);

CREATE INDEX idx_articles_search_en ON articles USING gin(search_vector_en);
CREATE INDEX idx_articles_search_es ON articles USING gin(search_vector_es);

-- Search in specific language
SELECT * FROM articles
WHERE search_vector_en @@ to_tsquery('english', 'postgresql');

SELECT * FROM articles
WHERE search_vector_es @@ to_tsquery('spanish', 'base de datos');
```

### Available Languages
```sql
-- List available text search configurations
SELECT cfgname FROM pg_ts_config;
-- english, spanish, french, german, italian, portuguese, russian, etc.
```

### Simple Language Configuration
```sql
-- Create custom configuration based on simple (no stemming)
CREATE TEXT SEARCH CONFIGURATION simple_english (COPY = simple);

-- Use for exact matching without stemming
SELECT to_tsvector('simple_english', 'running runs run');
-- 'run':3 'running':1 'runs':2  (no stemming)

SELECT to_tsvector('english', 'running runs run');
-- 'run':1,2,3  (all stemmed to 'run')
```

## Fuzzy Search with Trigrams

### Setup pg_trgm Extension
```sql
CREATE EXTENSION pg_trgm;

-- Create trigram index
CREATE INDEX idx_articles_title_trgm ON articles USING gin(title gin_trgm_ops);
CREATE INDEX idx_articles_content_trgm ON articles USING gin(content gin_trgm_ops);
```

### Similarity Search
```sql
-- Find similar strings (0 to 1, where 1 is exact match)
SELECT title, similarity(title, 'PostgreSQL Tutorial') AS sim
FROM articles
WHERE similarity(title, 'PostgreSQL Tutorial') > 0.3
ORDER BY sim DESC;

-- Shorthand using % operator
SELECT title
FROM articles
WHERE title % 'PostgreSQL Tutorial'  -- similarity > 0.3 (default threshold)
ORDER BY similarity(title, 'PostgreSQL Tutorial') DESC;

-- Set custom threshold
SET pg_trgm.similarity_threshold = 0.5;
```

### ILIKE with Trigram Index
```sql
-- Trigram index speeds up ILIKE queries
SELECT * FROM articles
WHERE content ILIKE '%postgr%';  -- Uses trigram index

-- Case-sensitive LIKE also works
SELECT * FROM articles
WHERE content LIKE '%Postgr%';
```

### Combining Full-Text and Trigram Search
```sql
-- Full-text search with trigram fallback
WITH fts AS (
    SELECT id, title, ts_rank(search_vector, query) AS rank
    FROM articles,
         websearch_to_tsquery('english', 'postgresql performance') AS query
    WHERE search_vector @@ query
),
fuzzy AS (
    SELECT id, title, similarity(content, 'postgresql performance') AS sim
    FROM articles
    WHERE content % 'postgresql performance'
        AND id NOT IN (SELECT id FROM fts)
)
SELECT id, title, rank AS score FROM fts
UNION ALL
SELECT id, title, sim AS score FROM fuzzy
ORDER BY score DESC;
```

## Performance Optimization

### GIN vs GiST Indexes
```sql
-- GIN: Faster search, slower updates, larger index
CREATE INDEX idx_articles_search_gin ON articles USING gin(search_vector);

-- GiST: Slower search, faster updates, smaller index
CREATE INDEX idx_articles_search_gist ON articles USING gist(search_vector);

-- Recommendation: Use GIN for most cases
```

### Partial Indexes for Common Queries
```sql
-- Index only recent articles
CREATE INDEX idx_recent_articles_search ON articles
USING gin(search_vector)
WHERE created_at > NOW() - INTERVAL '1 year';

-- Query must match WHERE condition
SELECT * FROM articles
WHERE search_vector @@ to_tsquery('english', 'postgresql')
    AND created_at > NOW() - INTERVAL '1 year';
```

### Covering Indexes for Ranking
```sql
-- Include frequently accessed columns
CREATE INDEX idx_articles_search_covering ON articles
USING gin(search_vector)
INCLUDE (title, created_at);

-- Enables index-only scan for ranking queries
```

## Advanced Patterns

### Search Across Multiple Tables
```sql
-- Union search results from multiple tables
SELECT 'article' AS type, id, title, search_vector
FROM articles
UNION ALL
SELECT 'blog' AS type, id, title, search_vector
FROM blog_posts
UNION ALL
SELECT 'product' AS type, id, name AS title, search_vector
FROM products;

-- Create view for unified search
CREATE VIEW searchable_content AS
SELECT 'article' AS type, id, title, search_vector, created_at FROM articles
UNION ALL
SELECT 'blog' AS type, id, title, search_vector, created_at FROM blog_posts;

-- Search across all content
SELECT * FROM searchable_content
WHERE search_vector @@ to_tsquery('english', 'postgresql')
ORDER BY created_at DESC;
```

### Autocomplete with Prefix Search
```sql
-- Create index for prefix matching
CREATE INDEX idx_articles_title_prefix ON articles(title text_pattern_ops);

-- Autocomplete query
SELECT DISTINCT title
FROM articles
WHERE title ILIKE 'postgre%'
LIMIT 10;

-- Or use trigram index for fuzzy autocomplete
SELECT title, similarity(title, 'postgre') AS sim
FROM articles
WHERE title % 'postgre'
ORDER BY sim DESC
LIMIT 10;
```

### Faceted Search
```sql
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name TEXT,
    category TEXT,
    brand TEXT,
    price NUMERIC,
    search_vector tsvector GENERATED ALWAYS AS (
        to_tsvector('english', name)
    ) STORED
);

-- Search with facets
SELECT
    p.*,
    COUNT(*) OVER (PARTITION BY category) AS category_count,
    COUNT(*) OVER (PARTITION BY brand) AS brand_count
FROM products p
WHERE search_vector @@ to_tsquery('english', 'laptop')
    AND category = 'Electronics'
    AND price BETWEEN 500 AND 1500
ORDER BY ts_rank(search_vector, to_tsquery('english', 'laptop')) DESC;
```

### Search Suggestions (Did You Mean?)
```sql
-- Find closest matching terms
SELECT word, similarity(word, 'postgrsql') AS sim
FROM (
    SELECT DISTINCT unnest(string_to_array(content, ' ')) AS word
    FROM articles
) AS words
WHERE word % 'postgrsql'
ORDER BY sim DESC
LIMIT 5;
```

## SQLAlchemy Full-Text Search

```python
from sqlalchemy import Column, Integer, String, Text, Index
from sqlalchemy.dialects.postgresql import TSVECTOR
from sqlalchemy import func

class Article(Base):
    __tablename__ = 'articles'

    id = Column(Integer, primary_key=True)
    title = Column(String(255))
    content = Column(Text)
    search_vector = Column(
        TSVECTOR,
        Computed(
            "to_tsvector('english', coalesce(title, '') || ' ' || coalesce(content, ''))"
        )
    )

    __table_args__ = (
        Index('idx_articles_search', 'search_vector', postgresql_using='gin'),
    )

# Search
from sqlalchemy.dialects.postgresql import TSVECTOR

query = session.query(Article).filter(
    Article.search_vector.op('@@')(
        func.to_tsquery('english', 'postgresql & performance')
    )
)

# With ranking
from sqlalchemy import desc

query = session.query(
    Article,
    func.ts_rank(
        Article.search_vector,
        func.to_tsquery('english', 'postgresql')
    ).label('rank')
).filter(
    Article.search_vector.op('@@')(
        func.to_tsquery('english', 'postgresql')
    )
).order_by(desc('rank'))

# Using websearch_to_tsquery for user input
user_query = "postgresql performance"
query = session.query(Article).filter(
    Article.search_vector.op('@@')(
        func.websearch_to_tsquery('english', user_query)
    )
)

# Highlighting
query = session.query(
    Article.id,
    Article.title,
    func.ts_headline(
        'english',
        Article.content,
        func.to_tsquery('english', 'postgresql'),
        'MaxWords=50, MinWords=20'
    ).label('snippet')
).filter(
    Article.search_vector.op('@@')(
        func.to_tsquery('english', 'postgresql')
    )
)
```

## Monitoring and Debugging

### Explain Full-Text Queries
```sql
EXPLAIN ANALYZE
SELECT * FROM articles
WHERE search_vector @@ to_tsquery('english', 'postgresql');

-- Should show: Bitmap Index Scan using idx_articles_search_gin
```

### Check Index Usage
```sql
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE indexrelname LIKE '%search%'
ORDER BY idx_scan DESC;
```

### Analyze Search Performance
```sql
-- Find most common search terms (requires logging)
-- Enable in postgresql.conf: log_min_duration_statement = 0

-- Check tsvector size
SELECT
    id,
    pg_column_size(search_vector) AS vector_size
FROM articles
ORDER BY vector_size DESC
LIMIT 10;
```
