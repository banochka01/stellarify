export type ProviderId =
  | "spotify"
  | "soundcloud"
  | "youtube"
  | "yandex"
  | "vk"
  | "unknown";

export type ProviderCapability = {
  id: Exclude<ProviderId, "unknown">;
  name: string;
  importMode: "api" | "link";
  playbackMode: "sdk" | "embed" | "external" | "api";
  status: "ready" | "credentials-required" | "link-only";
  note: string;
};

export const providerCapabilities: ProviderCapability[] = [
  {
    id: "spotify",
    name: "Spotify",
    importMode: "api",
    playbackMode: "api",
    status: "credentials-required",
    note: "Поиск и импорт по официальному API; воспроизведение 30-секундных превью. Полный трек требует Spotify Premium и официального клиента."
  },
  {
    id: "soundcloud",
    name: "SoundCloud",
    importMode: "api",
    playbackMode: "embed",
    status: "credentials-required",
    note: "Официальный widget или разрешённый stream URL с атрибуцией."
  },
  {
    id: "youtube",
    name: "YouTube Music",
    importMode: "api",
    playbackMode: "embed",
    status: "credentials-required",
    note: "Импорт и поиск метаданных; воспроизведение в Resonance не поддерживается."
  },
  {
    id: "yandex",
    name: "Яндекс Музыка",
    importMode: "api",
    playbackMode: "api",
    status: "credentials-required",
    note: "Поиск, импорт и нативное воспроизведение по OAuth-токену пользователя."
  },
  {
    id: "vk",
    name: "VK Музыка",
    importMode: "api",
    playbackMode: "api",
    status: "credentials-required",
    note: "Поиск, импорт и воспроизведение по токену VK с доступом к аудио."
  }
];
