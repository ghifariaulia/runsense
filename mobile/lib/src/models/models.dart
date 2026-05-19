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
    required this.summaryPolyline,
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
  final String? summaryPolyline;
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
        summaryPolyline: json['summary_polyline']?.toString(),
        type: json['type']?.toString() ?? 'Activity',
      );
}

class FitnessMetrics {
  FitnessMetrics({
    required this.current,
    required this.ctlChange,
    required this.trend,
    required this.projection,
    required this.interpretation,
  });

  final FitnessPoint current;
  final double ctlChange;
  final List<FitnessPoint> trend;
  final FitnessProjection projection;
  final String interpretation;

  factory FitnessMetrics.fromJson(Map<String, dynamic> json) {
    final trend = (json['trend'] as List<dynamic>? ?? [])
        .map((item) => FitnessPoint.fromJson(item as Map<String, dynamic>))
        .toList();
    return FitnessMetrics(
      current: FitnessPoint.fromJson(json['current'] as Map<String, dynamic>),
      ctlChange: (json['ctl_change'] as num?)?.toDouble() ?? 0,
      trend: trend,
      projection: FitnessProjection.fromJson(
          json['projection'] as Map<String, dynamic>? ?? {}),
      interpretation: json['interpretation']?.toString() ?? '',
    );
  }
}

class FitnessProjection {
  FitnessProjection({
    required this.days,
    required this.dailyTssAssumption,
    required this.end,
    required this.ctlChange,
    required this.atlChange,
    required this.tsbChange,
    required this.trend,
    required this.assumption,
  });

  final int days;
  final double dailyTssAssumption;
  final FitnessPoint end;
  final double ctlChange;
  final double atlChange;
  final double tsbChange;
  final List<FitnessPoint> trend;
  final String assumption;

  factory FitnessProjection.fromJson(Map<String, dynamic> json) {
    final trend = (json['trend'] as List<dynamic>? ?? [])
        .map((item) => FitnessPoint.fromJson(item as Map<String, dynamic>))
        .toList();
    return FitnessProjection(
      days: (json['days'] as num?)?.toInt() ?? 0,
      dailyTssAssumption:
          (json['daily_tss_assumption'] as num?)?.toDouble() ?? 0,
      end: FitnessPoint.fromJson(
          json['end'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ctlChange: (json['ctl_change'] as num?)?.toDouble() ?? 0,
      atlChange: (json['atl_change'] as num?)?.toDouble() ?? 0,
      tsbChange: (json['tsb_change'] as num?)?.toDouble() ?? 0,
      trend: trend,
      assumption: json['assumption']?.toString() ?? '',
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

class DashboardData {
  DashboardData(
      {required this.activities, required this.fitness, required this.trend});
  final List<Activity> activities;
  final FitnessMetrics fitness;
  final List<PaceHrTrend> trend;
}
