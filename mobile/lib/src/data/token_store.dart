import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';

class TokenStore {
  static const _storage = FlutterSecureStorage();

  Future<AuthTokens?> read() async {
    final accessToken = await _storage.read(key: 'strava_access_token');
    if (accessToken == null || accessToken.isEmpty) return null;
    return AuthTokens(
      accessToken: accessToken,
      refreshToken: await _storage.read(key: 'strava_refresh_token') ?? '',
      expiresAt:
          int.tryParse(await _storage.read(key: 'strava_expires_at') ?? '') ??
              0,
      athleteName: await _storage.read(key: 'strava_athlete_name') ?? 'Runner',
    );
  }

  Future<void> write(AuthTokens tokens) async {
    await _storage.write(key: 'strava_access_token', value: tokens.accessToken);
    await _storage.write(
        key: 'strava_refresh_token', value: tokens.refreshToken);
    await _storage.write(
        key: 'strava_expires_at', value: tokens.expiresAt.toString());
    await _storage.write(key: 'strava_athlete_name', value: tokens.athleteName);
  }

  Future<void> clear() => _storage.deleteAll();
}
