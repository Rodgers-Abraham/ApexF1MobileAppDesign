import os
from pydantic_settings import BaseSettings
from pydantic import field_validator
from functools import lru_cache
from typing import Union


_BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_ENV_PATH = os.path.join(_BACKEND_DIR, ".env")


class Settings(BaseSettings):
    app_name: str = "F1 Apex API"
    app_version: str = "1.0.0"
    debug: bool = False

    # Security
    jwt_secret: str = "f1_apex_default_jwt_secret_key_change_in_production"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7

    # Database
    database_url: str = "sqlite:///./f1_app.db"

    # API Keys
    openrouter_key: str | None = None
    gemini_keys: Union[list[str], str] = []

    # CORS
    allowed_origins: str = "http://localhost:3000,http://localhost:8000,http://localhost:8080"

    # Rate Limiting
    rate_limit_default: str = "100/minute"
    rate_limit_auth: str = "10/minute"
    rate_limit_chat: str = "20/minute"

    # RevenueCat (for webhook verification)
    revenuecat_webhook_secret: str | None = None

    # Neon Services
    neon_auth_base_url: str | None = None
    neon_function_hello_base_url: str | None = None
    aws_endpoint_url_s3: str | None = None

    @field_validator("gemini_keys")
    @classmethod
    def assemble_gemini_keys(cls, v):
        if isinstance(v, str):
            v = v.strip()
            if not v:
                return []
            if v.startswith("[") and v.endswith("]"):
                try:
                    import json
                    return json.loads(v)
                except Exception:
                    pass
            return [k.strip() for k in v.split(",") if k.strip()]
        return v or []

    class Config:
        env_file = (_ENV_PATH, ".env")
        env_file_encoding = "utf-8"
        case_sensitive = False
        extra = "ignore"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
