import type { Track } from "./types";

export const tracks: Track[] = [
  {
    id: "echoes",
    title: "Echoes in Orbit",
    artist: "Lunar Fields",
    album: "Night Signals",
    duration: "4:12",
    provider: "spotify",
    color: "linear-gradient(145deg, #17224c, #835cff 58%, #ff7bc4)"
  },
  {
    id: "still-blue",
    title: "Still Blue",
    artist: "Mira Vale",
    album: "Soft Geometry",
    duration: "3:46",
    provider: "soundcloud",
    color: "linear-gradient(145deg, #1a302e, #32a89d 56%, #d3ff88)",
    liked: true
  },
  {
    id: "afterglow",
    title: "Afterglow",
    artist: "Neon Palms",
    album: "Coastline",
    duration: "3:18",
    provider: "youtube",
    color: "linear-gradient(145deg, #38213f, #d45975 54%, #ffb979)"
  },
  {
    id: "polaroid",
    title: "Полароид",
    artist: "Северный ветер",
    album: "Тёплый свет",
    duration: "2:57",
    provider: "yandex",
    color: "linear-gradient(145deg, #30204a, #a65dea 55%, #faef79)"
  },
  {
    id: "parallel",
    title: "Parallel Lines",
    artist: "Arden",
    album: "Methods of Flight",
    duration: "4:04",
    provider: "vk",
    color: "linear-gradient(145deg, #142a45, #2582d8 55%, #7edcff)"
  }
];

export const mixes = [
  {
    title: "Космический фокус",
    subtitle: "Электроника без лишнего шума",
    color: "linear-gradient(135deg, #251f47, #6b48c5 54%, #c788ff)"
  },
  {
    title: "Мягкий свет",
    subtitle: "Инди, соул и спокойный вечер",
    color: "linear-gradient(135deg, #183934, #397e6d 50%, #b4d897)"
  },
  {
    title: "После полуночи",
    subtitle: "Синтвейв и ночные маршруты",
    color: "linear-gradient(135deg, #382039, #9b3d67 50%, #ef9078)"
  }
];

