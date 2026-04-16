# PostgreSQL Schema Design Patterns and Normalization

## Database Normalization

### First Normal Form (1NF)
- Each column contains atomic (indivisible) values
- Each column contains values of a single type
- Each column has a unique name
- The order of rows and columns doesn't matter

**Example:**
```sql
-- Bad: Multiple values in one column
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    phone_numbers VARCHAR(255)  -- "555-1234, 555-5678"
);

-- Good: Separate table for phone numbers
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100)
);

CREATE TABLE user_phone_numbers (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    phone_number VARCHAR(20)
);
```

### Second Normal Form (2NF)
- Must be in 1NF
- All non-key attributes are fully dependent on the primary key
- No partial dependencies

**Example:**
```sql
-- Bad: Partial dependency
CREATE TABLE order_items (
    order_id INTEGER,
    product_id INTEGER,
    product_name VARCHAR(100),  -- Depends only on product_id
    quantity INTEGER,
    PRIMARY KEY (order_id, product_id)
);

-- Good: Separate product information
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100)
);

CREATE TABLE order_items (
    order_id INTEGER,
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER,
    PRIMARY KEY (order_id, product_id)
);
```

### Third Normal Form (3NF)
- Must be in 2NF
- No transitive dependencies (non-key attributes depend only on primary key)

**Example:**
```sql
-- Bad: Transitive dependency
CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    department_id INTEGER,
    department_name VARCHAR(100),  -- Depends on department_id, not id
    department_location VARCHAR(100)  -- Depends on department_id, not id
);

-- Good: Separate department table
CREATE TABLE departments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    location VARCHAR(100)
);

CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    department_id INTEGER REFERENCES departments(id)
);
```

## Common Design Patterns

### One-to-Many Relationship
```sql
CREATE TABLE authors (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE
);

CREATE TABLE books (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    author_id INTEGER NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
    published_date DATE,
    isbn VARCHAR(13) UNIQUE
);

CREATE INDEX idx_books_author_id ON books(author_id);
```

### Many-to-Many Relationship
```sql
CREATE TABLE students (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE
);

CREATE TABLE courses (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20) UNIQUE
);

-- Junction table
CREATE TABLE enrollments (
    student_id INTEGER REFERENCES students(id) ON DELETE CASCADE,
    course_id INTEGER REFERENCES courses(id) ON DELETE CASCADE,
    enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    grade VARCHAR(2),
    PRIMARY KEY (student_id, course_id)
);

CREATE INDEX idx_enrollments_student_id ON enrollments(student_id);
CREATE INDEX idx_enrollments_course_id ON enrollments(course_id);
```

### Self-Referencing Relationship (Hierarchical Data)
```sql
-- Tree structure (e.g., organizational chart, categories)
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    parent_id INTEGER REFERENCES categories(id) ON DELETE CASCADE,
    level INTEGER NOT NULL DEFAULT 0,
    path TEXT  -- Materialized path for efficient queries
);

CREATE INDEX idx_categories_parent_id ON categories(parent_id);
CREATE INDEX idx_categories_path ON categories USING gin(path gin_trgm_ops);

-- Query descendants using recursive CTE
WITH RECURSIVE category_tree AS (
    SELECT id, name, parent_id, 0 AS depth
    FROM categories
    WHERE id = 1  -- Root category

    UNION ALL

    SELECT c.id, c.name, c.parent_id, ct.depth + 1
    FROM categories c
    JOIN category_tree ct ON c.parent_id = ct.id
)
SELECT * FROM category_tree;
```

### Polymorphic Associations
```sql
-- Pattern 1: Single Table Inheritance (STI)
CREATE TABLE content_items (
    id SERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL,  -- 'article', 'video', 'podcast'
    title VARCHAR(255) NOT NULL,
    -- Common fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Type-specific fields (nullable)
    article_body TEXT,
    video_url VARCHAR(500),
    video_duration INTEGER,
    podcast_audio_url VARCHAR(500),
    podcast_duration INTEGER
);

-- Pattern 2: Concrete Table Inheritance (recommended)
CREATE TABLE articles (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE videos (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    url VARCHAR(500) NOT NULL,
    duration INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE podcasts (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    audio_url VARCHAR(500) NOT NULL,
    duration INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Audit Trail Pattern
```sql
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit table tracking all changes
CREATE TABLE product_audit (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL,
    operation VARCHAR(10) NOT NULL,  -- 'INSERT', 'UPDATE', 'DELETE'
    old_data JSONB,
    new_data JSONB,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Trigger to populate audit table
CREATE OR REPLACE FUNCTION audit_product_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO product_audit(product_id, operation, old_data, changed_by)
        VALUES (OLD.id, 'DELETE', row_to_json(OLD), current_user);
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO product_audit(product_id, operation, old_data, new_data, changed_by)
        VALUES (NEW.id, 'UPDATE', row_to_json(OLD), row_to_json(NEW), current_user);
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO product_audit(product_id, operation, new_data, changed_by)
        VALUES (NEW.id, 'INSERT', row_to_json(NEW), current_user);
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER product_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON products
FOR EACH ROW EXECUTE FUNCTION audit_product_changes();
```

### Soft Delete Pattern
```sql
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    deleted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for efficient queries on non-deleted records
CREATE INDEX idx_posts_not_deleted ON posts(id) WHERE deleted_at IS NULL;

-- View for active posts
CREATE VIEW active_posts AS
SELECT * FROM posts WHERE deleted_at IS NULL;

-- Soft delete function
CREATE OR REPLACE FUNCTION soft_delete_post(post_id INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE posts SET deleted_at = CURRENT_TIMESTAMP WHERE id = post_id;
END;
$$ LANGUAGE plpgsql;

-- Restore function
CREATE OR REPLACE FUNCTION restore_post(post_id INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE posts SET deleted_at = NULL WHERE id = post_id;
END;
$$ LANGUAGE plpgsql;
```

### Temporal Data Pattern
```sql
-- Bi-temporal table: tracks both valid time and transaction time
CREATE TABLE employee_salary_history (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL,
    salary DECIMAL(10, 2) NOT NULL,
    -- Valid time (when the salary was/is/will be effective)
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    -- Transaction time (when the record was inserted into database)
    tx_from TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tx_to TIMESTAMP NOT NULL DEFAULT '9999-12-31',
    EXCLUDE USING gist (
        employee_id WITH =,
        daterange(valid_from, valid_to, '[]') WITH &&
    )
);

-- Get current salary
SELECT salary
FROM employee_salary_history
WHERE employee_id = 123
  AND valid_from <= CURRENT_DATE
  AND valid_to > CURRENT_DATE
  AND tx_to = '9999-12-31';

-- Get historical salary at specific date
SELECT salary
FROM employee_salary_history
WHERE employee_id = 123
  AND valid_from <= '2024-01-01'
  AND valid_to > '2024-01-01'
  AND tx_to = '9999-12-31';
```

## Anti-Patterns to Avoid

### Entity-Attribute-Value (EAV) Anti-Pattern
```sql
-- Bad: EAV pattern - very slow queries
CREATE TABLE object_attributes (
    object_id INTEGER,
    attribute_name VARCHAR(50),
    attribute_value TEXT
);

-- Better: Use JSONB for semi-structured data or proper columns
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    attributes JSONB  -- For truly dynamic attributes
);

-- Or create proper columns for known attributes
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    price DECIMAL(10, 2),
    weight DECIMAL(10, 2),
    color VARCHAR(50)
);
```

### Fear of NULL
```sql
-- Bad: Using sentinel values
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    middle_name VARCHAR(100) DEFAULT 'NONE',  -- Bad
    phone VARCHAR(20) DEFAULT 'N/A'  -- Bad
);

-- Good: Use NULL for unknown/missing values
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),  -- NULL if no middle name
    phone VARCHAR(20)  -- NULL if no phone
);
```

### God Table Anti-Pattern
```sql
-- Bad: Storing everything in one table
CREATE TABLE everything (
    id SERIAL PRIMARY KEY,
    user_name VARCHAR(100),
    user_email VARCHAR(255),
    order_date DATE,
    order_total DECIMAL(10, 2),
    product_name VARCHAR(255),
    product_price DECIMAL(10, 2)
    -- ... 50+ more columns
);

-- Good: Normalize into separate tables
-- (See normalization examples above)
```
