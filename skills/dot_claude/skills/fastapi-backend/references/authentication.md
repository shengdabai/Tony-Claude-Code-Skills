# Authentication Patterns for FastAPI

## JWT Authentication Flow

### Overview

1. User sends credentials (username/password)
2. Server validates credentials
3. Server generates JWT access token and refresh token
4. Client stores tokens
5. Client includes access token in Authorization header for protected routes
6. Server validates token on each request
7. Client uses refresh token to get new access token when it expires

## Implementation

### Settings Configuration

```python
# app/core/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    SECRET_KEY: str  # Load from environment, use strong random string
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    class Config:
        env_file = ".env"

settings = Settings()
```

### Password Hashing

```python
# app/core/security.py
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    """Generate password hash."""
    return pwd_context.hash(password)
```

### Token Creation

```python
# app/core/security.py
from datetime import datetime, timedelta
from jose import jwt
from app.core.config import settings

def create_access_token(subject: str, scopes: list[str] = None) -> str:
    """Create JWT access token."""
    expire = datetime.utcnow() + timedelta(
        minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    to_encode = {
        "exp": expire,
        "sub": str(subject),
        "type": "access",
        "scopes": scopes or []
    }
    encoded_jwt = jwt.encode(
        to_encode,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )
    return encoded_jwt

def create_refresh_token(subject: str) -> str:
    """Create JWT refresh token."""
    expire = datetime.utcnow() + timedelta(
        days=settings.REFRESH_TOKEN_EXPIRE_DAYS
    )
    to_encode = {
        "exp": expire,
        "sub": str(subject),
        "type": "refresh"
    }
    encoded_jwt = jwt.encode(
        to_encode,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )
    return encoded_jwt
```

### Login Endpoint

```python
# app/api/endpoints/auth.py
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from app.api import deps
from app import crud
from app.core import security
from app.schemas.token import Token

router = APIRouter()

@router.post("/login", response_model=Token)
async def login(
    db: AsyncSession = Depends(deps.get_db),
    form_data: OAuth2PasswordRequestForm = Depends()
):
    """OAuth2 compatible token login."""
    # Authenticate user
    user = await crud.user.authenticate(
        db,
        email=form_data.username,
        password=form_data.password
    )

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive user"
        )

    # Create tokens
    access_token = security.create_access_token(
        subject=user.id,
        scopes=["user"] + (["admin"] if user.is_superuser else [])
    )
    refresh_token = security.create_refresh_token(subject=user.id)

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer"
    }
```

### User Authentication in CRUD

```python
# app/crud/crud_user.py
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.security import verify_password
from app.models.user import User

async def authenticate(
    db: AsyncSession,
    *,
    email: str,
    password: str
) -> Optional[User]:
    """Authenticate user by email and password."""
    result = await db.execute(
        select(User).where(User.email == email)
    )
    user = result.scalar_one_or_none()

    if not user:
        return None
    if not verify_password(password, user.hashed_password):
        return None
    return user
```

### Protected Route Dependencies

```python
# app/api/deps.py
from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app import crud
from app.models.user import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

async def get_current_user(
    db: AsyncSession = Depends(get_db),
    token: str = Depends(oauth2_scheme)
) -> User:
    """Get current authenticated user from JWT token."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        user_id: str = payload.get("sub")
        token_type: str = payload.get("type")

        if user_id is None or token_type != "access":
            raise credentials_exception

    except JWTError:
        raise credentials_exception

    user = await crud.user.get(db, id=int(user_id))
    if user is None:
        raise credentials_exception

    return user

async def get_current_active_user(
    current_user: User = Depends(get_current_user),
) -> User:
    """Get current active user."""
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive user"
        )
    return current_user

async def get_current_superuser(
    current_user: User = Depends(get_current_user),
) -> User:
    """Get current superuser."""
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough privileges"
        )
    return current_user
```

### Refresh Token Endpoint

```python
# app/api/endpoints/auth.py
from app.schemas.token import TokenRefresh

@router.post("/refresh", response_model=Token)
async def refresh_token(
    db: AsyncSession = Depends(deps.get_db),
    refresh_token: TokenRefresh = None
):
    """Get new access token using refresh token."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
    )

    try:
        payload = jwt.decode(
            refresh_token.refresh_token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        user_id: str = payload.get("sub")
        token_type: str = payload.get("type")

        if user_id is None or token_type != "refresh":
            raise credentials_exception

    except JWTError:
        raise credentials_exception

    user = await crud.user.get(db, id=int(user_id))
    if not user or not user.is_active:
        raise credentials_exception

    # Create new access token
    access_token = security.create_access_token(
        subject=user.id,
        scopes=["user"] + (["admin"] if user.is_superuser else [])
    )

    return {
        "access_token": access_token,
        "token_type": "bearer"
    }
```

## OAuth2 with Scopes

### Scope-Based Authorization

```python
# app/api/deps.py
from fastapi import Security

def require_scopes(required_scopes: list[str]):
    """Factory for scope-based authorization."""
    async def check_scopes(
        db: AsyncSession = Depends(get_db),
        token: str = Depends(oauth2_scheme)
    ):
        # Decode token
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        token_scopes = payload.get("scopes", [])

        # Check scopes
        for scope in required_scopes:
            if scope not in token_scopes:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Missing required scope: {scope}"
                )

        # Get and return user
        user_id = int(payload.get("sub"))
        user = await crud.user.get(db, id=user_id)
        return user

    return check_scopes

# Usage in endpoints
@router.delete("/admin/users/{user_id}")
async def delete_user(
    user_id: int,
    db: AsyncSession = Depends(deps.get_db),
    current_user: User = Depends(require_scopes(["admin"]))
):
    await crud.user.delete(db, id=user_id)
    return {"message": "User deleted"}
```

## Third-Party OAuth2 (Google, GitHub, etc.)

### Using Authlib

```python
# app/core/oauth.py
from authlib.integrations.starlette_client import OAuth
from app.core.config import settings

oauth = OAuth()

# Register Google OAuth
oauth.register(
    name='google',
    client_id=settings.GOOGLE_CLIENT_ID,
    client_secret=settings.GOOGLE_CLIENT_SECRET,
    server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
    client_kwargs={
        'scope': 'openid email profile'
    }
)

# Register GitHub OAuth
oauth.register(
    name='github',
    client_id=settings.GITHUB_CLIENT_ID,
    client_secret=settings.GITHUB_CLIENT_SECRET,
    authorize_url='https://github.com/login/oauth/authorize',
    access_token_url='https://github.com/login/oauth/access_token',
    api_base_url='https://api.github.com/',
    client_kwargs={'scope': 'user:email'},
)
```

### OAuth2 Endpoints

```python
# app/api/endpoints/oauth.py
from fastapi import APIRouter, Request
from app.core.oauth import oauth

router = APIRouter()

@router.get("/login/google")
async def google_login(request: Request):
    """Redirect to Google OAuth."""
    redirect_uri = request.url_for('google_callback')
    return await oauth.google.authorize_redirect(request, redirect_uri)

@router.get("/callback/google")
async def google_callback(request: Request, db: AsyncSession = Depends(deps.get_db)):
    """Handle Google OAuth callback."""
    token = await oauth.google.authorize_access_token(request)
    user_info = token.get('userinfo')

    # Find or create user
    user = await crud.user.get_by_email(db, email=user_info['email'])
    if not user:
        user = await crud.user.create(db, obj_in={
            'email': user_info['email'],
            'full_name': user_info.get('name'),
            'is_active': True
        })

    # Create JWT tokens
    access_token = security.create_access_token(subject=user.id)
    refresh_token = security.create_refresh_token(subject=user.id)

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer"
    }
```

## API Key Authentication

### Alternative to JWT for service-to-service communication

```python
# app/models/api_key.py
from sqlalchemy import Column, String, Boolean, ForeignKey
from app.models.base import BaseModel

class APIKey(BaseModel):
    __tablename__ = "api_keys"

    key = Column(String, unique=True, index=True, nullable=False)
    name = Column(String)  # Descriptive name
    is_active = Column(Boolean, default=True)
    user_id = Column(Integer, ForeignKey("users.id"))

# app/api/deps.py
from fastapi import Header, HTTPException

async def get_api_key(
    x_api_key: str = Header(...),
    db: AsyncSession = Depends(get_db)
) -> APIKey:
    """Validate API key from header."""
    api_key = await crud.api_key.get_by_key(db, key=x_api_key)

    if not api_key or not api_key.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key"
        )

    return api_key

# Usage
@router.get("/service/data")
async def get_service_data(
    api_key: APIKey = Depends(get_api_key)
):
    return {"data": "protected data"}
```

## Security Best Practices

1. **Use strong secret keys** - Generate cryptographically secure random strings
2. **Store secrets in environment variables** - Never commit secrets to version control
3. **Use HTTPS only** - Tokens should never be transmitted over HTTP
4. **Implement token expiration** - Short-lived access tokens, longer refresh tokens
5. **Validate token type** - Ensure access tokens aren't used as refresh tokens
6. **Rate limit authentication endpoints** - Prevent brute force attacks
7. **Hash passwords properly** - Use bcrypt or argon2
8. **Implement logout** - Token blacklisting or short expiration
9. **Use CORS properly** - Restrict origins in production
10. **Audit authentication events** - Log successful and failed login attempts
