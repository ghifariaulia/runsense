# RunSense Mobile

Flutter client for the existing RunSense FastAPI backend.

## Features

- Strava OAuth with `runsense://auth/callback` deep link
- Secure token storage
- Training dashboard with CTL/ATL/TSB, pace/HR efficiency, activity filters, and activity history
- Coach chat using the same `/api/chat` agent endpoint and starter questions as the web app

## Run

Install Flutter, then from this directory:

```bash
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:8081
```

Use `http://10.0.2.2:8081` for the Android emulator, or your machine LAN IP for a physical device.

## Strava OAuth

The mobile app asks the backend for:

```text
/api/auth/strava/url?redirect_uri=runsense://auth/callback
```

Add `runsense://auth/callback` as an allowed callback URL in the Strava app settings if Strava rejects the redirect. The web app still uses `FRONTEND_URL/auth/callback`.
