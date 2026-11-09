import os
import hashlib
import binascii
import time
import requests
import jwt
from datetime import datetime, timedelta
from fastapi import Header, HTTPException
from cryptography.x509 import load_pem_x509_certificate
from cryptography.hazmat.backends import default_backend

from core.config import get_settings

settings = get_settings()
JWT_SECRET = settings.jwt_secret
JWT_ALGORITHM = settings.jwt_algorithm
ACCESS_TOKEN_EXPIRE_MINUTES = settings.access_token_expire_minutes

FIREBASE_PROJECT_ID = "f1-iq-2026"
_key_cache: dict = {"keys": {}, "exp": 0.0}


# ------------------------------------------------------------------
# Password helpers (kept for backward compat with old accounts)
# ------------------------------------------------------------------

def hash_password(password: str) -> str:
    salt = hashlib.sha256(os.urandom(60)).hexdigest().encode("utf-8")
    pwdhash = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, 100000)
    pwdhash = binascii.hexlify(pwdhash)
    return (salt + pwdhash).decode("utf-8")


def verify_password(stored_password: str, provided_password: str) -> bool:
    salt = stored_password[:64].encode("utf-8")
    stored_hash = stored_password[64:]
    pwdhash = hashlib.pbkdf2_hmac(
        "sha256", provided_password.encode("utf-8"), salt, 100000
    )
    pwdhash = binascii.hexlify(pwdhash).decode("utf-8")
    return pwdhash == stored_hash


# ------------------------------------------------------------------
# Legacy JWT helpers (kept for backward compat)
# ------------------------------------------------------------------

def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode["exp"] = expire
    return jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> dict:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=401, detail={"error": "Token has expired", "code": "TOKEN_EXPIRED"}
        )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=401, detail={"error": "Invalid token", "code": "INVALID_TOKEN"}
        )


# ------------------------------------------------------------------
# Firebase token verification
# ------------------------------------------------------------------

def _firebase_public_keys() -> dict:
    global _key_cache
    if time.time() < _key_cache["exp"] and _key_cache["keys"]:
        return _key_cache["keys"]
    try:
        resp = requests.get(
            "https://www.googleapis.com/robot/v1/metadata/x509/"
            "securetoken@system.gserviceaccount.com",
            timeout=5,
        )
        keys = resp.json()
        max_age = 3600
        for part in resp.headers.get("Cache-Control", "").split(","):
            if "max-age" in part:
                try:
                    max_age = int(part.split("=")[1].strip())
                except (ValueError, IndexError):
                    pass
        _key_cache = {"keys": keys, "exp": time.time() + max_age}
        return keys
    except Exception as e:
        print(f"Firebase public key fetch error: {e}")
        return _key_cache.get("keys", {})


def verify_firebase_token(id_token: str) -> dict:
    keys = _firebase_public_keys()
    header = jwt.get_unverified_header(id_token)
    kid = header.get("kid")
    if not kid or kid not in keys:
        raise ValueError(f"Unknown key ID: {kid}")
    cert = load_pem_x509_certificate(keys[kid].encode(), default_backend())
    decoded = jwt.decode(
        id_token,
        cert.public_key(),
        algorithms=["RS256"],
        audience=FIREBASE_PROJECT_ID,
        options={"verify_exp": True},
    )
    if decoded.get("iss") != f"https://securetoken.google.com/{FIREBASE_PROJECT_ID}":
        raise ValueError("Invalid token issuer")
    return decoded


# ------------------------------------------------------------------
# FastAPI dependency — accepts Firebase ID tokens
# ------------------------------------------------------------------

def get_current_user(authorization: str = Header(None)):
    from core.database import get_db_connection

    if not authorization:
        raise HTTPException(
            status_code=401,
            detail={"error": "Authorization header missing", "code": "AUTH_HEADER_MISSING"},
        )

    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=401,
            detail={"error": "Invalid auth header format", "code": "INVALID_AUTH_FORMAT"},
        )

    token = parts[1]

    # Try Firebase token first
    try:
        decoded = verify_firebase_token(token)
        uid = decoded.get("uid") or decoded.get("sub")
        email = decoded.get("email", "")

        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT id, email, name, favourite_team, favourite_driver, country, firebase_uid "
                "FROM users WHERE firebase_uid = ?",
                (uid,),
            )
            user = cursor.fetchone()

        if not user:
            raise HTTPException(
                status_code=401,
                detail={
                    "error": "User profile not found. Please register.",
                    "code": "USER_NOT_FOUND",
                },
            )
        return dict(user)

    except HTTPException:
        raise
    except Exception as firebase_err:
        # Fall back to legacy JWT for old sessions
        try:
            payload = decode_access_token(token)
            legacy_email = payload.get("email")
            if not legacy_email:
                raise HTTPException(
                    status_code=401,
                    detail={"error": "Invalid token payload", "code": "INVALID_PAYLOAD"},
                )
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    "SELECT id, email, name, favourite_team, favourite_driver, country "
                    "FROM users WHERE email = ?",
                    (legacy_email,),
                )
                user = cursor.fetchone()
            if not user:
                raise HTTPException(
                    status_code=401,
                    detail={"error": "User not found", "code": "USER_NOT_FOUND"},
                )
            return dict(user)
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(
                status_code=401,
                detail={
                    "error": f"Invalid token: {firebase_err}",
                    "code": "INVALID_TOKEN",
                },
            )
