// Shared HTTP client. Mirrors app/lib/data/net/http_client.dart.
export const requestTimeout = 15000;

export interface HttpClient {
  get(url: string, headers?: Record<string, string>): Promise<Response>;
  post(url: string, body?: unknown, headers?: Record<string, string>): Promise<Response>;
  delete(url: string, headers?: Record<string, string>): Promise<Response>;
}

export function createHttpClient(): HttpClient {
  const request = async (
    method: string,
    url: string,
    body?: unknown,
    headers?: Record<string, string>,
  ): Promise<Response> => {
    const ctrl = new AbortController();
    const to = setTimeout(() => ctrl.abort(), requestTimeout);
    try {
      const res = await fetch(url, {
        method,
        headers: { "content-type": "application/json", ...(headers ?? {}) },
        body: body != null ? JSON.stringify(body) : undefined,
        signal: ctrl.signal,
      });
      return res;
    } finally {
      clearTimeout(to);
    }
  };
  return {
    get: (url, headers) => request("GET", url, undefined, headers),
    post: (url, body, headers) => request("POST", url, body, headers),
    delete: (url, headers) => request("DELETE", url, undefined, headers),
  };
}
