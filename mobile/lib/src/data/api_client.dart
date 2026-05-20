import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/models.dart';

class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);
  }

  Future<T> _request<T>(
    String path, {
    String method = 'GET',
    Object? body,
    Map<String, String>? query,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers['Content-Type'] = 'application/json';
    if (body != null) {
      request.body = jsonEncode(body);
    }
    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _errorMessage(response);
      throw ApiException(message);
    }
    return jsonDecode(response.body) as T;
  }

  String _errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['detail']?.toString() ??
          response.reasonPhrase ??
          'Request failed';
    } catch (_) {
      return response.reasonPhrase ?? 'Request failed';
    }
  }

  Future<String> getAuthUrl() async {
    final data = await _request<Map<String, dynamic>>(
      '/api/auth/strava/url',
      query: {'redirect_uri': mobileRedirectUri, 'mobile': 'true'},
    );
    return data['url'] as String;
  }

  Future<AuthTokens> exchangeCode(String code) async {
    final data = await _request<Map<String, dynamic>>(
      '/api/auth/strava/callback',
      method: 'POST',
      body: {'code': code, 'redirect_uri': mobileRedirectUri},
    );
    return AuthTokens.fromJson(data);
  }

  Future<List<String>> starters() async {
    final data = await _request<List<dynamic>>('/api/chat/starters');
    return data.map((item) => item.toString()).toList();
  }

  Future<ChatResult> sendMessage({
    required String message,
    required String accessToken,
    required List<dynamic> history,
  }) async {
    final data = await _request<Map<String, dynamic>>(
      '/api/chat',
      method: 'POST',
      body: {
        'message': message,
        'access_token': accessToken,
        'conversation_history': history,
      },
    );
    return ChatResult(
      response: data['response'] as String,
      history: data['conversation_history'] as List<dynamic>,
    );
  }

  Future<List<Activity>> activities(String accessToken) async {
    final data = await _request<List<dynamic>>(
      '/api/strava/activities',
      method: 'POST',
      query: {'weeks': '0'},
      body: {'access_token': accessToken},
    );
    return data
        .map((item) => Activity.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ActivitySplit>> activitySplits(
      String accessToken, int activityId) async {
    final data = await _request<List<dynamic>>(
      '/api/strava/activities/$activityId/splits',
      method: 'POST',
      body: {'access_token': accessToken},
    );
    return data
        .map((item) => ActivitySplit.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FitnessMetrics> fitness(String accessToken) async {
    final data = await _request<Map<String, dynamic>>(
      '/api/strava/fitness',
      method: 'POST',
      query: {'days': '56', 'projection_days': '14'},
      body: {'access_token': accessToken},
    );
    return FitnessMetrics.fromJson(data);
  }

  Future<List<PaceHrTrend>> paceHrTrend(String accessToken) async {
    final data = await _request<List<dynamic>>(
      '/api/strava/trend',
      method: 'POST',
      query: {'weeks': '8'},
      body: {'access_token': accessToken},
    );
    return data
        .map((item) => PaceHrTrend.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
