from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.agents.coach import run_agent

router = APIRouter()


class ChatRequest(BaseModel):
    message: str
    access_token: str
    conversation_history: list[dict] = []


class ChatResponse(BaseModel):
    response: str
    conversation_history: list[dict]


@router.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    if not req.access_token:
        raise HTTPException(status_code=401, detail="Strava access token required")

    try:
        text, history = await run_agent(req.message, req.conversation_history, req.access_token)
    except RuntimeError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    return ChatResponse(response=text, conversation_history=history)


@router.get("/chat/starters")
async def chat_starters() -> list[str]:
    return [
        "How is my fitness trending?",
        "Am I carrying too much fatigue?",
        "What should I focus on this week?",
        "Do my recent activities show progress?",
    ]
