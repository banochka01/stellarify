import 'dart:async';

import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/auth/account_api.dart';
import 'package:resonance/features/auth/account_models.dart';
import 'package:resonance/features/auth/account_session_repository.dart';
import 'package:uuid/uuid.dart';

final class LibrarySyncService {
  LibrarySyncService(this._database, this._api, this._sessions);

  final AppDatabase _database;
  final AccountApi _api;
  final AccountSessionRepository _sessions;
  Future<void>? _activeSync;

  Future<void> connect(String userId) async {
    final boundUserId = await _sessions.readBoundUserId();
    if (boundUserId != null && boundUserId != userId) {
      await _database.replaceLocalLibrary(
        const LocalLibrarySnapshot(favorites: [], playlists: []),
      );
      await _sessions.writeBoundUserId(userId);
      final remote = await _api.library();
      await _database.replaceLocalLibrary(remote.toLocal());
      return;
    }
    await _database.claimUnscopedSyncOperations(userId);
    if (boundUserId == null) {
      await _enqueueBootstrap(userId);
      await _sessions.writeBoundUserId(userId);
    }
    await sync();
  }

  Future<void> sync() {
    return _activeSync ??= _performSync().whenComplete(() {
      _activeSync = null;
    });
  }

  Future<void> recordFavorite(UnifiedTrack track, bool favorite) {
    return _record({
      'type': favorite ? 'favoriteUpsert' : 'favoriteDelete',
      if (favorite) 'track': track.toJson() else 'trackId': track.id,
    });
  }

  Future<void> recordPlaylistUpsert(LocalPlaylistSummary playlist) {
    return _record({
      'type': 'playlistUpsert',
      'playlistId': playlist.id,
      'name': playlist.name,
      'createdAt': playlist.createdAt.toUtc().toIso8601String(),
    });
  }

  Future<void> recordPlaylistDelete(String playlistId) =>
      _record({'type': 'playlistDelete', 'playlistId': playlistId});

  Future<void> recordPlaylistTrack(
    String playlistId,
    UnifiedTrack track,
    int position,
  ) => _record({
    'type': 'playlistTrackUpsert',
    'playlistId': playlistId,
    'track': track.toJson(),
    'position': position,
  });

  Future<void> recordPlaylistTrackDelete(String playlistId, String trackId) =>
      _record({
        'type': 'playlistTrackDelete',
        'playlistId': playlistId,
        'trackId': trackId,
      });

  Future<void> _record(Map<String, dynamic> payload) async {
    final session = await _sessions.read();
    final userId = session?.user.id ?? await _sessions.readBoundUserId();
    final id = const Uuid().v4();
    await _database.enqueueSyncOperation(
      id: id,
      userId: userId,
      operation: {'id': id, ...payload},
    );
    if (session != null) unawaited(_syncSilently());
  }

  Future<void> _enqueueBootstrap(String userId) async {
    final snapshot = await _database.loadLocalLibrarySnapshot();
    for (final track in snapshot.favorites) {
      await _enqueue(userId, {
        'type': 'favoriteUpsert',
        'track': track.toJson(),
      });
    }
    for (final playlist in snapshot.playlists) {
      await _enqueue(userId, {
        'type': 'playlistUpsert',
        'playlistId': playlist.id,
        'name': playlist.name,
        'createdAt': playlist.createdAt.toUtc().toIso8601String(),
      });
      for (var position = 0; position < playlist.tracks.length; position++) {
        await _enqueue(userId, {
          'type': 'playlistTrackUpsert',
          'playlistId': playlist.id,
          'track': playlist.tracks[position].toJson(),
          'position': position,
        });
      }
    }
  }

  Future<void> _enqueue(String userId, Map<String, dynamic> payload) async {
    final id = const Uuid().v4();
    await _database.enqueueSyncOperation(
      id: id,
      userId: userId,
      operation: {'id': id, ...payload},
    );
  }

  Future<void> _performSync() async {
    final session = await _sessions.read();
    if (session == null) return;
    var remote = await _api.library();
    while (true) {
      final operations = await _database.loadSyncOperations(session.user.id);
      if (operations.isEmpty) break;
      remote = await _api.applyOperations(operations);
      await _database.deleteSyncOperations(
        operations.map((operation) => operation['id'] as String),
      );
    }
    await _database.replaceLocalLibrary(remote.toLocal());
  }

  Future<void> _syncSilently() async {
    try {
      await sync();
    } on AccountApiException {
      // The outbox remains intact and will retry on the next account sync.
    }
  }
}
