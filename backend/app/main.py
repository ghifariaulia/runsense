from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import chat, auth, strava as strava_api

app = FastAPI(title="RunSense", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:4321"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(chat.router, prefix="/api")
app.include_router(auth.router, prefix="/api/auth")
app.include_router(strava_api.router, prefix="/api/strava")