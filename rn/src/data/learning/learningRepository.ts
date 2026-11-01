// Learning repository. Mirrors app/lib/data/learning/learning_repository.dart.
import { API_BASE_URL } from "../../core/config/env";
import { learnedRouteFromJson } from "../../domain/learning/learnedRoute";
import type { LearnedRoute } from "../../domain/learning/learnedRoute";
import { learnedStopsResultFromJson } from "../../domain/learning/learnedStop";
import type { LearnedStopsResult } from "../../domain/learning/learnedStop";
import { LearnedRoutesIndex } from "../../domain/learning/learnedRouteIndex";
import { etaResultFromJson } from "../../domain/learning/etaEstimate";
import type { EtaResult } from "../../domain/learning/etaEstimate";

const TIMEOUT_MS = 8000;

async function getJson(url: string): Promise<{ status: number; body: any }> {
  const ctrl = new AbortController();
  const to = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(url, { signal: ctrl.signal });
    const body = res.ok ? await res.json().catch(() => null) : null;
    return { status: res.status, body };
  } finally {
    clearTimeout(to);
  }
}

export const learningRepo = {
  async fetchLearnedRoute(lineId: number): Promise<LearnedRoute | null> {
    try {
      const { status, body } = await getJson(`${API_BASE_URL}/v1/lines/${lineId}/learned-route`);
      if (status === 404) return null;
      if (status !== 200 || !body) return null;
      return learnedRouteFromJson(body as Record<string, unknown>);
    } catch {
      return null;
    }
  },
  async fetchStops(lineId: number): Promise<LearnedStopsResult | null> {
    try {
      const { status, body } = await getJson(`${API_BASE_URL}/v1/lines/${lineId}/stops`);
      if (status === 404) return null;
      if (status !== 200 || !body) return null;
      return learnedStopsResultFromJson(body as Record<string, unknown>);
    } catch {
      return null;
    }
  },
  async fetchLearnedRoutesIndex(): Promise<LearnedRoutesIndex> {
    try {
      const { status, body } = await getJson(`${API_BASE_URL}/v1/learned-routes`);
      if (status === 404 || status !== 200 || !body) return LearnedRoutesIndex.empty;
      return LearnedRoutesIndex.fromJson(body as Record<string, unknown>);
    } catch {
      return LearnedRoutesIndex.empty;
    }
  },
  async fetchEta(lineId: number, stopId: string): Promise<EtaResult | null> {
    try {
      const params = new URLSearchParams({ stop: stopId });
      const { status, body } = await getJson(`${API_BASE_URL}/v1/lines/${lineId}/eta?${params}`);
      if (status === 404) return null;
      if (status !== 200 || !body) return null;
      return etaResultFromJson(body as Record<string, unknown>);
    } catch {
      return null;
    }
  },
  async allLearnedRoutes(bbox?: string): Promise<LearnedRoutesIndex> {
    const url = bbox
      ? `${API_BASE_URL}/v1/learned-routes?bbox=${encodeURIComponent(bbox)}`
      : `${API_BASE_URL}/v1/learned-routes`;
    try {
      const { status, body } = await getJson(url);
      if (status !== 200 || !body) return LearnedRoutesIndex.empty;
      return LearnedRoutesIndex.fromJson(body as Record<string, unknown>);
    } catch {
      return LearnedRoutesIndex.empty;
    }
  },
};

export const learningRepository = learningRepo;
