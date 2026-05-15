from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from app.tools.strava import get_auth_url, exchange_code, refresh_token

router = APIRouter()


class CallbackRequest(BaseModel):
    code: str


class RefreshRequest(BaseModel):
    refresh_token: str


@router.get("/strava/url")
def strava_auth_url(redirect_uri: str | None = Query(default=None)):
    return {"url": get_auth_url(redirect_uri)}


@router.post("/strava/callback")
async def strava_callback(req: CallbackRequest):
    try:
        tokens = await exchange_code(req.code)
        return tokens
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/strava/refresh")
async def strava_refresh(req: RefreshRequest):
    try:
        tokens = await refresh_token(req.refresh_token)
        return tokens
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
