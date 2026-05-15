from fastapi import APIRouter, Depends, HTTPException
from app.tools.strava import get_recent_activities, get_personal_records, get_pace_hr_trend
from app.tools.fitness import get_fitness_metrics
from pydantic import BaseModel

router = APIRouter()


class StravaRequest(BaseModel):
    access_token: str


@router.post("/activities")
async def activities(req: StravaRequest, weeks: int = 8):
    try:
        return await get_recent_activities(req.access_token, weeks=weeks)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/trend")
async def pace_hr_trend(req: StravaRequest, weeks: int = 8):
    try:
        return await get_pace_hr_trend(req.access_token, weeks=weeks)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/stats")
async def personal_records(req: StravaRequest):
    try:
        return await get_personal_records(req.access_token)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/fitness")
async def fitness_metrics(req: StravaRequest, days: int = 56):
    try:
        return await get_fitness_metrics(req.access_token, days=days)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))