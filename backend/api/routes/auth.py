from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel
from typing import Optional
from core.database import get_db_connection, DBIntegrityError
from core.auth import get_current_user

router = APIRouter()

# ─── Schemas ──────────────────────────────────────────────────────────────────


class ThemeUpdate(BaseModel):
    favourite_team: str


class ProfileUpdate(BaseModel):
    name: Optional[str] = None
    favourite_driver: Optional[str] = None
    rival_driver: Optional[str] = None
    country: Optional[str] = None


# ─── Helpers ──────────────────────────────────────────────────────────────────


def _build_user_dict(row) -> dict:
    keys = row.keys() if hasattr(row, "keys") else row.keys()
    return {
        "id": row["id"],
        "email": row["email"],
        "name": row["name"],
        "favourite_team": row["favourite_team"],
        "favourite_driver": row["favourite_driver"],
        "rival_driver": row["rival_driver"] if "rival_driver" in keys else None,
        "country": row["country"] if "country" in keys else None,
    }


# ─── Routes ───────────────────────────────────────────────────────────────────


@router.get("/me")
async def get_me(current_user: dict = Depends(get_current_user)):
    return {
        "email": current_user["email"],
        "name": current_user.get("name"),
        "favourite_team": current_user["favourite_team"],
        "favourite_driver": current_user.get("favourite_driver"),
        "rival_driver": current_user.get("rival_driver"),
        "country": current_user.get("country"),
    }


@router.put("/profile")
async def update_profile(
    profile_in: ProfileUpdate, current_user: dict = Depends(get_current_user)
):
    with get_db_connection() as conn:
        cursor = conn.cursor()

        updates = []
        params = []

        if profile_in.name is not None:
            updates.append("name = ?")
            params.append(profile_in.name)

        if profile_in.favourite_driver is not None:
            updates.append("favourite_driver = ?")
            params.append(profile_in.favourite_driver)

        if profile_in.rival_driver is not None:
            updates.append("rival_driver = ?")
            params.append(profile_in.rival_driver)

        if profile_in.country is not None:
            updates.append("country = ?")
            params.append(profile_in.country)

        if not updates:
            return _build_user_dict(current_user)

        query = f"UPDATE users SET {', '.join(updates)} WHERE id = ?"
        params.append(current_user["id"])
        cursor.execute(query, tuple(params))
        conn.commit()

        cursor.execute(
            "SELECT id, email, name, favourite_team, favourite_driver, rival_driver, country "
            "FROM users WHERE id = ?",
            (current_user["id"],),
        )
        user = cursor.fetchone()

    return _build_user_dict(user)


@router.put("/theme")
async def update_theme(
    theme_in: ThemeUpdate, current_user: dict = Depends(get_current_user)
):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE users SET favourite_team = ? WHERE id = ?",
            (theme_in.favourite_team, current_user["id"]),
        )
        conn.commit()
    return {"status": "success", "favourite_team": theme_in.favourite_team}


@router.delete("/delete")
async def delete_account(current_user: dict = Depends(get_current_user)):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "DELETE FROM user_race_picks WHERE user_id = ?", (current_user["id"],)
            )
            cursor.execute(
                "DELETE FROM pro_subscriptions WHERE user_id = ?", (current_user["id"],)
            )
            cursor.execute(
                "DELETE FROM predictions WHERE user_id = ?", (current_user["id"],)
            )
            cursor.execute("DELETE FROM users WHERE id = ?", (current_user["id"],))
            conn.commit()
        except Exception as e:
            conn.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={
                    "error": f"Failed to delete account: {e}",
                    "code": "DELETE_FAILED",
                },
            )
    return {"status": "success", "message": "Account successfully deleted"}


# ─── Firebase Auth ─────────────────────────────────────────────────────────────


class FirebaseAuthRequest(BaseModel):
    firebase_token: str
    name: Optional[str] = None
    favourite_team: Optional[str] = "Ferrari"
    favourite_driver: Optional[str] = None
    rival_driver: Optional[str] = None
    country: Optional[str] = None


@router.post("/firebase")
async def firebase_auth(req: FirebaseAuthRequest):
    from firebase_admin import auth as firebase_auth_sdk

    try:
        decoded = firebase_auth_sdk.verify_id_token(req.firebase_token)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": str(e), "code": "INVALID_FIREBASE_TOKEN"},
        )

    uid = decoded.get("uid") or decoded.get("sub")
    email = decoded.get("email", "")

    with get_db_connection() as conn:
        cursor = conn.cursor()

        cursor.execute(
            "SELECT id, email, name, favourite_team, favourite_driver, rival_driver, country "
            "FROM users WHERE firebase_uid = ?",
            (uid,),
        )
        user = cursor.fetchone()

        if not user:
            # Try to find by email (linking old account)
            cursor.execute(
                "SELECT id, email, name, favourite_team, favourite_driver, rival_driver, country "
                "FROM users WHERE email = ?",
                (email.lower(),),
            )
            existing_by_email = cursor.fetchone()

            if existing_by_email:
                cursor.execute(
                    "UPDATE users SET firebase_uid = ? WHERE email = ?",
                    (uid, email.lower()),
                )
                conn.commit()
                user = existing_by_email
            else:
                try:
                    cursor.execute(
                        "INSERT INTO users "
                        "(firebase_uid, email, name, favourite_team, favourite_driver, rival_driver, country) "
                        "VALUES (?, ?, ?, ?, ?, ?, ?)",
                        (
                            uid,
                            email.lower(),
                            req.name,
                            req.favourite_team or "Ferrari",
                            req.favourite_driver,
                            req.rival_driver,
                            req.country,
                        ),
                    )
                    conn.commit()
                    cursor.execute(
                        "SELECT id, email, name, favourite_team, favourite_driver, rival_driver, country "
                        "FROM users WHERE firebase_uid = ?",
                        (uid,),
                    )
                    user = cursor.fetchone()
                except DBIntegrityError:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail={
                            "error": "Account creation failed.",
                            "code": "CREATE_FAILED",
                        },
                    )
        else:
            updates, params = [], []
            if req.name:
                updates.append("name = ?")
                params.append(req.name)
            if req.favourite_team and req.favourite_team != "Ferrari":
                updates.append("favourite_team = ?")
                params.append(req.favourite_team)
            if req.rival_driver:
                updates.append("rival_driver = ?")
                params.append(req.rival_driver)
            if req.country:
                updates.append("country = ?")
                params.append(req.country)
            if updates:
                params.append(uid)
                cursor.execute(
                    f"UPDATE users SET {', '.join(updates)} WHERE firebase_uid = ?",
                    tuple(params),
                )
                conn.commit()
                cursor.execute(
                    "SELECT id, email, name, favourite_team, favourite_driver, rival_driver, country "
                    "FROM users WHERE firebase_uid = ?",
                    (uid,),
                )
                user = cursor.fetchone()

    rival_val = user["rival_driver"] if "rival_driver" in user.keys() else None
    country_val = user["country"] if "country" in user.keys() else None
    return {
        "email": user["email"] or email,
        "name": user["name"],
        "favourite_team": user["favourite_team"] or "Ferrari",
        "favourite_driver": user["favourite_driver"],
        "rival_driver": rival_val,
        "country": country_val,
    }
