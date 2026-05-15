# RunSense 🏃

> AI running coach that tells you the truth about your training.

Ask questions like *"Am I actually improving?"* or *"Why does my pace feel harder?"* — and get specific, data-backed answers from your real Strava and Strava HR data data.

## What makes this non-trivial

Most "AI fitness apps" wrap generic advice in a chat UI. RunSense is different:

- **Real tool use** — Claude calls Strava + Strava HR data APIs as actual tools, deciding what to fetch based on your question
- **Multi-turn agentic reasoning** — the agent can call multiple tools in sequence before answering
- **Honest, specific insights** — cites actual numbers: "Your pace/HR efficiency dropped 8% over 3 weeks"
- **Real fitness science** — CTL/ATL/TSB from Strava HR data, not just step counts

## Architecture

```
User question
     │
     ▼
FastAPI /chat endpoint
     │
     ▼
Claude Agent (claude-sonnet-4) ── decides which tools to call
     │
     ├── get_recent_activities()   → Strava API (last N runs)
     ├── get_fitness_metrics()     → Strava HR data (CTL/ATL/TSB/HRV)
     ├── get_pace_hr_trend()       → Strava (weekly efficiency trend)
     ├── get_personal_records()    → Strava (YTD stats, PRs)
     └── get_hrv_trend()           → Strava HR data (HRV/RHR trend)
     │
     ▼
Data-backed insight with specific numbers
     │
     ▼
Astro + React chat UI (streaming-ready)
```

**Stack:** FastAPI · Anthropic Claude API (tool use) · Strava API · Strava HR data API · Astro · React · Docker

## Setup

### 1. Strava App
1. Go to [strava.com/settings/api](https://www.strava.com/settings/api)
2. Create an app, set redirect URI to `http://localhost:4321/auth/callback`
3. Copy Client ID and Client Secret

### 2. Strava HR data API Key
1. Go to Strava HR data → Settings → API
2. Copy your API key and athlete ID

### 3. Run locally

```bash
# Clone and set up env files
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
# Fill in your keys in backend/.env

# Start everything
docker-compose up
```

Open `http://localhost:4321`

### Manual (no Docker)

```bash
# Backend
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload

# Frontend
cd frontend
npm install
npm run dev
```

## Key files

```
backend/
├── app/
│   ├── agents/coach.py      # ← Claude agent + tool use loop
│   ├── tools/strava.py      # ← Strava API integration
│   ├── tools/intervals.py   # ← Strava HR data integration
│   └── api/chat.py          # ← FastAPI chat endpoint
frontend/
├── src/
│   ├── components/ChatInterface.tsx   # ← React chat UI
│   └── pages/
│       ├── index.astro               # ← Landing + Strava OAuth
│       ├── coach.astro               # ← Main chat page
│       └── auth/callback.astro       # ← OAuth callback handler
```

## Starter questions

- *"Am I actually improving or just running more?"*
- *"Am I overtraining right now?"*
- *"Why does my pace feel harder lately?"*
- *"Am I ready to race this weekend?"*
- *"What's been my biggest training mistake in the last 8 weeks?"*
- *"How does my current fitness compare to 4 weeks ago?"*

## Extending

- Add a `/stats` page with Recharts visualizations (pace trend, fitness curve)
- Add training plan generation based on current CTL
- Add race predictor using recent pace/HR efficiency
- Add Telegram/WhatsApp bot interface (you already know n8n)

## Built with

- [Anthropic Claude API](https://docs.anthropic.com) — tool use / agentic loops
- [Strava API](https://developers.strava.com)
- [Strava HR data API](https://forum.Strava HR data/t/api-access-for-intervals-icu/609)
- [FastAPI](https://fastapi.tiangolo.com)
- [Astro](https://astro.build)
