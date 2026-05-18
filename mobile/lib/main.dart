import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8081',
);
const mobileRedirectUri = 'runsense://auth/callback';

void main() {
  runApp(const RunSenseApp());
}

class RunSenseApp extends StatelessWidget {
  const RunSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RunSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
          onSurface: AppColors.foreground,
        ),
        fontFamily: Platform.isIOS ? 'Avenir Next' : null,
        useMaterial3: true,
      ),
      home: const RootScreen(),
    );
  }
}

class AppColors {
  static const background = Color(0xFF0A0A0A);
  static const foreground = Color(0xFFFAFAFA);
  static const muted = Color(0xFF737373);
  static const border = Color(0xFF262626);
  static const surface = Color(0xFF101010);
  static const accent = Color(0xFFFF3D00);
}

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
      query: {'redirect_uri': mobileRedirectUri},
    );
    return data['url'] as String;
  }

  Future<AuthTokens> exchangeCode(String code) async {
    final data = await _request<Map<String, dynamic>>(
      '/api/auth/strava/callback',
      method: 'POST',
      body: {'code': code},
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

  Future<FitnessMetrics> fitness(String accessToken) async {
    final data = await _request<Map<String, dynamic>>(
      '/api/strava/fitness',
      method: 'POST',
      query: {'days': '56'},
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

class AuthTokens {
  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.athleteName,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresAt;
  final String athleteName;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final athlete = (json['athlete'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = [athlete['firstname'], athlete['lastname']]
        .where((part) => part != null && part.toString().trim().isNotEmpty)
        .join(' ');
    return AuthTokens(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      expiresAt: (json['expires_at'] as num?)?.toInt() ?? 0,
      athleteName: name.isEmpty ? 'Runner' : name,
    );
  }
}

class Activity {
  Activity({
    required this.id,
    required this.name,
    required this.date,
    required this.distanceKm,
    required this.durationMin,
    required this.paceMinKm,
    required this.avgHr,
    required this.maxHr,
    required this.elevationM,
    required this.type,
  });

  final int id;
  final String name;
  final String date;
  final double distanceKm;
  final double durationMin;
  final double? paceMinKm;
  final double? avgHr;
  final double? maxHr;
  final double? elevationM;
  final String type;

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: (json['id'] as num).toInt(),
        name: json['name']?.toString() ?? 'Activity',
        date: json['date']?.toString() ?? '',
        distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
        durationMin: (json['duration_min'] as num?)?.toDouble() ?? 0,
        paceMinKm: (json['pace_min_km'] as num?)?.toDouble(),
        avgHr: (json['avg_hr'] as num?)?.toDouble(),
        maxHr: (json['max_hr'] as num?)?.toDouble(),
        elevationM: (json['elevation_m'] as num?)?.toDouble(),
        type: json['type']?.toString() ?? 'Activity',
      );
}

class FitnessMetrics {
  FitnessMetrics({
    required this.current,
    required this.ctlChange,
    required this.trend,
    required this.interpretation,
  });

  final FitnessPoint current;
  final double ctlChange;
  final List<FitnessPoint> trend;
  final String interpretation;

  factory FitnessMetrics.fromJson(Map<String, dynamic> json) {
    final trend = (json['trend'] as List<dynamic>? ?? [])
        .map((item) => FitnessPoint.fromJson(item as Map<String, dynamic>))
        .toList();
    return FitnessMetrics(
      current: FitnessPoint.fromJson(json['current'] as Map<String, dynamic>),
      ctlChange: (json['ctl_change'] as num?)?.toDouble() ?? 0,
      trend: trend,
      interpretation: json['interpretation']?.toString() ?? '',
    );
  }
}

class FitnessPoint {
  FitnessPoint({
    required this.date,
    required this.ctl,
    required this.atl,
    required this.tsb,
  });

  final String date;
  final double ctl;
  final double atl;
  final double tsb;

  factory FitnessPoint.fromJson(Map<String, dynamic> json) => FitnessPoint(
        date: json['date']?.toString() ?? '',
        ctl: (json['ctl'] as num?)?.toDouble() ?? 0,
        atl: (json['atl'] as num?)?.toDouble() ?? 0,
        tsb: (json['tsb'] as num?)?.toDouble() ?? 0,
      );
}

class PaceHrTrend {
  PaceHrTrend({
    required this.week,
    required this.efficiency,
  });

  final String week;
  final double efficiency;

  factory PaceHrTrend.fromJson(Map<String, dynamic> json) => PaceHrTrend(
        week: json['week']?.toString() ?? '',
        efficiency: (json['efficiency'] as num?)?.toDouble() ?? 0,
      );
}

class ChatResult {
  ChatResult({required this.response, required this.history});
  final String response;
  final List<dynamic> history;
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final _api = ApiClient();
  final _store = TokenStore();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  AuthTokens? _tokens;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _linkSub = _appLinks.uriLinkStream.listen(_handleLink);
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      await _handleLink(initialUri);
    } else {
      final tokens = await _store.read();
      setState(() {
        _tokens = tokens;
        _loading = false;
      });
    }
  }

  Future<void> _handleLink(Uri uri) async {
    if (uri.scheme != 'runsense' || uri.host != 'auth') return;
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      setState(() {
        _error = 'Authorization failed. No Strava code was returned.';
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final tokens = await _api.exchangeCode(code);
      await _store.write(tokens);
      setState(() {
        _tokens = tokens;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await _api.getAuthUrl();
      final launched =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched) throw ApiException('Could not open Strava authorization.');
      setState(() => _loading = false);
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await _store.clear();
    setState(() => _tokens = null);
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingScreen(label: 'Loading RunSense...');
    if (_tokens == null) {
      return LoginScreen(error: _error, onConnect: _connect);
    }
    return DashboardScreen(tokens: _tokens!, onReconnect: _signOut);
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.error, required this.onConnect});

  final String? error;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('STRAVA INTELLIGENCE', style: KickerStyle.text),
              const SizedBox(height: 18),
              const Text.rich(
                TextSpan(
                  text: 'Run',
                  children: [
                    TextSpan(
                        text: 'Sense',
                        style: TextStyle(color: AppColors.accent))
                  ],
                ),
                style: TextStyle(
                    fontSize: 84, height: .82, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 24),
              const Text(
                'An AI running coach powered by your Strava data. Honest, data-backed training insights.',
                style: TextStyle(
                    color: AppColors.muted, fontSize: 18, height: 1.45),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: onConnect,
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                child: const Text('CONNECT WITH STRAVA',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              if (error != null) ...[
                const SizedBox(height: 18),
                Text(error!, style: const TextStyle(color: AppColors.accent)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
                width: 72,
                child: LinearProgressIndicator(color: AppColors.accent)),
            const SizedBox(height: 18),
            Text(label, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen(
      {super.key, required this.tokens, required this.onReconnect});

  final AuthTokens tokens;
  final VoidCallback onReconnect;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiClient();
  late Future<DashboardData> _future;
  String _type = 'All';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DashboardData> _load() async {
    final activities = _api.activities(widget.tokens.accessToken);
    final fitness = _api.fitness(widget.tokens.accessToken);
    final trend = _api.paceHrTrend(widget.tokens.accessToken);
    return DashboardData(
      activities: await activities,
      fitness: await fitness,
      trend: await trend,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingScreen(label: 'Loading Strava dashboard...');
        }
        if (snapshot.hasError) {
          return ErrorScreen(
              message: snapshot.error.toString(),
              onReconnect: widget.onReconnect);
        }
        final data = snapshot.data!;
        final activityTypes =
            data.activities.map((a) => a.type).toSet().toList()..sort();
        final types = ['All', ...activityTypes];
        final filtered = _type == 'All'
            ? data.activities
            : data.activities.where((a) => a.type == _type).toList();
        final fourWeekDistance = data.activities
            .where((a) =>
                DateTime.tryParse(a.date)?.isAfter(
                    DateTime.now().subtract(const Duration(days: 28))) ??
                false)
            .fold<double>(0, (sum, activity) => sum + activity.distanceKm);
        final heroDistance = fourWeekDistance > 0
            ? fourWeekDistance
            : data.activities
                .fold<double>(0, (sum, activity) => sum + activity.distanceKm);
        final avgPace = average(nonNullDoubles(
            data.activities.where(isRun).map((a) => a.paceMinKm)));
        final avgHr =
            average(nonNullDoubles(data.activities.map((a) => a.avgHr)));

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: AppColors.background,
              title: const Text('RunSense',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              actions: [
                TextButton(
                    onPressed: widget.onReconnect,
                    child: const Text('Reconnect')),
              ],
              bottom: const TabBar(
                indicatorColor: AppColors.accent,
                tabs: [Tab(text: 'Dashboard'), Tab(text: 'Coach')],
              ),
            ),
            body: TabBarView(
              children: [
                RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: () {
                    final future = _load();
                    setState(() => _future = future);
                    return future.then((_) {});
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
                    children: [
                      const Text('RUNSENSE', style: KickerStyle.text),
                      const SizedBox(height: 10),
                      Text(
                        '${widget.tokens.athleteName.split(' ').first}\'s training index',
                        style: const TextStyle(
                            fontSize: 42,
                            height: .9,
                            fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 22),
                      Text.rich(
                        TextSpan(
                          text: heroDistance.toStringAsFixed(1),
                          children: const [
                            TextSpan(
                                text: 'KM',
                                style: TextStyle(color: AppColors.accent))
                          ],
                        ),
                        style: const TextStyle(
                            fontSize: 70,
                            height: .9,
                            fontWeight: FontWeight.w900),
                      ),
                      const Text('LAST 4 WEEKS', style: KickerStyle.text),
                      const SizedBox(height: 18),
                      Text(data.fitness.interpretation,
                          style: const TextStyle(
                              color: AppColors.muted, height: 1.45)),
                      const SizedBox(height: 22),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: [
                          MetricTile(
                              label: '4 week distance',
                              value: '${heroDistance.toStringAsFixed(1)} km',
                              detail: '${data.activities.length} loaded'),
                          MetricTile(
                              label: 'Current fitness',
                              value:
                                  '${data.fitness.current.ctl.toStringAsFixed(1)} CTL',
                              detail:
                                  '${data.fitness.ctlChange.toStringAsFixed(1)} over 4 weeks'),
                          MetricTile(
                              label: 'Fatigue balance',
                              value:
                                  '${data.fitness.current.tsb.toStringAsFixed(1)} TSB',
                              detail: data.fitness.current.tsb < -20
                                  ? 'high fatigue'
                                  : 'manageable load'),
                          MetricTile(
                              label: 'Pace / HR',
                              value: paceLabel(avgPace),
                              detail: avgHr == null
                                  ? 'HR unavailable'
                                  : '${avgHr.round()} bpm average'),
                        ],
                      ),
                      const SizedBox(height: 22),
                      ChartPanel(
                        title: 'Fitness and fatigue',
                        chart: FitnessChart(points: data.fitness.trend),
                      ),
                      const SizedBox(height: 14),
                      ChartPanel(
                        title: 'Running efficiency (m/beat)',
                        chart: TrendChart(points: data.trend),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        children: types.map((type) {
                          return ChoiceChip(
                            label: Text(type),
                            selected: _type == type,
                            selectedColor: AppColors.accent,
                            onSelected: (_) => setState(() => _type = type),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      ...filtered.take(40).map((activity) => ActivityRow(
                            activity,
                            onTap: () => showActivityDetails(context, activity),
                          )),
                    ],
                  ),
                ),
                CoachScreen(tokens: widget.tokens),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DashboardData {
  DashboardData(
      {required this.activities, required this.fitness, required this.trend});
  final List<Activity> activities;
  final FitnessMetrics fitness;
  final List<PaceHrTrend> trend;
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen(
      {super.key, required this.message, required this.onReconnect});
  final String message;
  final VoidCallback onReconnect;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RunSense',
                style: TextStyle(fontSize: 54, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 20),
            TextButton(
                onPressed: onReconnect, child: const Text('Reconnect Strava')),
          ],
        ),
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile(
      {super.key,
      required this.label,
      required this.value,
      required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(),
              style: KickerStyle.text.copyWith(fontSize: 10)),
          Text(value,
              style: const TextStyle(
                  fontSize: 24, height: .95, fontWeight: FontWeight.w900)),
          Text(detail,
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class ChartPanel extends StatelessWidget {
  const ChartPanel({super.key, required this.title, required this.chart});
  final String title;
  final Widget chart;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Expanded(child: chart),
        ],
      ),
    );
  }
}

class FitnessChart extends StatelessWidget {
  const FitnessChart({super.key, required this.points});
  final List<FitnessPoint> points;
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          line(points.map((p) => p.ctl).toList(), AppColors.foreground),
          line(points.map((p) => p.atl).toList(), AppColors.accent),
          line(points.map((p) => p.tsb).toList(), AppColors.muted),
        ],
      ),
    );
  }
}

class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.points});
  final List<PaceHrTrend> points;
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          line(points.map((p) => p.efficiency).toList(), AppColors.accent)
        ],
      ),
    );
  }
}

LineChartBarData line(List<double> values, Color color) {
  final safeValues = values.isEmpty ? [0.0] : values;
  return LineChartBarData(
    spots: safeValues.indexed
        .map((entry) => FlSpot(entry.$1.toDouble(), entry.$2))
        .toList(),
    color: color,
    barWidth: 3,
    dotData: const FlDotData(show: false),
  );
}

class ActivityRow extends StatelessWidget {
  const ActivityRow(this.activity, {super.key, required this.onTap});
  final Activity activity;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activity.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                      '${shortDate(activity.date)} - ${activity.type} - ${(activity.elevationM ?? 0).round()} m gain',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            Text('${activity.distanceKm.toStringAsFixed(1)} km',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Text(activityPaceOrSpeedLabel(activity),
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

void showActivityDetails(BuildContext context, Activity activity) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(activity.type.toUpperCase(), style: KickerStyle.text),
              const SizedBox(height: 8),
              Text(activity.name,
                  style: const TextStyle(
                      fontSize: 32, height: .95, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('${shortDate(activity.date)} - ${activity.date}',
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  DetailTile(
                      label: 'Distance',
                      value: '${activity.distanceKm.toStringAsFixed(2)} km'),
                  DetailTile(
                      label: 'Duration',
                      value: '${activity.durationMin.toStringAsFixed(1)} min'),
                  DetailTile(
                    label: activityPaceOrSpeedTitle(activity),
                    value: activityPaceOrSpeedLabel(activity),
                  ),
                  DetailTile(
                      label: 'Avg HR',
                      value: activity.avgHr == null
                          ? '--'
                          : '${activity.avgHr!.round()} bpm'),
                  DetailTile(
                      label: 'Max HR',
                      value: activity.maxHr == null
                          ? '--'
                          : '${activity.maxHr!.round()} bpm'),
                  DetailTile(
                      label: 'Elevation',
                      value: '${(activity.elevationM ?? 0).round()} m'),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class DetailTile extends StatelessWidget {
  const DetailTile({super.key, required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(),
              style: KickerStyle.text.copyWith(fontSize: 10)),
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, required this.tokens});
  final AuthTokens tokens;
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _api = ApiClient();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<String> _starters = [];
  List<ChatMessage> _messages = [];
  List<dynamic> _history = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _api.starters().then((value) => setState(() => _starters = value));
  }

  Future<void> _submit(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;
    setState(() {
      _messages = [
        ..._messages,
        ChatMessage.user(trimmed),
        ChatMessage.loading()
      ];
      _loading = true;
      _controller.clear();
    });
    try {
      final result = await _api.sendMessage(
        message: trimmed,
        accessToken: widget.tokens.accessToken,
        history: _history,
      );
      setState(() {
        _history = result.history;
        _messages = [
          ..._messages.take(_messages.length - 1),
          ChatMessage.assistant(result.response)
        ];
      });
    } catch (_) {
      setState(() {
        _messages = [
          ..._messages.take(_messages.length - 1),
          ChatMessage.assistant(
              'Something went wrong. Check your connection and try again.')
        ];
      });
    } finally {
      setState(() => _loading = false);
      unawaited(Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(18),
            children: [
              if (_messages.isEmpty) ...[
                const Text('DATA COACH', style: KickerStyle.text),
                const SizedBox(height: 10),
                Text(
                    'Ask the hard question, ${widget.tokens.athleteName.split(' ').first}.',
                    style: const TextStyle(
                        fontSize: 36, height: .9, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                const Text(
                    'Ask anything about your training. RunSense pulls real data before answering.',
                    style: TextStyle(color: AppColors.muted, height: 1.45)),
                const SizedBox(height: 16),
                ..._starters.map((starter) => StarterButton(
                    label: starter, onTap: () => _submit(starter))),
              ],
              ..._messages.map(MessageBubble.new),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_loading,
                    decoration: const InputDecoration(
                      hintText: 'Ask about your training...',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.border)),
                    ),
                    onSubmitted: _submit,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _loading ? null : () => _submit(_controller.text),
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.arrow_upward),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class StarterButton extends StatelessWidget {
  const StarterButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Text(label.toUpperCase(),
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.foreground)),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble(this.message, {super.key});
  final ChatMessage message;
  @override
  Widget build(BuildContext context) {
    if (message.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(color: AppColors.accent),
      );
    }
    if (message.role == ChatRole.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          color: AppColors.accent,
          child: Text(message.text,
              style: const TextStyle(
                  color: AppColors.background, fontWeight: FontWeight.w800)),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.only(left: 14),
      decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.accent, width: 3))),
      child: MarkdownBody(
        data: message.text,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: const TextStyle(height: 1.55, color: AppColors.foreground),
          strong: const TextStyle(
              color: AppColors.accent, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

enum ChatRole { user, assistant }

class ChatMessage {
  ChatMessage.user(this.text)
      : role = ChatRole.user,
        loading = false;
  ChatMessage.assistant(this.text)
      : role = ChatRole.assistant,
        loading = false;
  ChatMessage.loading()
      : role = ChatRole.assistant,
        text = '',
        loading = true;

  final ChatRole role;
  final String text;
  final bool loading;
}

class KickerStyle {
  static const text = TextStyle(
    color: AppColors.accent,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.4,
  );
}

bool isRun(Activity activity) {
  return activity.type == 'Run' ||
      activity.type == 'TrailRun' ||
      activity.type == 'VirtualRun';
}

bool isCycling(Activity activity) {
  return {
    'Ride',
    'VirtualRide',
    'MountainBikeRide',
    'GravelRide',
    'EBikeRide',
    'EMountainBikeRide',
  }.contains(activity.type);
}

double? average(Iterable<double> values) {
  final list = values.toList();
  if (list.isEmpty) return null;
  return list.reduce((a, b) => a + b) / list.length;
}

String paceLabel(double? value) {
  if (value == null || value <= 0) return '--';
  final minutes = value.floor();
  final seconds = ((value - minutes) * 60).round().toString().padLeft(2, '0');
  return '$minutes:$seconds/km';
}

String speedLabel(Activity activity) {
  if (activity.durationMin <= 0) return '--';
  final speed = (activity.distanceKm / activity.durationMin) * 60;
  return '${speed.toStringAsFixed(1)} km/h';
}

String activityPaceOrSpeedLabel(Activity activity) {
  return isCycling(activity)
      ? speedLabel(activity)
      : paceLabel(activity.paceMinKm);
}

String activityPaceOrSpeedTitle(Activity activity) {
  return isCycling(activity) ? 'Speed' : 'Pace';
}

Iterable<double> nonNullDoubles(Iterable<double?> values) =>
    values.whereType<double>();

String shortDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return DateFormat('MMM d').format(date);
}
