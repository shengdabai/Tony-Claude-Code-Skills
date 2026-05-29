#!/usr/bin/env python3
"""
Initialize Alembic for a SQLAlchemy project with best practices.

This script sets up Alembic with:
- Proper env.py configuration
- Environment variable support for database URL
- Automatic model detection
- Custom migration template

Usage:
    python init_alembic.py [--models-path path/to/models.py]

Example:
    python init_alembic.py --models-path app/models.py
"""

import os
import sys
import argparse
import subprocess
from pathlib import Path


CUSTOM_ENV_PY = '''"""
Alembic environment configuration.
"""
import os
from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool
from alembic import context

# Import your models' Base here
# Example: from myapp.models import Base
{models_import}

# Alembic Config object
config = context.config

# Interpret the config file for Python logging
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Get database URL from environment variable or config
database_url = os.environ.get('DATABASE_URL')
if database_url:
    config.set_main_option('sqlalchemy.url', database_url)

# Add your model's MetaData object here for 'autogenerate' support
target_metadata = {metadata_ref}


def run_migrations_offline():
    """Run migrations in 'offline' mode.

    This configures the context with just a URL
    and not an Engine, though an Engine is acceptable
    here as well. By skipping the Engine creation
    we don't even need a DBAPI to be available.

    Calls to context.execute() here emit the given string to the
    script output.
    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={{"paramstyle": "named"}},
        compare_type=True,
        compare_server_default=True,
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online():
    """Run migrations in 'online' mode.

    In this scenario we need to create an Engine
    and associate a connection with the context.
    """
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {{}}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
            compare_server_default=True,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
'''


CUSTOM_SCRIPT_MAKO = '''"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
Create Date: ${create_date}

"""
from alembic import op
import sqlalchemy as sa
${imports if imports else ""}

# revision identifiers, used by Alembic.
revision = ${repr(up_revision)}
down_revision = ${repr(down_revision)}
branch_labels = ${repr(branch_labels)}
depends_on = ${repr(depends_on)}


def upgrade():
    """Apply migration."""
    ${upgrades if upgrades else "pass"}


def downgrade():
    """Revert migration."""
    ${downgrades if downgrades else "pass"}
'''


README_MD = '''# Database Migrations

This directory contains Alembic migrations for the project.

## Setup

1. Set your database URL as an environment variable:
   ```bash
   export DATABASE_URL="postgresql://user:password@localhost/dbname"
   ```

2. Or update `alembic.ini` with your database connection string.

## Common Commands

### Create a new migration (auto-generate from models)
```bash
alembic revision --autogenerate -m "Add user table"
```

**⚠️ Important:** Always review auto-generated migrations! Alembic may not detect:
- Table/column renames (appears as drop + create)
- Changes to server_default values
- Custom database types

### Create an empty migration (manual)
```bash
alembic revision -m "Add custom index"
```

### Apply migrations
```bash
# Upgrade to latest
alembic upgrade head

# Upgrade to specific revision
alembic upgrade abc123

# Upgrade by relative steps
alembic upgrade +2
```

### Rollback migrations
```bash
# Downgrade by one revision
alembic downgrade -1

# Downgrade to specific revision
alembic downgrade abc123

# Downgrade to base (empty database)
alembic downgrade base
```

### Check migration status
```bash
# Show current revision
alembic current

# Show migration history
alembic history

# Show pending migrations
alembic history -r current:head
```

## Best Practices

1. **Always review auto-generated migrations** before applying them
2. **Test migrations** in development before production
3. **Write reversible migrations** with proper downgrade() implementations
4. **Use descriptive migration messages**
5. **Create indexes concurrently** in production:
   ```python
   def upgrade():
       op.execute('CREATE INDEX CONCURRENTLY idx_users_email ON users(email)')
   ```
6. **Handle data carefully** in migrations:
   ```python
   def upgrade():
       # Add column as nullable first
       op.add_column('users', sa.Column('email', sa.String(255), nullable=True))
       # Populate data
       op.execute("UPDATE users SET email = username || '@example.com' WHERE email IS NULL")
       # Make non-nullable
       op.alter_column('users', 'email', nullable=False)
   ```

## Production Deployment

For zero-downtime deployments:

1. Add new columns as nullable
2. Deploy code that writes to both old and new columns
3. Backfill data in a separate migration
4. Make columns non-nullable
5. Drop old columns in a later migration

## Troubleshooting

### Migrations out of sync
```bash
# Check what changed
alembic check

# Stamp database with current revision (use cautiously!)
alembic stamp head
```

### Need to merge branches
```bash
alembic merge -m "Merge migrations" head1 head2
```
'''


def init_alembic(models_path=None):
    """Initialize Alembic with best practices."""
    print("Initializing Alembic...")

    # Run alembic init
    try:
        subprocess.run(["alembic", "init", "alembic"], check=True, capture_output=True)
        print("✓ Created alembic directory structure")
    except subprocess.CalledProcessError as e:
        print(f"Error running 'alembic init': {e.stderr.decode()}")
        return False
    except FileNotFoundError:
        print("Error: alembic command not found. Install it with: pip install alembic")
        return False

    # Update env.py with custom configuration
    env_py_path = Path("alembic/env.py")

    if models_path:
        # Try to determine the import path
        models_path = Path(models_path)
        if models_path.exists():
            # Convert file path to import path
            import_path = str(models_path).replace("/", ".").replace(".py", "")
            models_import = f"from {import_path} import Base"
            metadata_ref = "Base.metadata"
        else:
            print(f"Warning: Models file not found at {models_path}")
            models_import = "# from myapp.models import Base  # TODO: Update this import"
            metadata_ref = "None  # TODO: Set to Base.metadata"
    else:
        models_import = "# from myapp.models import Base  # TODO: Update this import"
        metadata_ref = "None  # TODO: Set to Base.metadata"

    custom_env = CUSTOM_ENV_PY.format(
        models_import=models_import,
        metadata_ref=metadata_ref
    )

    env_py_path.write_text(custom_env)
    print("✓ Updated env.py with environment variable support")

    # Update script.py.mako
    script_mako_path = Path("alembic/script.py.mako")
    script_mako_path.write_text(CUSTOM_SCRIPT_MAKO)
    print("✓ Updated migration template")

    # Create README
    readme_path = Path("alembic/README.md")
    readme_path.write_text(README_MD)
    print("✓ Created README.md with migration guidelines")

    # Update alembic.ini comment about DATABASE_URL
    ini_path = Path("alembic.ini")
    ini_content = ini_path.read_text()

    # Add comment about environment variable
    if "DATABASE_URL" not in ini_content:
        ini_content = ini_content.replace(
            "sqlalchemy.url = ",
            "# Database URL can be set via DATABASE_URL environment variable\n"
            "# or configured here:\n"
            "sqlalchemy.url = "
        )
        ini_path.write_text(ini_content)
        print("✓ Updated alembic.ini with environment variable instructions")

    print("\n" + "=" * 70)
    print("Alembic initialized successfully!")
    print("=" * 70)
    print("\nNext steps:")
    print("1. Set DATABASE_URL environment variable:")
    print("   export DATABASE_URL='postgresql://user:password@localhost/dbname'")

    if not models_path or not Path(models_path).exists():
        print("2. Update alembic/env.py to import your SQLAlchemy Base")

    print("3. Create your first migration:")
    print("   alembic revision --autogenerate -m 'Initial migration'")
    print("4. Review the generated migration file")
    print("5. Apply migrations:")
    print("   alembic upgrade head")
    print("\n📚 See alembic/README.md for more details")

    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--models-path",
        help="Path to your SQLAlchemy models file (e.g., app/models.py)"
    )

    args = parser.parse_args()

    success = init_alembic(args.models_path)
    sys.exit(0 if success else 1)
