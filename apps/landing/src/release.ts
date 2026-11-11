import { useEffect, useState } from "react";

export type DownloadKey = "windows" | "windowsPortable" | "android" | "ios";
export type VisitorOs = DownloadKey | "mac" | "linux";

export type ChangelogEntry = {
  version: string;
  date: string;
  title: string;
  highlights: string[];
};

export type ReleaseInfo = {
  version: string | null;
  sizes: Partial<Record<DownloadKey, number>>;
  /** Sizes of the Resonance α builds; empty until they are published. */
  alphaSizes: Partial<Record<DownloadKey, number>>;
  changelog: ChangelogEntry[];
};

export type Channel = "stable" | "alpha";

/** Version of the experimental Resonance α client. */
export const alphaVersion = "0.1.0";

export const downloads: Record<DownloadKey, string> = {
  windows: "/downloads/windows",
  windowsPortable: "/downloads/windows-portable",
  android: "/downloads/android",
  ios: "/downloads/ios"
};

/** Resonance α ships only these builds so far. */
export const alphaDownloads: Partial<Record<DownloadKey, string>> = {
  windowsPortable: "/downloads/alpha/windows",
  ios: "/downloads/alpha/ios"
};

export function downloadsFor(channel: Channel): Partial<Record<DownloadKey, string>> {
  return channel === "alpha" ? alphaDownloads : downloads;
}

const channelKey = "resonance.download-channel";
const channelEvent = "resonance:channel";

function readChannel(): Channel {
  try {
    return localStorage.getItem(channelKey) === "alpha" ? "alpha" : "stable";
  } catch {
    return "stable";
  }
}

/** Stable/alpha choice shared by every download control on the page. */
export function useChannel(): [Channel, (channel: Channel) => void] {
  const [channel, setChannel] = useState<Channel>(readChannel);
  useEffect(() => {
    const sync = () => setChannel(readChannel());
    window.addEventListener(channelEvent, sync);
    window.addEventListener("storage", sync);
    return () => {
      window.removeEventListener(channelEvent, sync);
      window.removeEventListener("storage", sync);
    };
  }, []);
  const update = (next: Channel) => {
    try {
      localStorage.setItem(channelKey, next);
    } catch {
      // Private mode: the choice simply lasts for this page.
    }
    setChannel(next);
    window.dispatchEvent(new Event(channelEvent));
  };
  return [channel, update];
}

export function detectOs(): VisitorOs {
  const nav = navigator as Navigator & { userAgentData?: { platform?: string } };
  const ua = navigator.userAgent;
  const platform = nav.userAgentData?.platform ?? navigator.platform ?? "";
  if (/android/i.test(ua)) return "android";
  if (/iPhone|iPad|iPod/i.test(ua) || (/Mac/i.test(platform) && navigator.maxTouchPoints > 1)) return "ios";
  if (/Mac/i.test(platform) || /Mac OS X/i.test(ua)) return "mac";
  if (/Linux|X11|CrOS/i.test(platform) || /Linux/i.test(ua)) return "linux";
  return "windows";
}

export function formatSize(bytes: number | undefined): string | null {
  if (!bytes) return null;
  return `${Math.round(bytes / 1024 / 1024)} МБ`;
}

export function formatDate(iso: string): string {
  const date = new Date(`${iso}T12:00:00`);
  return Number.isNaN(date.getTime())
    ? iso
    : date.toLocaleDateString("ru-RU", { day: "numeric", month: "long", year: "numeric" });
}

async function json<T>(url: string): Promise<T | null> {
  try {
    const response = await fetch(url, { headers: { Accept: "application/json" } });
    return response.ok ? ((await response.json()) as T) : null;
  } catch {
    return null;
  }
}

async function size(url: string): Promise<number | undefined> {
  try {
    const response = await fetch(url, { method: "HEAD" });
    const length = Number(response.headers.get("content-length"));
    return response.ok && length > 0 ? length : undefined;
  } catch {
    return undefined;
  }
}

let cached: Promise<ReleaseInfo> | null = null;

function loadRelease(): Promise<ReleaseInfo> {
  cached ??= (async () => {
    const keys = Object.keys(downloads) as DownloadKey[];
    const alphaKeys = Object.keys(alphaDownloads) as DownloadKey[];
    const [version, log, alphaLengths, ...lengths] = await Promise.all([
      json<{ version?: string }>("/api/client-version"),
      json<{ entries?: ChangelogEntry[] }>("/api/v1/changelog?channel=stable&limit=8"),
      Promise.all(alphaKeys.map((key) => size(alphaDownloads[key]!))),
      ...keys.map((key) => size(downloads[key]))
    ]);
    const sizes: ReleaseInfo["sizes"] = {};
    keys.forEach((key, index) => { if (lengths[index]) sizes[key] = lengths[index]; });
    const alphaSizes: ReleaseInfo["alphaSizes"] = {};
    alphaKeys.forEach((key, index) => { if (alphaLengths[index]) alphaSizes[key] = alphaLengths[index]; });
    return {
      version: version?.version ?? null,
      sizes,
      alphaSizes,
      changelog: Array.isArray(log?.entries) ? log.entries : []
    };
  })();
  return cached;
}

/** Live release data; the page renders fine with the empty default if the API is unreachable. */
export function useRelease(): ReleaseInfo {
  const [info, setInfo] = useState<ReleaseInfo>({ version: null, sizes: {}, alphaSizes: {}, changelog: [] });
  useEffect(() => {
    let alive = true;
    void loadRelease().then((value) => { if (alive) setInfo(value); });
    return () => { alive = false; };
  }, []);
  return info;
}
