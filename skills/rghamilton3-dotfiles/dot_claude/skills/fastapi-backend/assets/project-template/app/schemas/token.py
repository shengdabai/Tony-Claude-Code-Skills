"""
Token Pydantic Schemas
"""
from pydantic import BaseModel


class Token(BaseModel):
    """Token response schema."""
    access_token: str
    token_type: str = "bearer"
    refresh_token: str | None = None


class TokenData(BaseModel):
    """Token data schema."""
    username: str | None = None
    scopes: list[str] = []
