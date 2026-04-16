# FastAPI Patterns and Best Practices

## Project Structure

Recommended directory structure for FastAPI projects:

```
app/
├── main.py                 # Application entry point
├── core/
│   ├── config.py          # Settings and configuration
│   ├── security.py        # Security utilities
│   └── deps.py            # Common dependencies
├── api/
│   ├── api_v1/
│   │   ├── api.py         # API router aggregation
│   │   └── endpoints/
│   │       ├── users.py
│   │       ├── items.py
│   │       └── auth.py
│   └── deps.py            # API dependencies
├── models/
│   ├── user.py            # SQLAlchemy models
│   └── item.py
├── schemas/
│   ├── user.py            # Pydantic schemas
│   └── item.py
├── crud/
│   ├── crud_user.py       # CRUD operations
│   └── crud_item.py
├── db/
│   ├── base.py            # Import all models for Alembic
│   ├── session.py         # Database session
│   └── init_db.py         # Database initialization
└── utils/
    └── email.py           # Utility functions
```

## Async/Await Patterns

### 1. Route Handlers

Always use `async def` for route handlers that perform I/O operations:

```python
@app.get("/users/{user_id}")
async def read_user(user_id: int, db: AsyncSession = Depends(get_db)):
    user = await crud.user.get(db, id=user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
```

### 2. Database Operations

Use async SQLAlchemy for all database operations:

```python
async def get_user_by_email(db: AsyncSession, email: str) -> Optional[User]:
    result = await db.execute(
        select(User).where(User.email == email)
    )
    return result.scalar_one_or_none()
```

### 3. Multiple Concurrent Operations

Use `asyncio.gather()` for concurrent operations:

```python
from asyncio import gather

@app.get("/dashboard")
async def get_dashboard(db: AsyncSession = Depends(get_db)):
    users, items, stats = await gather(
        crud.user.get_multi(db),
        crud.item.get_multi(db),
        get_statistics(db)
    )
    return {"users": users, "items": items, "stats": stats}
```

## Dependency Injection

### Common Dependencies

Create reusable dependencies in `app/api/deps.py`:

```python
from typing import Generator, AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import AsyncSessionLocal

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        yield session

async def get_current_user(
    db: AsyncSession = Depends(get_db),
    token: str = Depends(oauth2_scheme)
) -> User:
    # Validate token and return user
    pass

async def get_current_active_superuser(
    current_user: User = Depends(get_current_user),
) -> User:
    if not current_user.is_superuser:
        raise HTTPException(status_code=403, detail="Not enough privileges")
    return current_user
```

### Using Dependencies

```python
@app.get("/users/me")
async def read_users_me(
    current_user: User = Depends(get_current_user)
):
    return current_user

@app.delete("/users/{user_id}")
async def delete_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_superuser)
):
    await crud.user.delete(db, id=user_id)
    return {"message": "User deleted"}
```

## Response Models

### Using response_model

Always specify response models for type safety and documentation:

```python
from app.schemas.user import User, UserCreate

@app.post("/users", response_model=User)
async def create_user(
    user_in: UserCreate,
    db: AsyncSession = Depends(get_db)
):
    user = await crud.user.create(db, obj_in=user_in)
    return user
```

### Multiple Response Models

Use `Union` for endpoints that can return different models:

```python
from typing import Union
from app.schemas import User, PublicUser

@app.get("/users/{user_id}", response_model=Union[User, PublicUser])
async def read_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_current_user)
):
    user = await crud.user.get(db, id=user_id)
    if current_user and (current_user.id == user_id or current_user.is_superuser):
        return user  # Full User model
    return PublicUser.model_validate(user)  # Limited public model
```

## Pagination

Standard pagination pattern:

```python
from typing import List
from pydantic import BaseModel

class PaginatedResponse(BaseModel):
    items: List[Any]
    total: int
    page: int
    size: int
    pages: int

@app.get("/users", response_model=PaginatedResponse)
async def list_users(
    db: AsyncSession = Depends(get_db),
    skip: int = 0,
    limit: int = 100
):
    users = await crud.user.get_multi(db, skip=skip, limit=limit)
    total = await crud.user.count(db)
    return PaginatedResponse(
        items=users,
        total=total,
        page=skip // limit + 1,
        size=limit,
        pages=(total + limit - 1) // limit
    )
```

## Background Tasks

### Using FastAPI Background Tasks

For lightweight tasks:

```python
from fastapi import BackgroundTasks

def send_notification(email: str, message: str):
    # Send notification logic
    pass

@app.post("/users")
async def create_user(
    user: UserCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    new_user = await crud.user.create(db, obj_in=user)
    background_tasks.add_task(send_notification, new_user.email, "Welcome!")
    return new_user
```

### Using Celery for Heavy Tasks

For long-running or resource-intensive tasks, use Celery (see celery_task_example.py).

## API Versioning

Version your API using prefixes:

```python
from fastapi import APIRouter

api_router = APIRouter()

# Version 1
api_v1_router = APIRouter(prefix="/v1")
api_v1_router.include_router(users_router, prefix="/users", tags=["users"])
api_v1_router.include_router(items_router, prefix="/items", tags=["items"])

# Version 2 with breaking changes
api_v2_router = APIRouter(prefix="/v2")
api_v2_router.include_router(users_v2_router, prefix="/users", tags=["users"])

# Mount versions
api_router.include_router(api_v1_router)
api_router.include_router(api_v2_router)

app.include_router(api_router, prefix="/api")
```

## Configuration Management

Use Pydantic Settings:

```python
from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    PROJECT_NAME: str = "FastAPI Project"
    API_V1_STR: str = "/api/v1"
    DATABASE_URL: str
    SECRET_KEY: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    class Config:
        env_file = ".env"

@lru_cache()
def get_settings() -> Settings:
    return Settings()

# Usage
settings = get_settings()
```

## Testing Patterns

### Test Client Setup

```python
import pytest
from httpx import AsyncClient
from app.main import app

@pytest.fixture
async def client():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

@pytest.mark.asyncio
async def test_read_users(client: AsyncClient):
    response = await client.get("/api/v1/users")
    assert response.status_code == 200
```

### Database Testing

```python
import pytest
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

@pytest.fixture
async def db_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with async_session() as session:
        yield session

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
```
