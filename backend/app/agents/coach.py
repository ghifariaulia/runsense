"""
RunSense AI Agent — Ollama with tool use.
All data comes from Strava only. Fitness metrics (CTL/ATL/TSB)
are estimated from Strava HR + duration data.
"""
import httpx
import json
from app.core.config import settings
from app.tools.strava import (
    get_recent_activities,
    get_pace_hr_trend,
    get_personal_records,
)
from app.tools.fitness import get_fitness_metrics

SYSTEM_PROMPT = """You are RunSense, an AI running coach that gives honest, specific, data-backed insights.

You have access to the athlete's real Strava data via tools. Fitness metrics (CTL, ATL, TSB) are
estimated from their Strava heart rate and duration data using the Coggan TSS approximation.

ALWAYS fetch data before answering — never give generic advice without looking at their actual numbers.

Your analysis style:
- Be specific: cite actual numbers, dates, trends
- Be honest: if they're stagnating or overtraining, say so clearly
- Be actionable: end with 1-2 concrete recommendations
- Be concise: no fluff, no motivational filler

When you spot something non-obvious (e.g. pace getting slower despite more mileage, efficiency
declining week over week, fitness plateaued for 6 weeks), call it out — that's your value over a generic app.

When referencing metrics, briefly explain what they mean:
e.g. "Your TSB is -24, meaning you're carrying significant accumulated fatigue."

Format responses with clear sections. Use **bold** for key numbers and findings.
"""

OLLAMA_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "get_recent_activities",
            "description": "Fetch the athlete's recent Strava activities across sport types. Returns distance, pace, heart rate, elevation, and activity type. Use this to analyze training volume, consistency, and patterns.",
            "parameters": {
                "type": "object",
                "properties": {
                    "weeks": {
                        "type": "integer",
                        "description": "Number of weeks to look back (default 8, max 16)",
                        "default": 8,
                    }
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_fitness_metrics",
            "description": "Estimate CTL (fitness), ATL (fatigue), and TSB (form = CTL minus ATL) from Strava data. Use this to assess training load trends, overtraining risk, and race readiness.",
            "parameters": {
                "type": "object",
                "properties": {
                    "days": {
                        "type": "integer",
                        "description": "Number of days to analyze (default 56 = 8 weeks)",
                        "default": 56,
                    }
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_pace_hr_trend",
            "description": "Calculate weekly pace/HR efficiency trend. Efficiency = pace per km divided by avg HR. Worsening efficiency means fitness is declining or fatigue is accumulating despite similar effort.",
            "parameters": {
                "type": "object",
                "properties": {
                    "weeks": {
                        "type": "integer",
                        "description": "Number of weeks to analyze (default 8)",
                        "default": 8,
                    }
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_personal_records",
            "description": "Fetch the athlete's YTD distance, run count, elevation, and all-time totals from Strava.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
]


def get_ollama_chat_url() -> str:
    """Build chat URL from either host base or /api base."""
    base_url = settings.ollama_base_url.rstrip("/")
    if base_url.endswith("/api"):
        return f"{base_url}/chat"
    return f"{base_url}/api/chat"


async def execute_tool(name: str, inputs: dict, access_token: str) -> str:
    """Route tool calls to the appropriate function."""
    try:
        if name == "get_recent_activities":
            result = await get_recent_activities(access_token, **inputs)
        elif name == "get_fitness_metrics":
            result = await get_fitness_metrics(access_token, **inputs)
        elif name == "get_pace_hr_trend":
            result = await get_pace_hr_trend(access_token, **inputs)
        elif name == "get_personal_records":
            result = await get_personal_records(access_token)
        else:
            return json.dumps({"error": f"Unknown tool: {name}"})
        return json.dumps(result)
    except Exception as e:
        return json.dumps({"error": str(e)})


async def run_agent(
    user_message: str,
    conversation_history: list[dict],
    access_token: str,
) -> tuple[str, list[dict]]:
    """
    Agentic loop using Ollama /api/chat endpoint:
    1. Send message to model with tools
    2. If model calls a tool, execute it and feed results back
    3. Repeat until model returns a final text response
    Returns (final_response_text, updated_history)
    """
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        *conversation_history,
        {"role": "user", "content": user_message},
    ]

    headers = {"Content-Type": "application/json"}
    if settings.ollama_api_key:
        headers["Authorization"] = f"Bearer {settings.ollama_api_key}"

    while True:
        async with httpx.AsyncClient(timeout=120.0) as client:
            resp = await client.post(
                get_ollama_chat_url(),
                headers=headers,
                json={
                    "model": settings.ollama_model,
                    "messages": messages,
                    "tools": OLLAMA_TOOLS,
                    "stream": False,
                },
            )
            try:
                resp.raise_for_status()
            except httpx.HTTPStatusError as exc:
                detail = exc.response.text
                raise RuntimeError(f"Ollama API error {exc.response.status_code}: {detail}") from exc
            data = resp.json()

        assistant_msg = data["message"]
        messages.append(assistant_msg)

        tool_calls = assistant_msg.get("tool_calls", [])

        if not tool_calls:
            return assistant_msg.get("content", ""), messages

        for tc in tool_calls:
            func = tc["function"]
            result = await execute_tool(func["name"], func["arguments"], access_token)
            messages.append({
                "role": "tool",
                "name": func["name"],
                "content": result,
            })

    return "I couldn't generate a response. Please try again.", messages
