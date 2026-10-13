// Opaque device tokens. 256-bit CSPRNG, prefix bm1_, only SHA-256 stored.
// See PLAN.md 6.9. Never log tokens.
// SECURITY: token format is fixed; lookups are by hash only.

const PREFIX = "bm1_";

function base64Url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  const b64 = btoa(s).replaceAll("+", "-").replaceAll("/", "_").replaceAll(
    "=",
    "",
  );
  return b64;
}

/** Generate a new opaque token: bm1_ plus 43 base64url chars (32 bytes). */
export function generateToken(): string {
  return PREFIX + base64Url(crypto.getRandomValues(new Uint8Array(32)));
}

/** True when the token has the expected shape. */
export function isTokenFormat(token: string): boolean {
  return /^bm1_[A-Za-z0-9_-]{43}$/.test(token);
}

/** Extract the bearer token, or null when missing or malformed. */
export function bearerToken(header: string | null): string | null {
  if (!header) return null;
  const m = /^Bearer (bm1_[A-Za-z0-9_-]{43})$/.exec(header.trim());
  return m ? m[1] : null;
}

/** SHA-256 hash of the token for storage and lookup. */
export async function tokenHash(token: string): Promise<Uint8Array> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(token),
  );
  return new Uint8Array(digest);
}

/** Hex rendering of a hash, for cache keys. Single home for the
 * conversion so auth and account routes cannot drift apart. */
export function hashHex(hash: Uint8Array): string {
  return [...hash].map((b) => b.toString(16).padStart(2, "0")).join("");
}
