import os
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Import routes
from api.routes import auth, chatbot, predictor, sessions, telemetry, history, pro as pro_routes

# Import config & database
from core.config import get_settings
from core.database import init_db

settings = get_settings()

# Initialize database on startup and sync real F1 session data
init_db()
try:
    from services.f1_poller import f1_poller
    f1_poller.poll_jolpica_api()
except Exception as e:
    print(f"Startup F1 API poll notice: {e}")


# Rate limiter setup (in-memory storage; use Redis in production)
limiter = Limiter(key_func=get_remote_address)

app = FastAPI(
    title=settings.app_name,
    description="Backend for the F1 Apex Mobile App containing AI Reports, ML Predictor, and Chatbot",
    version=settings.app_version,
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Configure CORS with proper allowlist
origins = settings.allowed_origins if isinstance(settings.allowed_origins, list) else ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount API Routers with rate limiting
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(chatbot.router, prefix="/api", tags=["Chatbot"])
app.include_router(predictor.router, prefix="/api/predictor", tags=["ML Predictor"])
app.include_router(sessions.router, prefix="/api/sessions", tags=["Race Sessions"])
app.include_router(telemetry.router, prefix="/api/f1", tags=["F1 Dynamic Data"])
app.include_router(history.router, prefix="/api/f1/history", tags=["F1 Historical Archive"])
app.include_router(pro_routes.router, prefix="/api/pro", tags=["Pro Subscriptions"])

@app.get("/")
@app.get("/health")
def read_root():
    return {
        "status": "healthy",
        "app": settings.app_name,
        "version": settings.app_version,
    }

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Catch-all exception handler to avoid leaking internal server errors."""
    import logging
    logger = logging.getLogger(__name__)
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"error": "Internal server error", "code": "INTERNAL_ERROR"},
    )

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=settings.debug)
