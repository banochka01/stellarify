import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { invidiousVideos, songLinkVideos, YoutubeWebSearch } from "./clip-sources.js";

test("reads youtube.com cookies from a Netscape file and signs requests", () => {
  const path = join(mkdtempSync(join(tmpdir(), "yt-")), "cookies.txt");
  writeFileSync(path, [
    "# Netscape HTTP Cookie File",
    ".youtube.com\tTRUE\t/\tTRUE\t0\tSAPISID\tsecret-sapisid",
    "#HttpOnly_.youtube.com\tTRUE\t/\tTRUE\t0\tSID\tsid-value",
    ".google.com\tTRUE\t/\tTRUE\t0\tNID\tother-site"
  ].join("\n"));
  const search = YoutubeWebSearch.fromFile(path);
  assert.equal(search.signedIn, true);
  const headers = search.headers(1_700_000_000_000);
  assert.equal(headers.cookie, "SAPISID=secret-sapisid; SID=sid-value");
  assert.match(headers.authorization ?? "", /^SAPISIDHASH 1700000000_[0-9a-f]{40}$/);
  assert.equal(new YoutubeWebSearch().headers().cookie, undefined);
});

test("extracts video ids from YouTube web search results", async () => {
  const hits = await new YoutubeWebSearch().search(async (_url, init) => {
    assert.equal(init?.method, "POST");
    return { contents: { sections: [{ items: [
      { videoRenderer: { videoId: "4NRXx6U8ABQ", title: { runs: [{ text: "The Weeknd - Blinding Lights" }] },
        ownerText: { runs: [{ text: "TheWeekndVEVO" }] } } },
      { videoRenderer: { videoId: "bad id" } }
    ] }] } };
  }, "Blinding Lights", "The Weeknd");
  assert.deepEqual(hits, [{ id: "4NRXx6U8ABQ", title: "The Weeknd - Blinding Lights", channel: "TheWeekndVEVO", source: "YouTube" }]);
});

test("song.link sends the key and maps YouTube links; Invidious skips dead mirrors", async () => {
  const hits = await songLinkVideos(async (url) => {
    if (url.host === "itunes.apple.com") return { results: [{ trackName: "Signal", artistName: "Artist", trackViewUrl: "https://music.apple.com/x" }] };
    assert.equal(url.searchParams.get("key"), "k");
    return { linksByPlatform: { youtube: { url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ" } } };
  }, "k", "Signal", "Artist");
  assert.equal(hits[0]?.id, "dQw4w9WgXcQ");
  const searched = await invidiousVideos(async (url) => {
    if (url.host === "dead.example") throw new Error("down");
    return [{ type: "video", videoId: "dQw4w9WgXcQ", title: "Signal", author: "Artist" }, { type: "channel" }];
  }, ["https://dead.example", "https://live.example"], "Signal", "Artist");
  assert.deepEqual(searched.map((hit) => hit.id), ["dQw4w9WgXcQ"]);
});
