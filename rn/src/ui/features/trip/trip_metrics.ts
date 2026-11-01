// Trip metrics. Port of app/lib/ui/features/trip/trip_metrics.dart.
export function formatElapsed(totalS: number): string {
  const s = totalS < 0 ? 0 : Math.floor(totalS);
  const hh = String(Math.floor(s / 3600)).padStart(2, "0");
  const mm = String(Math.floor((s / 60) % 60)).padStart(2, "0");
  const ss = String(s % 60).padStart(2, "0");
  return `${hh}:${mm}:${ss}`;
}

export function roleLabel(role: string | null | undefined): string {
  switch (role) {
    case "L":
    case "leader":
      return "líder";
    case "F":
    case "follower":
      return "viajante";
    default:
      return "conectando";
  }
}
