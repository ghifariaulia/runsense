import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/training_formatters.dart';
import 'route_preview.dart';

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
  const FitnessChart(
      {super.key, required this.points, required this.projection});
  final List<FitnessPoint> points;
  final List<FitnessPoint> projection;
  @override
  Widget build(BuildContext context) {
    final projectionStart = math.max(0, points.length - 1);
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          line(points.map((p) => p.ctl).toList(), AppColors.foreground),
          line(points.map((p) => p.atl).toList(), AppColors.accent),
          line(points.map((p) => p.tsb).toList(), AppColors.muted),
          line(
            [
              if (points.isNotEmpty) points.last.ctl,
              ...projection.map((p) => p.ctl)
            ],
            AppColors.foreground,
            startIndex: projectionStart,
            dashed: true,
          ),
          line(
            [
              if (points.isNotEmpty) points.last.atl,
              ...projection.map((p) => p.atl)
            ],
            AppColors.accent,
            startIndex: projectionStart,
            dashed: true,
          ),
          line(
            [
              if (points.isNotEmpty) points.last.tsb,
              ...projection.map((p) => p.tsb)
            ],
            AppColors.muted,
            startIndex: projectionStart,
            dashed: true,
          ),
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

LineChartBarData line(
  List<double> values,
  Color color, {
  int startIndex = 0,
  bool dashed = false,
}) {
  final safeValues = values.isEmpty ? [0.0] : values;
  return LineChartBarData(
    spots: safeValues.indexed
        .map((entry) => FlSpot((entry.$1 + startIndex).toDouble(), entry.$2))
        .toList(),
    color: color,
    barWidth: 3,
    dashArray: dashed ? [8, 7] : null,
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

void showActivityDetails(
  BuildContext context,
  Activity activity, {
  required Future<List<ActivitySplit>> Function(int activityId) loadSplits,
}) {
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
              RoutePreview(polyline: activity.summaryPolyline),
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
              const SizedBox(height: 18),
              Text('SPLITS', style: KickerStyle.text),
              const SizedBox(height: 10),
              FutureBuilder<List<ActivitySplit>>(
                future: loadSplits(activity.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Loading splits...',
                          style: TextStyle(color: AppColors.muted)),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(snapshot.error.toString(),
                          style: const TextStyle(color: AppColors.muted)),
                    );
                  }
                  final splits = snapshot.data ?? [];
                  if (splits.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No splits available for this activity.',
                          style: TextStyle(color: AppColors.muted)),
                    );
                  }
                  return SplitTable(splits: splits);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class SplitTable extends StatelessWidget {
  const SplitTable({super.key, required this.splits});
  final List<ActivitySplit> splits;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          const SplitRow(
            split: 'KM',
            pace: 'Pace',
            time: 'Time',
            hr: 'HR',
            elev: 'Elev',
            header: true,
          ),
          ...splits.map((split) => SplitRow(
                split: split.split.toString(),
                pace: paceLabel(split.paceMinKm),
                time: durationLabel(split.movingTimeSec),
                hr: split.avgHr == null
                    ? '--'
                    : split.avgHr!.round().toString(),
                elev: split.elevationDifferenceM == null
                    ? '--'
                    : '${split.elevationDifferenceM!.round()} m',
              )),
        ],
      ),
    );
  }
}

class SplitRow extends StatelessWidget {
  const SplitRow({
    super.key,
    required this.split,
    required this.pace,
    required this.time,
    required this.hr,
    required this.elev,
    this.header = false,
  });
  final String split;
  final String pace;
  final String time;
  final String hr;
  final String elev;
  final bool header;
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: header ? AppColors.muted : AppColors.foreground,
      fontSize: 12,
      fontWeight: header ? FontWeight.w800 : FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text(split, style: style)),
          Expanded(child: Text(pace, style: style)),
          Expanded(child: Text(time, style: style)),
          SizedBox(width: 44, child: Text(hr, style: style)),
          SizedBox(width: 58, child: Text(elev, style: style)),
        ],
      ),
    );
  }
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
