import { createHash } from "node:crypto";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";

const youtubeIdPattern = /^[A-Za-z0-9_-]{11}$/;

/** Extracts a YouTube video id from watch, short, embed and youtu.be links. */
export function youtubeId(value: string): string | undefined {
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" || url.username || url.password) return undefined;
    const host = url.hostname.toLowerCase().replace(/^(?:www|m|music)\./, "");
    let id: string | null | undefined;
    if (host === "youtu.be") id = url.pathname.split("/")[1];
    else if (host === "youtube.com" || host === "youtube-nocookie.com") {
      const [, first, second] = url.pathname.split("/");
      id = first === "watch" ? url.searchParams.get("v") : ["embed", "shorts", "v"].includes(first ?? "") ? second : undefined;
    }
    return id && youtubeIdPattern.test(id) ? id : undefined;
  } catch { return undefined; }
}

export function isYoutubeId(value: unknown): value is string {
  return typeof value === "string" && youtubeIdPattern.test(value);
}

/**
 * A tiny page that hosts the official YouTube IFrame player, served from our
 * origin so the embed gets a valid referrer. The client drives it through
 * window.stage.* and receives state via the Flutter bridge or postMessage.
 */
export function youtubeEmbedPage(videoId: string) {
  return `<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>html,body{margin:0;height:100%;background:#000;overflow:hidden}
#wrap{position:fixed;inset:0;display:flex;align-items:center;justify-content:center}
#player{position:absolute;top:50%;left:50%;width:100vw;height:56.25vw;min-height:100vh;min-width:177.78vh;transform:translate(-50%,-50%)}</style>
</head><body><div id="wrap"><div id="player"></div></div>
<script>
var player, ready = false, pending = [];
function send(type, data) {
  var message = Object.assign({ type: type }, data || {});
  try { if (window.flutter_inappwebview) window.flutter_inappwebview.callHandler("stage", message); } catch (e) {}
  try { if (window.chrome && window.chrome.webview) window.chrome.webview.postMessage(message); } catch (e) {}
}
function run(fn) { if (ready) fn(); else pending.push(fn); }
window.stage = {
  play: function () { run(function () { player.mute(); player.playVideo(); }); },
  pause: function () { run(function () { player.pauseVideo(); }); },
  seek: function (seconds) { run(function () { player.seekTo(Math.max(0, seconds), true); }); },
  sync: function (seconds, playing) {
    run(function () {
      var current = player.getCurrentTime() || 0;
      if (Math.abs(current - seconds) > 1.0) player.seekTo(Math.max(0, seconds), true);
      var state = player.getPlayerState();
      if (playing && state !== 1 && state !== 3) { player.mute(); player.playVideo(); }
      if (!playing && state === 1) player.pauseVideo();
    });
  }
};
function onYouTubeIframeAPIReady() {
  player = new YT.Player("player", {
    videoId: ${JSON.stringify(videoId)},
    host: "https://www.youtube-nocookie.com",
    playerVars: { autoplay: 0, controls: 0, disablekb: 1, fs: 0, iv_load_policy: 3, modestbranding: 1,
      playsinline: 1, rel: 0, mute: 1, origin: location.origin },
    events: {
      onReady: function () {
        player.mute(); ready = true;
        send("ready", { duration: player.getDuration() || 0 });
        pending.splice(0).forEach(function (fn) { fn(); });
      },
      onStateChange: function (event) {
        send("state", { state: event.data, time: player.getCurrentTime() || 0 });
      },
      onError: function (event) { send("error", { code: event.data }); }
    }
  });
}
setInterval(function () {
  if (ready) send("time", { time: player.getCurrentTime() || 0, state: player.getPlayerState() });
}, 1000);
</script>
<script src="https://www.youtube.com/iframe_api"></script>
</body></html>`;
}

/**
 * Crowd-sourced clip offsets. Every voter (hashed address) keeps one value per
 * track+clip; the published offset is the median of the latest votes, so a
 * single bad actor cannot move it far.
 */
export class ClipOffsetStore {
  readonly #database: DatabaseSync;
  readonly #pepper: string;

  constructor(path: string, pepper = "") {
    if (path !== ":memory:") mkdirSync(dirname(path), { recursive: true });
    this.#database = new DatabaseSync(path);
    this.#pepper = pepper;
    this.#database.exec("PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000;");
    this.#database.exec(`
      CREATE TABLE IF NOT EXISTS clip_offset_votes (
        track_key TEXT NOT NULL,
        clip_id TEXT NOT NULL,
        voter TEXT NOT NULL,
        offset_ms INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (track_key, clip_id, voter)
      );
      CREATE INDEX IF NOT EXISTS idx_clip_offset_track ON clip_offset_votes(track_key);
    `);
  }

  vote(trackKey: string, clipId: string, voterAddress: string, offsetMs: number) {
    const voter = createHash("sha256").update(`${this.#pepper}:${voterAddress}`).digest("hex").slice(0, 32);
    this.#database.prepare(`
      INSERT INTO clip_offset_votes (track_key, clip_id, voter, offset_ms, updated_at) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT (track_key, clip_id, voter) DO UPDATE SET offset_ms = excluded.offset_ms, updated_at = excluded.updated_at
    `).run(trackKey, clipId, voter, Math.round(offsetMs), Date.now());
    return this.offsets(trackKey).get(clipId) ?? 0;
  }

  offsets(trackKey: string): Map<string, number> {
    const rows = this.#database.prepare(`
      SELECT clip_id, offset_ms FROM clip_offset_votes WHERE track_key = ? ORDER BY updated_at DESC LIMIT 400
    `).all(trackKey) as Array<{ clip_id: string; offset_ms: number }>;
    const grouped = new Map<string, number[]>();
    for (const row of rows) {
      const values = grouped.get(row.clip_id) ?? [];
      if (values.length < 25) values.push(Number(row.offset_ms));
      grouped.set(row.clip_id, values);
    }
    return new Map([...grouped].map(([clipId, values]) => {
      const sorted = values.sort((left, right) => left - right);
      const middle = sorted.length >> 1;
      const median = sorted.length % 2 ? sorted[middle]! : (sorted[middle - 1]! + sorted[middle]!) / 2;
      return [clipId, Math.round(median)];
    }));
  }
}
