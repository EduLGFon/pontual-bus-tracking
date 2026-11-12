// Client IP resolution. IPs are used for in-memory rate-limit buckets only
// and are never stored or logged. See PLAN.md 6.9.
// CF-Connecting-IP is trusted only when TRUST_CLOUDFLARE is true. In this
// deployment the API is unpublished and shares the internal edge network
// only with cloudflared, so the header cannot come from an untrusted peer.

/** Resolve the client IP from the socket or the Cloudflare header. */
export function clientIp(
  socketAddr: string | null,
  cfConnectingIp: string | null,
  trustCloudflare: boolean,
): string {
  if (trustCloudflare && cfConnectingIp && cfConnectingIp !== "") {
    return cfConnectingIp.trim();
  }
  return socketAddr ?? "unknown";
}
