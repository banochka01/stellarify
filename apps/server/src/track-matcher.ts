/**
 * Cross-provider track matching for "Переезд" (library migration).
 *
 * Strategy: ISRC equality wins outright. Otherwise both sides are reduced to a
 * normalized, transliterated form (feat./remaster/version noise stripped) and
 * compared with a weighted title + artist similarity, gated by a ±3 s duration
 * tolerance.
 */

export type MatchConfidence = "exact" | "high" | "low" | "none";

export interface MatchableTrack {
  title: string;
  artist: string;
  durationMs?: number;
  isrc?: string;
}

export interface MatchResult<T extends MatchableTrack> {
  candidate?: T;
  confidence: MatchConfidence;
  score: number;
}

export const DURATION_TOLERANCE_MS = 3_000;

const NOISE_WORDS = [
  "feat", "ft", "featuring", "with", "prod",
  "remaster", "remastered", "remasterd", "mono", "stereo",
  "deluxe", "bonus", "explicit", "clean", "single version", "album version",
  "original mix", "radio edit", "edit", "version", "anniversary", "expanded",
  "from", "ost", "soundtrack", "official", "audio", "video", "lyrics", "hd", "hq"
];

const NOISE_PATTERN = new RegExp(
  `(^|\\s)(${NOISE_WORDS.map((word) => word.replace(/ /g, "\\s+")).join("|")})(\\.|\\s|$)|\\b(19|20)\\d{2}\\b`,
  "iu"
);

const CYRILLIC: Record<string, string> = {
  а: "a", б: "b", в: "v", г: "g", д: "d", е: "e", ё: "e", ж: "zh", з: "z", и: "i",
  й: "i", к: "k", л: "l", м: "m", н: "n", о: "o", п: "p", р: "r", с: "s", т: "t",
  у: "u", ф: "f", х: "h", ц: "ts", ч: "ch", ш: "sh", щ: "sch", ъ: "", ы: "y", ь: "",
  э: "e", ю: "yu", я: "ya", і: "i", ї: "i", є: "e", ґ: "g", ў: "u"
};

/** Folds Latin transliteration variants so "Кино"/"Kino", "Цой"/"Tsoi"/"Coi" meet. */
function foldLatin(value: string) {
  return value
    .replace(/kh/g, "h")
    .replace(/sch|shch/g, "sh")
    .replace(/tz|tc|ts|cz/g, "c")
    .replace(/(?<=[aeiou])j(?=[aeiou]|$|\s)/g, "i")
    .replace(/y(?=[aeiou])/g, "i")
    .replace(/([aeiou])y\b/g, "$1i")
    .replace(/w/g, "v")
    .replace(/x/g, "ks")
    .replace(/ph/g, "f")
    // Letters only: collapsing digits would make "Song 2" equal "Song 22".
    .replace(/(\p{L})\1+/gu, "$1");
}

export function transliterate(value: string) {
  let output = "";
  for (const char of value) output += CYRILLIC[char] ?? char;
  return output;
}

function baseNormalize(value: string) {
  return value
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/ё/g, "е")
    .replace(/[’'`´]/g, "")
    .replace(/&/g, " and ");
}

const KEEP_PATTERN = /remix|rmx|live|acoustic|instrumental|karaoke|cover|sped|slowed|nightcore|demo|unplugged|extended|акуст|ремикс|концерт/iu;

const isNoise = (fragment: string) => NOISE_PATTERN.test(` ${fragment} `) && !KEEP_PATTERN.test(fragment);

/** Removes bracketed or dash-suffixed fragments that only describe the release. */
export function stripTitleNoise(title: string) {
  let value = baseNormalize(title);
  value = value.replace(/[([{]([^)\]}]*)[)\]}]/g, (_whole, inner: string) =>
    isNoise(inner) ? " " : ` ${inner} `
  );
  value = value.replace(/\s[-–—]\s(.*)$/u, (_whole, tail: string) =>
    isNoise(tail) ? "" : ` ${tail}`
  );
  value = value.replace(/\s(feat|ft|featuring)\.?\s.*$/u, "");
  return value;
}

function tokenize(value: string) {
  return foldLatin(
    transliterate(value)
      .replace(/[^\p{L}\p{N}]+/gu, " ")
      .trim()
  )
    .split(/\s+/)
    .filter((token) => token && !["the", "a", "an", "and", "i"].includes(token));
}

export function normalizeTitle(title: string) {
  return tokenize(stripTitleNoise(title)).join(" ");
}

export function splitArtists(artist: string) {
  return baseNormalize(artist)
    .split(/\s*(?:,|;|\/|\s&\s|\sand\s|\sx\s|\sи\s|\sfeat\.?\s|\sft\.?\s|\sfeaturing\s|\svs\.?\s|\swith\s)\s*/u)
    .map((part) => tokenize(part).join(" "))
    .filter(Boolean);
}

export function normalizeArtist(artist: string) {
  return splitArtists(artist)[0] ?? "";
}

export function levenshteinRatio(left: string, right: string) {
  if (left === right) return 1;
  if (!left.length || !right.length) return 0;
  let previous = Array.from({ length: right.length + 1 }, (_, index) => index);
  for (let i = 1; i <= left.length; i += 1) {
    const current = [i];
    for (let j = 1; j <= right.length; j += 1) {
      current[j] = Math.min(
        previous[j]! + 1,
        current[j - 1]! + 1,
        previous[j - 1]! + (left[i - 1] === right[j - 1] ? 0 : 1)
      );
    }
    previous = current;
  }
  return 1 - previous[right.length]! / Math.max(left.length, right.length);
}

function tokenSetSimilarity(left: string, right: string) {
  const a = new Set(left.split(" ").filter(Boolean));
  const b = new Set(right.split(" ").filter(Boolean));
  if (!a.size || !b.size) return 0;
  let shared = 0;
  for (const token of a) if (b.has(token)) shared += 1;
  return (2 * shared) / (a.size + b.size);
}

function stringSimilarity(left: string, right: string) {
  if (!left || !right) return 0;
  if (left === right) return 1;
  const compactLeft = left.replace(/ /g, "");
  const compactRight = right.replace(/ /g, "");
  if (compactLeft === compactRight) return 0.98;
  return Math.max(levenshteinRatio(compactLeft, compactRight), tokenSetSimilarity(left, right));
}

export function titleSimilarity(left: string, right: string) {
  return stringSimilarity(normalizeTitle(left), normalizeTitle(right));
}

export function artistSimilarity(left: string, right: string) {
  const a = splitArtists(left);
  const b = splitArtists(right);
  if (!a.length || !b.length) return 0;
  let best = 0;
  for (const x of a) for (const y of b) best = Math.max(best, stringSimilarity(x, y));
  // Whole-credit comparison catches "Simon & Garfunkel" vs "Simon and Garfunkel".
  return Math.max(best, stringSimilarity(a.join(" "), b.join(" ")));
}

function durationCompatible(left?: number, right?: number) {
  if (!left || !right) return undefined;
  return Math.abs(left - right) <= DURATION_TOLERANCE_MS;
}

export function scoreTrackPair(source: MatchableTrack, candidate: MatchableTrack): {
  confidence: MatchConfidence;
  score: number;
} {
  const sourceIsrc = source.isrc?.trim().toUpperCase();
  if (sourceIsrc && sourceIsrc === candidate.isrc?.trim().toUpperCase()) {
    return { confidence: "exact", score: 1 };
  }
  const title = titleSimilarity(source.title, candidate.title);
  const artist = artistSimilarity(source.artist, candidate.artist);
  const duration = durationCompatible(source.durationMs, candidate.durationMs);
  let score = title * 0.6 + artist * 0.4;
  if (duration === true) score = Math.min(1, score + 0.03);
  if (duration === false) score *= 0.85;
  score = Math.round(score * 1000) / 1000;

  let confidence: MatchConfidence = "none";
  if (title >= 0.98 && artist >= 0.95 && duration !== false) confidence = duration ? "exact" : "high";
  else if (title >= 0.85 && artist >= 0.75 && duration !== false) confidence = "high";
  else if (title >= 0.6 && artist >= 0.5) confidence = "low";
  else if (title >= 0.9 && duration === true) confidence = "low";
  return { confidence, score };
}

const confidenceRank: Record<MatchConfidence, number> = { exact: 3, high: 2, low: 1, none: 0 };

export function confidenceAtLeast(value: MatchConfidence, threshold: MatchConfidence) {
  return confidenceRank[value] >= confidenceRank[threshold];
}

export function matchTrack<T extends MatchableTrack>(source: MatchableTrack, candidates: T[]): MatchResult<T> {
  let best: MatchResult<T> = { confidence: "none", score: 0 };
  for (const candidate of candidates) {
    const result = scoreTrackPair(source, candidate);
    const better =
      confidenceRank[result.confidence] > confidenceRank[best.confidence] ||
      (result.confidence === best.confidence && result.score > best.score);
    if (better) best = { ...result, candidate };
  }
  if (best.confidence === "none") return { confidence: "none", score: best.score };
  return best;
}

/** Search query used against the target catalog. */
export function searchQueryFor(track: MatchableTrack) {
  const artist = track.artist.split(/\s*(?:,|&|\sfeat\.?\s|\sft\.?\s)\s*/iu)[0]?.trim() ?? "";
  const title = stripTitleNoise(track.title).replace(/\s+/g, " ").trim() || track.title;
  return `${artist} ${title}`.trim().slice(0, 200);
}
