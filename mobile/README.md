# RunSense Mobile

Flutter client for the existing RunSense FastAPI backend.

## Features

- Strava OAuth with a `runsense://<callback-domain>/auth/callback` deep link
- Secure token storage
- Training dashboard with CTL/ATL/TSB, meters-per-heartbeat running efficiency, activity filters, and activity history
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
/api/auth/strava/url?redirect_uri=runsense://localhost/auth/callback&mobile=true
```

Strava validates the host part of `redirect_uri` against the Authorized Callback Domain in the Strava app settings. For local development, set the Strava callback domain to `localhost`; the default mobile redirect is `runsense://localhost/auth/callback`.

For a deployed callback domain, pass the same domain in the mobile redirect URI:

```bash
flutter run \
  --dart-define=API_URL=http://10.0.2.2:8081 \
  --dart-define=STRAVA_REDIRECT_URI=runsense://yourdomain.com/auth/callback
```

The Android app also accepts the older `runsense://auth/callback` link shape, but Strava will reject it unless the callback domain is configured as `auth`. The web app still uses `FRONTEND_URL/auth/callback`.
