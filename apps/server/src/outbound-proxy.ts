import { Agent, Dispatcher, ProxyAgent, setGlobalDispatcher } from "undici";
import { normalizeProxyUrl } from "./soundcloud.js";

/** Provider hosts that must never be reached directly from the server. */
export const DEFAULT_PROXIED_HOSTS = [
  "youtube.com", "youtu.be", "youtube-nocookie.com", "googlevideo.com", "ytimg.com", "googleapis.com",
  "soundcloud.com", "sndcdn.com", "soundcloud.cloud",
  "spotify.com", "spotifycdn.com", "scdn.co", "spotify.link"
];

export function hostMatches(hostname: string, suffixes: readonly string[]) {
  const host = hostname.toLowerCase().replace(/\.$/, "");
  return suffixes.some((suffix) => host === suffix || host.endsWith(`.${suffix}`));
}

/**
 * Routes provider hosts through the proxy and everything else directly. A
 * request that already carries its own dispatcher (the SoundCloud relay) keeps
 * it; this only replaces the default route.
 */
export class HostRoutingDispatcher extends Dispatcher {
  constructor(
    private readonly proxy: Dispatcher,
    private readonly direct: Dispatcher,
    private readonly hosts: readonly string[]
  ) { super(); }

  route(origin: string | URL | undefined) {
    try {
      return origin && hostMatches(new URL(String(origin)).hostname, this.hosts) ? this.proxy : this.direct;
    } catch { return this.direct; }
  }

  override dispatch(options: Dispatcher.DispatchOptions, handler: Dispatcher.DispatchHandler) {
    return this.route(options.origin).dispatch(options, handler);
  }

  // Dispatcher declares callback and promise overloads for close/destroy.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  override close(...args: any[]): any {
    const done = Promise.all([this.proxy.close(), this.direct.close()]).then(() => undefined);
    const callback = args.find((arg) => typeof arg === "function") as (() => void) | undefined;
    if (!callback) return done;
    void done.then(callback, callback);
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  override destroy(...args: any[]): any {
    const error = args.find((arg) => arg instanceof Error) as Error | undefined;
    const done = Promise.all([this.proxy.destroy(error ?? null), this.direct.destroy(error ?? null)]).then(() => undefined);
    const callback = args.find((arg) => typeof arg === "function") as (() => void) | undefined;
    if (!callback) return done;
    void done.then(callback, callback);
  }
}

/**
 * PROVIDER_PROXY_URL (or the existing SOUNDCLOUD_PROXY_URL) becomes the route
 * for YouTube, SoundCloud and Spotify. PROVIDER_PROXY_HOSTS may override the
 * host list. Returns the active host list, or undefined when no proxy is set.
 */
export function installProviderProxy(env = process.env) {
  const url = normalizeProxyUrl(env.PROVIDER_PROXY_URL || env.SOUNDCLOUD_PROXY_URL);
  if (!url) return undefined;
  const hosts = env.PROVIDER_PROXY_HOSTS
    ? env.PROVIDER_PROXY_HOSTS.split(",").map((host) => host.trim().toLowerCase()).filter(Boolean)
    : DEFAULT_PROXIED_HOSTS;
  setGlobalDispatcher(new HostRoutingDispatcher(new ProxyAgent(url), new Agent(), hosts));
  return hosts;
}
