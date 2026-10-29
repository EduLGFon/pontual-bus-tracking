// Learning repository. Mirrors app/lib/data/learning/learning_repository.dart (simplified).
import { API_BASE_URL } from "../../core/config/env";

export const learningRepo = {
  async learnedRoute(lineId: number) {
    try {
      const res = await fetch(`${API_BASE_URL}/v1/lines/${lineId}/learned-route`);
      if (!res.ok) return null;
      return res.json();
    } catch {
      return null;
    }
  },
  async learnedStops(lineId: number) {
    try {
      const res = await fetch(`${API_BASE_URL}/v1/lines/${lineId}/stops`);
      if (!res.ok) return null;
      return res.json();
    } catch {
      return null;
    }
  },
  async eta(lineId: number, stopId: string, vehicle?: string) {
    try {
      const params = new URLSearchParams({ stop: stopId });
      if (vehicle) params.set("vehicle", vehicle);
      const res = await fetch(`${API_BASE_URL}/v1/lines/${lineId}/eta?${params}`);
      if (!res.ok) return null;
      return res.json();
    } catch {
      return null;
    }
  },
  async allLearnedRoutes(bbox?: string) {
    try {
      const url = bbox
        ? `${API_BASE_URL}/v1/learned-routes?bbox=${encodeURIComponent(bbox)}`
        : `${API_BASE_URL}/v1/learned-routes`;
      const res = await fetch(url);
      if (!res.ok) return null;
      return res.json();
    } catch {
      return null;
    }
  },
};
