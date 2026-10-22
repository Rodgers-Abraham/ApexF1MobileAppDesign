from fastapi import APIRouter, HTTPException, Depends, Request, status
from pydantic import BaseModel, EmailStr
from typing import Optional
from core.database import get_db_connection, DBIntegrityError
from core.auth import hash_password, verify_password, create_access_token, get_current_user
import sqlite3

router = APIRouter()

# ─── Schemas ──────────────────────────────────────────────────────────────────

class UserRegister(BaseModel):
    email: EmailStr
    password: str
    name: Optional[str] = None
    favourite_team: Optional[str] = "Ferrari"
    favourite_driver: Optional[str] = None

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class ThemeUpdate(BaseModel):
    favourite_team: str

class ProUpdate(BaseModel):
    is_pro: bool

class ProfileUpdate(BaseModel):
    name: Optional[str] = None
    favourite_driver: Optional[str] = None
    new_password: Optional[str] = None

class AuthResponse(BaseModel):
    token: str
    email: str
    name: Optional[str] = None
    favourite_team: str
    favourite_driver: Optional[str] = None
    is_pro: bool


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _build_user_dict(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "email": row["email"],
        "name": row["name"],
        "favourite_team": row["favourite_team"],
        "favourite_driver": row["favourite_driver"],
        "is_pro": bool(row["is_pro"]),
    }


def _get_user_by_email(cursor, email: str):
    cursor.execute(
        "SELECT id, email, name, favourite_team, favourite_driver, is_pro FROM users WHERE email = ?",
        (email.lower(),),
    )
    return cursor.fetchone()


# ─── Routes ───────────────────────────────────────────────────────────────────

@router.post("/register", response_model=AuthResponse)
async def register(user_in: UserRegister):
    with get_db_connection() as conn:
        cursor = conn.cursor()

        # Hash the password
        pwd_hash = hash_password(user_in.password)

        try:
            cursor.execute(
                "INSERT INTO users (email, password_hash, name, favourite_team, favourite_driver, is_pro) VALUES (?, ?, ?, ?, ?, 0)",
                (user_in.email.lower(), pwd_hash, user_in.name, user_in.favourite_team, user_in.favourite_driver),
            )
            conn.commit()
        except DBIntegrityError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"error": "Email is already registered", "code": "EMAIL_ALREADY_REGISTERED"},
            )

        # Fetch the newly created user
        cursor.execute(
            "SELECT id, email, name, favourite_team, favourite_driver, is_pro FROM users WHERE email = ?",
            (user_in.email.lower(),),
        )
        user = cursor.fetchone()

    token = create_access_token({"email": user["email"]})

    return AuthResponse(
        token=token,
        email=user["email"],
        name=user["name"],
        favourite_team=user["favourite_team"],
        favourite_driver=user["favourite_driver"],
        is_pro=bool(user["is_pro"]),
    )


@router.post("/login", response_model=AuthResponse)
async def login(user_in: UserLogin):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT id, email, password_hash, name, favourite_team, favourite_driver, is_pro FROM users WHERE email = ?",
            (user_in.email.lower(),),
        )
        user = cursor.fetchone()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "Invalid email or password", "code": "INVALID_CREDENTIALS"},
        )

    if not verify_password(user["password_hash"], user_in.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "Invalid email or password", "code": "INVALID_CREDENTIALS"},
        )

    token = create_access_token({"email": user["email"]})

    return AuthResponse(
        token=token,
        email=user["email"],
        name=user["name"],
        favourite_team=user["favourite_team"],
        favourite_driver=user["favourite_driver"],
        is_pro=bool(user["is_pro"]),
    )


@router.get("/me")
async def get_me(current_user: dict = Depends(get_current_user)):
    return {
        "email": current_user["email"],
        "name": current_user.get("name"),
        "favourite_team": current_user["favourite_team"],
        "favourite_driver": current_user.get("favourite_driver"),
        "is_pro": bool(current_user["is_pro"]),
    }


@router.put("/profile")
async def update_profile(profile_in: ProfileUpdate, current_user: dict = Depends(get_current_user)):
    with get_db_connection() as conn:
        cursor = conn.cursor()

        # Use a safe column-to-value mapping with positional params only
        updates = []
        params = []

        if profile_in.name is not None:
            updates.append("name = ?")
            params.append(profile_in.name)

        if profile_in.favourite_driver is not None:
            updates.append("favourite_driver = ?")
            params.append(profile_in.favourite_driver)

        if profile_in.new_password is not None and profile_in.new_password.strip() != "":
            pwd_hash = hash_password(profile_in.new_password)
            updates.append("password_hash = ?")
            params.append(pwd_hash)

        if not updates:
            return _build_user_dict(current_user)

        query = f"UPDATE users SET {', '.join(updates)} WHERE id = ?"
        params.append(current_user["id"])
        cursor.execute(query, tuple(params))
        conn.commit()

        # Fetch updated user
        cursor.execute(
            "SELECT id, email, name, favourite_team, favourite_driver, is_pro FROM users WHERE id = ?",
            (current_user["id"],),
        )
        user = cursor.fetchone()

    return _build_user_dict(user)


@router.put("/theme")
async def update_theme(theme_in: ThemeUpdate, current_user: dict = Depends(get_current_user)):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE users SET favourite_team = ? WHERE id = ?",
            (theme_in.favourite_team, current_user["id"]),
        )
        conn.commit()
    return {"status": "success", "favourite_team": theme_in.favourite_team}


@router.put("/pro")
async def update_pro(pro_in: ProUpdate, current_user: dict = Depends(get_current_user)):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE users SET is_pro = ? WHERE id = ?",
            (1 if pro_in.is_pro else 0, current_user["id"]),
        )
        conn.commit()
        cursor.execute(
            "SELECT id, email, name, favourite_team, favourite_driver, is_pro FROM users WHERE id = ?",
            (current_user["id"],),
        )
        user = cursor.fetchone()
    return _build_user_dict(user)


@router.delete("/delete")
async def delete_account(current_user: dict = Depends(get_current_user)):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        try:
            cursor.execute("DELETE FROM predictions WHERE user_id = ?", (current_user["id"],))
            cursor.execute("DELETE FROM pro_subscriptions WHERE user_id = ?", (current_user["id"],))
            cursor.execute("DELETE FROM users WHERE id = ?", (current_user["id"],))
            conn.commit()
        except Exception as e:
            conn.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={"error": f"Failed to delete account: {e}", "code": "DELETE_FAILED"},
            )
    return {"status": "success", "message": "Account successfully deleted"}
