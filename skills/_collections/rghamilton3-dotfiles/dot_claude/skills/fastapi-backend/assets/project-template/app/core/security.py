"""
Security Utilities
"""
from datetime import datetime, timedelta
from typing import Optional
import jwt
from jwt.exceptions import InvalidTokenError
from passlib.context import CryptContext
from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Generate password hash."""
    return pwd_context.hash(password)


def create_access_token(subject: str, scopes: list = None) -> str:
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
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_refresh_token(subject: str) -> str:
    """Create JWT refresh token."""
    expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode = {"exp": expire, "sub": str(subject), "type": "refresh"}
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_token(token: str) -> dict:
    """Verify a token using configured keys and the local-token claim policy."""
    key = jwt.get_algorithm_by_name(settings.ALGORITHM).prepare_key(settings.SECRET_KEY)
    # Private asymmetric keys sign tokens; their public half verifies them.
    if hasattr(key, "public_key"):
        key = key.public_key()
    payload = jwt.decode(token, key, algorithms=[settings.ALGORITHM])
    # No audience or OpenID access token is configured for these tokens.
    if "aud" in payload or "at_hash" in payload:
        raise InvalidTokenError("Unsupported audience or access-token hash")
    return payload
