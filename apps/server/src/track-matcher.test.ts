import assert from "node:assert/strict";
import test from "node:test";
import {
  confidenceAtLeast,
  matchTrack,
  normalizeTitle,
  scoreTrackPair,
  searchQueryFor,
  type MatchConfidence,
  type MatchableTrack
} from "./track-matcher.js";

type Fixture = {
  name: string;
  source: MatchableTrack;
  candidate: MatchableTrack;
  /** Minimum confidence the matcher must reach (for positive pairs). */
  atLeast?: MatchConfidence;
  /** Maximum confidence allowed (for negative pairs). */
  atMost?: MatchConfidence;
};

const t = (artist: string, title: string, seconds?: number, isrc?: string): MatchableTrack => ({
  artist,
  title,
  ...(seconds ? { durationMs: seconds * 1_000 } : {}),
  ...(isrc ? { isrc } : {})
});

// Hand-written regression fixture of known Spotify/VK/Yandex pairs.
const fixtures: Fixture[] = [
  { name: "isrc wins over metadata", source: t("Queen", "Bohemian Rhapsody - Remastered 2011", 355, "GBUM71029604"), candidate: t("Queen", "Bohemian Rhapsody", 354, "gbum71029604"), atLeast: "exact" },
  { name: "identical", source: t("Daft Punk", "Get Lucky", 369), candidate: t("Daft Punk", "Get Lucky", 368), atLeast: "exact" },
  { name: "remaster dash suffix", source: t("The Beatles", "Let It Be - Remastered 2009", 243), candidate: t("The Beatles", "Let It Be", 243), atLeast: "exact" },
  { name: "remaster brackets", source: t("Pink Floyd", "Wish You Were Here (2011 Remaster)", 334), candidate: t("Pink Floyd", "Wish You Were Here", 335), atLeast: "exact" },
  { name: "feat in title", source: t("Eminem", "Love The Way You Lie (feat. Rihanna)", 263), candidate: t("Eminem, Rihanna", "Love The Way You Lie", 263), atLeast: "high" },
  { name: "ft. outside brackets", source: t("Calvin Harris", "This Is What You Came For ft. Rihanna", 222), candidate: t("Calvin Harris", "This Is What You Came For", 222), atLeast: "high" },
  { name: "with credit", source: t("Post Malone", "Sunflower (with Swae Lee)", 158), candidate: t("Post Malone & Swae Lee", "Sunflower", 158), atLeast: "high" },
  { name: "cyrillic vs latin artist", source: t("Кино", "Группа крови", 286), candidate: t("Kino", "Gruppa krovi", 287), atLeast: "high" },
  { name: "tsoi transliteration", source: t("Виктор Цой", "Кукушка", 400), candidate: t("Viktor Tsoi", "Kukushka", 399), atLeast: "high" },
  { name: "yo vs e", source: t("Земфира", "Хочешь?", 210), candidate: t("Земфира", "Хочешь", 211), atLeast: "exact" },
  { name: "case and punctuation", source: t("AC/DC", "Back In Black", 255), candidate: t("AC/DC", "back in black", 255), atLeast: "exact" },
  { name: "ampersand vs and", source: t("Simon & Garfunkel", "The Sound of Silence", 185), candidate: t("Simon and Garfunkel", "Sound of Silence", 185), atLeast: "high" },
  { name: "the prefix artist", source: t("The Weeknd", "Blinding Lights", 200), candidate: t("Weeknd", "Blinding Lights", 201), atLeast: "high" },
  { name: "multiple artists order", source: t("Lady Gaga, Bradley Cooper", "Shallow", 215), candidate: t("Bradley Cooper, Lady Gaga", "Shallow", 216), atLeast: "high" },
  { name: "diacritics", source: t("Beyoncé", "Halo", 261), candidate: t("Beyonce", "Halo", 261), atLeast: "exact" },
  { name: "radio edit", source: t("Avicii", "Levels - Radio Edit", 199), candidate: t("Avicii", "Levels", 200), atLeast: "high" },
  { name: "single version brackets", source: t("Coldplay", "Yellow (Single Version)", 266), candidate: t("Coldplay", "Yellow", 267), atLeast: "high" },
  { name: "unknown duration", source: t("Linkin Park", "Numb"), candidate: t("Linkin Park", "Numb", 185), atLeast: "high" },
  { name: "duration within 3s", source: t("Muse", "Hysteria", 227), candidate: t("Muse", "Hysteria", 230), atLeast: "exact" },
  { name: "small typo", source: t("Imagine Dragons", "Believer", 204), candidate: t("Imagine Dragons", "Beliver", 204), atLeast: "high" },
  { name: "russian with feat", source: t("Баста", "Сансара (feat. Скриптонит)", 290), candidate: t("Баста, Скриптонит", "Сансара", 291), atLeast: "high" },
  { name: "yandex russian latin title", source: t("Мумий Тролль", "Владивосток 2000", 160), candidate: t("Mumiy Troll", "Vladivostok 2000", 161), atLeast: "high" },
  { name: "explicit tag", source: t("Kendrick Lamar", "HUMBLE. (Explicit)", 177), candidate: t("Kendrick Lamar", "HUMBLE.", 177), atLeast: "exact" },
  { name: "deluxe tag", source: t("Adele", "Hello (Deluxe)", 295), candidate: t("Adele", "Hello", 295), atLeast: "exact" },
  { name: "duration far but same metadata stays low", source: t("Nirvana", "Smells Like Teen Spirit", 301), candidate: t("Nirvana", "Smells Like Teen Spirit", 340), atLeast: "low", atMost: "low" },

  // Negative pairs: must not be confidently matched.
  { name: "remix is not original", source: t("Dua Lipa", "Levitating", 203), candidate: t("Dua Lipa", "Levitating (DaBaby Remix)", 229), atMost: "low" },
  { name: "live is not studio", source: t("Nirvana", "Lithium", 257), candidate: t("Nirvana", "Lithium (Live)", 272), atMost: "low" },
  { name: "acoustic version kept", source: t("Oasis", "Wonderwall", 258), candidate: t("Oasis", "Wonderwall (Acoustic Version)", 250), atMost: "low" },
  { name: "different song same artist", source: t("Metallica", "One", 446), candidate: t("Metallica", "Fade to Black", 417), atMost: "none" },
  { name: "same title different artist", source: t("Adele", "Hello", 295), candidate: t("Lionel Richie", "Hello", 246), atMost: "low" },
  { name: "cover by other artist", source: t("Leonard Cohen", "Hallelujah", 279), candidate: t("Jeff Buckley", "Hallelujah", 413), atMost: "low" },
  { name: "unrelated russian", source: t("Кино", "Звезда по имени Солнце", 225), candidate: t("Ленинград", "Экспонат", 190), atMost: "none" },
  { name: "isrc mismatch falls back to metadata", source: t("Queen", "Under Pressure", 248, "GBUM71029605"), candidate: t("Queen", "Somebody to Love", 296, "GBUM71029606"), atMost: "none" }
];

const rank = { none: 0, low: 1, high: 2, exact: 3 } as const;

for (const fixture of fixtures) {
  test(`matcher fixture: ${fixture.name}`, () => {
    const { confidence, score } = scoreTrackPair(fixture.source, fixture.candidate);
    if (fixture.atLeast) {
      assert.ok(
        rank[confidence] >= rank[fixture.atLeast],
        `${fixture.name}: expected ≥ ${fixture.atLeast}, got ${confidence} (${score})`
      );
    }
    if (fixture.atMost) {
      assert.ok(
        rank[confidence] <= rank[fixture.atMost],
        `${fixture.name}: expected ≤ ${fixture.atMost}, got ${confidence} (${score})`
      );
    }
  });
}

test("matcher fixture keeps an overall success rate above 95%", () => {
  const positives = fixtures.filter((fixture) => fixture.atLeast && !fixture.atMost);
  const hits = positives.filter((fixture) =>
    confidenceAtLeast(scoreTrackPair(fixture.source, fixture.candidate).confidence, "high")
  );
  assert.ok(positives.length >= 20);
  assert.ok(hits.length / positives.length >= 0.95, `${hits.length}/${positives.length}`);
});

test("matchTrack picks the best candidate and prefers the original over a remix", () => {
  const source = t("Dua Lipa", "Levitating", 203);
  const result = matchTrack(source, [
    t("Dua Lipa", "Levitating (DaBaby Remix)", 229),
    t("Dua Lipa", "Levitating", 203),
    t("Dua Lipa", "Physical", 193)
  ]);
  assert.equal(result.candidate?.title, "Levitating");
  assert.equal(result.confidence, "exact");
});

test("matchTrack reports none without a candidate", () => {
  const result = matchTrack(t("Metallica", "One", 446), [t("ABBA", "Waterloo", 168)]);
  assert.equal(result.confidence, "none");
  assert.equal(result.candidate, undefined);
});

test("normalization strips noise but keeps meaningful fragments", () => {
  assert.equal(normalizeTitle("Let It Be - Remastered 2009"), normalizeTitle("Let it be"));
  assert.notEqual(normalizeTitle("Levitating (Remix)"), normalizeTitle("Levitating"));
  assert.equal(normalizeTitle("Кукушка"), normalizeTitle("Kukushka"));
  assert.equal(searchQueryFor(t("Eminem, Rihanna", "Love The Way You Lie (feat. Rihanna)")), "Eminem love the way you lie");
});
