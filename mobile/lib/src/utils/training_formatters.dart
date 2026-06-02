import 'package:intl/intl.dart';

import '../models/models.dart';

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

String signed(double value) {
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)}';
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

String durationLabel(int? seconds) {
  if (seconds == null || seconds <= 0) return '--';
  final minutes = seconds ~/ 60;
  final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remainingSeconds';
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
