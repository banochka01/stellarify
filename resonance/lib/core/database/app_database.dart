import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_session.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/repositories/playback_persistence.dart';

part 'app_database.g.dart';

class StoredTracks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get normalizedTitle => text()();
  TextColumn get artist => text()();
  TextColumn get normalizedArtist => text()();
  TextColumn get album => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get artworkUrl => text().nullable()();
  TextColumn get preferredProvider => textEnum<MusicProvider>().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StoredTrackSources extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get trackId =>
      text().references(StoredTracks, #id, onDelete: KeyAction.cascade)();
  TextColumn get provider => textEnum<MusicProvider>()();
  TextColumn get externalId => text()();
  TextColumn get externalUrl => text()();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {provider, externalId},
  ];
}

class LocalPlaylists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalPlaylistTracks extends Table {
  TextColumn get playlistId =>
      text().references(LocalPlaylists, #id, onDelete: KeyAction.cascade)();
  TextColumn get trackId =>
      text().references(StoredTracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {playlistId, trackId};
}

class FavoriteTracks extends Table {
  TextColumn get trackId =>
      text().references(StoredTracks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {trackId};
}

class ListeningHistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trackId =>
      text().references(StoredTracks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get playedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
}

class SearchHistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get query => text()();
  DateTimeColumn get searchedAt => dateTime().withDefault(currentDateAndTime)();
}

class ProviderPreferences extends Table {
  TextColumn get provider => textEnum<MusicProvider>()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get fallbackPriority => integer()();
  TextColumn get quality =>
      textEnum<AudioQuality>().withDefault(Constant(AudioQuality.high.name))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {provider};
}

class PlaybackQueueEntries extends Table {
  IntColumn get position => integer()();
  TextColumn get trackId =>
      text().references(StoredTracks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {position};
}

class CachedMetadataEntries extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get provider => textEnum<MusicProvider>().nullable()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {cacheKey};
}

@DriftDatabase(
  tables: [
    StoredTracks,
    StoredTrackSources,
    LocalPlaylists,
    LocalPlaylistTracks,
    FavoriteTracks,
    ListeningHistoryEntries,
    SearchHistoryEntries,
    ProviderPreferences,
    PlaybackQueueEntries,
    CachedMetadataEntries,
  ],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'resonance'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 1) {
        await migrator.createAll();
      }
      await _createIndexes();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_track_normalized '
      'ON stored_tracks(normalized_title, normalized_artist)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sources_track '
      'ON stored_track_sources(track_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_playlist_position '
      'ON local_playlist_tracks(playlist_id, position)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_history_played '
      'ON listening_history_entries(played_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_search_searched '
      'ON search_history_entries(searched_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_metadata_expiry '
      'ON cached_metadata_entries(expires_at)',
    );
  }

  Future<void> upsertUnifiedTrack(UnifiedTrack track) async {
    await transaction(() async {
      await _upsertTrackRow(track);
      await (delete(
        storedTrackSources,
      )..where((table) => table.trackId.equals(track.id))).go();
      if (track.sources.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            storedTrackSources,
            track.sources
                .map(
                  (source) => StoredTrackSourcesCompanion.insert(
                    trackId: track.id,
                    provider: source.provider,
                    externalId: source.externalId,
                    externalUrl: source.externalUrl.toString(),
                    metadataJson: Value(jsonEncode(source.metadata)),
                  ),
                )
                .toList(growable: false),
            mode: InsertMode.insertOrReplace,
          );
        });
      }
    });
  }

  Future<void> _upsertTrackRow(UnifiedTrack track) {
    return into(storedTracks).insertOnConflictUpdate(
      StoredTracksCompanion.insert(
        id: track.id,
        title: track.title,
        normalizedTitle: track.normalizedTitle,
        artist: track.artist,
        normalizedArtist: track.normalizedArtist,
        album: Value(track.album),
        durationMs: Value(track.duration?.inMilliseconds),
        artworkUrl: Value(track.artworkUrl?.toString()),
        preferredProvider: Value(track.preferredProvider),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<UnifiedTrack?> getUnifiedTrack(String id) async {
    final track = await (select(
      storedTracks,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (track == null) {
      return null;
    }
    final sources = await (select(
      storedTrackSources,
    )..where((table) => table.trackId.equals(id))).get();

    return UnifiedTrack(
      id: track.id,
      title: track.title,
      normalizedTitle: track.normalizedTitle,
      artist: track.artist,
      normalizedArtist: track.normalizedArtist,
      album: track.album,
      duration: track.durationMs == null
          ? null
          : Duration(milliseconds: track.durationMs!),
      artworkUrl: track.artworkUrl == null
          ? null
          : Uri.tryParse(track.artworkUrl!),
      preferredProvider: track.preferredProvider,
      sources: sources
          .map(
            (source) => TrackSource(
              provider: source.provider,
              externalId: source.externalId,
              externalUrl: Uri.parse(source.externalUrl),
              metadata: _decodeJsonMap(source.metadataJson),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<bool> isFavorite(String trackId) async {
    final row = await (select(
      favoriteTracks,
    )..where((table) => table.trackId.equals(trackId))).getSingleOrNull();
    return row != null;
  }

  Future<void> setFavorite(UnifiedTrack track, bool favorite) async {
    await upsertUnifiedTrack(track);
    if (favorite) {
      await into(favoriteTracks).insert(
        FavoriteTracksCompanion.insert(trackId: track.id),
        mode: InsertMode.insertOrIgnore,
      );
      return;
    }
    await (delete(
      favoriteTracks,
    )..where((table) => table.trackId.equals(track.id))).go();
  }

  Future<List<UnifiedTrack>> loadFavoriteTracks() async {
    final rows = await (select(
      favoriteTracks,
    )..orderBy([(table) => OrderingTerm.desc(table.addedAt)])).get();
    final tracks = <UnifiedTrack>[];
    for (final row in rows) {
      final track = await getUnifiedTrack(row.trackId);
      if (track != null) tracks.add(track);
    }
    return tracks;
  }

  Future<void> createLocalPlaylist(String id, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Playlist name cannot be empty');
    }
    await into(
      localPlaylists,
    ).insert(LocalPlaylistsCompanion.insert(id: id, name: trimmedName));
  }

  Future<List<LocalPlaylistSummary>> loadLocalPlaylistSummaries() async {
    final playlists = await (select(
      localPlaylists,
    )..orderBy([(table) => OrderingTerm.desc(table.updatedAt)])).get();
    final result = <LocalPlaylistSummary>[];
    for (final playlist in playlists) {
      final count = localPlaylistTracks.trackId.count();
      final query = selectOnly(localPlaylistTracks)
        ..addColumns([count])
        ..where(localPlaylistTracks.playlistId.equals(playlist.id));
      final row = await query.getSingle();
      result.add(
        LocalPlaylistSummary(
          id: playlist.id,
          name: playlist.name,
          trackCount: row.read(count) ?? 0,
          updatedAt: playlist.updatedAt,
        ),
      );
    }
    return result;
  }

  Future<void> addTrackToLocalPlaylist(
    String playlistId,
    UnifiedTrack track,
  ) async {
    await upsertUnifiedTrack(track);
    await transaction(() async {
      final maxPosition = localPlaylistTracks.position.max();
      final query = selectOnly(localPlaylistTracks)
        ..addColumns([maxPosition])
        ..where(localPlaylistTracks.playlistId.equals(playlistId));
      final row = await query.getSingle();
      final position = (row.read(maxPosition) ?? -1) + 1;
      await into(localPlaylistTracks).insert(
        LocalPlaylistTracksCompanion.insert(
          playlistId: playlistId,
          trackId: track.id,
          position: position,
        ),
        mode: InsertMode.insertOrIgnore,
      );
      await (update(
        localPlaylists,
      )..where((table) => table.id.equals(playlistId))).write(
        LocalPlaylistsCompanion(updatedAt: Value(DateTime.now().toUtc())),
      );
    });
  }

  Future<List<UnifiedTrack>> loadLocalPlaylistTracks(String playlistId) async {
    final rows =
        await (select(localPlaylistTracks)
              ..where((table) => table.playlistId.equals(playlistId))
              ..orderBy([(table) => OrderingTerm.asc(table.position)]))
            .get();
    final tracks = <UnifiedTrack>[];
    for (final row in rows) {
      final track = await getUnifiedTrack(row.trackId);
      if (track != null) tracks.add(track);
    }
    return tracks;
  }

  Future<void> removeTrackFromLocalPlaylist(
    String playlistId,
    String trackId,
  ) async {
    await (delete(localPlaylistTracks)..where(
          (table) =>
              table.playlistId.equals(playlistId) &
              table.trackId.equals(trackId),
        ))
        .go();
  }

  Future<void> deleteLocalPlaylist(String playlistId) async {
    await (delete(
      localPlaylists,
    )..where((table) => table.id.equals(playlistId))).go();
  }

  Future<void> replacePlaybackQueue(PlaybackSession session) async {
    await transaction(() async {
      for (final track in session.queue) {
        await _upsertTrackRow(track);
        await (delete(
          storedTrackSources,
        )..where((table) => table.trackId.equals(track.id))).go();
        for (final source in track.sources) {
          await into(storedTrackSources).insert(
            StoredTrackSourcesCompanion.insert(
              trackId: track.id,
              provider: source.provider,
              externalId: source.externalId,
              externalUrl: source.externalUrl.toString(),
              metadataJson: Value(jsonEncode(source.metadata)),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }

      await delete(playbackQueueEntries).go();
      await batch((batch) {
        batch.insertAll(playbackQueueEntries, [
          for (var index = 0; index < session.queue.length; index++)
            PlaybackQueueEntriesCompanion.insert(
              position: Value(index),
              trackId: session.queue[index].id,
            ),
        ]);
      });
      await into(cachedMetadataEntries).insertOnConflictUpdate(
        CachedMetadataEntriesCompanion.insert(
          cacheKey: 'playback_session',
          payloadJson: jsonEncode({
            'currentIndex': session.currentIndex,
            'volume': session.volume,
          }),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    });
  }

  Future<PlaybackSession> loadPlaybackQueue() async {
    final entries = await (select(
      playbackQueueEntries,
    )..orderBy([(table) => OrderingTerm.asc(table.position)])).get();
    final queue = <UnifiedTrack>[];
    for (final entry in entries) {
      final track = await getUnifiedTrack(entry.trackId);
      if (track != null) {
        queue.add(track);
      }
    }

    final metadata =
        await (select(cachedMetadataEntries)
              ..where((table) => table.cacheKey.equals('playback_session')))
            .getSingleOrNull();
    final payload = metadata == null
        ? const <String, dynamic>{}
        : _decodeJsonMap(metadata.payloadJson);
    return PlaybackSession(
      queue: queue,
      currentIndex: (payload['currentIndex'] as num?)?.toInt() ?? -1,
      volume: (payload['volume'] as num?)?.toDouble() ?? 70,
    );
  }
}

final class LocalPlaylistSummary {
  const LocalPlaylistSummary({
    required this.id,
    required this.name,
    required this.trackCount,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int trackCount;
  final DateTime updatedAt;
}

Map<String, dynamic> _decodeJsonMap(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } on FormatException {
    return const {};
  }
  return const {};
}

final class DriftPlaybackPersistence implements PlaybackPersistence {
  DriftPlaybackPersistence(this._database);

  final AppDatabase _database;

  @override
  Future<PlaybackSession> load() => _database.loadPlaybackQueue();

  @override
  Future<void> save(PlaybackSession session) =>
      _database.replacePlaybackQueue(session);
}
