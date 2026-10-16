import assert from "node:assert/strict";
import test from "node:test";
import { dotifyFileSchema, importDotifyFile } from "./dotify-file.js";

test("maps .dotifyplaylist tracks by source and matches Apple Music on SoundCloud", async () => {
  const file = dotifyFileSchema.parse({
    id: "99049705",
    title: "Мне нравится",
    tracks: [
      { id: "1595213250", title: "к чёрту любовь", artist: "Edge Runner", duration: 234, source: "soundcloud", cover_art: "https://i1.sndcdn.com/a.jpg" },
      { id: "129483669", title: "Трек", artist: "Артист", source: "yandex", album: { title: "Альбом" } },
      { id: "6cf7CqOH2WU", title: "Видео", artist: "Канал", source: "youtube" },
      { id: "1890018672", title: "Song", artist: "Singer", source: "applemusic" },
      { id: "1", title: "Nothing", artist: "Nobody", source: "applemusic" }
    ]
  });
  const queries: string[] = [];
  const soundcloud = {
    searchTracks: async (query: string) => {
      queries.push(query);
      return query.startsWith("Singer") ? [{ id: "soundcloud:tracks:5", title: "Song", artist: "Singer", externalUrl: "https://soundcloud.com/s/song" }] : [];
    }
  };
  const result = await importDotifyFile(file, soundcloud);
  assert.equal(result.title, "Мне нравится");
  assert.deepEqual(result.tracks.map((track) => [track.provider, track.id]), [
    ["soundcloud", "soundcloud:tracks:1595213250"],
    ["yandex", "129483669"],
    ["youtube", "6cf7CqOH2WU"],
    ["soundcloud", "soundcloud:tracks:5"]
  ]);
  assert.equal(result.tracks[0]?.durationMs, 234_000);
  assert.equal(result.tracks[1]?.album, "Альбом");
  assert.deepEqual(queries, ["Singer Song", "Nobody Nothing"]);
  assert.equal(result.unmatched, 1);
});
