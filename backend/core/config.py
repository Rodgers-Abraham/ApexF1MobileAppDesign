import os
from pydantic_settings import BaseSettings
from functools import lru_cache


_BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_ENV_PATH = os.path.join(_BACKEND_DIR, ".env")


class Settings(BaseSettings):
    app_name: str = "F1 Apex API"
    app_version: str = "1.0.0"
    debug: bool = False

    # Security
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7

    # Database
    database_url: str = "sqlite:///./f1_app.db"

    # API Keys
    openrouter_key: str | None = None
    gemini_keys: list[str] = []

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

    class Config:
        env_file = (_ENV_PATH, ".env")
        env_file_encoding = "utf-8"
        case_sensitive = False
        extra = "ignore"

        @classmethod
        def parse_env_var(cls, field_name: str, raw_val: str) -> any:
            if field_name == "gemini_keys":
                return [k.strip() for k in raw_val.split(",") if k.strip()]
            if field_name == "allowed_origins":
                return [o.strip() for o in raw_val.split(",") if o.strip()]
            return cls.json_loads(raw_val)


@lru_cache()
def get_settings() -> Settings:
    return Settings()
