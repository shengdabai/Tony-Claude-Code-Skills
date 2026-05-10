# JSONB Usage for Flexible Data

## JSONB vs JSON

**Always use JSONB unless you need to preserve exact JSON formatting:**

```sql
-- JSON: Stores exact text, slower processing
CREATE TABLE logs_json (
    id SERIAL PRIMARY KEY,
    data JSON
);

-- JSONB: Binary format, faster, supports indexing
CREATE TABLE logs (
    id SERIAL PRIMARY KEY,
    data JSONB
);
```

**JSONB advantages:**
- Faster processing (no reparsing)
- Supports indexing
- Removes duplicate keys
- Removes whitespace

**JSON advantages:**
- Preserves exact formatting
- Preserves key order
- Preserves duplicate keys
- Slightly faster insertion

## Basic JSONB Operations

### Creating and Inserting JSONB Data
```sql
-- Create table with JSONB column
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    attributes JSONB
);

-- Insert JSONB data
INSERT INTO products (name, attributes) VALUES
    ('T-Shirt', '{"color": "red", "size": "large", "material": "cotton"}'),
    ('Laptop', '{"brand": "Dell", "ram": 16, "storage": 512}'),
    ('Book', '{"author": "Tolkien", "pages": 1178, "isbn": "978-0618260584"}');

-- Insert NULL
INSERT INTO products (name, attributes) VALUES ('Item', NULL);

-- Insert empty JSONB
INSERT INTO products (name, attributes) VALUES ('Item', '{}');
```

### Accessing JSONB Fields
```sql
-- Get field value as JSONB
SELECT attributes -> 'color' FROM products;  -- Returns: "red"

-- Get field value as text
SELECT attributes ->> 'color' FROM products;  -- Returns: red

-- Nested access
INSERT INTO products (name, attributes) VALUES
    ('Laptop', '{"specs": {"cpu": "Intel i7", "ram": 16}}');

SELECT
    attributes -> 'specs' -> 'cpu' AS cpu_jsonb,    -- "Intel i7"
    attributes -> 'specs' ->> 'cpu' AS cpu_text,    -- Intel i7
    attributes #> '{specs, cpu}' AS cpu_path_jsonb, -- "Intel i7"
    attributes #>> '{specs, cpu}' AS cpu_path_text  -- Intel i7
FROM products;
```

### Operators Reference
```sql
-- -> Get JSON object field (returns JSONB)
SELECT data -> 'name' FROM table;

-- ->> Get JSON object field (returns text)
SELECT data ->> 'name' FROM table;

-- #> Get JSON object at specified path (returns JSONB)
SELECT data #> '{address, city}' FROM table;

-- #>> Get JSON object at specified path (returns text)
SELECT data #>> '{address, city}' FROM table;

-- @> Contains
SELECT * FROM table WHERE data @> '{"status": "active"}';

-- <@ Is contained by
SELECT * FROM table WHERE '{"status": "active"}' <@ data;

-- ? Key exists
SELECT * FROM table WHERE data ? 'email';

-- ?| Any key exists
SELECT * FROM table WHERE data ?| array['email', 'phone'];

-- ?& All keys exist
SELECT * FROM table WHERE data ?& array['email', 'phone'];

-- || Concatenate
SELECT '{"a": 1}'::jsonb || '{"b": 2}'::jsonb;  -- {"a": 1, "b": 2}

-- - Delete key
SELECT '{"a": 1, "b": 2}'::jsonb - 'a';  -- {"b": 2}

-- #- Delete at path
SELECT '{"a": {"b": 2}}'::jsonb #- '{a, b}';  -- {"a": {}}
```

## Querying JSONB Data

### Equality and Containment
```sql
-- Exact match
SELECT * FROM products WHERE attributes = '{"color": "red"}';

-- Contains (right side is subset of left)
SELECT * FROM products WHERE attributes @> '{"color": "red"}';

-- Is contained by (left side is subset of right)
SELECT * FROM products WHERE '{"color": "red"}' <@ attributes;

-- Check if key exists
SELECT * FROM products WHERE attributes ? 'color';

-- Check if any key exists
SELECT * FROM products WHERE attributes ?| array['color', 'size'];

-- Check if all keys exist
SELECT * FROM products WHERE attributes ?& array['color', 'size'];
```

### Filtering by Nested Values
```sql
-- Simple nested field
SELECT * FROM products
WHERE attributes -> 'specs' ->> 'ram' = '16';

-- Numeric comparison (cast to numeric)
SELECT * FROM products
WHERE (attributes -> 'specs' ->> 'ram')::int >= 16;

-- Deep nesting
SELECT * FROM products
WHERE attributes #>> '{specs, cpu, cores}' = '8';

-- Array containment
INSERT INTO products (name, attributes) VALUES
    ('Phone', '{"features": ["wifi", "bluetooth", "5g"]}');

SELECT * FROM products
WHERE attributes -> 'features' @> '"wifi"';  -- Contains "wifi"
```

### Working with JSONB Arrays
```sql
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    title TEXT,
    tags JSONB  -- Array of strings
);

INSERT INTO posts (title, tags) VALUES
    ('PostgreSQL Tips', '["database", "postgresql", "sql"]'),
    ('Python Tutorial', '["python", "programming"]');

-- Check if array contains value
SELECT * FROM posts WHERE tags @> '"postgresql"';

-- Get array length
SELECT title, jsonb_array_length(tags) AS tag_count FROM posts;

-- Expand array elements
SELECT title, jsonb_array_elements_text(tags) AS tag
FROM posts;

-- Array element by index
SELECT tags -> 0 FROM posts;  -- First element (JSONB)
SELECT tags ->> 0 FROM posts;  -- First element (text)
```

## Modifying JSONB Data

### Update JSONB Fields
```sql
-- Set/update a field
UPDATE products
SET attributes = jsonb_set(attributes, '{color}', '"blue"')
WHERE id = 1;

-- Set nested field
UPDATE products
SET attributes = jsonb_set(
    attributes,
    '{specs, ram}',
    '32',
    true  -- create_missing: create path if doesn't exist
)
WHERE id = 1;

-- Update multiple fields
UPDATE products
SET attributes = attributes || '{"color": "blue", "size": "medium"}'
WHERE id = 1;

-- Delete a field
UPDATE products
SET attributes = attributes - 'color'
WHERE id = 1;

-- Delete nested field
UPDATE products
SET attributes = attributes #- '{specs, ram}'
WHERE id = 1;

-- Delete multiple fields
UPDATE products
SET attributes = attributes - '{color, size}'::text[]
WHERE id = 1;
```

### Conditional Updates
```sql
-- Update only if key exists
UPDATE products
SET attributes = jsonb_set(attributes, '{color}', '"blue"')
WHERE attributes ? 'color';

-- Update or insert field
UPDATE products
SET attributes = CASE
    WHEN attributes ? 'discount'
    THEN jsonb_set(attributes, '{discount}', '0.15')
    ELSE attributes || '{"discount": 0.15}'
END
WHERE id = 1;
```

## JSONB Functions

### Construction Functions
```sql
-- Build JSONB from values
SELECT jsonb_build_object('name', 'Alice', 'age', 30);
-- {"name": "Alice", "age": 30}

-- Build JSONB array
SELECT jsonb_build_array('a', 'b', 'c');
-- ["a", "b", "c"]

-- Convert row to JSONB
SELECT row_to_json(u) FROM users u WHERE id = 1;

-- Aggregate rows to JSONB array
SELECT jsonb_agg(row_to_json(u)) FROM users u;
-- [{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}]

-- Aggregate to JSONB object
SELECT jsonb_object_agg(name, age) FROM users;
-- {"Alice": 30, "Bob": 25}
```

### Extraction Functions
```sql
-- Extract object keys
SELECT jsonb_object_keys(attributes) FROM products;

-- Extract as text
SELECT jsonb_extract_path_text(attributes, 'specs', 'cpu') FROM products;

-- Pretty-print JSONB
SELECT jsonb_pretty(attributes) FROM products;
```

### Type Checking
```sql
-- Check JSONB type
SELECT jsonb_typeof(attributes -> 'color');  -- "string"
SELECT jsonb_typeof(attributes -> 'specs');  -- "object"
SELECT jsonb_typeof(attributes -> 'tags');   -- "array"

-- Filter by type
SELECT * FROM products
WHERE jsonb_typeof(attributes -> 'price') = 'number';
```

## Indexing JSONB

### GIN Index (Most Common)
```sql
-- Index entire JSONB column
CREATE INDEX idx_products_attributes ON products USING gin(attributes);

-- Queries that use this index:
SELECT * FROM products WHERE attributes @> '{"color": "red"}';
SELECT * FROM products WHERE attributes ? 'size';
SELECT * FROM products WHERE attributes ?| array['color', 'size'];
```

### GIN Index with jsonb_path_ops
```sql
-- More efficient for @> queries, but only supports @> operator
CREATE INDEX idx_products_attributes_path ON products
USING gin(attributes jsonb_path_ops);

-- Faster containment queries
SELECT * FROM products WHERE attributes @> '{"color": "red", "size": "large"}';

-- But cannot use:
-- SELECT * FROM products WHERE attributes ? 'color';  -- Not supported
```

### Expression Index on Specific Field
```sql
-- Index specific JSONB field
CREATE INDEX idx_products_color ON products((attributes ->> 'color'));

-- Very fast for specific field queries
SELECT * FROM products WHERE attributes ->> 'color' = 'red';
```

### Partial Index on JSONB
```sql
-- Index only products with color attribute
CREATE INDEX idx_products_with_color ON products
USING gin(attributes)
WHERE attributes ? 'color';
```

## Advanced JSONB Patterns

### Schema Validation with Check Constraints
```sql
-- Ensure required fields exist
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    data JSONB,
    CONSTRAINT check_required_fields
        CHECK (data ?& array['event_type', 'timestamp'])
);

-- Validate value types
CREATE TABLE settings (
    id SERIAL PRIMARY KEY,
    config JSONB,
    CONSTRAINT check_valid_types CHECK (
        jsonb_typeof(config -> 'enabled') = 'boolean' AND
        jsonb_typeof(config -> 'max_connections') = 'number'
    )
);

-- Validate value ranges
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    attributes JSONB,
    CONSTRAINT check_price_positive CHECK (
        (attributes ->> 'price')::numeric > 0
    )
);
```

### Combining Structured and Flexible Data
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,  -- Structured
    created_at TIMESTAMP NOT NULL,        -- Structured
    profile JSONB,                        -- Flexible
    preferences JSONB                     -- Flexible
);

-- Query combining both
SELECT * FROM users
WHERE email LIKE '%@example.com'
    AND profile @> '{"country": "USA"}'
    AND preferences @> '{"notifications": true}';
```

### Merging JSONB Objects
```sql
-- Deep merge function
CREATE OR REPLACE FUNCTION jsonb_merge(left JSONB, right JSONB)
RETURNS JSONB AS $$
    SELECT jsonb_object_agg(
        key,
        CASE
            WHEN jsonb_typeof(left_value) = 'object' AND jsonb_typeof(right_value) = 'object'
            THEN jsonb_merge(left_value, right_value)
            ELSE COALESCE(right_value, left_value)
        END
    )
    FROM (
        SELECT * FROM jsonb_each(left)
        UNION ALL
        SELECT * FROM jsonb_each(right)
    ) AS t(key, left_value)
    JOIN jsonb_each(right) AS r ON t.key = r.key
$$ LANGUAGE SQL;

-- Usage
UPDATE products
SET attributes = jsonb_merge(attributes, '{"new_field": "value"}')
WHERE id = 1;
```

### Generating Unique Constraints from JSONB
```sql
-- Unique constraint on JSONB field
CREATE UNIQUE INDEX idx_users_email_unique
ON users((profile ->> 'email'))
WHERE profile ? 'email';
```

### Full-Text Search on JSONB
```sql
-- Extract text values for full-text search
CREATE INDEX idx_products_attributes_fts ON products
USING gin(to_tsvector('english', jsonb_to_text(attributes)));

-- Helper function to convert JSONB to searchable text
CREATE OR REPLACE FUNCTION jsonb_to_text(data JSONB)
RETURNS TEXT AS $$
    SELECT string_agg(value, ' ')
    FROM jsonb_each_text(data)
$$ LANGUAGE SQL IMMUTABLE;

-- Search
SELECT * FROM products
WHERE to_tsvector('english', jsonb_to_text(attributes))
    @@ to_tsquery('laptop & dell');
```

## Performance Considerations

### JSONB vs Separate Columns
```sql
-- When to use separate columns:
CREATE TABLE users_structured (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),    -- Use column: frequently queried
    last_name VARCHAR(50),     -- Use column: frequently queried
    email VARCHAR(255),        -- Use column: unique constraint needed
    age INTEGER                -- Use column: numeric operations
);

-- When to use JSONB:
CREATE TABLE users_flexible (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255),        -- Structured
    profile JSONB              -- Flexible: preferences, metadata, etc.
);

-- Hybrid approach (best of both worlds):
CREATE TABLE users_hybrid (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,  -- Frequent queries, constraints
    created_at TIMESTAMP NOT NULL,        -- Frequent filters, sorts
    profile JSONB,                        -- Flexible user data
    metadata JSONB                        -- Optional system metadata
);
```

### Avoid Deep Nesting
```sql
-- Bad: Deep nesting makes queries complex and slow
{
    "user": {
        "profile": {
            "settings": {
                "notifications": {
                    "email": true
                }
            }
        }
    }
}

-- Good: Flatter structure
{
    "email_notifications": true,
    "push_notifications": false
}
```

### Index Only What You Query
```sql
-- Don't index entire JSONB if you only query specific fields
-- Bad: Index entire column
CREATE INDEX idx_users_profile ON users USING gin(profile);

-- Good: Index specific field
CREATE INDEX idx_users_country ON users((profile ->> 'country'));
```

## SQLAlchemy JSONB Usage

```python
from sqlalchemy import Column, Integer, String
from sqlalchemy.dialects.postgresql import JSONB

class Product(Base):
    __tablename__ = 'products'

    id = Column(Integer, primary_key=True)
    name = Column(String(255))
    attributes = Column(JSONB)

# Insert
product = Product(
    name='Laptop',
    attributes={'brand': 'Dell', 'ram': 16, 'storage': 512}
)
session.add(product)

# Query with containment
products = session.query(Product).filter(
    Product.attributes.contains({'brand': 'Dell'})
).all()

# Query specific field
products = session.query(Product).filter(
    Product.attributes['ram'].astext.cast(Integer) >= 16
).all()

# Check key exists
products = session.query(Product).filter(
    Product.attributes.has_key('warranty')
).all()

# Update JSONB field
from sqlalchemy.dialects.postgresql import insert

stmt = insert(Product).values(
    id=1,
    attributes={'brand': 'Dell', 'ram': 32}
).on_conflict_do_update(
    index_elements=['id'],
    set_=dict(attributes=Product.attributes + {'ram': 32})
)
session.execute(stmt)
```

## Migration from JSON to JSONB

```sql
-- Add new JSONB column
ALTER TABLE products ADD COLUMN attributes_jsonb JSONB;

-- Copy and convert data
UPDATE products SET attributes_jsonb = attributes::jsonb;

-- Verify data
SELECT COUNT(*) FROM products
WHERE attributes_jsonb IS NULL AND attributes IS NOT NULL;

-- Drop old column and rename
ALTER TABLE products DROP COLUMN attributes;
ALTER TABLE products RENAME COLUMN attributes_jsonb TO attributes;

-- Add index
CREATE INDEX idx_products_attributes ON products USING gin(attributes);
```
