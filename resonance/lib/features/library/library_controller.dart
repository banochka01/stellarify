import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/playlist_import_service.dart';
import 'package:resonance/features/music_graph/music_graph.dart';
import 'package:uuid/uuid.dart';

final libraryControllerProvider =
    AsyncNotifierProvider<LibraryController, LibraryState>(
      LibraryController.new,
    );

final class LibraryState {
  const LibraryState({
    this.favorites = const [],
    this.playlists = const [],
    this.tracks = const [],
    this.graphTracks = const [],
  });

  final List<UnifiedTrack> favorites;
  final List<LocalPlaylistSummary> playlists;
  final List<UnifiedTrack> tracks;
  final List<UnifiedTrack> graphTracks;

  Set<String> get favoriteIds => favorites.map((track) => track.id).toSet();
}

final class LibraryController extends AsyncNotifier<LibraryState> {
  AppDatabase get _database => ref.read(appDatabaseProvider);

  @override
  Future<LibraryState> build() => _load();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> toggleFavorite(UnifiedTrack track) async {
    final sync = ref.read(librarySyncServiceProvider);
    await sync.runLocalMutation(() async {
      final current =
          state.valueOrNull?.favoriteIds.contains(track.id) ??
          await _database.isFavorite(track.id);
      await _database.setFavorite(track, !current);
      await sync.recordFavorite(track, !current);
    });
    state = AsyncData(await _load());
  }

  Future<String> createPlaylist(String name) async {
    final id = const Uuid().v4();
    final sync = ref.read(librarySyncServiceProvider);
    late LibraryState updated;
    await sync.runLocalMutation(() async {
      await _database.createLocalPlaylist(id, name);
      updated = await _load();
      await sync.recordPlaylistUpsert(
        updated.playlists.firstWhere((playlist) => playlist.id == id),
      );
    });
    state = AsyncData(updated);
    return id;
  }

  Future<void> addToPlaylist(String playlistId, UnifiedTrack track) async {
    final sync = ref.read(librarySyncServiceProvider);
    await sync.runLocalMutation(() async {
      await _database.addTrackToLocalPlaylist(playlistId, track);
      final tracks = await _database.loadLocalPlaylistTracks(playlistId);
      await sync.recordPlaylistTrack(
        playlistId,
        track,
        tracks.indexWhere((item) => item.id == track.id),
      );
    });
    state = AsyncData(await _load());
  }

  Future<String> importPlaylist(ImportedPlaylist imported) async {
    final id = const Uuid().v4();
    final sync = ref.read(librarySyncServiceProvider);
    late LocalPlaylistSummary summary;
    late List<UnifiedTrack> canonicalTracks;
    await sync.runLocalMutation(() async {
      canonicalTracks = const MusicGraphBuilder().canonicalize(imported.tracks);
      await _database.createLocalPlaylistWithTracks(
        id,
        imported.name,
        canonicalTracks,
      );
      summary = (await _database.loadLocalPlaylistSummaries()).firstWhere(
        (playlist) => playlist.id == id,
      );
      await sync.recordPlaylistImport(
        LocalPlaylistSnapshot(
          id: id,
          name: summary.name,
          createdAt: summary.createdAt,
          tracks: canonicalTracks,
        ),
      );
    });
    final current = state.valueOrNull;
    if (current == null) {
      state = AsyncData(await _load());
    } else {
      state = AsyncData(
        LibraryState(
          favorites: current.favorites,
          playlists: [
            summary,
            ...current.playlists.where((playlist) => playlist.id != id),
          ],
          tracks: _mergeTracks(current.tracks, canonicalTracks),
          graphTracks: _mergeTracks(current.graphTracks, canonicalTracks),
        ),
      );
    }
    return id;
  }

  Future<LibraryImportResult> importProviderLibrary(
    ImportedProviderLibrary imported,
  ) async {
    final sync = ref.read(librarySyncServiceProvider);
    var importedPlaylistCount = 0;
    final syncedPlaylists = <LocalPlaylistSnapshot>[];
    await sync.runLocalMutation(() async {
      for (final track in imported.favorites) {
        await _database.setFavorite(track, true);
      }
      for (final playlist in imported.playlists) {
        if (playlist.tracks.isEmpty) continue;
        final id = const Uuid().v4();
        await _database.createLocalPlaylist(id, playlist.name);
        final summary = (await _database.loadLocalPlaylistSummaries())
            .firstWhere((item) => item.id == id);
        for (var position = 0; position < playlist.tracks.length; position++) {
          final track = playlist.tracks[position];
          await _database.addTrackToLocalPlaylist(id, track);
        }
        syncedPlaylists.add(
          LocalPlaylistSnapshot(
            id: id,
            name: summary.name,
            createdAt: summary.createdAt,
            tracks: playlist.tracks,
          ),
        );
        importedPlaylistCount++;
      }
      await sync.recordLibraryImport(
        favorites: imported.favorites,
        playlists: syncedPlaylists,
      );
    });
    state = AsyncData(await _load());
    return LibraryImportResult(
      favorites: imported.favorites.length,
      playlists: importedPlaylistCount,
      tracks: imported.trackCount,
      truncated: imported.truncated,
    );
  }

  Future<void> deletePlaylist(String playlistId) async {
    final sync = ref.read(librarySyncServiceProvider);
    await sync.runLocalMutation(() async {
      await _database.deleteLocalPlaylist(playlistId);
      await sync.recordPlaylistDelete(playlistId);
    });
    state = AsyncData(await _load());
  }

  Future<List<UnifiedTrack>> loadPlaylistTracks(String playlistId) {
    return _database.loadLocalPlaylistTracks(playlistId);
  }

  /// Merges duplicate recordings. With [onlyCanonicalIds] only the selected
  /// duplicate groups (by canonical track id) are merged.
  Future<MusicGraphCleanupResult> reconcileMusicGraph({
    Set<String>? onlyCanonicalIds,
  }) async {
    final sync = ref.read(librarySyncServiceProvider);
    late MusicGraphCleanupResult result;
    await sync.runLocalMutation(() async {
      final before = await _database.loadLocalLibrarySnapshot();
      final allTracks = <UnifiedTrack>[
        ...before.favorites,
        ...before.playlists.expand((playlist) => playlist.tracks),
      ];
      final built = const MusicGraphBuilder().build(allTracks);
      final graph = onlyCanonicalIds == null
          ? built
          : _restrictGraph(built, onlyCanonicalIds);
      final favorites = <String, UnifiedTrack>{};
      for (final track in before.favorites) {
        final canonical = graph.canonicalFor(track);
        favorites[canonical.id] = canonical;
      }
      final playlists = [
        for (final playlist in before.playlists)
          LocalPlaylistSnapshot(
            id: playlist.id,
            name: playlist.name,
            createdAt: playlist.createdAt,
            updatedAt: playlist.updatedAt,
            tracks: _canonicalPlaylist(playlist.tracks, graph),
          ),
      ];
      final after = LocalLibrarySnapshot(
        favorites: favorites.values.toList(growable: false),
        playlists: playlists,
      );
      await _database.replaceLocalLibrary(after);
      await sync.recordLibraryReplacement(before: before, after: after);
      result = MusicGraphCleanupResult(
        mergedTracks: graph.duplicateCount,
        canonicalTracks: graph.nodes.length,
        sources: graph.sourceCount,
      );
    });
    state = AsyncData(await _load());
    return result;
  }

  Future<LocalLibrarySnapshot> snapshot() =>
      _database.loadLocalLibrarySnapshot();

  /// How many distinct tracks from [ids] occur and in how many places
  /// (favorites + each playlist entry) — for the cleanup confirmation.
  Future<({int tracks, int places})> countOccurrences(Set<String> ids) async {
    final snapshot = await _database.loadLocalLibrarySnapshot();
    final found = <String>{};
    var places = 0;
    for (final track in [
      ...snapshot.favorites,
      ...snapshot.playlists.expand((playlist) => playlist.tracks),
    ]) {
      if (ids.contains(track.id)) {
        found.add(track.id);
        places++;
      }
    }
    return (tracks: found.length, places: places);
  }

  /// Smart cleanup. Every entry whose id is in [replacements] is replaced in
  /// place (same position); other entries are untouched. For ids in
  /// [duplicateIds] the entry is dropped instead when its replacement is
  /// already present in the same list. Returns the snapshot before the change
  /// so the caller can offer "Отменить" via [restoreLibrary].
  Future<LocalLibrarySnapshot> replaceTracks(
    Map<String, UnifiedTrack> replacements, {
    Set<String> duplicateIds = const {},
  }) async {
    final sync = ref.read(librarySyncServiceProvider);
    late LocalLibrarySnapshot previous;
    await sync.runLocalMutation(() async {
      final before = await _database.loadLocalLibrarySnapshot();
      previous = before;
      if (replacements.isEmpty) return;
      List<UnifiedTrack> apply(
        List<UnifiedTrack> tracks, {
        bool unique = false,
      }) {
        final present = tracks.map((track) => track.id).toSet();
        final result = <UnifiedTrack>[];
        final seen = <String>{};
        for (final track in tracks) {
          final next = replacements[track.id];
          if (next == null) {
            if (!unique || seen.add(track.id)) result.add(track);
            continue;
          }
          if (duplicateIds.contains(track.id) && present.contains(next.id)) {
            continue; // the kept recording is already in this list
          }
          if (!unique || seen.add(next.id)) result.add(next);
        }
        return result;
      }

      final after = LocalLibrarySnapshot(
        favorites: apply(before.favorites, unique: true),
        playlists: [
          for (final playlist in before.playlists)
            LocalPlaylistSnapshot(
              id: playlist.id,
              name: playlist.name,
              createdAt: playlist.createdAt,
              updatedAt: playlist.updatedAt,
              // The schema keeps one entry per track in a playlist.
              tracks: apply(playlist.tracks, unique: true),
            ),
        ],
      );
      await _database.replaceLocalLibrary(after);
      await sync.recordLibraryReplacement(before: before, after: after);
    });
    state = AsyncData(await _load());
    return previous;
  }

  /// Undo for [replaceTracks]/cleanup: restores a previous snapshot.
  Future<void> restoreLibrary(LocalLibrarySnapshot snapshot) async {
    final sync = ref.read(librarySyncServiceProvider);
    await sync.runLocalMutation(() async {
      final before = await _database.loadLocalLibrarySnapshot();
      await _database.replaceLocalLibrary(snapshot);
      await sync.recordLibraryReplacement(before: before, after: snapshot);
    });
    state = AsyncData(await _load());
  }

  Future<LibraryState> _load() async {
    final snapshot = await _database.loadLocalLibrarySnapshot();
    final graphTracks = <String, UnifiedTrack>{};
    for (final track in snapshot.favorites) {
      graphTracks[track.id] = track;
    }
    for (final track in snapshot.playlists.expand((item) => item.tracks)) {
      graphTracks[track.id] = track;
    }
    return LibraryState(
      favorites: snapshot.favorites,
      playlists: await _database.loadLocalPlaylistSummaries(),
      tracks: await _database.loadStoredTracks(),
      graphTracks: graphTracks.values.toList(growable: false),
    );
  }
}

MusicGraphSnapshot _restrictGraph(MusicGraphSnapshot graph, Set<String> ids) {
  final nodes = graph.nodes
      .where((node) => ids.contains(node.track.id))
      .toList(growable: false);
  return MusicGraphSnapshot(
    nodes: nodes,
    edges: const [],
    canonicalByTrackId: {
      for (final entry in graph.canonicalByTrackId.entries)
        if (ids.contains(entry.value.id)) entry.key: entry.value,
    },
  );
}

List<UnifiedTrack> _canonicalPlaylist(
  List<UnifiedTrack> tracks,
  MusicGraphSnapshot graph,
) {
  final result = <UnifiedTrack>[];
  final seen = <String>{};
  for (final track in tracks) {
    final canonical = graph.canonicalFor(track);
    if (seen.add(canonical.id)) result.add(canonical);
  }
  return result;
}

List<UnifiedTrack> _mergeTracks(
  List<UnifiedTrack> current,
  List<UnifiedTrack> added,
) {
  final tracks = <String, UnifiedTrack>{
    for (final track in current) track.id: track,
    for (final track in added) track.id: track,
  };
  return tracks.values.toList(growable: false);
}

final class LibraryImportResult {
  const LibraryImportResult({
    required this.favorites,
    required this.playlists,
    required this.tracks,
    required this.truncated,
  });

  final int favorites;
  final int playlists;
  final int tracks;
  final bool truncated;
}

final class MusicGraphCleanupResult {
  const MusicGraphCleanupResult({
    required this.mergedTracks,
    required this.canonicalTracks,
    required this.sources,
  });

  final int mergedTracks;
  final int canonicalTracks;
  final int sources;
}
