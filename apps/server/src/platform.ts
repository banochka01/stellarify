import { createHash } from "node:crypto";
import express from "express";
import { z } from "zod";
import { clientKey, handle, optionalUser, parse, RateGate, requireUser, type Authenticate } from "./api-helpers.js";
import type { ReleaseChannel, SocialStore } from "./social-store.js";

export type ChangelogEntry = {
  version: string;
  date: string;
  channel: ReleaseChannel;
  title: string;
  highlights: string[];
};

/** Public changelog, newest first. Beta entries are only shown to the beta channel. */
export const changelog: ChangelogEntry[] = [
  {
    version: "5.0.2",
    date: "2026-10-13",
    channel: "stable",
    title: "Resonance 5.0.2",
    highlights: [
      "Вкладка «Настройки» снова открывает настройки, а не «Что нового»",
      "Кнопка «Назад» на экранах друзей, совместных плейлистов, чистки и обновлений"
    ]
  },
  {
    version: "5.0.1",
    date: "2026-10-13",
    channel: "stable",
    title: "Resonance 5.0.1",
    highlights: [
      "Быстрее запуск и плавнее интерфейс",
      "Меньше расход памяти на обложки и фон",
      "Приложение стало легче"
    ]
  },
  {
    version: "5.0.0",
    date: "2026-10-13",
    channel: "stable",
    title: "Resonance 5.0 «Граф»",
    highlights: [
      "Друзья: профили, заявки, лента «что слушают друзья» и совместимость вкусов",
      "Blend — общий микс на двоих",
      "Музыкальный граф и «радио по пути» от одного артиста к другому",
      "Страницы артистов 2.0: релизы, клипы, концерты и сет-листы",
      "Совместные плейлисты с историей правок и откатом, DJ-режим в комнатах",
      "Умная чистка медиатеки: дубли и замены недоступных треков",
      "Нормализация громкости, gapless, выбор качества и lossless",
      "Трансляция на Chromecast и DLNA, распознавание трека",
      "Android Auto, Wear OS, Android TV; новый дизайн приложения и сайта"
    ]
  },
  {
    version: "4.0.0",
    date: "2026-10-11",
    channel: "stable",
    title: "Resonance 4.0",
    highlights: [
      "Переезд всей медиатеки из Spotify, VK и Яндекса",
      "Умный офлайн, «Ваш день» и радио по треку",
      "Новые релизы и «Свежее за неделю»",
      "Комнаты 2.0 с чатом и реакциями, караоке-тексты"
    ]
  },
  {
    version: "3.13.0",
    date: "2026-09-20",
    channel: "stable",
    title: "Resonance 3.13",
    highlights: ["Таймер сна", "Итоги прослушиваний", "Оверлей для OBS"]
  }
];

export type FeatureFlag = {
  key: string;
  description: string;
  channels: ReleaseChannel[];
  /** 0–100: share of accounts (stable hash) that get the flag. */
  rollout: number;
  /** Optional external dependency (e.g. API key) that must be configured. */
  requires?: () => boolean;
};

export function defaultFeatureFlags(env = process.env): FeatureFlag[] {
  return [
    { key: "social.profiles", description: "Профили и друзья", channels: ["stable", "beta"], rollout: 100 },
    { key: "social.feed", description: "Лента «что слушают друзья»", channels: ["stable", "beta"], rollout: 100 },
    { key: "social.compatibility", description: "Совместимость вкусов", channels: ["stable", "beta"], rollout: 100 },
    { key: "social.blend", description: "Blend-микс на двоих", channels: ["stable", "beta"], rollout: 100 },
    { key: "social.rooms", description: "Друзья в комнатах", channels: ["stable", "beta"], rollout: 100 },
    { key: "graph.explore", description: "Музыкальный граф", channels: ["stable", "beta"], rollout: 100 },
    { key: "graph.pathRadio", description: "Радио по пути", channels: ["stable", "beta"], rollout: 100 },
    { key: "artists.page2", description: "Страницы артистов 2.0", channels: ["stable", "beta"], rollout: 100 },
    { key: "artists.followReleases", description: "Следить за релизами", channels: ["stable", "beta"], rollout: 100 },
    { key: "artists.concerts", description: "Концерты", channels: ["stable", "beta"], rollout: 100, requires: () => Boolean(env.BANDSINTOWN_APP_ID?.trim()) },
    { key: "artists.setlists", description: "Сет-листы", channels: ["stable", "beta"], rollout: 100, requires: () => Boolean(env.SETLISTFM_API_KEY?.trim()) },
    { key: "playlists.collab", description: "Совместные плейлисты", channels: ["stable", "beta"], rollout: 100 },
    { key: "library.cleanup", description: "Умная чистка медиатеки", channels: ["stable", "beta"], rollout: 100 }
  ];
}

/**
 * `FEATURE_FLAGS` overrides, comma-separated: `key=stable` (both channels),
 * `key=beta`, `key=off`, optionally with a rollout percent `key=stable:25`.
 */
export function applyFlagOverrides(flags: FeatureFlag[], raw = ""): FeatureFlag[] {
  const overrides = new Map<string, { channels: ReleaseChannel[]; rollout?: number }>();
  for (const part of raw.split(",").map((value) => value.trim()).filter(Boolean)) {
    const match = part.match(/^([A-Za-z0-9_.-]{1,64})=(stable|beta|off)(?::(\d{1,3}))?$/u);
    if (!match) continue;
    const channels: ReleaseChannel[] = match[2] === "stable" ? ["stable", "beta"] : match[2] === "beta" ? ["beta"] : [];
    overrides.set(match[1]!, { channels, ...(match[3] ? { rollout: Math.min(100, Number(match[3])) } : {}) });
  }
  return flags.map((flag) => {
    const override = overrides.get(flag.key);
    return override ? { ...flag, channels: override.channels, rollout: override.rollout ?? flag.rollout } : flag;
  });
}

export function enabledFlags(flags: FeatureFlag[], channel: ReleaseChannel, userId?: string) {
  return flags.filter((flag) => {
    if (!flag.channels.includes(channel)) return false;
    if (flag.requires && !flag.requires()) return false;
    if (flag.rollout >= 100) return true;
    if (!userId || flag.rollout <= 0) return false;
    const bucket = createHash("sha256").update(`${flag.key}:${userId}`).digest().readUInt32BE(0) % 100;
    return bucket < flag.rollout;
  }).map((flag) => flag.key);
}

const channelSchema = z.enum(["stable", "beta"]);

export function createPlatformRouter(
  social: SocialStore,
  authenticate: Authenticate,
  flags: FeatureFlag[] = applyFlagOverrides(defaultFeatureFlags(), process.env.FEATURE_FLAGS)
) {
  const router = express.Router();
  const gate = new RateGate(120, 60_000);
  const channelOf = (request: express.Request) => {
    const userId = optionalUser(authenticate, request);
    if (userId) return { userId, channel: social.channel(userId) };
    return { userId: undefined, channel: parse(channelSchema.default("stable"), request.query.channel, "Неизвестный канал") };
  };

  router.get("/changelog", handle((request, response) => {
    gate.check(clientKey(request));
    const query = parse(z.object({
      channel: channelSchema.default("stable"),
      limit: z.coerce.number().int().min(1).max(50).default(20)
    }), request.query, "Некорректный запрос");
    response.setHeader("cache-control", "public, max-age=300");
    const entries = changelog.filter((entry) => query.channel === "beta" || entry.channel === "stable").slice(0, query.limit);
    return { channel: query.channel, entries };
  }));

  router.get("/features", handle((request, response) => {
    gate.check(clientKey(request));
    response.setHeader("cache-control", "private, no-store");
    const { userId, channel } = channelOf(request);
    return { channel, flags: enabledFlags(flags, channel, userId) };
  }));

  router.get("/channel", handle((request, response) => {
    response.setHeader("cache-control", "private, no-store");
    const userId = requireUser(authenticate, request);
    gate.check(userId);
    return { channel: social.channel(userId) };
  }));

  router.put("/channel", handle((request) => {
    const userId = requireUser(authenticate, request);
    gate.check(userId);
    const { channel } = parse(z.object({ channel: channelSchema }).strict(), request.body, "Выберите канал: stable или beta");
    social.setChannel(userId, channel);
    return { channel, flags: enabledFlags(flags, channel, userId) };
  }));
  return router;
}
