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
  playbackMode: "sdk" | "embed" | "external";
  status: "ready" | "credentials-required" | "link-only";
  note: string;
};

export const providerCapabilities: ProviderCapability[] = [
  {
    id: "spotify",
    name: "Spotify",
    importMode: "api",
    playbackMode: "sdk",
    status: "credentials-required",
    note: "OAuth и Premium нужны для полного воспроизведения."
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
    note: "Воспроизведение через официальный YouTube IFrame Player."
  },
  {
    id: "yandex",
    name: "Яндекс Музыка",
    importMode: "link",
    playbackMode: "external",
    status: "link-only",
    note: "Пока сохраняем ссылки и открываем официальный клиент."
  },
  {
    id: "vk",
    name: "VK Музыка",
    importMode: "link",
    playbackMode: "external",
    status: "link-only",
    note: "Пока сохраняем ссылки и открываем официальный клиент."
  }
];

