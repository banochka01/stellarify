import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';
import 'package:resonance/features/auth/account_controller.dart';
import 'package:resonance/features/auth/account_models.dart';
import 'package:resonance/features/migration/migration_api.dart';
import 'package:resonance/features/migration/migration_screen.dart';

Map<String, dynamic> _job({
  String status = 'completed',
  String kind = 'full',
}) => {
  'id': 'job-1',
  'source': 'spotify',
  'target': 'yandex',
  'kind': kind,
  'status': status,
  'total': 6,
  'processed': status == 'completed' ? 6 : 3,
  'progress': status == 'completed' ? 100 : 50,
  'truncated': false,
  'lastSyncedAt': '2026-10-10T10:00:00.000Z',
};

Map<String, dynamic> _track(String id, String title, String artist) => {
  'id': id,
  'title': title,
  'artist': artist,
  'durationMs': 301000,
  'externalUrl': 'https://example.com/$id',
};

Map<String, dynamic> _reportJson() => {
  'job': _job(),
  'summary': {
    'total': 6,
    'migrated': 4,
    'percent': 66.7,
    'exact': 3,
    'high': 1,
    'low': 1,
    'none': 1,
    'manual': 0,
    'pending': 0,
  },
  'lowConfidence': [
    {
      'itemId': 3,
      'section': 'favorite',
      'status': 'matched',
      'confidence': 'low',
      'score': 0.85,
      'source': _track('spotify:track:3', 'Smells Like Teen Spirit', 'Nirvana'),
      'match': {
        ..._track('103', 'Smells Like Teen Spirit', 'Nirvana'),
        'provider': 'yandex',
      },
    },
  ],
  'unmatched': [
    {
      'itemId': 4,
      'section': 'playlist',
      'collectionId': 'playlist:pl1',
      'collectionTitle': 'Классика',
      'status': 'unmatched',
      'confidence': 'none',
      'score': 0.1,
      'source': _track('spotify:track:4', 'Unknown Song', 'Nobody'),
      'match': null,
    },
  ],
  'collections': [
    {
      'id': 'playlist:pl1',
      'kind': 'playlist',
      'title': 'Классика',
      'trackCount': 1,
    },
  ],
  'artists': [
    {'externalId': 'spotify:artist:1', 'name': 'Daft Punk'},
  ],
};

void main() {
  test('report JSON is parsed into summary, review lists and artists', () {
    final report = MigrationReport.fromJson(_reportJson());
    expect(report.percent, 66.7);
    expect(report.job.source, MusicProvider.spotify);
    expect(report.job.isCompleted, isTrue);
    expect(report.lowConfidence.single.confidence, MigrationConfidence.low);
    expect(report.lowConfidence.single.match?.provider, MusicProvider.yandex);
    expect(report.unmatched.single.collectionTitle, 'Классика');
    expect(report.artists, ['Daft Punk']);
    expect(report.collections, 1);
  });

  testWidgets('report screen shows review actions, confirms and re-syncs', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final api = _FakeMigrationApi();
    var refreshed = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountControllerProvider.overrideWith(_SignedInController.new),
          migrationApiProvider.overrideWithValue(api),
          migrationLibraryRefreshProvider.overrideWithValue(
            () async => refreshed++,
          ),
        ],
        child: const MaterialApp(home: MigrationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('66.7%'), findsOneWidget);
    expect(find.text('Медиатека переехала'), findsOneWidget);
    expect(
      find.textContaining('Nirvana — Smells Like Teen Spirit'),
      findsWidgets,
    );
    expect(find.text('Найти вручную'), findsOneWidget);
    expect(find.text('Daft Punk'), findsOneWidget);
    expect(refreshed, 1);

    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    expect(api.confirmed, [3]);

    await tester.tap(find.byKey(const ValueKey('migration-resync')));
    await tester.pumpAndSettle();
    expect(api.resyncs, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-out users are asked to sign in to Resonance ID', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountControllerProvider.overrideWith(_SignedOutController.new),
          migrationApiProvider.overrideWithValue(_FakeMigrationApi()),
        ],
        child: const MaterialApp(home: MigrationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Переезд работает через Resonance ID'), findsOneWidget);
  });
}

final class _SignedInController extends AccountController {
  @override
  Future<AccountUser?> build() async => AccountUser(
    id: 'user-1',
    email: 'listener@example.com',
    createdAt: DateTime.utc(2026),
  );
}

final class _SignedOutController extends AccountController {
  @override
  Future<AccountUser?> build() async => null;
}

class _NoTokens implements SecureTokenRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<String?>.value();
}

class _FakeMigrationApi extends MigrationApi {
  _FakeMigrationApi()
    : super(
        Dio(),
        () => Uri.parse('https://example.com'),
        () async => 'token',
        _NoTokens(),
      );

  final confirmed = <int>[];
  var resyncs = 0;

  @override
  Future<List<MigrationJob>> jobs() async => [MigrationJob.fromJson(_job())];

  @override
  Future<MigrationReport> report(String id) async =>
      MigrationReport.fromJson(_reportJson());

  @override
  Future<void> confirm(String jobId, int itemId) async => confirmed.add(itemId);

  @override
  Future<MigrationJob> start(
    MusicProvider source,
    MusicProvider target, {
    bool resync = false,
  }) async {
    if (resync) resyncs++;
    return MigrationJob.fromJson(_job(kind: resync ? 'resync' : 'full'));
  }
}
