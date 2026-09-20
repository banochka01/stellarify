import { ProxyAgent, type Dispatcher } from "undici";
import { normalizeProxyUrl } from "./soundcloud.js";

export type ProxiedRequestInit = RequestInit & { dispatcher?: Dispatcher };
export type ProxiedFetch = typeof fetch;

/**
 * Keeps provider proxy credentials on the server while exposing a normal
 * fetch-compatible function to provider adapters.
 */
export function createProxiedFetch(proxyUrl?: string): ProxiedFetch {
  const normalized = normalizeProxyUrl(proxyUrl);
  const dispatcher = normalized ? new ProxyAgent(normalized) : undefined;
  return (input, init) =>
    fetch(input, {
      ...init,
      ...(dispatcher ? { dispatcher } : {})
    } as ProxiedRequestInit);
}
