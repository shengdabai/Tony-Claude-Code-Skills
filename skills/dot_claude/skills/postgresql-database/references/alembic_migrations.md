# Alembic Migration Workflows

## Setup and Configuration

### Initial Setup
```bash
# Install Alembic
pip install alembic

# Initialize Alembic in your project
alembic init alembic

# This creates:
# alembic/
#   env.py          # Migration environment configuration
#   script.py.mako  # Template for new migrations
#   versions/       # Migration files go here
# alembic.ini       # Alembic configuration file
```

### Configure Database Connection
```python
# alembic/env.py
from sqlalchemy import engine_from_config, pool
from alembic import context
from myapp.models import Base  # Import your SQLAlchemy Base

# Add your models' metadata
target_metadata = Base.metadata

def run_migrations_offline():
    """Run migrations in 'offline' mode."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online():
    """Run migrations in 'online' mode."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata
        )

        with context.begin_transaction():
            context.run_migrations()
```

```ini
# alembic.ini
[alembic]
script_location = alembic
sqlalchemy.url = postgresql://user:password@localhost/dbname

# Or use environment variables
# sqlalchemy.url = postgresql://%(DB_USER)s:%(DB_PASSWORD)s@%(DB_HOST)s/%(DB_NAME)s
```

### Better: Use Environment Variables
```python
# alembic/env.py
import os
from sqlalchemy import engine_from_config, pool

# Get database URL from environment
config.set_main_option(
    'sqlalchemy.url',
    os.environ.get('DATABASE_URL', 'postgresql://localhost/mydb')
)
```

## Creating Migrations

### Auto-generate Migrations from Models
```bash
# Create a new migration based on model changes
alembic revision --autogenerate -m "Add user table"

# This creates: alembic/versions/xxxxx_add_user_table.py
```

**Important:** Always review auto-generated migrations! Alembic may not detect:
- Table/column renames (appears as drop + add)
- Changes to server_default values
- Custom database types
- CHECK constraints

### Manual Migration Creation
```bash
# Create an empty migration file
alembic revision -m "Add custom index"
```

## Migration File Structure

### Basic Migration Example
```python
"""Add user table

Revision ID: 1a2b3c4d5e6f
Revises:
Create Date: 2024-01-15 10:30:00.000000
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic
revision = '1a2b3c4d5e6f'
down_revision = None
branch_labels = None
depends_on = None

def upgrade():
    op.create_table(
        'users',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('username', sa.String(50), nullable=False),
        sa.Column('email', sa.String(255), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('NOW()')),
        sa.UniqueConstraint('username', name='uq_users_username'),
        sa.UniqueConstraint('email', name='uq_users_email')
    )
    op.create_index('ix_users_email', 'users', ['email'])

def downgrade():
    op.drop_index('ix_users_email', table_name='users')
    op.drop_table('users')
```

### Adding Columns
```python
def upgrade():
    # Add a simple column
    op.add_column('users', sa.Column('phone', sa.String(20), nullable=True))

    # Add column with default value
    op.add_column('users',
        sa.Column('is_active', sa.Boolean(),
                  nullable=False,
                  server_default=sa.text('true'))
    )

    # Add column with foreign key
    op.add_column('posts', sa.Column('author_id', sa.Integer(), nullable=True))
    op.create_foreign_key(
        'fk_posts_author_id',
        'posts', 'users',
        ['author_id'], ['id'],
        ondelete='CASCADE'
    )

def downgrade():
    op.drop_constraint('fk_posts_author_id', 'posts', type_='foreignkey')
    op.drop_column('posts', 'author_id')
    op.drop_column('users', 'is_active')
    op.drop_column('users', 'phone')
```

### Modifying Columns
```python
def upgrade():
    # Change column type
    op.alter_column('users', 'username',
                    type_=sa.String(100),
                    existing_type=sa.String(50))

    # Make column nullable
    op.alter_column('users', 'phone',
                    nullable=True,
                    existing_type=sa.String(20))

    # Make column non-nullable (ensure data is valid first!)
    op.execute("UPDATE users SET email = '' WHERE email IS NULL")
    op.alter_column('users', 'email',
                    nullable=False,
                    existing_type=sa.String(255))

    # Rename column
    op.alter_column('users', 'username',
                    new_column_name='user_name')

def downgrade():
    op.alter_column('users', 'user_name',
                    new_column_name='username')
    op.alter_column('users', 'email',
                    nullable=True)
    op.alter_column('users', 'phone',
                    nullable=False)
    op.alter_column('users', 'username',
                    type_=sa.String(50))
```

### Creating Indexes
```python
def upgrade():
    # Simple index
    op.create_index('ix_users_created_at', 'users', ['created_at'])

    # Partial index
    op.create_index(
        'ix_users_active_email',
        'users',
        ['email'],
        postgresql_where=sa.text('is_active = true')
    )

    # Multi-column index
    op.create_index(
        'ix_posts_author_created',
        'posts',
        ['author_id', 'created_at']
    )

    # Unique index
    op.create_index(
        'ix_users_username_lower',
        'users',
        [sa.text('LOWER(username)')],
        unique=True
    )

    # GIN index for full-text search
    op.create_index(
        'ix_posts_content_fts',
        'posts',
        [sa.text('to_tsvector(\'english\', content)')],
        postgresql_using='gin'
    )

def downgrade():
    op.drop_index('ix_posts_content_fts')
    op.drop_index('ix_users_username_lower')
    op.drop_index('ix_posts_author_created')
    op.drop_index('ix_users_active_email')
    op.drop_index('ix_users_created_at')
```

### Data Migrations
```python
from alembic import op
import sqlalchemy as sa
from sqlalchemy.sql import table, column

def upgrade():
    # Define table structure for data migration
    users = table('users',
        column('id', sa.Integer),
        column('username', sa.String),
        column('legacy_status', sa.String),
        column('is_active', sa.Boolean)
    )

    # Migrate data
    op.execute(
        users.update()
        .where(users.c.legacy_status == 'active')
        .values(is_active=True)
    )

    op.execute(
        users.update()
        .where(users.c.legacy_status == 'inactive')
        .values(is_active=False)
    )

    # Remove old column
    op.drop_column('users', 'legacy_status')

def downgrade():
    # Add back old column
    op.add_column('users',
        sa.Column('legacy_status', sa.String(20), nullable=True)
    )

    # Migrate data back
    users = table('users',
        column('is_active', sa.Boolean),
        column('legacy_status', sa.String)
    )

    op.execute(
        users.update()
        .where(users.c.is_active == True)
        .values(legacy_status='active')
    )

    op.execute(
        users.update()
        .where(users.c.is_active == False)
        .values(legacy_status='inactive')
    )
```

### PostgreSQL-Specific Features
```python
def upgrade():
    # Create ENUM type
    status_enum = sa.Enum('pending', 'active', 'suspended', name='user_status')
    status_enum.create(op.get_bind())

    op.add_column('users',
        sa.Column('status', sa.Enum('pending', 'active', 'suspended',
                                     name='user_status'),
                  nullable=False,
                  server_default='pending')
    )

    # Create extension
    op.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"')
    op.execute('CREATE EXTENSION IF NOT EXISTS pg_trgm')

    # Add JSONB column
    op.add_column('users',
        sa.Column('metadata', sa.dialects.postgresql.JSONB, nullable=True)
    )

    # Create GIN index on JSONB
    op.create_index(
        'ix_users_metadata',
        'users',
        ['metadata'],
        postgresql_using='gin'
    )

def downgrade():
    op.drop_index('ix_users_metadata')
    op.drop_column('users', 'metadata')
    op.drop_column('users', 'status')

    # Drop ENUM type
    sa.Enum(name='user_status').drop(op.get_bind())
```

## Running Migrations

### Upgrade Database
```bash
# Upgrade to latest revision
alembic upgrade head

# Upgrade to specific revision
alembic upgrade 1a2b3c4d5e6f

# Upgrade by relative steps
alembic upgrade +2  # Apply next 2 migrations
```

### Downgrade Database
```bash
# Downgrade by one revision
alembic downgrade -1

# Downgrade to specific revision
alembic downgrade 1a2b3c4d5e6f

# Downgrade to base (empty database)
alembic downgrade base
```

### Check Current Version
```bash
# Show current revision
alembic current

# Show migration history
alembic history

# Show pending migrations
alembic history -r current:head
```

## Best Practices

### 1. Always Review Auto-Generated Migrations
```python
# Alembic may incorrectly detect renames as drop + create
# BAD (auto-generated):
def upgrade():
    op.drop_column('users', 'username')
    op.add_column('users', sa.Column('user_name', sa.String(50)))

# GOOD (manually corrected):
def upgrade():
    op.alter_column('users', 'username', new_column_name='user_name')
```

### 2. Use Batch Operations for SQLite Compatibility
```python
def upgrade():
    with op.batch_alter_table('users') as batch_op:
        batch_op.add_column(sa.Column('phone', sa.String(20)))
        batch_op.create_index('ix_users_phone', ['phone'])
```

### 3. Handle Data Safely in Migrations
```python
def upgrade():
    # Add column as nullable first
    op.add_column('users', sa.Column('email', sa.String(255), nullable=True))

    # Populate data
    op.execute("UPDATE users SET email = username || '@example.com' WHERE email IS NULL")

    # Make non-nullable
    op.alter_column('users', 'email', nullable=False)

def downgrade():
    op.drop_column('users', 'email')
```

### 4. Use Transactions
```python
def upgrade():
    # Use context manager for transaction
    with op.get_context().autocommit_block():
        # Operations that need to be outside transaction
        op.execute('CREATE INDEX CONCURRENTLY ix_users_email ON users(email)')

    # Regular operations are automatically in a transaction
    op.add_column('users', sa.Column('phone', sa.String(20)))
```

### 5. Test Migrations
```python
# Test both upgrade and downgrade
# tests/test_migrations.py
import pytest
from alembic import command
from alembic.config import Config

def test_migration_upgrade_downgrade():
    alembic_cfg = Config("alembic.ini")

    # Upgrade
    command.upgrade(alembic_cfg, "head")

    # Downgrade
    command.downgrade(alembic_cfg, "base")

    # Upgrade again
    command.upgrade(alembic_cfg, "head")
```

### 6. Use Descriptive Migration Messages
```bash
# Good
alembic revision -m "Add email verification fields to users table"

# Bad
alembic revision -m "Update users"
```

### 7. Separate Schema and Data Migrations
```bash
# Create schema change first
alembic revision -m "Add status column to users"

# Create separate data migration
alembic revision -m "Populate status column based on legacy data"
```

## Branching and Merging

### Creating Branches
```bash
# Create a branch
alembic revision -m "Feature A changes" --branch-label feature_a

# Create another branch
alembic revision -m "Feature B changes" --branch-label feature_b
```

### Merging Branches
```bash
# Create a merge revision
alembic merge -m "Merge features A and B" feature_a feature_b
```

## Multiple Databases

### Configure Multiple Bases
```python
# models/base_user.py
from sqlalchemy.ext.declarative import declarative_base
UserBase = declarative_base()

# models/base_analytics.py
AnalyticsBase = declarative_base()

# alembic/env.py
from models.base_user import UserBase
from models.base_analytics import AnalyticsBase

target_metadata = {
    'users': UserBase.metadata,
    'analytics': AnalyticsBase.metadata
}
```

## Common Issues and Solutions

### Issue: "Can't proceed with migration due to pending changes"
```bash
# Review what changed
alembic check

# Create migration for pending changes
alembic revision --autogenerate -m "Catch up with model changes"
```

### Issue: Need to run migrations in production without downtime
```python
def upgrade():
    # Step 1: Add new column as nullable
    op.add_column('users', sa.Column('new_email', sa.String(255), nullable=True))

    # Step 2: Deploy application code that writes to both columns
    # (This happens between migrations in a separate deployment)

    # Step 3: In next migration, backfill data
    # op.execute("UPDATE users SET new_email = email WHERE new_email IS NULL")

    # Step 4: In next migration, make non-nullable and drop old column
    # op.alter_column('users', 'new_email', nullable=False)
    # op.drop_column('users', 'email')
```

### Issue: Need to add index without locking table
```python
def upgrade():
    # Use CONCURRENTLY for large tables in production
    op.execute('CREATE INDEX CONCURRENTLY ix_users_email ON users(email)')

def downgrade():
    op.execute('DROP INDEX CONCURRENTLY ix_users_email')
```
