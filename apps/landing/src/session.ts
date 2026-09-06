export type SessionTrack = {
  title: string;
  artist: string;
  source: "SoundCloud" | "Яндекс Музыка" | "Spotify" | "VK Музыка";
  cover?: string;
  tint: string;
  duration: number;
};

/** Плейлист сессии — реальные треки из Resonance. */
export const SESSION_TRACKS: SessionTrack[] = [
  {
    title: "crush",
    artist: "2hollis",
    source: "SoundCloud",
    cover: "/assets/covers/crush.jpg",
    tint: "linear-gradient(135deg, #8f7cf5, #241a5e)",
    duration: 171
  },
  {
    title: "Выходной",
    artist: "MONATIK",
    source: "VK Музыка",
    cover: "/assets/covers/vyhodnoy.jpg",
    tint: "linear-gradient(135deg, #f2a03d, #4a220c)",
    duration: 184
  },
  {
    title: "Night, Blooming Jasmine . (Prod Me)",
    artist: "fakemink",
    source: "SoundCloud",
    tint: "linear-gradient(135deg, #5fb0f0, #122a4a)",
    duration: 195
  },
  {
    title: "так совпало",
    artist: "wavescale",
    source: "Яндекс Музыка",
    cover: "/assets/covers/tak-sovpalo.jpg",
    tint: "linear-gradient(135deg, #3fc98f, #0c2e20)",
    duration: 168
  },
  {
    title: "Noir by anoufie",
    artist: "anoufie",
    source: "SoundCloud",
    cover: "/assets/covers/noir.jpg",
    tint: "linear-gradient(135deg, #5a5f6b, #15161c)",
    duration: 174
  },
  {
    title: "Surround Sound (feat. 21 Savage & Baby Tate)",
    artist: "JID",
    source: "Spotify",
    cover: "/assets/covers/surround-sound.jpg",
    tint: "linear-gradient(135deg, #ef5570, #3d0f1c)",
    duration: 212
  },
  {
    title: "1cePillow - WIN4BLS",
    artist: "Andforel",
    source: "VK Музыка",
    tint: "linear-gradient(135deg, #e0b64a, #3a2a08)",
    duration: 187
  },
  {
    title: "Can't Tell Me Nothing",
    artist: "Kanye West",
    source: "Яндекс Музыка",
    cover: "/assets/covers/cant-tell.jpg",
    tint: "linear-gradient(135deg, #c9c4bb, #26241f)",
    duration: 232
  },
  {
    title: "Тревога",
    artist: "Whole Lotta Swag",
    source: "VK Музыка",
    tint: "linear-gradient(135deg, #f05a49, #401511)",
    duration: 158
  }
];

export function trackByTitle(title: string): SessionTrack {
  const found = SESSION_TRACKS.find((track) => track.title === title);
  if (!found) throw new Error(`Unknown session track: ${title}`);
  return found;
}
