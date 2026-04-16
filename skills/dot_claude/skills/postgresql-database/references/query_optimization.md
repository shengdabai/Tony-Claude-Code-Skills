# Query Optimization Techniques

## Understanding EXPLAIN and EXPLAIN ANALYZE

### Basic EXPLAIN
```sql
EXPLAIN SELECT * FROM users WHERE email = 'user@example.com';

-- Output shows query plan without execution
-- Seq Scan on users  (cost=0.00..15.50 rows=1 width=100)
--   Filter: (email = 'user@example.com'::text)
```

### EXPLAIN ANALYZE (Actually Executes Query)
```sql
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'user@example.com';

-- Shows actual execution time and row counts
-- Index Scan using users_email_idx on users  (cost=0.15..8.17 rows=1 width=100) (actual time=0.025..0.026 rows=1 loops=1)
--   Index Cond: (email = 'user@example.com'::text)
-- Planning Time: 0.123 ms
-- Execution Time: 0.051 ms
```

### Advanced EXPLAIN Options
```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) SELECT * FROM users WHERE email = 'user@example.com';

-- ANALYZE: Execute and show actual times
-- BUFFERS: Show buffer usage (cache hits/misses)
-- VERBOSE: Show detailed column information
-- FORMAT JSON: Output as JSON for programmatic analysis
```

## Scan Types (From Fastest to Slowest)

### 1. Index-Only Scan (Fastest)
```sql
-- Query uses only indexed columns
CREATE INDEX idx_users_email ON users(email);

SELECT email FROM users WHERE email = 'user@example.com';
-- Index Only Scan using idx_users_email
```

### 2. Index Scan
```sql
-- Uses index to find rows, then fetches from table
CREATE INDEX idx_users_email ON users(email);

SELECT * FROM users WHERE email = 'user@example.com';
-- Index Scan using idx_users_email
```

### 3. Bitmap Index Scan
```sql
-- Combines multiple index scans
CREATE INDEX idx_users_age ON users(age);
CREATE INDEX idx_users_city ON users(city);

SELECT * FROM users WHERE age > 25 AND city = 'New York';
-- Bitmap Heap Scan on users
--   Recheck Cond: ((age > 25) AND (city = 'New York'))
--   ->  BitmapAnd
--         ->  Bitmap Index Scan on idx_users_age
--         ->  Bitmap Index Scan on idx_users_city
```

### 4. Sequential Scan (Slowest for Large Tables)
```sql
-- Reads entire table
SELECT * FROM users WHERE some_unindexed_column = 'value';
-- Seq Scan on users
```

## N+1 Query Problem

### Problem Example (SQLAlchemy)
```python
# BAD: N+1 queries
users = session.query(User).all()  # 1 query
for user in users:
    print(user.posts)  # N queries (one per user)
```

### Solution 1: Eager Loading with joinedload
```python
from sqlalchemy.orm import joinedload

# GOOD: 1 query with JOIN
users = session.query(User).options(
    joinedload(User.posts)
).all()

for user in users:
    print(user.posts)  # No additional queries
```

### Solution 2: Subquery Loading
```python
from sqlalchemy.orm import subqueryload

# GOOD: 2 queries total (better for one-to-many with many items)
users = session.query(User).options(
    subqueryload(User.posts)
).all()
```

### Solution 3: Selectin Loading (SQLAlchemy 1.2+)
```python
from sqlalchemy.orm import selectinload

# GOOD: 2 queries with IN clause (most efficient)
users = session.query(User).options(
    selectinload(User.posts)
).all()
```

## Join Optimization

### Inner Join vs Left Join
```sql
-- Inner join - only matching rows
SELECT u.name, p.title
FROM users u
INNER JOIN posts p ON u.id = p.user_id;

-- Left join - all users even without posts
SELECT u.name, p.title
FROM users u
LEFT JOIN posts p ON u.id = p.user_id;
```

### Join Order Matters
```sql
-- PostgreSQL query planner usually optimizes this,
-- but explicit order can help with complex queries

-- Better: Start with smaller table
SELECT *
FROM small_table s
JOIN large_table l ON s.id = l.small_id;

-- Can be slower: Start with larger table
SELECT *
FROM large_table l
JOIN small_table s ON l.small_id = s.id;
```

### Using LATERAL Joins for Correlated Subqueries
```sql
-- Traditional correlated subquery (can be slow)
SELECT u.*, (
    SELECT COUNT(*)
    FROM posts p
    WHERE p.user_id = u.id
) AS post_count
FROM users u;

-- Better: LATERAL join
SELECT u.*, p.post_count
FROM users u
CROSS JOIN LATERAL (
    SELECT COUNT(*) AS post_count
    FROM posts
    WHERE user_id = u.id
) p;
```

## Pagination Optimization

### Bad: OFFSET with Large Numbers
```sql
-- SLOW: Must scan and skip 1,000,000 rows
SELECT * FROM posts
ORDER BY id
LIMIT 10 OFFSET 1000000;
```

### Good: Keyset Pagination (Seek Method)
```sql
-- FAST: Uses index to find starting point
SELECT * FROM posts
WHERE id > 1000000
ORDER BY id
LIMIT 10;

-- For complex sorting
SELECT * FROM posts
WHERE (created_at, id) > ('2024-01-01', 12345)
ORDER BY created_at, id
LIMIT 10;
```

### SQLAlchemy Keyset Pagination
```python
from sqlalchemy import and_

def get_page(last_id=None, limit=10):
    query = session.query(Post).order_by(Post.id)

    if last_id:
        query = query.filter(Post.id > last_id)

    return query.limit(limit).all()

# Usage
page1 = get_page(limit=10)
page2 = get_page(last_id=page1[-1].id, limit=10)
```

## Aggregation Optimization

### Use Appropriate Aggregates
```sql
-- Fast: COUNT(*)
SELECT COUNT(*) FROM users;

-- Slower: COUNT(column) - skips NULL values
SELECT COUNT(email) FROM users;

-- Approximate count for huge tables (PostgreSQL 9.2+)
SELECT reltuples::bigint AS estimate
FROM pg_class
WHERE relname = 'users';
```

### Partial Aggregates
```sql
-- Instead of counting all rows
SELECT COUNT(*) FROM posts WHERE status = 'published';

-- Use a filtered index and index-only scan
CREATE INDEX idx_posts_published ON posts(id) WHERE status = 'published';

-- Query can use index-only scan
SELECT COUNT(*) FROM posts WHERE status = 'published';
```

### Group By Optimization
```sql
-- Ensure columns in GROUP BY are indexed
CREATE INDEX idx_posts_user_id ON posts(user_id);

SELECT user_id, COUNT(*)
FROM posts
GROUP BY user_id;
-- Uses index for grouping
```

## Subquery Optimization

### EXISTS vs IN
```sql
-- EXISTS: Stops at first match (better for large datasets)
SELECT * FROM users u
WHERE EXISTS (
    SELECT 1 FROM posts p
    WHERE p.user_id = u.id
);

-- IN: Must complete subquery (better for small datasets)
SELECT * FROM users
WHERE id IN (SELECT user_id FROM posts);

-- Modern PostgreSQL often optimizes these similarly
```

### WITH Queries (CTEs)
```sql
-- Materialized CTE (PostgreSQL 12+)
WITH popular_posts AS MATERIALIZED (
    SELECT user_id, COUNT(*) as post_count
    FROM posts
    WHERE created_at > NOW() - INTERVAL '30 days'
    GROUP BY user_id
    HAVING COUNT(*) > 10
)
SELECT u.*, p.post_count
FROM users u
JOIN popular_posts p ON u.id = p.user_id;

-- Non-materialized CTE (inlined into main query)
WITH popular_posts AS NOT MATERIALIZED (
    SELECT user_id, COUNT(*) as post_count
    FROM posts
    WHERE created_at > NOW() - INTERVAL '30 days'
    GROUP BY user_id
    HAVING COUNT(*) > 10
)
SELECT u.*, p.post_count
FROM users u
JOIN popular_posts p ON u.id = p.user_id;
```

## Batch Operations

### Bulk Insert
```python
# BAD: Individual inserts
for i in range(1000):
    session.add(User(username=f"user{i}"))
    session.commit()  # 1000 commits!

# GOOD: Bulk insert with one commit
users = [User(username=f"user{i}") for i in range(1000)]
session.bulk_save_objects(users)
session.commit()  # 1 commit

# BETTER: Use COPY for very large datasets
from sqlalchemy import text

session.execute(text("""
    COPY users (username, email)
    FROM STDIN
    WITH CSV
"""))
```

### Bulk Update
```python
# BAD: Update one by one
for user in users:
    user.is_active = False
    session.commit()

# GOOD: Bulk update
session.query(User).filter(
    User.last_login < datetime.now() - timedelta(days=365)
).update({'is_active': False})
session.commit()

# Or using bulk_update_mappings
session.bulk_update_mappings(
    User,
    [{'id': 1, 'is_active': False}, {'id': 2, 'is_active': False}]
)
session.commit()
```

## Query Hints and Configuration

### Work Memory Configuration
```sql
-- Increase work_mem for complex sorts/aggregations
SET work_mem = '256MB';

SELECT user_id, COUNT(*)
FROM posts
GROUP BY user_id
ORDER BY COUNT(*) DESC;

-- Reset to default
RESET work_mem;
```

### Parallel Queries
```sql
-- Enable parallel workers for large queries
SET max_parallel_workers_per_gather = 4;

EXPLAIN ANALYZE SELECT COUNT(*) FROM large_table;
-- Shows: Gather (workers: 4)
```

### Join Collapse Limit
```sql
-- For queries with many joins
SET join_collapse_limit = 12;  -- Default is 8
```

## Avoiding Common Anti-Patterns

### Wildcard at Start of LIKE
```sql
-- BAD: Can't use index
SELECT * FROM users WHERE email LIKE '%@example.com';

-- GOOD: Index can be used
SELECT * FROM users WHERE email LIKE 'john%';

-- For suffix search, use trigram index
CREATE INDEX idx_users_email_trgm ON users USING gin(email gin_trgm_ops);
SELECT * FROM users WHERE email LIKE '%@example.com';
```

### Functions on Indexed Columns
```sql
-- BAD: Function prevents index use
SELECT * FROM users WHERE LOWER(email) = 'user@example.com';

-- GOOD: Functional index
CREATE INDEX idx_users_email_lower ON users(LOWER(email));
SELECT * FROM users WHERE LOWER(email) = 'user@example.com';

-- BETTER: Store normalized data
UPDATE users SET email = LOWER(email);
CREATE INDEX idx_users_email ON users(email);
SELECT * FROM users WHERE email = 'user@example.com';
```

### OR Conditions
```sql
-- BAD: Can't efficiently use indexes
SELECT * FROM posts WHERE user_id = 1 OR status = 'published';

-- GOOD: Use UNION
SELECT * FROM posts WHERE user_id = 1
UNION
SELECT * FROM posts WHERE status = 'published';

-- Or restructure query
SELECT * FROM posts WHERE user_id = 1
UNION ALL
SELECT * FROM posts WHERE status = 'published' AND user_id != 1;
```

### SELECT *
```sql
-- BAD: Fetches unnecessary data
SELECT * FROM users WHERE id = 1;

-- GOOD: Select only needed columns
SELECT id, username, email FROM users WHERE id = 1;

-- Enables covering index (index-only scan)
CREATE INDEX idx_users_id_username_email ON users(id, username, email);
```

## Monitoring Slow Queries

### Enable Slow Query Logging
```sql
-- In postgresql.conf
log_min_duration_statement = 1000  -- Log queries taking > 1 second

-- Or set for current session
SET log_min_duration_statement = 1000;
```

### Find Slow Queries with pg_stat_statements
```sql
-- Enable extension
CREATE EXTENSION pg_stat_statements;

-- Find slowest queries
SELECT
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Reset statistics
SELECT pg_stat_statements_reset();
```

### SQLAlchemy Query Profiling
```python
from sqlalchemy import event
from sqlalchemy.engine import Engine
import time
import logging

logging.basicConfig()
logger = logging.getLogger("sqlalchemy.engine")
logger.setLevel(logging.INFO)

@event.listens_for(Engine, "before_cursor_execute")
def before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    conn.info.setdefault('query_start_time', []).append(time.time())

@event.listens_for(Engine, "after_cursor_execute")
def after_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    total = time.time() - conn.info['query_start_time'].pop(-1)
    logger.info(f"Query took: {total:.3f}s")
    logger.info(f"Statement: {statement}")
```

## Advanced Optimization Techniques

### Partial Indexes
```sql
-- Index only active users
CREATE INDEX idx_active_users ON users(id) WHERE is_active = true;

-- Index only recent posts
CREATE INDEX idx_recent_posts ON posts(created_at)
WHERE created_at > NOW() - INTERVAL '30 days';
```

### Expression Indexes
```sql
-- Index on computed value
CREATE INDEX idx_users_full_name ON users((first_name || ' ' || last_name));

SELECT * FROM users WHERE first_name || ' ' || last_name = 'John Doe';
```

### Covering Indexes
```sql
-- Include non-key columns in index for index-only scans
CREATE INDEX idx_users_email_covering ON users(email)
INCLUDE (username, created_at);

SELECT username, created_at FROM users WHERE email = 'user@example.com';
-- Uses index-only scan
```

### Denormalization for Read Performance
```sql
-- Add redundant column to avoid JOIN
ALTER TABLE posts ADD COLUMN author_name VARCHAR(100);

UPDATE posts p
SET author_name = u.name
FROM users u
WHERE p.user_id = u.id;

-- Now can query without JOIN
SELECT title, author_name FROM posts WHERE id = 1;
-- Instead of: SELECT p.title, u.name FROM posts p JOIN users u ON p.user_id = u.id
```
