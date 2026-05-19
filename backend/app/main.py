from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import chat, auth, strava as strava_api
from app.core.config import settings

app = FastAPI(title="RunSense", version="0.1.0")

default_cors_origins = {
    "http://localhost:4321",
    "http://127.0.0.1:4321",
    settings.frontend_url.rstrip("/"),
}
configured_cors_origins = {
    origin.strip().rstrip("/")
    for origin in settings.cors_origins.split(",")
    if origin.strip()
}
cors_origins = default_cors_origins | configured_cors_origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=sorted(cors_origins),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(chat.router, prefix="/api")
app.include_router(auth.router, prefix="/api/auth")
app.include_router(strava_api.router, prefix="/api/strava")
