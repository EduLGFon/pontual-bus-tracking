// Backoff with jitter. Mirrors app/lib/core/net/backoff.dart.
export function backoffMs(attempt: number, baseMs = 500, capMs = 30000): number {
  const exp = Math.min(capMs, baseMs * 2 ** attempt);
  const jitter = Math.random() * 0.3 * exp;
  return Math.round(exp + (Math.random() < 0.5 ? -jitter : jitter));
}
