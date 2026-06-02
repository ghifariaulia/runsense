import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/training_formatters.dart';
import '../widgets/dashboard_widgets.dart';
import 'coach_screen.dart';
import 'loading_screen.dart';

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

  Future<void> _refresh() {
    final future = _load();
    setState(() => _future = future);
    return future.then((_) {});
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
            onReconnect: widget.onReconnect,
          );
        }

        final data = snapshot.data!;
        final activityTypes = data.activities
            .map((activity) => activity.type)
            .toSet()
            .toList()
          ..sort();
        final types = ['All', ...activityTypes];
        final filtered = _type == 'All'
            ? data.activities
            : data.activities
                .where((activity) => activity.type == _type)
                .toList();
        final fourWeekDistance = data.activities
            .where((activity) =>
                DateTime.tryParse(activity.date)?.isAfter(
                    DateTime.now().subtract(const Duration(days: 28))) ??
                false)
            .fold<double>(0, (sum, activity) => sum + activity.distanceKm);
        final heroDistance = fourWeekDistance > 0
            ? fourWeekDistance
            : data.activities
                .fold<double>(0, (sum, activity) => sum + activity.distanceKm);
        final avgPace = average(nonNullDoubles(data.activities
            .where(isRun)
            .map((activity) => activity.paceMinKm)));
        final avgHr = average(
            nonNullDoubles(data.activities.map((activity) => activity.avgHr)));

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
                  onRefresh: _refresh,
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
                              label: 'Projected fitness',
                              value:
                                  '${data.fitness.projection.end.ctl.toStringAsFixed(1)} CTL',
                              detail:
                                  '${signed(data.fitness.projection.ctlChange)} in ${data.fitness.projection.days} days'),
                          MetricTile(
                              label: 'Projected fatigue',
                              value:
                                  '${data.fitness.projection.end.atl.toStringAsFixed(1)} ATL',
                              detail:
                                  '${data.fitness.projection.end.tsb.toStringAsFixed(1)} TSB projected'),
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
                        chart: FitnessChart(
                          points: data.fitness.trend,
                          projection: data.fitness.projection.trend,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 6),
                        child: Text(
                          '${data.fitness.projection.assumption} Daily TSS: ${data.fitness.projection.dailyTssAssumption.toStringAsFixed(1)}.',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12),
                        ),
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
                            onTap: () => showActivityDetails(
                              context,
                              activity,
                              loadSplits: (activityId) => _api.activitySplits(
                                  widget.tokens.accessToken, activityId),
                            ),
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
