"""
Strava API integration — OAuth token management + data fetching.
These functions are used both as standalone helpers and wrapped as Claude tools.
"""
import httpx
from datetime import datetime, timedelta
from typing import Optional
from urllib.parse import urlencode
from app.core.config import settings

STRAVA_BASE = "https://www.strava.com/api/v3"
STRAVA_AUTH = "https://www.strava.com/oauth"


# ── OAuth ──────────────────────────────────────────────────────────────────────

def get_auth_url(redirect_uri: Optional[str] = None, mobile: bool = False) -> str:
    scope = "activity:read_all"
    callback_url = redirect_uri or f"{settings.frontend_url}/auth/callback"
    params = urlencode({
        "client_id": settings.strava_client_id,
        "redirect_uri": callback_url,
        "response_type": "code",
        "approval_prompt": "auto",
        "scope": scope,
    })
    endpoint = "mobile/authorize" if mobile else "authorize"
    return f"{STRAVA_AUTH}/{endpoint}?{params}"


async def exchange_code(code: str, redirect_uri: Optional[str] = None) -> dict:
    """Exchange auth code for access + refresh tokens."""
    data = {
        "client_id": settings.strava_client_id,
        "client_secret": settings.strava_client_secret,
        "code": code,
        "grant_type": "authorization_code",
    }
    if redirect_uri:
        data["redirect_uri"] = redirect_uri

    async with httpx.AsyncClient() as client:
        r = await client.post(f"{STRAVA_AUTH}/token", data=data)
        r.raise_for_status()
        return r.json()


async def refresh_token(refresh_token: str) -> dict:
    async with httpx.AsyncClient() as client:
        r = await client.post(f"{STRAVA_AUTH}/token", data={
            "client_id": settings.strava_client_id,
            "client_secret": settings.strava_client_secret,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
        })
        r.raise_for_status()
        return r.json()


# ── Data fetchers (used as Claude tools) ───────────────────────────────────────

async def get_recent_activities(access_token: str, weeks: int = 8) -> list[dict]:
    """Fetch activities from the last N weeks. weeks=0 loads all available pages."""
    since = int((datetime.now() - timedelta(weeks=weeks)).timestamp()) if weeks > 0 else None
    max_pages = 20 if weeks == 0 or weeks > 16 else 1
    activities = []
    async with httpx.AsyncClient() as client:
        for page in range(1, max_pages + 1):
            params = {"per_page": 100, "page": page}
            if since is not None:
                params["after"] = since
            r = await client.get(
                f"{STRAVA_BASE}/athlete/activities",
                headers={"Authorization": f"Bearer {access_token}"},
                params=params,
            )
            r.raise_for_status()
            page_activities = r.json()
            activities.extend(page_activities)
            if len(page_activities) < 100:
                break

    cleaned = [
        {
            "id": a["id"],
            "name": a["name"],
            "date": a["start_date_local"][:10],
            "distance_km": round(a["distance"] / 1000, 2),
            "duration_min": round(a["moving_time"] / 60, 1),
            "pace_min_km": round((a["moving_time"] / 60) / (a["distance"] / 1000), 2) if a["distance"] > 0 else None,
            "avg_hr": a.get("average_heartrate"),
            "max_hr": a.get("max_heartrate"),
            "elevation_m": a.get("total_elevation_gain"),
            "summary_polyline": a.get("map", {}).get("summary_polyline"),
            "type": a["sport_type"],
        }
        for a in activities
        if a.get("sport_type") and a.get("distance") is not None and a.get("moving_time") is not None
    ]
    return cleaned


async def get_activity_splits(access_token: str, activity_id: int) -> list[dict]:
    """Fetch metric splits for one activity from Strava's detailed activity endpoint."""
    async with httpx.AsyncClient() as client:
        r = await client.get(
            f"{STRAVA_BASE}/activities/{activity_id}",
            headers={"Authorization": f"Bearer {access_token}"},
            params={"include_all_efforts": "false"},
        )
        r.raise_for_status()

    activity = r.json()
    splits = activity.get("splits_metric") or []
    cleaned = []
    for index, split in enumerate(splits, start=1):
        distance_m = split.get("distance") or 0
        moving_time = split.get("moving_time") or 0
        pace = round((moving_time / 60) / (distance_m / 1000), 2) if distance_m > 0 else None
        cleaned.append({
            "split": split.get("split") or index,
            "distance_km": round(distance_m / 1000, 2),
            "elapsed_time_sec": split.get("elapsed_time"),
            "moving_time_sec": moving_time,
            "pace_min_km": pace,
            "avg_hr": split.get("average_heartrate"),
            "elevation_difference_m": split.get("elevation_difference"),
        })
    return cleaned


async def get_personal_records(access_token: str) -> dict:
    """Fetch athlete PRs and stats."""
    async with httpx.AsyncClient() as client:
        athlete = await client.get(
            f"{STRAVA_BASE}/athlete",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        athlete.raise_for_status()
        stats = await client.get(
            f"{STRAVA_BASE}/athletes/{athlete.json()['id']}/stats",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        stats.raise_for_status()

    s = stats.json()
    return {
        "ytd_distance_km": round(s["ytd_run_totals"]["distance"] / 1000, 1),
        "ytd_runs": s["ytd_run_totals"]["count"],
        "ytd_elevation_m": s["ytd_run_totals"]["elevation_gain"],
        "all_time_distance_km": round(s["all_run_totals"]["distance"] / 1000, 1),
        "recent_4w_distance_km": round(s["recent_run_totals"]["distance"] / 1000, 1),
    }


async def get_pace_hr_trend(access_token: str, weeks: int = 8) -> list[dict]:
    """
    Calculate weekly running efficiency trend.
    Efficiency = meters per heartbeat — higher is better.
    """
    activities = await get_recent_activities(access_token, weeks=weeks)

    # Group by week
    from collections import defaultdict
    weekly: dict = defaultdict(list)
    for activity in activities:
        week = datetime.strptime(activity["date"], "%Y-%m-%d").strftime("%Y-W%W")
        if activity["avg_hr"] and activity["pace_min_km"]:
            meters_per_beat = 1000 / (activity["pace_min_km"] * activity["avg_hr"])
            weekly[week].append({
                "pace": activity["pace_min_km"],
                "hr": activity["avg_hr"],
                "efficiency": round(meters_per_beat, 2),
            })

    trend = []
    for week in sorted(weekly.keys()):
        entries = weekly[week]
        avg_pace = round(sum(e["pace"] for e in entries) / len(entries), 2)
        avg_hr = round(sum(e["hr"] for e in entries) / len(entries), 1)
        avg_eff = round(sum(e["efficiency"] for e in entries) / len(entries), 2)
        trend.append({
            "week": week,
            "avg_pace_min_km": avg_pace,
            "avg_hr": avg_hr,
            "efficiency": avg_eff,
            "efficiency_unit": "m/beat",
            "run_count": len(entries),
        })
    return trend
