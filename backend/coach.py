"""
RunSense AI Agent — Claude with tool use.
All data comes from Strava only. Fitness metrics (CTL/ATL/TSB)
are estimated from Strava HR + duration data.
"""
import json
import anthropic
from app.core.config import settings
from app.tools.strava import (
    get_recent_activities,
    get_pace_hr_trend,
    get_personal_records,
)
from app.tools.fitness import get_fitness_metrics

client = anthropic.Anthropic(api_key=settings.anthropic_api_key)

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

TOOLS = [
    {
        "name": "get_recent_activities",
        "description": "Fetch the athlete's recent running activities from Strava. Returns distance, pace, heart rate, and elevation per run. Use this to analyze training volume, consistency, and patterns.",
        "input_schema": {
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
    {
        "name": "get_fitness_metrics",
        "description": "Estimate CTL (fitness), ATL (fatigue), and TSB (form = CTL minus ATL) from Strava data. Use this to assess training load trends, overtraining risk, and race readiness.",
        "input_schema": {
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
    {
        "name": "get_pace_hr_trend",
        "description": "Calculate weekly running efficiency in meters per heartbeat. Higher efficiency means the athlete is covering more distance per heartbeat; a falling trend can indicate fatigue, heat, terrain changes, or declining aerobic efficiency.",
        "input_schema": {
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
    {
        "name": "get_personal_records",
        "description": "Fetch the athlete's YTD distance, run count, elevation, and all-time totals from Strava.",
        "input_schema": {"type": "object", "properties": {}},
    },
]


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
    Agentic loop:
    1. Send message to Claude with tools
    2. If Claude calls a tool, execute it and feed results back
    3. Repeat until Claude returns a final text response
    Returns (final_response_text, updated_history)
    """
    messages = conversation_history + [{"role": "user", "content": user_message}]

    while True:
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=2048,
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages,
        )

        messages.append({"role": "assistant", "content": response.content})

        if response.stop_reason == "end_turn":
            text = next(
                (block.text for block in response.content if hasattr(block, "text")),
                ""
            )
            return text, messages

        if response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    result = await execute_tool(block.name, block.input, access_token)
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": result,
                    })
            messages.append({"role": "user", "content": tool_results})

        else:
            break

    return "I couldn't generate a response. Please try again.", messages
