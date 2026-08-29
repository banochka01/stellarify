import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/auth/account_api.dart';
import 'package:resonance/features/auth/account_models.dart';
import 'package:resonance/features/auth/account_session_repository.dart';
import 'package:resonance/features/auth/library_sync_service.dart';

void main() {
  late AppDatabase database;
  late AccountSessionRepository sessions;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    sessions = AccountSessionRepository(_MemorySecureStore());
  });

  tearDown(() async {
    await database.close();
    await sessions.dispose();
  });

  test('an old account sync cannot write after switching accounts', () async {
    final api = _DelayedLibraryApi();
    final service = LibrarySyncService(database, api, sessions);
    await sessions.write(_session('user-a'));

    final sync = service.sync();
    await api.started.future;
    await sessions.write(_session('user-b'));
    api.release.complete();

    await expectLater(
      sync,
      throwsA(
        isA<AccountApiException>().having(
          (error) => error.code,
          'code',
          'SESSION_CHANGED',
        ),
      ),
    );
    expect(api.requestedUsers, ['user-a']);
  });

  test('a mutation arriving during sync is sent in a follow-up pass', () async {
    final api = _DelayedLibraryApi();
    final service = LibrarySyncService(database, api, sessions);
    await sessions.write(_session('user-a'));

    final sync = service.sync();
    await api.started.future;
    await service.runLocalMutation(() async {
      await database.setFavorite(_track, true);
      await service.recordFavorite(_track, true);
    });
    api.release.complete();
    await sync;

    expect(api.appliedOperations, hasLength(1));
    expect(await database.isFavorite(_track.id), isTrue);
    expect(await database.loadSyncOperations('user-a'), isEmpty);
  });
}

AccountSession _session(String userId) => AccountSession(
  user: AccountUser(
    id: userId,
    email: '$userId@example.com',
    createdAt: DateTime.utc(2026, 8, 29),
  ),
  accessToken: 'access-$userId',
  refreshToken: 'refresh-$userId',
  accessExpiresAt: DateTime.utc(2026, 8, 29, 12),
  refreshExpiresAt: DateTime.utc(2026, 9, 29),
);

const _track = UnifiedTrack(
  id: 'track-1',
  title: 'Track',
  normalizedTitle: 'track',
  artist: 'Artist',
  normalizedArtist: 'artist',
);

final class _DelayedLibraryApi implements AccountLibraryApi {
  final started = Completer<void>();
  final release = Completer<void>();
  final requestedUsers = <String>[];
  final appliedOperations = <Map<String, dynamic>>[];
  RemoteLibrarySnapshot snapshot = const RemoteLibrarySnapshot(
    favorites: [],
    playlists: [],
  );

  @override
  Future<RemoteLibrarySnapshot> library(String expectedUserId) async {
    requestedUsers.add(expectedUserId);
    if (!started.isCompleted) started.complete();
    await release.future;
    return snapshot;
  }

  @override
  Future<RemoteLibrarySnapshot> applyOperations(
    String expectedUserId,
    List<Map<String, dynamic>> operations,
  ) async {
    requestedUsers.add(expectedUserId);
    appliedOperations.addAll(operations);
    snapshot = RemoteLibrarySnapshot(favorites: [_track], playlists: const []);
    return snapshot;
  }
}

final class _MemorySecureStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
