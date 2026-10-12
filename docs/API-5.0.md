# Resonance 5.0 — серверное API (кратко)

Все пути под `/api/v1`. Ошибки: `{ "error": { "code": string, "message": string } }` (message — на русском, можно показывать пользователю).
Авторизация — существующий Resonance ID: `Authorization: Bearer <accessToken>` (как для `/api/v1/account/*`).
«(auth)» — без токена `401 AUTH_REQUIRED`. Лимиты запросов: `429 RATE_LIMITED` + `retry-after`.
Токены провайдеров для поиска передаются как в Волне: `x-soundcloud-token`, `x-yandex-token`, `x-spotify-token`, `x-vk-token`.
`provider` ∈ `soundcloud | yandex | spotify | vk`.

## 1. Социальный слой — `/api/v1/social` (все эндпоинты — auth)

Профиль по умолчанию **скрыт** (`isPublic=false`, `shareListening=false`, `shareRooms=false`).

| Метод | Путь | Тело / query | Ответ |
|---|---|---|---|
| GET | `/profile` | — | `{ profile: SocialProfile }` |
| PATCH | `/profile` | `{ displayName?, handle?: string\|null, isPublic?, shareListening?, shareRooms? }` | `{ profile }`; `409 HANDLE_TAKEN`, `400 INVALID_HANDLE` (`^[a-z0-9_.]{3,24}$`) |
| POST | `/profile/invite` | — | `{ profile }` с новым `inviteCode` |
| GET | `/users/search?q=` | q ≥ 2 символов | `{ users: PublicProfile[] }` — только публичные профили |
| GET | `/users/:userId` | — | `{ user: PublicProfile & { relation } }` или 404 |
| GET | `/friends` | — | `{ friends[], incoming[], outgoing[], blocked[] }` (PublicProfile + `since`/`requestedAt`) |
| POST | `/friends/requests` | одно из `{ userId }`, `{ handle }` (только публичные), `{ inviteCode }` (работает и для скрытых) | `{ user, relation }`; встречная заявка принимается автоматически → `"friends"` |
| POST | `/friends/requests/:userId/accept` | — | `{ relation: "friends" }` |
| DELETE | `/friends/requests/:userId` | — | 204 (отклонить входящую / отменить исходящую) |
| DELETE | `/friends/:userId` | — | 204 |
| POST | `/blocks` | `{ userId }` | 204; удаляет дружбу и заявки, скрывает из поиска |
| DELETE | `/blocks/:userId` | — | 204 |
| PUT | `/now-playing` | `{ title, artist, provider?, trackId? }` | 204. Присылать при старте трека (живёт 10 мин) |
| DELETE | `/now-playing` | — | 204 |
| GET | `/feed` | — | `{ items: FeedItem[] }` |
| GET | `/compatibility/:userId` | только друзья (иначе `403 NOT_FRIENDS`) | `{ compatibility: { percent 0–100, enoughData, sharedArtists[], sharedGenres[] } }` |
| POST | `/blend/:userId` | `{ enabledProviders?, tzOffsetMinutes? }` | `{ title, compatibility, day, nextRefreshAt, mixes: DailyMix[] }` |

```ts
type SocialProfile = { userId; displayName; handle: string|null; isPublic; shareListening; shareRooms; inviteCode; updatedAt };
type PublicProfile = { userId; displayName; handle: string|null };
type relation = "none" | "friends" | "outgoing" | "incoming" | "blocked";
type FeedItem = {
  friend: PublicProfile;
  nowPlaying: { title; artist; at } | null;          // только при shareListening
  recent: Array<{ title; artist; at }>;              // до 5 за 3 дня, только при shareListening
  room: { code: string|null; isPrivate; participants; track: {title; artist}|null } | null; // только при shareRooms
};
```
Закрытая комната показывается без `code`/`track`, если зритель не был её участником раньше. Лента содержит только друзей, разрешивших показ.
Совместимость считается по пересечению артистов из истории Волны, избранного и плейлистов (с учётом транслитерации «Кино»/«Kino»). Жанров в истории нет — `sharedGenres` пока всегда `[]`.
Blend строится поверх «Вашего дня» (`DailyMix[]` того же формата, `id` с префиксом `blend:`), учитывает исключения обоих.

## 2. Music Graph — `/api/v1/graph`

| Метод | Путь | Ответ |
|---|---|---|
| GET | `/artist?name=&limit=20` | `{ artist, key, source: "graph"\|"providers"\|"mixed", neighbors: GraphNeighbor[] }` |
| GET | `/path?from=&to=&tracks=0\|1&provider=soundcloud` | `{ found, nodes: [{ artist, key, via: EdgeKind[], listened? }], queries: [{ artist, query }], tracks?: WaveItem[] }` |
| GET | `/me` (auth) | `{ listened: [{ artist, key, plays }], unexplored: GraphNeighbor[] & { from }, newUser }` |

`GraphNeighbor = { artist, key, weight, kinds: { colisten?, feat?, similar? }, listened? }` — `listened` есть, если запрос с токеном.
`colisten` — число аккаунтов, слушающих обоих (ребро есть только если таких ≥ `GRAPH_MIN_USERS`, по умолчанию 3; данные обезличены). `feat` — совместные кредиты. `similar` — fallback по данным провайдеров (для новых пользователей и редких артистов).
«Радио по пути»: `queries` — упорядоченные поисковые запросы; с `tracks=1` сервер сам ищет до 2 треков на запрос у `provider` (`reason: "По пути: <артист>"`). Если путь не найден, `found=false`, `nodes=[from, to]`.

## 3. Страницы артистов 2.0 — `/api/v1/artists`

| Метод | Путь | Ответ |
|---|---|---|
| GET | `/overview?name=&provider=soundcloud` | см. ниже (токен необязателен, нужен для `following`) |
| GET | `/follows` (auth) | `{ follows: [{ artist, key, followedAt, seenAt }] }` |
| PUT | `/follows` (auth) `{ artist }` | `{ follow }` (лимит 500) |
| DELETE | `/follows?artist=` (auth) | 204 |
| GET | `/releases/unread` (auth) | `{ available, count, releases: (Release & { followedArtist })[] }` — для пушей/бейджа |
| POST | `/releases/seen` (auth) `{ artist? }` | `{ marked }` — отметить прочитанными (все или одного артиста) |

```ts
overview = {
  artist, provider,
  topTracks: (ProviderTrack & { provider })[],
  releases: { available, items: Release[] },        // Spotify, если настроен
  clips: Clip[],                                     // через существующий ClipService (до 6)
  concerts: { available, items: [{ id, date, venue, city, country, url }] }, // BANDSINTOWN_APP_ID, иначе пусто
  setlists: { available, setlists: Setlist[] },      // SETLISTFM_API_KEY, иначе пусто
  similar: GraphNeighbor[],
  following: boolean
}
```
Непрочитанными считаются релизы, вышедшие не раньше дня подписки и ещё не отмеченные `seen`.

## 4. Сет-листы — `GET /api/v1/setlists?artist=&limit=5`

`{ available: boolean, setlists: Setlist[] }`, `Setlist = { id, eventDate (YYYY-MM-DD), venue, city, country, tour, url, tracks: [{ title, query, cover, tape }] }`.
`query` — готовая строка для `/catalog/search` (для каверов — с исполнителем оригинала). Без `SETLISTFM_API_KEY` → `available: false`.

## 5. Совместные плейлисты — `/api/v1/collab-playlists` (auth)

Роли: `owner` (всё), `editor` (треки, название, откат), `viewer` (чтение). Чужим плейлист отвечает 404.

| Метод | Путь | Тело | Ответ |
|---|---|---|---|
| GET | `/` | — | `{ playlists: [{ id, name, ownerId, role, trackCount, memberCount, updatedAt }] }` |
| POST | `/` | `{ name }` | 201 `{ playlist }` |
| GET | `/:id` | — | `{ playlist: { id, name, ownerId, role, version, members[], tracks: Entry[] } }` |
| PATCH | `/:id` | `{ name }` | `{ playlist }` |
| DELETE | `/:id` | — | 204 (owner) |
| PUT | `/:id/members/:userId` | `{ role: "editor"\|"viewer" }` | `{ playlist }` (owner; только друзья, иначе `403 NOT_FRIENDS`) |
| DELETE | `/:id/members/:userId` | — | 204 (owner, или сам участник — выйти) |
| POST | `/:id/tracks` | `{ track: { id, title, artist, ...Track }, position? }` | 201 `{ entry }` |
| DELETE | `/:id/tracks/:entryId` | — | 204 |
| GET | `/:id/history?limit=100` | — | `{ history: HistoryEntry[] }` (новые сверху) |
| POST | `/:id/history/:historyId/revert` | — | `{ playlist }`; `409 ALREADY_REVERTED` / `CONFLICT` |

`Entry = { entryId, track, position, addedBy, addedAt }`.
`HistoryEntry = { id, userId, action: "add"|"remove"|"rename", entryId, track, position, oldName, newName, revertOf, revertedBy, createdAt }`.
Откат применяет обратное действие и пишет его новой записью (`revertOf`); у исходной появляется `revertedBy`. Поле `version` растёт при каждом изменении — удобно для опроса.

## 6. Умная чистка медиатеки — `POST /api/v1/library/cleanup` (auth)

Тело: `{ enabledProviders?: provider[], unavailableTrackIds?: string[] }` (id треков, которые клиент не смог воспроизвести).
Ответ:
```ts
{
  scanned: number,
  duplicates: [{ keep: LibraryItem, duplicates: (LibraryItem & { confidence, score })[], crossProvider: boolean }],
  replacements: [{ item: LibraryItem, reason: "no_sources"|"provider_disabled"|"reported_unavailable",
                   suggestion: (ProviderTrack & { provider, confidence, score }) | null }],
  truncated: boolean   // поиск замен делается максимум для 25 треков за запрос
}
LibraryItem = { trackId, title, artist, durationMs?, isrc?, providers: string[], locations: [{kind:"favorites"} | {kind:"playlist", playlistId, playlistName}] }
```
Сервер ничего не удаляет сам: клиент применяет выбранное через обычные `/account/library/operations`. Дубли ищутся `track-matcher` (уверенность ≥ high), хранитель выбирается по порядку `enabledProviders`, числу мест и источников.

## 7. Changelog, фича-флаги, бета-канал

| Метод | Путь | Ответ |
|---|---|---|
| GET | `/api/v1/changelog?channel=stable\|beta&limit=20` | `{ channel, entries: [{ version, date, channel, title, highlights[] }] }` (публично) |
| GET | `/api/v1/features?channel=` | `{ channel, flags: string[] }` — с токеном канал берётся из аккаунта, query игнорируется |
| GET | `/api/v1/channel` (auth) | `{ channel }` (по умолчанию `stable`) |
| PUT | `/api/v1/channel` (auth) `{ channel }` | `{ channel, flags }` |

Флаги 5.0: `social.profiles`, `social.feed`, `social.compatibility`, `social.blend` (beta), `social.rooms`, `graph.explore`, `graph.pathRadio` (beta), `artists.page2`, `artists.followReleases`, `artists.concerts` (нужен ключ), `artists.setlists` (нужен ключ), `playlists.collab`, `library.cleanup` (beta).
Клиент показывает функцию, только если её ключ есть в `flags`.

## Переменные окружения (все необязательны)

| Переменная | Назначение |
|---|---|
| `SOCIAL_DB_PATH` | SQLite для соцслоя, совместных плейлистов, подписок и канала (по умолчанию `social.sqlite` рядом с `AUTH_DB_PATH`) |
| `GRAPH_MIN_USERS` | порог k-анонимности для рёбер совместного прослушивания (3) |
| `SETLISTFM_API_KEY` | включает сет-листы |
| `BANDSINTOWN_APP_ID` | включает концерты на странице артиста |
| `FEATURE_FLAGS` | переопределения: `key=stable\|beta\|off[:процент]`, через запятую, напр. `social.blend=stable,library.cleanup=beta:25` |
