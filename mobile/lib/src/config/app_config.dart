const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://136.112.108.87:8081',
);
const mobileRedirectUri = String.fromEnvironment(
  'STRAVA_REDIRECT_URI',
  defaultValue: 'runsense://localhost/auth/callback',
);
