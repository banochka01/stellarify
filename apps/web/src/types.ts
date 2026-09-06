export type ProviderId =
  | "all"
  | "spotify"
  | "soundcloud"
  | "youtube"
  | "yandex"
  | "vk";

export type Track = {
  id: string;
  title: string;
  artist: string;
  album: string;
  duration: string;
  provider: Exclude<ProviderId, "all">;
  color: string;
  liked?: boolean;
};

export type RoomQueueEntry = {
  id: string;
  track: {
    id: string;
    title: string;
    artist: string;
    album?: string;
  };
  addedBy: { id: string; name: string };
  votes: number;
  voters: string[];
};

export type RoomState = {
  code: string;
  hostId: string;
  participants: Array<{
    id: string;
    name: string;
    joinedAt: number;
  }>;
  playback: {
    trackId: string | null;
    provider: string | null;
    paused: boolean;
    positionMs: number;
    updatedAt: number;
    version: number;
  };
  queue?: RoomQueueEntry[];
};

export type ImportedSource = {
  provider: string;
  kind: string;
  sourceUrl?: string;
  externalId?: string;
  label: string;
};

