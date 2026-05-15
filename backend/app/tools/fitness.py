"""
Training load estimates derived purely from Strava data.
We approximate CTL/ATL/TSB using Training Stress Score (TSS) estimates
calculated from pace + heart rate — no third-party service needed.

TSS estimate per activity = (duration_hours * avg_hr / threshold_hr)^2 * 100
This is a simplification of the Coggan TSS formula, good enough for trends.
"""
from datetime import datetime, timedelta
from collections import defaultdict
from app.tools.strava import get_recent_activities

# Assume threshold HR of 170 if unknown (user can override later)
DEFAULT_THRESHOLD_HR = 170


def estimate_tss(duration_min: float, avg_hr: float, threshold_hr: float = DEFAULT_THRESHOLD_HR) -> float:
    """Rough TSS estimate from duration and HR."""
    intensity_factor = avg_hr / threshold_hr
    hours = duration_min / 60
    return round((hours * intensity_factor ** 2) * 100, 1)


async def get_fitness_metrics(access_token: str, days: int = 56) -> dict:
    """
    Estimate CTL (fitness), ATL (fatigue), TSB (form) from Strava activities.
    
    CTL = 42-day exponential weighted average of daily TSS
    ATL = 7-day exponential weighted average of daily TSS
    TSB = CTL - ATL (positive = fresh, negative = fatigued)
    """
    activities = await get_recent_activities(access_token, weeks=max(days // 7, 12))

    # Build daily TSS map
    daily_tss: dict = defaultdict(float)
    for activity in activities:
        if activity["avg_hr"] and activity["duration_min"]:
            tss = estimate_tss(activity["duration_min"], activity["avg_hr"])
            daily_tss[activity["date"]] += tss

    # Generate date range
    today = datetime.now().date()
    date_range = [(today - timedelta(days=i)).isoformat() for i in range(days, -1, -1)]

    # Compute CTL (42d) and ATL (7d) using exponential decay
    ctl_decay = 1 - 1 / 42
    atl_decay = 1 - 1 / 7
    ctl = atl = 0.0
    trend = []

    for date in date_range:
        tss = daily_tss.get(date, 0.0)
        ctl = ctl * ctl_decay + tss * (1 - ctl_decay)
        atl = atl * atl_decay + tss * (1 - atl_decay)
        tsb = ctl - atl
        trend.append({
            "date": date,
            "ctl": round(ctl, 1),
            "atl": round(atl, 1),
            "tsb": round(tsb, 1),
            "tss": round(tss, 1),
        })

    latest = trend[-1]
    four_weeks_ago = trend[-28] if len(trend) >= 28 else trend[0]

    return {
        "current": {
            "date": latest["date"],
            "ctl": latest["ctl"],
            "atl": latest["atl"],
            "tsb": latest["tsb"],
        },
        "four_weeks_ago": {
            "date": four_weeks_ago["date"],
            "ctl": four_weeks_ago["ctl"],
        },
        "ctl_change": round(latest["ctl"] - four_weeks_ago["ctl"], 1),
        "trend": trend[-28:],  # last 4 weeks for charting
        "interpretation": _interpret(latest["tsb"], latest["ctl"], four_weeks_ago["ctl"]),
        "note": "CTL/ATL estimated from Strava HR + duration data (Coggan TSS approximation).",
    }


def _interpret(tsb: float, ctl_now: float, ctl_4w: float) -> str:
    form = "fresh" if tsb > 5 else "significantly fatigued" if tsb < -20 else "in training load zone"
    trend = "improving" if ctl_now > ctl_4w + 2 else "declining" if ctl_now < ctl_4w - 2 else "plateaued"
    return f"Form: {form} (TSB {tsb:+.1f}). Fitness trend over 4 weeks: {trend} (CTL {ctl_4w:.0f} → {ctl_now:.0f})."
