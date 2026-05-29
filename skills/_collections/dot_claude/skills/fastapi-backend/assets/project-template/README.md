# FastAPI Backend Template

A production-ready FastAPI backend template with async SQLAlchemy, JWT authentication, and Celery.

## Features

- FastAPI with async/await
- SQLAlchemy 2.0 with async support
- JWT authentication with refresh tokens
- Pydantic v2 for validation
- Alembic for database migrations
- Celery for background tasks
- Docker Compose for local development
- OpenAPI documentation

## Quick Start

### Local Development

1. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Create `.env` file from `.env.example`:
```bash
cp .env.example .env
# Edit .env with your settings
```

4. Run with Docker Compose:
```bash
docker-compose up
```

5. Access API documentation:
- Swagger UI: http://localhost:8000/api/v1/docs
- ReDoc: http://localhost:8000/api/v1/redoc

### Database Migrations

Initialize Alembic (first time only):
```bash
alembic init alembic
```

Create migration:
```bash
alembic revision --autogenerate -m "Description"
```

Apply migrations:
```bash
alembic upgrade head
```

## Project Structure

```
app/
├── main.py              # Application entry point
├── core/
│   ├── config.py       # Settings
│   ├── security.py     # Security utilities
│   └── deps.py         # Dependencies
├── api/
│   └── v1/
│       ├── api.py      # API router
│       └── endpoints/  # Route handlers
├── models/             # SQLAlchemy models
├── schemas/            # Pydantic schemas
├── crud/               # CRUD operations
└── db/                 # Database configuration
```

## Testing

Run tests:
```bash
pytest
```

With coverage:
```bash
pytest --cov=app tests/
```

## Code Quality

Format code:
```bash
ruff format .
```

Lint code:
```bash
ruff check .
```

Type check:
```bash
mypy app
```
