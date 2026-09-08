import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/playlist_import_service.dart';
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
  });

  final List<UnifiedTrack> favorites;
  final List<LocalPlaylistSummary> playlists;
  final List<UnifiedTrack> tracks;

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
    await sync.runLocalMutation(() async {
      await _database.createLocalPlaylist(id, imported.name);
      final summary = (await _database.loadLocalPlaylistSummaries()).firstWhere(
        (playlist) => playlist.id == id,
      );
      await sync.recordPlaylistUpsert(summary);
      for (var position = 0; position < imported.tracks.length; position++) {
        final track = imported.tracks[position];
        await _database.addTrackToLocalPlaylist(id, track);
        await sync.recordPlaylistTrack(id, track, position);
      }
    });
    state = AsyncData(await _load());
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

  Future<LibraryState> _load() async => LibraryState(
    favorites: await _database.loadFavoriteTracks(),
    playlists: await _database.loadLocalPlaylistSummaries(),
    tracks: await _database.loadStoredTracks(),
  );
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
