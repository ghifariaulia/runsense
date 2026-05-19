import 'dart:io' show Platform;

const _configuredApiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: '',
);

String get apiBaseUrl {
  if (_configuredApiBaseUrl.isNotEmpty) {
    return _configuredApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  }
  if (Platform.isAndroid) return 'http://10.0.2.2:8081';
  return 'http://localhost:8081';
}

const mobileRedirectUri = String.fromEnvironment(
  'STRAVA_REDIRECT_URI',
  defaultValue: 'runsense://localhost/auth/callback',
);
