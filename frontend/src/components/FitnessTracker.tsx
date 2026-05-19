import { useEffect, useMemo, useState } from 'react';
import ChatInterface from './ChatInterface';
import {
  getActivities,
  getFitness,
  getPaceHrTrend,
  type Activity,
  type FitnessMetrics,
  type PaceHrTrend,
} from '../lib/api';

type LoadState = 'loading' | 'ready' | 'error';
const ACTIVITY_PAGE_SIZE = 12;

interface Series {
  key: string;
  label: string;
  color: string;
  values: Array<number | null>;
  dashed?: boolean;
}

interface RoutePoint {
  lat: number;
  lng: number;
}

function paceLabel(value: number | null | undefined) {
  if (!value) return '--';
  const minutes = Math.floor(value);
  const seconds = Math.round((value - minutes) * 60).toString().padStart(2, '0');
  return `${minutes}:${seconds}/km`;
}

function speedLabel(activity: Activity) {
  if (!activity.duration_min) return '--';
  return `${((activity.distance_km / activity.duration_min) * 60).toFixed(1)} km/h`;
}

function isCyclingActivity(activity: Activity) {
  return ['Ride', 'VirtualRide', 'MountainBikeRide', 'GravelRide', 'EBikeRide', 'EMountainBikeRide'].includes(activity.type);
}

function activityPaceOrSpeedLabel(activity: Activity) {
  return isCyclingActivity(activity) ? speedLabel(activity) : paceLabel(activity.pace_min_km);
}

function activityPaceOrSpeedTitle(activity: Activity) {
  return isCyclingActivity(activity) ? 'Speed' : 'Pace';
}

function decodePolyline(polyline: string): RoutePoint[] {
  const points: RoutePoint[] = [];
  let index = 0;
  let lat = 0;
  let lng = 0;

  while (index < polyline.length) {
    let result = 0;
    let shift = 0;
    let byte = 0;
    do {
      byte = polyline.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    lat += result & 1 ? ~(result >> 1) : result >> 1;

    result = 0;
    shift = 0;
    do {
      byte = polyline.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    lng += result & 1 ? ~(result >> 1) : result >> 1;

    points.push({ lat: lat / 1e5, lng: lng / 1e5 });
  }

  return points;
}

function routePath(points: RoutePoint[], width: number, height: number, pad: number) {
  if (points.length < 2) return '';
  const minLat = Math.min(...points.map(point => point.lat));
  const maxLat = Math.max(...points.map(point => point.lat));
  const minLng = Math.min(...points.map(point => point.lng));
  const maxLng = Math.max(...points.map(point => point.lng));
  const latSpan = maxLat - minLat || 1;
  const lngSpan = maxLng - minLng || 1;
  const scale = Math.min((width - pad * 2) / lngSpan, (height - pad * 2) / latSpan);
  const routeWidth = lngSpan * scale;
  const routeHeight = latSpan * scale;
  const offsetX = (width - routeWidth) / 2;
  const offsetY = (height - routeHeight) / 2;

  return points
    .map((point, index) => {
      const x = offsetX + (point.lng - minLng) * scale;
      const y = offsetY + (maxLat - point.lat) * scale;
      return `${index === 0 ? 'M' : 'L'} ${x.toFixed(1)} ${y.toFixed(1)}`;
    })
    .join(' ');
}

function routePoint(points: RoutePoint[], pointIndex: number, width: number, height: number, pad: number) {
  const point = points[pointIndex];
  const minLat = Math.min(...points.map(item => item.lat));
  const maxLat = Math.max(...points.map(item => item.lat));
  const minLng = Math.min(...points.map(item => item.lng));
  const maxLng = Math.max(...points.map(item => item.lng));
  const latSpan = maxLat - minLat || 1;
  const lngSpan = maxLng - minLng || 1;
  const scale = Math.min((width - pad * 2) / lngSpan, (height - pad * 2) / latSpan);
  const offsetX = (width - lngSpan * scale) / 2;
  const offsetY = (height - latSpan * scale) / 2;
  return {
    x: offsetX + (point.lng - minLng) * scale,
    y: offsetY + (maxLat - point.lat) * scale,
  };
}

function shortDate(value: string) {
  return new Date(`${value}T00:00:00`).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

function shortWeek(value: string) {
  return value.replace('-', ' ');
}

function sum(values: number[]) {
  return values.reduce((total, value) => total + value, 0);
}

function isWithinDays(date: string, days: number) {
  const activityTime = new Date(`${date}T00:00:00`).getTime();
  const cutoff = Date.now() - days * 24 * 60 * 60 * 1000;
  return activityTime >= cutoff;
}

function isRunActivity(activity: Activity) {
  return activity.type === 'Run' || activity.type === 'TrailRun' || activity.type === 'VirtualRun';
}

function linePath(values: Array<number | null>, width: number, height: number, min: number, max: number) {
  if (values.length === 0) return '';
  const span = max - min || 1;
  let started = false;
  return values
    .map((value, index) => {
      if (value === null) {
        started = false;
        return '';
      }
      const x = values.length === 1 ? width / 2 : (index / (values.length - 1)) * width;
      const y = height - ((value - min) / span) * height;
      const command = started ? 'L' : 'M';
      started = true;
      return `${command} ${x.toFixed(1)} ${y.toFixed(1)}`;
    })
    .filter(Boolean)
    .join(' ');
}

function point(value: number, index: number, count: number, width: number, height: number, min: number, max: number) {
  const span = max - min || 1;
  return {
    x: count === 1 ? width / 2 : (index / (count - 1)) * width,
    y: height - ((value - min) / span) * height,
  };
}

function lastNumberIndex(values: Array<number | null>) {
  for (let index = values.length - 1; index >= 0; index -= 1) {
    if (values[index] !== null) return index;
  }
  return -1;
}

function LineChart({ series, labels, height = 180 }: { series: Series[]; labels: string[]; height?: number }) {
  const width = 640;
  const pad = 28;
  const leftPad = 58;
  const plotWidth = width - leftPad - pad;
  const chartHeight = height - pad * 2;
  const allValues = series.flatMap(item => item.values).filter((value): value is number => value !== null);
  const min = allValues.length ? Math.min(...allValues, 0) : 0;
  const max = allValues.length ? Math.max(...allValues, 1) : 1;
  const mid = (min + max) / 2;
  const firstLabel = labels[0] || '';
  const lastLabel = labels[labels.length - 1] || '';

  return (
    <div className="chart-frame">
      <svg viewBox={`0 0 ${width} ${height}`} role="img">
        <g transform={`translate(${leftPad} ${pad})`}>
          <line x1="0" y1={chartHeight} x2={plotWidth} y2={chartHeight} className="axis" />
          <line x1="0" y1="0" x2={plotWidth} y2="0" className="grid" />
          <line x1="0" y1={chartHeight / 2} x2={plotWidth} y2={chartHeight / 2} className="grid" />
          {series.map(item => (
            <path
              key={item.key}
              d={linePath(item.values, plotWidth, chartHeight, min, max)}
              fill="none"
              stroke={item.color}
              strokeWidth="3"
              strokeDasharray={item.dashed ? '8 7' : undefined}
              strokeLinecap="square"
              strokeLinejoin="miter"
            />
          ))}
          {series.map(item => {
            if (!item.values.length) return null;
            const latestIndex = lastNumberIndex(item.values);
            if (latestIndex === -1) return null;
            const latest = item.values[latestIndex] as number;
            const latestPoint = point(latest, latestIndex, item.values.length, plotWidth, chartHeight, min, max);
            return (
              <g key={`${item.key}-value`}>
                <circle cx={latestPoint.x} cy={latestPoint.y} r="3.5" fill={item.color} />
                <text x={Math.min(latestPoint.x + 8, plotWidth - 42)} y={Math.max(latestPoint.y - 7, 10)} className="chart-value" fill={item.color}>
                  {latest.toFixed(latest < 1 ? 4 : 1)}
                </text>
              </g>
            );
          })}
        </g>
        <text x={leftPad - 10} y={pad + 4} className="chart-label y">{max.toFixed(max < 1 ? 3 : 0)}</text>
        <text x={leftPad - 10} y={pad + chartHeight / 2 + 4} className="chart-label y">{mid.toFixed(mid < 1 ? 3 : 0)}</text>
        <text x={leftPad - 10} y={pad + chartHeight + 4} className="chart-label y">{min.toFixed(min < 1 ? 3 : 0)}</text>
        <text x={leftPad} y={height - 4} className="chart-label">{firstLabel}</text>
        <text x={width - pad} y={height - 4} className="chart-label end">{lastLabel}</text>
      </svg>
    </div>
  );
}

function BarChart({ values, labels }: { values: number[]; labels: string[] }) {
  const max = Math.max(...values, 1);
  return (
    <div className="bars">
      {values.map((value, index) => (
        <div className="bar-col" key={`${labels[index]}-${index}`}>
          <div className="bar-track">
            <strong>{value.toFixed(1)}</strong>
            <div className="bar-fill" style={{ height: `${Math.max(6, (value / max) * 100)}%` }} />
          </div>
          <span>{labels[index]}</span>
        </div>
      ))}
    </div>
  );
}

function StatTile({ label, value, detail }: { label: string; value: string; detail: string }) {
  return (
    <div className="stat-tile">
      <span>{label}</span>
      <strong>{value}</strong>
      <small>{detail}</small>
    </div>
  );
}

function ActivityDetail({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function RoutePreview({ polyline }: { polyline?: string | null }) {
  const points = useMemo(() => (polyline ? decodePolyline(polyline) : []), [polyline]);
  if (points.length < 2) {
    return (
      <div className="route-preview empty">
        <span>No route map available</span>
      </div>
    );
  }

  const width = 560;
  const height = 220;
  const pad = 18;
  const start = routePoint(points, 0, width, height, pad);
  const end = routePoint(points, points.length - 1, width, height, pad);

  return (
    <div className="route-preview" aria-label="Activity route shape">
      <svg viewBox={`0 0 ${width} ${height}`} role="img">
        <path d={routePath(points, width, height, pad)} />
        <circle cx={start.x} cy={start.y} r="5" className="route-start" />
        <circle cx={end.x} cy={end.y} r="5" className="route-end" />
      </svg>
    </div>
  );
}

export default function FitnessTracker() {
  const [state, setState] = useState<LoadState>('loading');
  const [error, setError] = useState('');
  const [activities, setActivities] = useState<Activity[]>([]);
  const [fitness, setFitness] = useState<FitnessMetrics | null>(null);
  const [trend, setTrend] = useState<PaceHrTrend[]>([]);
  const [activityType, setActivityType] = useState('All');
  const [activityPage, setActivityPage] = useState(1);
  const [selectedActivity, setSelectedActivity] = useState<Activity | null>(null);

  const accessToken = typeof localStorage === 'undefined' ? '' : localStorage.getItem('strava_access_token') || '';
  const athleteName = typeof localStorage === 'undefined' ? 'Runner' : localStorage.getItem('strava_athlete_name') || 'Runner';

  useEffect(() => {
    if (!accessToken) {
      window.location.href = '/';
      return;
    }

    async function load() {
      try {
        setState('loading');
        const [activityData, fitnessData, trendData] = await Promise.all([
          getActivities(accessToken, 0),
          getFitness(accessToken, 56),
          getPaceHrTrend(accessToken, 8),
        ]);
        setActivities(activityData);
        setFitness(fitnessData);
        setTrend(trendData);
        setState('ready');
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Could not load Strava data.');
        setState('error');
      }
    }

    load();
  }, [accessToken]);

  useEffect(() => {
    setActivityPage(1);
  }, [activityType]);

  const activityTypes = useMemo(
    () => ['All', ...Array.from(new Set(activities.map(activity => activity.type))).sort()],
    [activities],
  );
  const filteredActivities = useMemo(
    () => (activityType === 'All' ? activities : activities.filter(activity => activity.type === activityType)),
    [activities, activityType],
  );
  const totalActivityPages = Math.max(1, Math.ceil(filteredActivities.length / ACTIVITY_PAGE_SIZE));
  const visibleActivities = useMemo(
    () => filteredActivities.slice((activityPage - 1) * ACTIVITY_PAGE_SIZE, activityPage * ACTIVITY_PAGE_SIZE),
    [filteredActivities, activityPage],
  );
  const chartActivities = useMemo(() => activities.slice(0, 10).reverse(), [activities]);
  const totalDistance = useMemo(() => sum(activities.map(activity => activity.distance_km)), [activities]);
  const fourWeekDistance = useMemo(
    () => Number(sum(activities.filter(activity => isWithinDays(activity.date, 28)).map(activity => activity.distance_km)).toFixed(1)),
    [activities],
  );
  const avgPace = useMemo(() => {
    const paces = activities
      .filter(isRunActivity)
      .map(activity => activity.pace_min_km)
      .filter((value): value is number => Boolean(value));
    return paces.length ? sum(paces) / paces.length : null;
  }, [activities]);
  const avgHr = useMemo(() => {
    const hrs = activities.map(activity => activity.avg_hr).filter((value): value is number => Boolean(value));
    return hrs.length ? Math.round(sum(hrs) / hrs.length) : null;
  }, [activities]);
  const heroDistance = fourWeekDistance || Number(totalDistance.toFixed(1));
  const projected = fitness?.projection.end;

  if (state === 'loading') {
    return (
      <main className="tracker-shell center-state">
        <div className="pulse" />
        <p>Loading Strava dashboard...</p>
      </main>
    );
  }

  if (state === 'error') {
    return (
      <main className="tracker-shell center-state">
        <h1>RunSense</h1>
        <p>{error}</p>
        <a href="/">Reconnect Strava</a>
      </main>
    );
  }

  return (
    <main className="tracker-shell">
      <section className="topbar">
        <div>
          <p className="eyebrow">RunSense</p>
          <h1>{athleteName.split(' ')[0]}'s training index</h1>
          <p className="hero-subhead">
            Fitness, fatigue, running efficiency, and activity history from Strava. Built for quick reads before planning the next block.
          </p>
        </div>
        <div className="top-actions">
          <a href="/faq" className="ghost-link">How to read this</a>
          <a href="/" className="ghost-link">Reconnect</a>
        </div>
      </section>

      <section className="hero-metric" aria-label="Four week training summary">
        <div>
          <p className="section-kicker">Last 4 weeks</p>
          <strong>{heroDistance}<span>KM</span></strong>
        </div>
        <p>
          {fitness?.interpretation || 'Training load will appear once Strava activities with heart rate are available.'}
        </p>
      </section>

      <section className="stat-grid">
        <StatTile label="4 week distance" value={`${heroDistance} km`} detail={`${activities.length} loaded activities`} />
        <StatTile label="Current fitness" value={`${fitness?.current.ctl ?? '--'} CTL`} detail={`${fitness?.ctl_change ?? '--'} over 4 weeks`} />
        <StatTile label="Projected fitness" value={`${projected?.ctl ?? '--'} CTL`} detail={fitness ? `${fitness.projection.ctl_change >= 0 ? '+' : ''}${fitness.projection.ctl_change} in ${fitness.projection.days} days` : 'waiting for HR data'} />
        <StatTile label="Projected fatigue" value={`${projected?.atl ?? '--'} ATL`} detail={projected ? `${projected.tsb} TSB projected` : 'waiting for HR data'} />
        <StatTile label="Avg run pace / HR" value={paceLabel(avgPace)} detail={avgHr ? `${avgHr} bpm average, all activities` : 'HR not available'} />
      </section>

      <section className="workspace">
        <div className="dashboard">
          <article className="panel wide">
            <div className="panel-head">
              <div>
                <h2>Fitness and fatigue</h2>
                <p>{fitness?.interpretation}</p>
              </div>
              <div className="legend">
                <span><i className="ctl" />CTL</span>
                <span><i className="atl" />ATL</span>
                <span><i className="tsb" />TSB</span>
                <span><i className="projected" />Projection</span>
              </div>
            </div>
            {fitness && (
              <LineChart
                labels={[...fitness.trend, ...fitness.projection.trend].map(item => shortDate(item.date))}
                series={[
                  { key: 'ctl', label: 'CTL', color: '#FAFAFA', values: [...fitness.trend.map(item => item.ctl), ...Array(fitness.projection.trend.length).fill(null)] },
                  { key: 'atl', label: 'ATL', color: '#FF3D00', values: [...fitness.trend.map(item => item.atl), ...Array(fitness.projection.trend.length).fill(null)] },
                  { key: 'tsb', label: 'TSB', color: '#737373', values: [...fitness.trend.map(item => item.tsb), ...Array(fitness.projection.trend.length).fill(null)] },
                  { key: 'ctl-projected', label: 'Projected CTL', color: '#FAFAFA', dashed: true, values: [...Array(fitness.trend.length - 1).fill(null), fitness.current.ctl, ...fitness.projection.trend.map(item => item.ctl)] },
                  { key: 'atl-projected', label: 'Projected ATL', color: '#FF3D00', dashed: true, values: [...Array(fitness.trend.length - 1).fill(null), fitness.current.atl, ...fitness.projection.trend.map(item => item.atl)] },
                  { key: 'tsb-projected', label: 'Projected TSB', color: '#737373', dashed: true, values: [...Array(fitness.trend.length - 1).fill(null), fitness.current.tsb, ...fitness.projection.trend.map(item => item.tsb)] },
                ]}
              />
            )}
            {fitness && <p>{fitness.projection.assumption} Daily TSS assumption: {fitness.projection.daily_tss_assumption}.</p>}
          </article>

          <article className="panel">
            <div className="panel-head">
              <div>
                <h2>Running efficiency</h2>
                <p>Meters covered per heartbeat each week. Higher usually means you are moving farther for the same cardiovascular cost.</p>
              </div>
            </div>
            <LineChart
              height={170}
              labels={trend.map(item => shortWeek(item.week))}
              series={[{ key: 'efficiency', label: 'Meters per beat', color: '#FF3D00', values: trend.map(item => item.efficiency) }]}
            />
          </article>

          <article className="panel">
            <div className="panel-head">
              <div>
                <h2>Recent activity distance</h2>
                <p>Last {chartActivities.length} activities by distance.</p>
              </div>
            </div>
            <BarChart values={chartActivities.map(activity => activity.distance_km)} labels={chartActivities.map(activity => shortDate(activity.date))} />
          </article>

          <article className="panel wide">
            <div className="panel-head">
              <div>
                <h2>Activity log</h2>
                <p>
                  Showing {visibleActivities.length} of {filteredActivities.length} filtered activities.
                  {activities.length !== filteredActivities.length ? ` ${activities.length} loaded total.` : ''}
                </p>
              </div>
            </div>
            <div className="activity-controls" aria-label="Activity log filters">
              <div className="type-filter">
                {activityTypes.map(type => (
                  <button
                    key={type}
                    type="button"
                    className={type === activityType ? 'active' : ''}
                    onClick={() => setActivityType(type)}
                  >
                    {type}
                  </button>
                ))}
              </div>
              <div className="pagination">
                <button
                  type="button"
                  onClick={() => setActivityPage(page => Math.max(1, page - 1))}
                  disabled={activityPage === 1}
                >
                  Prev
                </button>
                <span>Page {activityPage} / {totalActivityPages}</span>
                <button
                  type="button"
                  onClick={() => setActivityPage(page => Math.min(totalActivityPages, page + 1))}
                  disabled={activityPage === totalActivityPages}
                >
                  Next
                </button>
              </div>
            </div>
            <div className="run-list">
              {visibleActivities.map(activity => (
                <button
                  className="run-row"
                  key={activity.id}
                  type="button"
                  onClick={() => setSelectedActivity(activity)}
                  aria-label={`View details for ${activity.name}`}
                >
                  <div>
                    <strong>{activity.name}</strong>
                    <span>{shortDate(activity.date)} · {activity.type} · {activity.elevation_m ?? 0} m gain</span>
                  </div>
                  <div>{activity.distance_km} km</div>
                  <div>{activityPaceOrSpeedLabel(activity)}</div>
                  <div>{activity.avg_hr ? `${Math.round(activity.avg_hr)} bpm` : '--'}</div>
                </button>
              ))}
            </div>
          </article>
        </div>

        <aside className="coach-panel">
          <div className="coach-head">
            <h2>Coach</h2>
            <p>Ask about this data.</p>
          </div>
          <ChatInterface accessToken={accessToken} athleteName={athleteName} />
        </aside>
      </section>

      {selectedActivity && (
        <div className="activity-modal" role="dialog" aria-modal="true" aria-labelledby="activity-title" onClick={() => setSelectedActivity(null)}>
          <div className="activity-card" onClick={event => event.stopPropagation()}>
            <button type="button" className="activity-close" onClick={() => setSelectedActivity(null)} aria-label="Close activity details">×</button>
            <p className="section-kicker">{selectedActivity.type}</p>
            <h2 id="activity-title">{selectedActivity.name}</h2>
            <p className="activity-date">{shortDate(selectedActivity.date)} · {selectedActivity.date}</p>
            <RoutePreview polyline={selectedActivity.summary_polyline} />
            <div className="activity-detail-grid">
              <ActivityDetail label="Distance" value={`${selectedActivity.distance_km} km`} />
              <ActivityDetail label="Duration" value={`${selectedActivity.duration_min} min`} />
              <ActivityDetail label={activityPaceOrSpeedTitle(selectedActivity)} value={activityPaceOrSpeedLabel(selectedActivity)} />
              <ActivityDetail label="Avg HR" value={selectedActivity.avg_hr ? `${Math.round(selectedActivity.avg_hr)} bpm` : '--'} />
              <ActivityDetail label="Max HR" value={selectedActivity.max_hr ? `${Math.round(selectedActivity.max_hr)} bpm` : '--'} />
              <ActivityDetail label="Elevation" value={`${selectedActivity.elevation_m ?? 0} m`} />
            </div>
          </div>
        </div>
      )}
    </main>
  );
}
