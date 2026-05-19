const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8081',
);
const mobileRedirectUri = String.fromEnvironment(
  'STRAVA_REDIRECT_URI',
  defaultValue: 'runsense://localhost/auth/callback',
);
