const API_URL = (import.meta.env.PUBLIC_API_URL || 'http://136.112.108.87:8081').replace(/\/+$/, '');

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({ detail: res.statusText }));
    throw new Error(body.detail || res.statusText);
  }
  return res.json();
}

export async function getAuthUrl(): Promise<string> {
  const data = await request<{ url: string }>('/api/auth/strava/url');
  return data.url;
}

export async function exchangeCode(code: string): Promise<{
  access_token: string;
  refresh_token: string;
  expires_at: number;
  athlete: { firstname: string; lastname: string };
}> {
  return request('/api/auth/strava/callback', {
    method: 'POST',
    body: JSON.stringify({ code }),
  });
}

export async function sendMessage(
  message: string,
  history: Record<string, unknown>[],
  accessToken: string,
): Promise<{ response: string; conversation_history: Record<string, unknown>[] }> {
  return request('/api/chat', {
    method: 'POST',
    body: JSON.stringify({ message, access_token: accessToken, conversation_history: history }),
  });
}

export async function getStarterQuestions(): Promise<string[]> {
  return request('/api/chat/starters');
}

export interface Activity {
  id: number;
  name: string;
  date: string;
  distance_km: number;
  duration_min: number;
  pace_min_km: number | null;
  avg_hr: number | null;
  max_hr: number | null;
  elevation_m: number | null;
  type: string;
}

export interface FitnessMetrics {
  current: { date: string; ctl: number; atl: number; tsb: number };
  four_weeks_ago: { date: string; ctl: number };
  ctl_change: number;
  trend: Array<{ date: string; ctl: number; atl: number; tsb: number; tss: number }>;
  interpretation: string;
  note: string;
}

export interface PaceHrTrend {
  week: string;
  avg_pace_min_km: number;
  avg_hr: number;
  efficiency: number;
  efficiency_unit?: string;
  run_count: number;
}

export interface PersonalStats {
  ytd_distance_km: number;
  ytd_runs: number;
  ytd_elevation_m: number;
  all_time_distance_km: number;
  recent_4w_distance_km: number;
}

function tokenBody(accessToken: string) {
  return { method: 'POST', body: JSON.stringify({ access_token: accessToken }) };
}

export async function getActivities(accessToken: string, weeks = 8): Promise<Activity[]> {
  return request(`/api/strava/activities?weeks=${weeks}`, tokenBody(accessToken));
}

export async function getFitness(accessToken: string, days = 56): Promise<FitnessMetrics> {
  return request(`/api/strava/fitness?days=${days}`, tokenBody(accessToken));
}

export async function getPaceHrTrend(accessToken: string, weeks = 8): Promise<PaceHrTrend[]> {
  return request(`/api/strava/trend?weeks=${weeks}`, tokenBody(accessToken));
}

export async function getPersonalStats(accessToken: string): Promise<PersonalStats> {
  return request('/api/strava/stats', tokenBody(accessToken));
}
