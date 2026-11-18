import os

import firebase_admin
from fastapi import Header, HTTPException
from firebase_admin import auth as firebase_auth

FIREBASE_PROJECT_ID = "f1-iq-2026"


def initialize_firebase_admin() -> None:
    """Initialize Firebase Admin SDK once at startup."""
    try:
        firebase_admin.get_app()
        return
    except ValueError:
        pass

    sa_json_str = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
    if sa_json_str:
        import json

        from firebase_admin import credentials

        cred = credentials.Certificate(json.loads(sa_json_str))
        firebase_admin.initialize_app(cred)
    else:
        # CI / local dev: project-only init. verify_id_token still works because
        # it fetches Google's public keys from googleapis.com automatically.
        firebase_admin.initialize_app(options={"projectId": FIREBASE_PROJECT_ID})


def get_current_user(authorization: str = Header(None)) -> dict:
    """FastAPI dependency — verifies a Firebase ID token and returns the user row."""
    from core.database import get_db_connection

    if not authorization:
        raise HTTPException(
            status_code=401,
            detail={
                "error": "Authorization header missing",
                "code": "AUTH_HEADER_MISSING",
            },
        )

    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=401,
            detail={
                "error": "Invalid auth header format",
                "code": "INVALID_AUTH_FORMAT",
            },
        )

    token = parts[1]

    try:
        decoded = firebase_auth.verify_id_token(token)
    except firebase_auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=401,
            detail={"error": "Token has expired", "code": "TOKEN_EXPIRED"},
        )
    except (
        firebase_auth.InvalidIdTokenError,
        firebase_auth.CertificateFetchError,
    ) as exc:
        raise HTTPException(
            status_code=401,
            detail={"error": f"Invalid token: {exc}", "code": "INVALID_TOKEN"},
        )
    except Exception as exc:
        raise HTTPException(
            status_code=401,
            detail={
                "error": f"Token verification failed: {exc}",
                "code": "INVALID_TOKEN",
            },
        )

    uid = decoded.get("uid") or decoded.get("sub")
    if not uid:
        raise HTTPException(
            status_code=401,
            detail={"error": "Token has no uid", "code": "INVALID_TOKEN"},
        )

    email = decoded.get("email", "")

    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT id, email, name, favourite_team, favourite_driver, rival_driver, country, firebase_uid "
            "FROM users WHERE firebase_uid = ?",
            (uid,),
        )
        user = cursor.fetchone()

        if not user:
            # User profile lives in Firestore. Auto-create a minimal row here
            # so picks/predictions can store a FK. Profile fields come from Firestore.
            from core.database import DBIntegrityError

            try:
                cursor.execute(
                    "INSERT INTO users (firebase_uid, email, favourite_team) VALUES (?, ?, ?)",
                    (uid, email, "Ferrari"),
                )
                conn.commit()
            except DBIntegrityError:
                pass  # race condition — another request beat us

            cursor.execute(
                "SELECT id, email, name, favourite_team, favourite_driver, rival_driver, country, firebase_uid "
                "FROM users WHERE firebase_uid = ?",
                (uid,),
            )
            user = cursor.fetchone()

    if not user:
        raise HTTPException(
            status_code=401,
            detail={
                "error": "Failed to initialise user record.",
                "code": "USER_NOT_FOUND",
            },
        )

    return dict(user)
