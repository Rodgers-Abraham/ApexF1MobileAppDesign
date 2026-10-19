import os
import hashlib
import binascii
import jwt
from datetime import datetime, timedelta
from fastapi import Header, HTTPException

# Lazy import to avoid circular imports at module level
from core.config import get_settings

settings = get_settings()
JWT_SECRET = settings.jwt_secret
JWT_ALGORITHM = settings.jwt_algorithm
ACCESS_TOKEN_EXPIRE_MINUTES = settings.access_token_expire_minutes

def hash_password(password: str) -> str:
    """Hashes a password using PBKDF2 HMAC-SHA256."""
    salt = hashlib.sha256(os.urandom(60)).hexdigest().encode('utf-8')
    pwdhash = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, 100000)
    pwdhash = binascii.hexlify(pwdhash)
    return (salt + pwdhash).decode('utf-8')

def verify_password(stored_password: str, provided_password: str) -> bool:
    """Verifies a password against its stored hash."""
    salt = stored_password[:64].encode('utf-8')
    stored_hash = stored_password[64:]
    pwdhash = hashlib.pbkdf2_hmac('sha256', provided_password.encode('utf-8'), salt, 100000)
    pwdhash = binascii.hexlify(pwdhash).decode('utf-8')
    return pwdhash == stored_hash

def create_access_token(data: dict) -> str:
    """Generates a JWT access token."""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode["exp"] = expire
    encoded_jwt = jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGORITHM)
    return encoded_jwt

def decode_access_token(token: str) -> dict:
    """Decodes a JWT access token, raising error if expired/invalid."""
    try:
        decoded = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return decoded
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail={"error": "Token has expired", "code": "TOKEN_EXPIRED"})
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail={"error": "Invalid token credentials", "code": "INVALID_TOKEN"})

def get_current_user(authorization: str = Header(None)):
    """Dependency to retrieve the currently logged in user based on the Auth header."""
    from core.database import get_db_connection
    if not authorization:
        raise HTTPException(status_code=401, detail={"error": "Authorization header missing", "code": "AUTH_HEADER_MISSING"})

    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(status_code=401, detail={"error": "Invalid auth header format. Must be Bearer <token>", "code": "INVALID_AUTH_FORMAT"})

    token = parts[1]
    payload = decode_access_token(token)
    email = payload.get("email")

    if not email:
        raise HTTPException(status_code=401, detail={"error": "Invalid token payload", "code": "INVALID_PAYLOAD"})

    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT id, email, name, favourite_team, favourite_driver, is_pro FROM users WHERE email = ?", (email,))
        user = cursor.fetchone()

    if not user:
        raise HTTPException(status_code=401, detail={"error": "User no longer exists", "code": "USER_NOT_FOUND"})

    return dict(user)
