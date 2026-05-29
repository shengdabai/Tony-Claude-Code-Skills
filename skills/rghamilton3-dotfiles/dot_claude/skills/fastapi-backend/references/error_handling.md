# Error Handling and Logging in FastAPI

## Exception Handling

### Custom Exception Classes

```python
# app/core/exceptions.py
from fastapi import HTTPException, status

class NotFoundException(HTTPException):
    """Raised when a resource is not found."""
    def __init__(self, detail: str = "Resource not found"):
        super().__init__(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=detail
        )

class BadRequestException(HTTPException):
    """Raised when request is invalid."""
    def __init__(self, detail: str = "Bad request"):
        super().__init__(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail
        )

class UnauthorizedException(HTTPException):
    """Raised when authentication fails."""
    def __init__(self, detail: str = "Unauthorized"):
        super().__init__(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
            headers={"WWW-Authenticate": "Bearer"}
        )

class ForbiddenException(HTTPException):
    """Raised when user lacks permissions."""
    def __init__(self, detail: str = "Forbidden"):
        super().__init__(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=detail
        )

class ConflictException(HTTPException):
    """Raised when there's a conflict (e.g., duplicate resource)."""
    def __init__(self, detail: str = "Conflict"):
        super().__init__(
            status_code=status.HTTP_409_CONFLICT,
            detail=detail
        )
```

### Global Exception Handlers

```python
# app/main.py
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from sqlalchemy.exc import IntegrityError
import logging

app = FastAPI()
logger = logging.getLogger(__name__)

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Handle Pydantic validation errors."""
    logger.warning(f"Validation error: {exc.errors()}")
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "detail": exc.errors(),
            "body": exc.body
        }
    )

@app.exception_handler(IntegrityError)
async def integrity_exception_handler(request: Request, exc: IntegrityError):
    """Handle database integrity errors."""
    logger.error(f"Database integrity error: {str(exc)}")
    return JSONResponse(
        status_code=status.HTTP_409_CONFLICT,
        content={
            "detail": "Database integrity error. Resource may already exist."
        }
    )

@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Catch-all for unhandled exceptions."""
    logger.exception(f"Unhandled exception: {str(exc)}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "Internal server error"
        }
    )
```

### Using Custom Exceptions in Endpoints

```python
# app/api/endpoints/users.py
from app.core.exceptions import NotFoundException, ConflictException

@router.get("/users/{user_id}")
async def get_user(
    user_id: int,
    db: AsyncSession = Depends(get_db)
):
    user = await crud.user.get(db, id=user_id)
    if not user:
        raise NotFoundException(f"User with id {user_id} not found")
    return user

@router.post("/users")
async def create_user(
    user_in: UserCreate,
    db: AsyncSession = Depends(get_db)
):
    # Check if user exists
    existing = await crud.user.get_by_email(db, email=user_in.email)
    if existing:
        raise ConflictException(f"User with email {user_in.email} already exists")

    user = await crud.user.create(db, obj_in=user_in)
    return user
```

## Error Response Models

### Standardized Error Response

```python
# app/schemas/error.py
from pydantic import BaseModel
from typing import Optional, Any

class ErrorResponse(BaseModel):
    """Standard error response."""
    detail: str
    error_code: Optional[str] = None
    field: Optional[str] = None

class ValidationErrorResponse(BaseModel):
    """Validation error response."""
    detail: list[dict[str, Any]]
    body: Optional[dict] = None

# Usage in endpoint documentation
@router.get(
    "/users/{user_id}",
    response_model=User,
    responses={
        404: {"model": ErrorResponse, "description": "User not found"},
        500: {"model": ErrorResponse, "description": "Internal server error"}
    }
)
async def get_user(user_id: int):
    pass
```

## Logging Configuration

### Structured Logging Setup

```python
# app/core/logging.py
import logging
import sys
from pathlib import Path
from loguru import logger

class InterceptHandler(logging.Handler):
    """Intercept standard logging and redirect to loguru."""
    def emit(self, record):
        try:
            level = logger.level(record.levelname).name
        except ValueError:
            level = record.levelno

        frame, depth = logging.currentframe(), 2
        while frame.f_code.co_filename == logging.__file__:
            frame = frame.f_back
            depth += 1

        logger.opt(depth=depth, exception=record.exc_info).log(
            level, record.getMessage()
        )

def setup_logging(log_level: str = "INFO", log_file: Path = None):
    """Configure application logging."""
    # Remove default logger
    logger.remove()

    # Add console logger with formatting
    logger.add(
        sys.stdout,
        format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>",
        level=log_level,
        colorize=True
    )

    # Add file logger if specified
    if log_file:
        logger.add(
            log_file,
            format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {name}:{function}:{line} - {message}",
            level=log_level,
            rotation="500 MB",
            retention="10 days",
            compression="zip"
        )

    # Intercept standard logging
    logging.basicConfig(handlers=[InterceptHandler()], level=0)

    # Set levels for third-party libraries
    logging.getLogger("uvicorn").setLevel(logging.INFO)
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)

# app/main.py
from app.core.logging import setup_logging

setup_logging(log_level="INFO", log_file=Path("logs/app.log"))
```

### Logging in Application Code

```python
# app/api/endpoints/users.py
from loguru import logger

@router.post("/users")
async def create_user(
    user_in: UserCreate,
    db: AsyncSession = Depends(get_db)
):
    logger.info(f"Creating user with email: {user_in.email}")

    try:
        user = await crud.user.create(db, obj_in=user_in)
        logger.info(f"User created successfully: {user.id}")
        return user
    except Exception as e:
        logger.error(f"Failed to create user: {str(e)}")
        raise
```

### Request/Response Logging Middleware

```python
# app/middleware/logging.py
import time
from fastapi import Request
from loguru import logger
from starlette.middleware.base import BaseHTTPMiddleware

class LoggingMiddleware(BaseHTTPMiddleware):
    """Log all requests and responses."""

    async def dispatch(self, request: Request, call_next):
        # Log request
        logger.info(
            f"Request: {request.method} {request.url.path} "
            f"from {request.client.host}"
        )

        # Time the request
        start_time = time.time()

        # Process request
        try:
            response = await call_next(request)
            process_time = time.time() - start_time

            # Log response
            logger.info(
                f"Response: {response.status_code} "
                f"in {process_time:.2f}s"
            )

            # Add timing header
            response.headers["X-Process-Time"] = str(process_time)
            return response

        except Exception as e:
            process_time = time.time() - start_time
            logger.error(
                f"Request failed: {request.method} {request.url.path} "
                f"in {process_time:.2f}s - {str(e)}"
            )
            raise

# app/main.py
from app.middleware.logging import LoggingMiddleware

app.add_middleware(LoggingMiddleware)
```

## Request ID Tracking

### Middleware for Request Tracking

```python
# app/middleware/request_id.py
import uuid
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

class RequestIDMiddleware(BaseHTTPMiddleware):
    """Add unique request ID to each request."""

    async def dispatch(self, request: Request, call_next):
        # Generate or get request ID
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))

        # Store in request state
        request.state.request_id = request_id

        # Process request
        response = await call_next(request)

        # Add to response headers
        response.headers["X-Request-ID"] = request_id

        return response

# Usage in logging
from fastapi import Request

@router.get("/users")
async def list_users(request: Request):
    request_id = request.state.request_id
    logger.info(f"[{request_id}] Listing users")
    # ...
```

## Health Check and Monitoring

### Health Check Endpoint

```python
# app/api/endpoints/health.py
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.api import deps

router = APIRouter()

@router.get("/health")
async def health_check():
    """Basic health check."""
    return {"status": "healthy"}

@router.get("/health/db")
async def health_check_db(db: AsyncSession = Depends(deps.get_db)):
    """Health check including database connectivity."""
    try:
        await db.execute("SELECT 1")
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        logger.error(f"Database health check failed: {str(e)}")
        return {
            "status": "unhealthy",
            "database": "disconnected",
            "error": str(e)
        }
```

## Error Tracking Integration

### Sentry Integration

```python
# app/main.py
import sentry_sdk
from sentry_sdk.integrations.asgi import SentryAsgiMiddleware
from app.core.config import settings

if settings.SENTRY_DSN:
    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        environment=settings.ENVIRONMENT,
        traces_sample_rate=1.0,
    )
    app.add_middleware(SentryAsgiMiddleware)
```

## Best Practices

1. **Use appropriate HTTP status codes** - Follow REST conventions
2. **Provide meaningful error messages** - Help clients understand what went wrong
3. **Log errors with context** - Include request ID, user ID, etc.
4. **Don't expose internal errors** - Return generic messages to clients
5. **Use structured logging** - Makes log analysis easier
6. **Implement request tracing** - Track requests across services
7. **Monitor error rates** - Set up alerts for unusual error patterns
8. **Handle async exceptions** - Properly catch and log exceptions in async code
9. **Validate early** - Use Pydantic models to validate input
10. **Document error responses** - Include error examples in API documentation
