from fastapi import APIRouter, HTTPException, Request, status
from pydantic import BaseModel
from core.database import get_db_connection
import sqlite3
import hmac
import hashlib
import json

router = APIRouter()

class RevenueCatWebhookPayload(BaseModel):
    event: dict


@router.post("/revenuecat-webhook")
async def revenuecat_webhook(request: Request):
    """
    Secure webhook endpoint for RevenueCat to notify us of subscription events.
    Must be protected by RevenueCat webhook secret verification.
    """
    from core.config import get_settings
    settings = get_settings()

    body = await request.body()

    # Verify webhook signature if secret is configured
    if settings.revenuecat_webhook_secret:
        signature = request.headers.get("x-revenuecat-signature")
        if not signature:
            raise HTTPException(status_code=401, detail="Missing webhook signature")

        expected = hmac.new(
            settings.revenuecat_webhook_secret.encode(),
            body,
            hashlib.sha256,
        ).hexdigest()
        if not hmac.compare_digest(expected, signature):
            raise HTTPException(status_code=401, detail="Invalid webhook signature")

    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON payload")

    event_type = payload.get("event", {}).get("type")
    customer_id = payload.get("event", {}).get("app_user_id")
    is_active = payload.get("event", {}).get("is_active", False)
    expires_at = payload.get("event", {}).get("expires_at")

    if not customer_id:
        raise HTTPException(status_code=400, detail="Missing app_user_id in event")

    with get_db_connection() as conn:
        cursor = conn.cursor()
        # Find user by RevenueCat customer ID (stored in pro_subscriptions table)
        # For now, we link by email or user_id. In a real app, you'd store revenuecat_customer_id
        # For this implementation, we'll use the webhook to enable/disable Pro
        # RevenueCat passes app_user_id which we can map to our user_id
        user_id = payload.get("event", {}).get("app_user_id")

        if event_type in ["INITIAL_PURCHASE", "RENEWAL", "CANCELLATION", "UNCANCELLATION"]:
            # Upsert subscription record
            cursor.execute(
                """
                INSERT INTO pro_subscriptions (user_id, revenuecat_customer_id, is_active, expires_at)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(user_id) DO UPDATE SET
                is_active=excluded.is_active,
                expires_at=excluded.expires_at
                """,
                (user_id, customer_id, 1 if is_active else 0, expires_at),
            )

            # Update user's is_pro flag
            cursor.execute(
                "UPDATE users SET is_pro = ? WHERE id = ?",
                (1 if is_active else 0, user_id),
            )
            conn.commit()

    return {"status": "success", "event": event_type}

def check_pro_status(user_id: int) -> bool:
    """Check if a user has an active Pro subscription."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        # Check user table first (legacy)
        cursor.execute("SELECT is_pro FROM users WHERE id = ?", (user_id,))
        user = cursor.fetchone()
        if user and user["is_pro"]:
            return True

        # Check subscription table for active, non-expired
        cursor.execute(
            """
            SELECT is_active, expires_at FROM pro_subscriptions
            WHERE user_id = ?
            """,
            (user_id,),
        )
        sub = cursor.fetchone()
        if sub and sub["is_active"]:
            # Check expiration
            if sub["expires_at"]:
                from datetime import datetime
                try:
                    expires = datetime.fromisoformat(sub["expires_at"].replace("Z", "+00:00"))
                    if datetime.now(sub["expires_at"].tzinfo if hasattr(sub["expires_at"], "tzinfo") else None).replace(tzinfo=None) < expires.replace(tzinfo=None):
                        return True
                except (ValueError, TypeError):
                    pass
            else:
                return True
    return False
