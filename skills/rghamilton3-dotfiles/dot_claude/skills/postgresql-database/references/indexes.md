# PostgreSQL Index Strategies

## Index Types

### B-Tree Index (Default)
Best for: Equality and range queries on sortable data

```sql
-- Create B-tree index (default type)
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);

-- Composite B-tree index
CREATE INDEX idx_posts_user_date ON posts(user_id, created_at);

-- Unique B-tree index
CREATE UNIQUE INDEX idx_users_username ON users(username);

-- Use cases:
SELECT * FROM users WHERE email = 'user@example.com';  -- Equality
SELECT * FROM posts WHERE created_at > '2024-01-01';   -- Range
SELECT * FROM posts WHERE created_at BETWEEN '2024-01-01' AND '2024-12-31';  -- Range
```

**When to use:**
- Equality comparisons (`=`, `IN`)
- Range queries (`<`, `<=`, `>`, `>=`, `BETWEEN`)
- Sorting operations (`ORDER BY`)
- Prefix matching (`LIKE 'prefix%'`)

**Index structure:**
```
B-tree maintains sorted order:
        [M]
       /   \
    [D-L] [N-Z]
   /  |  \
[A-C][E-G][H-L]
```

### Hash Index
Best for: Simple equality comparisons (PostgreSQL 10+)

```sql
-- Create hash index
CREATE INDEX idx_users_email_hash ON users USING hash(email);

-- Use case:
SELECT * FROM users WHERE email = 'user@example.com';  -- Equality only
```

**When to use:**
- Only equality comparisons (`=`)
- Smaller index size than B-tree
- Faster for exact matches (PostgreSQL 10+)

**When NOT to use:**
- Range queries
- Sorting
- Prefix matching
- PostgreSQL < 10 (not WAL-logged)

### GiST (Generalized Search Tree)
Best for: Geometric data, full-text search, range types

```sql
-- Install required extension
CREATE EXTENSION btree_gist;

-- Geometric data
CREATE INDEX idx_locations_position ON locations USING gist(position);

-- Range types
CREATE TABLE reservations (
    id SERIAL PRIMARY KEY,
    room_id INTEGER,
    period daterange
);

CREATE INDEX idx_reservations_period ON reservations USING gist(period);

-- Use cases:
SELECT * FROM reservations WHERE period && '[2024-01-01, 2024-01-07]'::daterange;

-- Prevent overlapping ranges
ALTER TABLE reservations
ADD CONSTRAINT no_overlapping_reservations
EXCLUDE USING gist (room_id WITH =, period WITH &&);

-- Full-text search
CREATE INDEX idx_documents_content_gist ON documents USING gist(to_tsvector('english', content));
```

**When to use:**
- Geometric/geographic data (PostGIS)
- Range types (daterange, int4range, etc.)
- Full-text search (less efficient than GIN)
- Custom data types with GiST support

### GIN (Generalized Inverted Index)
Best for: Full-text search, JSONB, arrays

```sql
-- Array columns
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    tags TEXT[]
);

CREATE INDEX idx_posts_tags ON posts USING gin(tags);

SELECT * FROM posts WHERE tags @> ARRAY['postgresql'];  -- Contains
SELECT * FROM posts WHERE tags && ARRAY['database', 'sql'];  -- Overlap

-- JSONB columns
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    attributes JSONB
);

CREATE INDEX idx_products_attributes ON products USING gin(attributes);

SELECT * FROM products WHERE attributes @> '{"color": "red"}';
SELECT * FROM products WHERE attributes ? 'size';  -- Has key

-- Full-text search
CREATE INDEX idx_articles_content_fts ON articles USING gin(to_tsvector('english', content));

SELECT * FROM articles WHERE to_tsvector('english', content) @@ to_tsquery('postgresql & performance');

-- Trigram search (fuzzy matching)
CREATE EXTENSION pg_trgm;
CREATE INDEX idx_users_name_trgm ON users USING gin(name gin_trgm_ops);

SELECT * FROM users WHERE name ILIKE '%john%';  -- Can use trigram index
SELECT * FROM users WHERE name % 'jon';  -- Similarity search
```

**When to use:**
- Full-text search
- JSONB queries
- Array containment/overlap
- Trigram similarity search

**GIN vs GiST for full-text:**
- GIN: Faster search, slower updates, larger index
- GiST: Slower search, faster updates, smaller index

### BRIN (Block Range Index)
Best for: Very large tables with natural clustering

```sql
-- Create BRIN index
CREATE INDEX idx_logs_created_at_brin ON logs USING brin(created_at);

-- Use case: Time-series data
SELECT * FROM logs WHERE created_at > '2024-01-01';
```

**When to use:**
- Very large tables (hundreds of GB+)
- Data naturally ordered (time-series, monotonic IDs)
- Read-mostly workloads
- When index size matters more than query speed

**Advantages:**
- Extremely small index size
- Fast creation and maintenance

**Disadvantages:**
- Less precise than B-tree (scans more blocks)
- Only effective with clustered data

### SP-GiST (Space-Partitioned GiST)
Best for: Non-balanced data structures (quadtrees, radix trees)

```sql
-- Text with prefix search
CREATE INDEX idx_urls_path_spgist ON urls USING spgist(path);

-- IP addresses
CREATE INDEX idx_logs_ip_spgist ON logs USING spgist(ip_address inet_ops);
```

**When to use:**
- Prefix searching on text
- IP address ranges
- Phone numbers
- Geometric data with clustering

## Composite Indexes

### Column Order Matters
```sql
-- Index on (user_id, created_at)
CREATE INDEX idx_posts_user_date ON posts(user_id, created_at);

-- Can be used for:
SELECT * FROM posts WHERE user_id = 1;  -- ✓ Uses first column
SELECT * FROM posts WHERE user_id = 1 AND created_at > '2024-01-01';  -- ✓ Uses both
SELECT * FROM posts WHERE user_id = 1 ORDER BY created_at;  -- ✓ Uses both

-- Cannot efficiently use for:
SELECT * FROM posts WHERE created_at > '2024-01-01';  -- ✗ Doesn't use first column
```

**Rule of thumb:** Put equality columns before range columns
```sql
-- Better ordering for mixed queries
CREATE INDEX idx_posts_user_date ON posts(user_id, created_at);

-- For queries like:
SELECT * FROM posts WHERE user_id = 1 AND created_at > '2024-01-01';
```

### When to Use Multiple Indexes vs Composite
```sql
-- Separate indexes
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_created_at ON posts(created_at);

-- Good for queries that use only one column:
SELECT * FROM posts WHERE user_id = 1;
SELECT * FROM posts WHERE created_at > '2024-01-01';

-- Composite index
CREATE INDEX idx_posts_user_date ON posts(user_id, created_at);

-- Better for queries that use both columns:
SELECT * FROM posts WHERE user_id = 1 AND created_at > '2024-01-01';
SELECT * FROM posts WHERE user_id = 1 ORDER BY created_at;
```

## Partial Indexes

### Index Only Relevant Rows
```sql
-- Index only active users
CREATE INDEX idx_active_users ON users(email) WHERE is_active = true;

-- Query must match the WHERE condition
SELECT * FROM users WHERE email = 'user@example.com' AND is_active = true;

-- More examples
CREATE INDEX idx_pending_orders ON orders(created_at)
WHERE status = 'pending';

CREATE INDEX idx_recent_posts ON posts(id)
WHERE created_at > NOW() - INTERVAL '30 days';

CREATE INDEX idx_non_null_phone ON users(phone)
WHERE phone IS NOT NULL;
```

**Benefits:**
- Smaller index size
- Faster index maintenance
- Better cache utilization

### Unique Partial Indexes for Conditional Uniqueness
```sql
-- Allow multiple soft-deleted records with same email,
-- but only one active record per email
CREATE UNIQUE INDEX idx_users_email_active
ON users(email)
WHERE deleted_at IS NULL;

-- Allow only one primary address per user
CREATE UNIQUE INDEX idx_user_primary_address
ON addresses(user_id)
WHERE is_primary = true;
```

## Expression Indexes

### Index on Computed Values
```sql
-- Case-insensitive search
CREATE INDEX idx_users_email_lower ON users(LOWER(email));

SELECT * FROM users WHERE LOWER(email) = 'user@example.com';

-- Full name search
CREATE INDEX idx_users_full_name ON users((first_name || ' ' || last_name));

SELECT * FROM users WHERE first_name || ' ' || last_name = 'John Doe';

-- Date part extraction
CREATE INDEX idx_posts_year ON posts(EXTRACT(YEAR FROM created_at));

SELECT * FROM posts WHERE EXTRACT(YEAR FROM created_at) = 2024;

-- JSONB field
CREATE INDEX idx_products_price ON products((attributes->>'price')::numeric);

SELECT * FROM products WHERE (attributes->>'price')::numeric > 100;
```

**Important:** Query must use exact same expression!

## Covering Indexes (INCLUDE)

### Include Non-Key Columns (PostgreSQL 11+)
```sql
-- Traditional index
CREATE INDEX idx_users_email ON users(email);

-- Query requires table lookup for name
SELECT email, name FROM users WHERE email = 'user@example.com';

-- Covering index with INCLUDE
CREATE INDEX idx_users_email_covering ON users(email) INCLUDE (name, created_at);

-- Now query can use index-only scan (faster!)
SELECT email, name, created_at FROM users WHERE email = 'user@example.com';
```

**Benefits:**
- Index-only scans (no heap access)
- Included columns don't affect index order
- Can include columns that aren't B-tree indexable

**Use cases:**
```sql
-- Lookup table with frequently accessed columns
CREATE INDEX idx_products_sku_covering ON products(sku)
INCLUDE (name, price, stock_quantity);

-- Foreign key with denormalized data
CREATE INDEX idx_orders_user_covering ON orders(user_id)
INCLUDE (created_at, total_amount, status);
```

## Index Maintenance

### Monitor Index Usage
```sql
-- Find unused indexes
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND indexrelname NOT LIKE 'pg_toast%'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Find duplicate indexes
SELECT
    indrelid::regclass AS table_name,
    array_agg(indexrelid::regclass) AS indexes
FROM pg_index
GROUP BY indrelid, indkey
HAVING COUNT(*) > 1;

-- Index size
SELECT
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Rebuild Indexes
```sql
-- Rebuild single index (locks table)
REINDEX INDEX idx_users_email;

-- Rebuild all indexes on table (locks table)
REINDEX TABLE users;

-- Rebuild concurrently (PostgreSQL 12+, no locks)
REINDEX INDEX CONCURRENTLY idx_users_email;

-- Drop and recreate to rename
DROP INDEX CONCURRENTLY idx_old_name;
CREATE INDEX CONCURRENTLY idx_new_name ON users(email);
```

### Analyze Tables After Index Creation
```sql
-- Update statistics after creating index
CREATE INDEX idx_users_email ON users(email);
ANALYZE users;
```

## Index Best Practices

### 1. Don't Over-Index
```sql
-- Too many indexes slow down writes
-- Each index adds overhead to INSERT/UPDATE/DELETE

-- Bad: Index every column
CREATE INDEX idx_users_id ON users(id);  -- Unnecessary (primary key)
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_users_updated_at ON users(updated_at);
CREATE INDEX idx_users_last_login ON users(last_login);

-- Good: Index only queried columns
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
```

### 2. Create Indexes Concurrently in Production
```sql
-- Bad: Locks table during index creation
CREATE INDEX idx_users_email ON users(email);

-- Good: Creates index without blocking writes
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);
```

### 3. Consider Write Performance Trade-off
```sql
-- More indexes = slower writes, faster reads
-- Evaluate based on your workload:

-- Read-heavy: More indexes acceptable
-- Write-heavy: Fewer indexes, focus on most important queries
```

### 4. Use Appropriate Index Type
```sql
-- Don't use hash for range queries
-- Bad
CREATE INDEX idx_users_age_hash ON users USING hash(age);
SELECT * FROM users WHERE age > 18;  -- Can't use hash index

-- Good
CREATE INDEX idx_users_age ON users(age);
SELECT * FROM users WHERE age > 18;  -- Uses B-tree index
```

### 5. Monitor and Remove Unused Indexes
```sql
-- Check index usage regularly
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan AS scans,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan < 10  -- Adjust threshold
    AND indexrelname !~ '^pg_toast'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Remove unused index
DROP INDEX CONCURRENTLY idx_unused;
```

## Advanced Index Strategies

### Multi-Column Statistics
```sql
-- Create extended statistics for correlated columns
CREATE STATISTICS stats_users_location
ON city, state
FROM users;

ANALYZE users;

-- Helps planner estimate selectivity for:
SELECT * FROM users WHERE city = 'New York' AND state = 'NY';
```

### Conditional Unique Indexes
```sql
-- Ensure email is unique only for active users
CREATE UNIQUE INDEX idx_active_users_email
ON users(email)
WHERE deleted_at IS NULL;
```

### Index on Foreign Keys
```sql
-- Always index foreign key columns for JOIN performance
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    category_id INTEGER REFERENCES categories(id)
);

CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_category_id ON posts(category_id);

-- Speeds up:
-- - JOINs
-- - CASCADE deletes
-- - Foreign key checks
```

### Indexes for Sorting
```sql
-- Index in DESC order for DESC queries
CREATE INDEX idx_posts_created_desc ON posts(created_at DESC);

SELECT * FROM posts ORDER BY created_at DESC LIMIT 10;

-- Multi-column with mixed order
CREATE INDEX idx_posts_user_date_desc ON posts(user_id ASC, created_at DESC);

SELECT * FROM posts
WHERE user_id = 1
ORDER BY created_at DESC
LIMIT 10;
```

### Bloom Filters (PostgreSQL 9.6+)
```sql
-- Efficient for queries with many equality conditions
CREATE EXTENSION bloom;

CREATE INDEX idx_products_bloom ON products
USING bloom (color, size, material, brand)
WITH (length=80, col1=2, col2=2, col3=2, col4=2);

-- Efficient for:
SELECT * FROM products
WHERE color = 'red' AND size = 'large' AND material = 'cotton';
```

## SQLAlchemy Index Creation

```python
from sqlalchemy import Index, text

class User(Base):
    __tablename__ = 'users'

    id = Column(Integer, primary_key=True)
    email = Column(String(255))
    username = Column(String(50))
    is_active = Column(Boolean)
    created_at = Column(DateTime)

    # Simple index
    __table_args__ = (
        Index('idx_users_email', 'email'),
        Index('idx_users_username', 'username', unique=True),
    )

# Composite index
Index('idx_posts_user_date', Post.user_id, Post.created_at)

# Partial index
Index('idx_active_users', User.email,
      postgresql_where=User.is_active == True)

# Expression index
Index('idx_users_email_lower', func.lower(User.email))

# GIN index for JSONB
Index('idx_products_attrs', Product.attributes,
      postgresql_using='gin')

# Covering index with INCLUDE
Index('idx_users_email_covering', User.email,
      postgresql_include=['username', 'created_at'])

# Create index concurrently (use raw SQL)
session.execute(text(
    'CREATE INDEX CONCURRENTLY idx_users_email ON users(email)'
))
```
