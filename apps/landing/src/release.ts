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
  changelog: ChangelogEntry[];
};

export const downloads: Record<DownloadKey, string> = {
  windows: "/downloads/windows",
  windowsPortable: "/downloads/windows-portable",
  android: "/downloads/android",
  ios: "/downloads/ios"
};

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
    const [version, log, ...lengths] = await Promise.all([
      json<{ version?: string }>("/api/client-version"),
      json<{ entries?: ChangelogEntry[] }>("/api/v1/changelog?channel=stable&limit=8"),
      ...keys.map((key) => size(downloads[key]))
    ]);
    const sizes: ReleaseInfo["sizes"] = {};
    keys.forEach((key, index) => { if (lengths[index]) sizes[key] = lengths[index]; });
    return {
      version: version?.version ?? null,
      sizes,
      changelog: Array.isArray(log?.entries) ? log.entries : []
    };
  })();
  return cached;
}

/** Live release data; the page renders fine with the empty default if the API is unreachable. */
export function useRelease(): ReleaseInfo {
  const [info, setInfo] = useState<ReleaseInfo>({ version: null, sizes: {}, changelog: [] });
  useEffect(() => {
    let alive = true;
    void loadRelease().then((value) => { if (alive) setInfo(value); });
    return () => { alive = false; };
  }, []);
  return info;
}
