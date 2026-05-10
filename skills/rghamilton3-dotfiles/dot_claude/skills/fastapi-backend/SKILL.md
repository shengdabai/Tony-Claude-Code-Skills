---
name: fastapi-backend
description: Build production-ready FastAPI backends with async/await, SQLAlchemy, JWT authentication, Pydantic validation, and Celery background tasks. Use when creating REST APIs, implementing CRUD endpoints, setting up authentication, managing database sessions, or building backend services with FastAPI.
---

# FastAPI Backend Development

## Overview

This skill provides comprehensive guidance for building modern, production-ready FastAPI backend applications. Covers async/await patterns, database session management with async SQLAlchemy, JWT and OAuth2 authentication, Pydantic model validation, OpenAPI documentation, error handling patterns, and background task processing with Celery.

## When to Use This Skill

Use this skill when:
- Building a new FastAPI backend application from scratch
- Implementing CRUD endpoints with async database operations
- Setting up JWT or OAuth2 authentication
- Configuring async SQLAlchemy session management
- Creating Pydantic models with complex validation
- Implementing background tasks with Celery
- Setting up proper error handling and logging
- Building RESTful APIs with OpenAPI documentation

## Quick Start with Project Template

For new projects, use the complete FastAPI project template available in `assets/project-template/`. This template includes:

- Complete application structure with async/await throughout
- JWT authentication with access and refresh tokens
- Async SQLAlchemy 2.0 configuration
- User model and CRUD operations
- Pydantic schemas for request/response validation
- Docker Compose setup with PostgreSQL, Redis, and Celery
- Alembic migrations configuration
- Environment-based configuration with Pydantic Settings
- OpenAPI documentation

To use the template:
1. Copy the entire `assets/project-template/` directory to the project location
2. Create `.env` file from `.env.example` and configure settings
3. Install dependencies: `pip install -r requirements.txt`
4. Run with Docker Compose: `docker-compose up`

## Core Development Tasks

### 1. CRUD Operations with Async/Await

For implementing CRUD endpoints, refer to `scripts/crud_template.py` which provides a generic, type-safe CRUD base class.

**Key patterns:**
- Use Generic types for type safety: `CRUDBase[ModelType, CreateSchemaType, UpdateSchemaType]`
- Always use async session operations: `await db.execute()`, `await db.commit()`
- Implement pagination with skip/limit parameters
- Support optional filtering with dictionary-based filters
- Use `scalar_one_or_none()` for single results, `scalars().all()` for lists

**Implementation steps:**
1. Define SQLAlchemy model in `app/models/`
2. Create Pydantic schemas in `app/schemas/` for Create, Update, and Response
3. Implement CRUD class in `app/crud/` inheriting from the template
4. Create API endpoints in `app/api/v1/endpoints/`
5. Use database session dependency: `db: AsyncSession = Depends(get_db)`

For detailed patterns and query examples, consult `references/patterns.md` section "Async/Await Patterns" and `references/database.md`.

### 2. JWT Authentication

For authentication implementation, refer to `scripts/auth_middleware.py` which provides complete JWT authentication utilities.

**Key components:**
- Password hashing with bcrypt: `verify_password()`, `get_password_hash()`
- Token creation: `create_access_token()`, `create_refresh_token()`
- OAuth2 password bearer scheme for token validation
- Current user dependency: `get_current_user()` for protected routes
- Scope-based authorization: `require_scopes()` factory

**Implementation steps:**
1. Configure SECRET_KEY and token expiration in settings
2. Implement user authentication in CRUD layer
3. Create login endpoint that returns access and refresh tokens
4. Use `get_current_user` dependency in protected routes
5. Implement refresh token endpoint for token renewal

For complete authentication flows including OAuth2 integration, consult `references/authentication.md`.

### 3. Database Session Management

For database configuration, use the pattern from `assets/project-template/app/db/session.py`.

**Key patterns:**
- Create async engine with proper connection pooling
- Use `sessionmaker` with `AsyncSession` class
- Implement dependency that handles commit/rollback automatically
- Configure pool size and overflow based on load requirements
- Use `pool_pre_ping=True` to verify connections before use

**Session dependency pattern:**
```python
async def get_db() -> AsyncGenerator[AsyncSession, None]:
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

For detailed database patterns including transactions, bulk operations, and migrations, consult `references/database.md`.

### 4. Pydantic Models and Validation

Create Pydantic schemas for all request and response models.

**Schema patterns:**
- Base schema with common fields
- Create schema for incoming data (excludes id, timestamps)
- Update schema with all fields optional
- Response schema that matches database model
- Use `model_config = ConfigDict(from_attributes=True)` for ORM mode

**Validation features:**
- Use `EmailStr` for email validation
- Custom validators with `@field_validator`
- Computed fields with `@computed_field`
- Model validators with `@model_validator`
- Constrained types: `constr()`, `conint()`, etc.

Refer to project template schemas in `assets/project-template/app/schemas/` for examples.

### 5. API Documentation with OpenAPI

FastAPI automatically generates OpenAPI documentation.

**Enhancement patterns:**
- Add response models to all endpoints: `response_model=UserSchema`
- Document error responses: `responses={404: {"model": ErrorResponse}}`
- Use tags to group endpoints: `router = APIRouter(tags=["users"])`
- Add descriptions to route decorators
- Include examples in Pydantic models with `model_config`

**Documentation URLs:**
- Swagger UI: `http://localhost:8000/api/v1/docs`
- ReDoc: `http://localhost:8000/api/v1/redoc`
- OpenAPI JSON: `http://localhost:8000/api/v1/openapi.json`

### 6. Error Handling and Logging

For comprehensive error handling patterns, consult `references/error_handling.md`.

**Key patterns:**
- Create custom exception classes inheriting from `HTTPException`
- Implement global exception handlers for common errors
- Use structured logging with loguru
- Add request ID tracking middleware
- Log all errors with context (user ID, request ID, etc.)

**Custom exceptions:**
- `NotFoundException` - 404 errors
- `BadRequestException` - 400 errors
- `UnauthorizedException` - 401 errors
- `ForbiddenException` - 403 errors
- `ConflictException` - 409 errors

**Logging setup:**
- Configure loguru with console and file outputs
- Intercept standard logging to route through loguru
- Set appropriate log levels for third-party libraries
- Include request/response logging middleware
- Use log rotation and retention policies

### 7. Background Tasks with Celery

For background task implementation, refer to `scripts/celery_task_example.py`.

**Task patterns:**
- Simple async tasks: `@celery_app.task(name="task_name")`
- Tasks with retry logic: `@celery_app.task(bind=True, max_retries=3)`
- Task chaining: Use `chain()` to link tasks
- Periodic tasks: Configure with `@celery_app.on_after_configure.connect`
- Task monitoring: Track task status with `AsyncResult`

**When to use Celery vs FastAPI BackgroundTasks:**
- Use FastAPI BackgroundTasks for lightweight, fast operations (email notifications, logging)
- Use Celery for long-running, resource-intensive, or scheduled tasks (report generation, data processing)

**Integration with FastAPI:**
1. Create Celery app with Redis broker
2. Define tasks in separate module
3. Trigger tasks from endpoints: `task.delay(params)`
4. Provide endpoint to check task status
5. Run Celery worker: `celery -A app.tasks worker`

## Project Structure Best Practices

Follow the structure from the project template:

```
app/
├── main.py                 # Application entry point, middleware, CORS
├── core/
│   ├── config.py          # Pydantic Settings configuration
│   ├── security.py        # JWT, password hashing utilities
│   └── deps.py            # Common dependencies (DB session, current user)
├── api/
│   └── v1/
│       ├── api.py         # Router aggregation
│       └── endpoints/     # Individual route modules
├── models/                # SQLAlchemy ORM models
├── schemas/               # Pydantic request/response schemas
├── crud/                  # Database operations (separated from routes)
├── db/
│   ├── session.py         # Database engine and session factory
│   └── base.py            # Import all models for Alembic
└── utils/                 # Utility functions
```

## Advanced Patterns

### API Versioning
Version APIs using router prefixes (`/api/v1`, `/api/v2`) to maintain backward compatibility when introducing breaking changes.

### Pagination
Implement standard pagination with skip/limit parameters and return total count for client-side pagination controls.

### Filtering and Searching
Support complex filters using SQLAlchemy's `or_()`, `and_()`, and `.ilike()` for case-insensitive searches.

### Relationships and Eager Loading
Use `selectinload()` for one-to-many relationships and `joinedload()` for many-to-one to avoid N+1 queries.

### Transactions
Wrap related database operations in transactions using `async with db.begin()` or the session dependency's automatic handling.

### Testing
Write async tests using pytest-asyncio with in-memory SQLite database for fast test execution.

## Resources

### scripts/
Reusable code templates for common patterns:

- `crud_template.py` - Generic CRUD base class with full typing support
- `auth_middleware.py` - Complete JWT authentication implementation
- `celery_task_example.py` - Background task patterns and Celery configuration

These scripts can be copied directly into projects or used as reference implementations.

### references/
Comprehensive documentation for advanced patterns:

- `patterns.md` - FastAPI best practices, async patterns, dependency injection, response models, pagination, background tasks, API versioning, configuration management, and testing
- `database.md` - Async SQLAlchemy setup, model definition, query patterns, relationships, transactions, bulk operations, Alembic migrations, and connection pooling
- `authentication.md` - JWT authentication flow, OAuth2 implementation, scope-based authorization, third-party OAuth (Google, GitHub), API key authentication, and security best practices
- `error_handling.md` - Custom exceptions, global exception handlers, error response models, structured logging with loguru, request ID tracking, health checks, and Sentry integration

Load these references when implementing specific features or troubleshooting issues.

### assets/
Complete project boilerplate:

- `project-template/` - Production-ready FastAPI project with all components configured and integrated, including Docker Compose setup, example models and endpoints, and configuration files

Copy this template to bootstrap new FastAPI projects quickly.
