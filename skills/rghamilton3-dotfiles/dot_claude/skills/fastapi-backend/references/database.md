# Database Session Management with SQLAlchemy

## Async SQLAlchemy Setup

### Database Configuration

```python
# app/db/session.py
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
from app.core.config import settings

# Create async engine
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=True,  # Set to False in production
    future=True,
    pool_pre_ping=True,  # Verify connections before using
    pool_size=10,
    max_overflow=20
)

# Create async session factory
AsyncSessionLocal = sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False
)

# Base class for models
Base = declarative_base()
```

### Database Dependency

```python
# app/api/deps.py
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import AsyncSessionLocal

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependency that provides a database session.
    Automatically commits on success, rolls back on exception.
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
```

## Model Definition

### Base Model Pattern

```python
# app/models/base.py
from sqlalchemy import Column, Integer, DateTime, func
from app.db.session import Base

class BaseModel(Base):
    """Base model with common fields."""
    __abstract__ = True

    id = Column(Integer, primary_key=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
```

### User Model Example

```python
# app/models/user.py
from sqlalchemy import Column, String, Boolean
from sqlalchemy.orm import relationship
from app.models.base import BaseModel

class User(BaseModel):
    __tablename__ = "users"

    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    full_name = Column(String)
    is_active = Column(Boolean, default=True)
    is_superuser = Column(Boolean, default=False)

    # Relationships
    items = relationship("Item", back_populates="owner")
```

### Relationship Patterns

```python
# One-to-Many
from sqlalchemy import ForeignKey
from sqlalchemy.orm import relationship

class User(BaseModel):
    __tablename__ = "users"
    # ... other columns
    items = relationship("Item", back_populates="owner", cascade="all, delete-orphan")

class Item(BaseModel):
    __tablename__ = "items"
    # ... other columns
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    owner = relationship("User", back_populates="items")

# Many-to-Many
from sqlalchemy import Table

user_roles = Table(
    "user_roles",
    Base.metadata,
    Column("user_id", Integer, ForeignKey("users.id")),
    Column("role_id", Integer, ForeignKey("roles.id"))
)

class User(BaseModel):
    __tablename__ = "users"
    roles = relationship("Role", secondary=user_roles, back_populates="users")

class Role(BaseModel):
    __tablename__ = "roles"
    name = Column(String, unique=True)
    users = relationship("User", secondary=user_roles, back_populates="roles")
```

## Query Patterns

### Basic Queries

```python
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

# Get by ID
async def get_user(db: AsyncSession, user_id: int):
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()

# Get multiple with filters
async def get_users(db: AsyncSession, skip: int = 0, limit: int = 100):
    result = await db.execute(
        select(User)
        .where(User.is_active == True)
        .offset(skip)
        .limit(limit)
    )
    return result.scalars().all()

# Count
from sqlalchemy import func as sql_func

async def count_users(db: AsyncSession):
    result = await db.execute(select(sql_func.count(User.id)))
    return result.scalar()
```

### Joining and Loading Relationships

```python
from sqlalchemy.orm import selectinload, joinedload

# Eager loading with selectinload (separate query)
async def get_user_with_items(db: AsyncSession, user_id: int):
    result = await db.execute(
        select(User)
        .options(selectinload(User.items))
        .where(User.id == user_id)
    )
    return result.scalar_one_or_none()

# Eager loading with joinedload (single query with JOIN)
async def get_users_with_roles(db: AsyncSession):
    result = await db.execute(
        select(User)
        .options(joinedload(User.roles))
    )
    return result.unique().scalars().all()

# Complex joins
async def get_items_with_owner(db: AsyncSession):
    result = await db.execute(
        select(Item)
        .join(Item.owner)
        .where(User.is_active == True)
        .options(selectinload(Item.owner))
    )
    return result.scalars().all()
```

### Filtering and Ordering

```python
from sqlalchemy import or_, and_

# Complex filters
async def search_users(db: AsyncSession, query: str):
    result = await db.execute(
        select(User).where(
            or_(
                User.email.ilike(f"%{query}%"),
                User.full_name.ilike(f"%{query}%")
            )
        )
    )
    return result.scalars().all()

# Ordering
async def get_recent_users(db: AsyncSession, limit: int = 10):
    result = await db.execute(
        select(User)
        .order_by(User.created_at.desc())
        .limit(limit)
    )
    return result.scalars().all()
```

## Transactions

### Manual Transaction Management

```python
async def transfer_items(
    db: AsyncSession,
    from_user_id: int,
    to_user_id: int,
    item_ids: list[int]
):
    """Transfer items between users in a transaction."""
    async with db.begin():  # Explicit transaction
        # Get users
        from_user = await get_user(db, from_user_id)
        to_user = await get_user(db, to_user_id)

        if not from_user or not to_user:
            raise ValueError("User not found")

        # Update items
        await db.execute(
            update(Item)
            .where(Item.id.in_(item_ids))
            .where(Item.owner_id == from_user_id)
            .values(owner_id=to_user_id)
        )

        # Transaction automatically commits if no exception
```

### Nested Transactions (Savepoints)

```python
async def complex_operation(db: AsyncSession):
    """Use savepoints for nested transaction control."""
    # Main transaction
    user = User(email="test@example.com")
    db.add(user)
    await db.flush()  # Get user.id

    try:
        # Savepoint
        async with db.begin_nested():
            item = Item(owner_id=user.id, name="Test")
            db.add(item)
            await db.flush()

            # This might fail
            risky_operation(item)

    except Exception:
        # Rolls back to savepoint, user is still created
        logger.error("Item creation failed, but user was created")

    await db.commit()
```

## Bulk Operations

### Bulk Insert

```python
async def bulk_create_users(db: AsyncSession, users_data: list[dict]):
    """Efficiently create multiple users."""
    users = [User(**data) for data in users_data]
    db.add_all(users)
    await db.commit()
    return users
```

### Bulk Update

```python
from sqlalchemy import update

async def deactivate_users(db: AsyncSession, user_ids: list[int]):
    """Bulk update user status."""
    await db.execute(
        update(User)
        .where(User.id.in_(user_ids))
        .values(is_active=False)
    )
    await db.commit()
```

## Alembic Migrations

### Initial Setup

```bash
# Initialize Alembic
alembic init alembic

# Configure alembic.ini
sqlalchemy.url = postgresql+asyncpg://user:pass@localhost/dbname
```

### Alembic Configuration

```python
# alembic/env.py
from app.db.session import Base
from app.models import *  # Import all models

target_metadata = Base.metadata

# For async migrations
from sqlalchemy.ext.asyncio import create_async_engine
from asyncio import run

async def run_migrations_online():
    connectable = create_async_engine(config.get_main_option("sqlalchemy.url"))

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

run(run_migrations_online())
```

### Creating Migrations

```bash
# Auto-generate migration
alembic revision --autogenerate -m "Add user table"

# Apply migrations
alembic upgrade head

# Rollback
alembic downgrade -1
```

## Connection Pooling

### Pool Configuration

```python
from sqlalchemy.ext.asyncio import create_async_engine

engine = create_async_engine(
    DATABASE_URL,
    pool_size=20,           # Number of connections to maintain
    max_overflow=10,        # Additional connections when pool is exhausted
    pool_timeout=30,        # Seconds to wait for connection
    pool_recycle=3600,      # Recycle connections after 1 hour
    pool_pre_ping=True,     # Verify connections before use
    echo_pool=True,         # Log pool checkouts/checkins
)
```

## Best Practices

1. **Always use async/await** - Never mix sync and async SQLAlchemy operations
2. **Close sessions properly** - Use context managers or the dependency pattern
3. **Use transactions** - Wrap related operations in transactions
4. **Eager load relationships** - Avoid N+1 queries with selectinload/joinedload
5. **Index frequently queried columns** - Especially foreign keys and filters
6. **Use connection pooling** - Configure pool size based on your needs
7. **Handle connection errors** - Implement retry logic for transient failures
8. **Use migrations** - Never modify database schema manually
