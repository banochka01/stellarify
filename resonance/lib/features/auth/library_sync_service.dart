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
  final AccountLibraryApi _api;
  final AccountSessionRepository _sessions;
  Future<void>? _activeSync;
  String? _activeSyncUserId;
  bool _syncRequested = false;
  Future<void> _localMutationTail = Future.value();

  Future<T> runLocalMutation<T>(Future<T> Function() mutation) async {
    final previous = _localMutationTail;
    final completed = Completer<void>();
    _localMutationTail = completed.future;
    await previous;
    try {
      return await mutation();
    } finally {
      completed.complete();
    }
  }

  Future<void> connect(String userId) async {
    final boundUserId = await _sessions.readBoundUserId();
    if (boundUserId != null && boundUserId != userId) {
      await runLocalMutation(
        () => _database.replaceLocalLibrary(
          const LocalLibrarySnapshot(favorites: [], playlists: []),
        ),
      );
      await _sessions.writeBoundUserId(userId);
      final remote = await _api.library(userId);
      await _requireCurrentUser(userId);
      await runLocalMutation(
        () => _database.replaceLocalLibrary(remote.toLocal()),
      );
      return;
    }
    await _database.claimUnscopedSyncOperations(userId);
    if (boundUserId == null) {
      await _enqueueBootstrap(userId);
      await _sessions.writeBoundUserId(userId);
    }
    await sync();
  }

  Future<void> sync() async {
    final session = await _sessions.read();
    if (session == null) return;
    final active = _activeSync;
    if (active != null) {
      if (_activeSyncUserId == session.user.id) return active;
      try {
        await active;
      } on AccountApiException {
        // A superseded account sync must finish before the new one starts.
      }
      return sync();
    }
    final userId = session.user.id;
    _activeSyncUserId = userId;
    final future = _performSync(userId);
    _activeSync = future;
    return future.whenComplete(() {
      if (identical(_activeSync, future)) {
        _activeSync = null;
        _activeSyncUserId = null;
        if (_syncRequested) unawaited(_syncSilently());
      }
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
    _syncRequested = true;
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

  Future<void> _performSync(String userId) async {
    do {
      _syncRequested = false;
      await _requireCurrentUser(userId);
      var remote = await _api.library(userId);
      while (true) {
        await _requireCurrentUser(userId);
        final operations = await _database.loadSyncOperations(userId);
        if (operations.isEmpty) break;
        remote = await _api.applyOperations(userId, operations);
        await _requireCurrentUser(userId);
        await _database.deleteSyncOperations(
          operations.map((operation) => operation['id'] as String),
        );
      }
      await _requireCurrentUser(userId);
      await runLocalMutation(() async {
        await _requireCurrentUser(userId);
        await _database.replaceLocalLibrary(remote.toLocal());
      });
      if ((await _database.loadSyncOperations(userId, limit: 1)).isNotEmpty) {
        _syncRequested = true;
      }
    } while (_syncRequested);
  }

  Future<void> _requireCurrentUser(String userId) async {
    if ((await _sessions.read())?.user.id != userId) {
      throw const AccountApiException(
        'Аккаунт изменился во время синхронизации',
        code: 'SESSION_CHANGED',
      );
    }
  }

  Future<void> _syncSilently() async {
    try {
      await sync();
    } on AccountApiException catch (error) {
      if (error.code == 'INVALID_SESSION' || error.code == 'AUTH_REQUIRED') {
        await _sessions.invalidate();
      }
      // The outbox remains intact and will retry on the next account sync.
    }
  }
}
