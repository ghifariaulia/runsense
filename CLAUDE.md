# RunSense — Claude Code Rules

## Project Overview

RunSense is an AI running coach that connects to Strava and gives honest, data-backed training insights via an agentic LLM loop with tool use.

**Stack:** FastAPI (backend) · Astro + React (frontend) · Ollama Cloud API (GLM/Kimi) · Strava API · Docker

---

## Architecture

```
frontend/                          # Astro + React
├── src/
│   ├── pages/
│   │   ├── index.astro            # Landing + Strava OAuth trigger
│   │   ├── coach.astro            # Main chat page (auth-gated)
│   │   └── auth/callback.astro   # Strava OAuth callback handler
│   ├── components/
│   │   └── ChatInterface.tsx      # React chat UI with starter questions
│   └── lib/
│       └── api.ts                 # Typed API client (fetch wrappers)

backend/                           # FastAPI
├── app/
│   ├── main.py                    # FastAPI app, CORS, router registration
│   ├── core/config.py             # Pydantic settings (env vars)
│   ├── agents/
│   │   └── coach.py              # ← CORE: Ollama agentic loop + tool definitions
│   ├── tools/
│   │   ├── strava.py             # Strava API: OAuth + 3 data fetchers
│   │   └── fitness.py            # CTL/ATL/TSB estimation from Strava data
│   └── api/
│       ├── chat.py               # POST /chat — runs the agent
│       ├── auth.py               # GET /auth/strava/url, POST /auth/strava/callback
│       └── strava.py             # GET /strava/activities, /trend, /stats
```

---

## Core Concepts

### Agent loop (`agents/coach.py`)
The heart of the project. The LLM (GLM 5.1 or Kimi 2.6 via Ollama cloud) is given 4 tools and decides which to call based on the user's question. The loop runs until the model returns a text response with no tool calls. Uses `httpx.AsyncClient` for non-blocking HTTP calls to the Ollama `/api/chat` endpoint.

**Tools available to the LLM:**
- `get_recent_activities` → Strava runs (distance, pace, HR, elevation)
- `get_fitness_metrics` → CTL/ATL/TSB estimated from Strava HR data
- `get_pace_hr_trend` → weekly pace/HR efficiency trend
- `get_personal_records` → YTD stats and all-time totals

**Rule:** Never add a tool without a clear reason the LLM would need to call it. Tool bloat degrades agent quality.

### Fitness metrics (`tools/fitness.py`)
CTL/ATL/TSB are computed from Strava data using Coggan TSS approximation:
- TSS per run = `(duration_hours × (avg_hr / threshold_hr)²) × 100`
- CTL = 42-day exponential moving average of daily TSS
- ATL = 7-day exponential moving average of daily TSS
- TSB = CTL − ATL

No intervals.icu or third-party fitness service — intentional for onboarding simplicity.

### Auth flow
Strava uses OAuth 2.0. Tokens are stored in `localStorage` on the client (acceptable for a portfolio project). Access tokens expire every 6 hours — the app currently requires re-auth on expiry.

Scope required: `activity:read_all` — set in `get_auth_url()`, not in Strava's UI.

---

## Development Commands

```bash
# Start everything
docker-compose up --build

# Backend only (faster iteration)
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload

# Frontend only
cd frontend
npm install
npm run dev
```

**Ports:**
- Frontend: http://localhost:4321
- Backend: http://localhost:8081
- API docs: http://localhost:8081/docs

---

## Environment Variables

**Never read, edit, or output the contents of any `.env` file.** For variable names, refer to `.env.example` only.

```bash
# backend/.env.example
OLLAMA_BASE_URL=https://ollama.com
OLLAMA_API_KEY=
OLLAMA_MODEL=glm-5.1:cloud
STRAVA_CLIENT_ID=...
STRAVA_CLIENT_SECRET=...
SECRET_KEY=change-me-in-production
FRONTEND_URL=http://localhost:4321

# frontend/.env.example
PUBLIC_API_URL=http://localhost:8081
```

---

## Code Conventions

### Backend
- **Async everywhere** — all route handlers and tool functions are `async def`
- **Typed** — use Python type hints on all function signatures
- **Tools are plain async functions** — `execute_tool()` in `coach.py` routes by name; keep tool functions in `tools/` pure and testable
- **Error handling in tools** — wrap tool execution in try/except and return `{"error": ...}` as JSON so the LLM can handle failures gracefully
- **No business logic in `api/`** — routes call agent or tool functions; no data processing inline
- **LLM via httpx** — agent loop uses `httpx.AsyncClient` to call Ollama `/api/chat`; no SDK dependency

### Frontend
- **Astro pages, React islands** — Astro handles routing and page shell; React only for interactive components (`ChatInterface.tsx`)
- **No SSR for auth** — tokens live in `localStorage`; auth checks happen client-side in `<script>` blocks
- **API calls via `lib/api.ts`** — never call the backend directly from components; go through the typed client

### LLM tool definitions
- `description` must be specific enough for the LLM to decide *when* to call it without guessing
- `parameters` must list all parameters with types and defaults (OpenAI function calling format)
- Keep tool count low (currently 4) — more tools = more LLM indecision
- Tools use `{"type": "function", "function": {"name", "description", "parameters"}}` format for Ollama

---

## What Not To Do

- **Don't add RAG** — data is structured JSON from an API, not a document corpus. RAG adds no value here.
- **Don't add LangChain** — the raw `httpx` agentic loop is simpler, more readable, and more impressive than a framework wrapper.
- **Don't store tokens server-side** — for this portfolio scope, localStorage is fine. Don't add a database just for token storage.
- **Don't add intervals.icu** — was intentionally removed to keep onboarding to a single OAuth (Strava only).
- **Don't generate generic advice** — the system prompt explicitly forbids this. If you modify `SYSTEM_PROMPT`, preserve the instruction to always fetch data first.

---

## Extending

Good next additions (in priority order):
1. `/stats` page — Recharts visualizations of CTL/ATL curve and pace trend
2. Token refresh — auto-refresh Strava access token using stored refresh token
3. Training plan generation — based on current CTL and user's goal race date
4. Race predictor — estimate finish time from recent pace/HR efficiency
