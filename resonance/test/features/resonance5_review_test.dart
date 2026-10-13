import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/library_cleanup/library_cleanup.dart';
import 'package:resonance/features/music_graph/graph_map.dart';
import 'package:resonance/features/music_graph/music_graph.dart';
import 'package:resonance/features/music_graph/music_graph_map_view.dart';
import 'package:resonance/features/platform/feature_api.dart';
import 'package:resonance/features/platform/feature_flags.dart';
import 'package:resonance/features/platform/feature_views.dart';
import 'package:resonance/features/social/social_api.dart';

import '../helpers/fake_feature_transport.dart';

UnifiedTrack _track(String id, {String? title}) => UnifiedTrack(
  id: id,
  title: title ?? 'Track $id',
  normalizedTitle: (title ?? 'track $id').toLowerCase(),
  artist: 'A',
  normalizedArtist: 'a',
  sources: [
    TrackSource(
      provider: MusicProvider.soundcloud,
      externalId: id,
      externalUrl: Uri.parse('https://soundcloud.com/x/$id'),
    ),
  ],
);

Future<AppDatabase> _pump(
  WidgetTester tester,
  FakeFeatureTransport transport,
  Widget child, {
  List<Override> overrides = const [],
  MemoryKeyValueStore? store,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1600);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        featureTransportProvider.overrideWithValue(transport),
        secureKeyValueStoreProvider.overrideWithValue(
          store ?? MemoryKeyValueStore(),
        ),
        appDatabaseProvider.overrideWithValue(database),
        ...overrides,
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
  return database;
}

Map<String, dynamic> _cleanupResponse() => {
  'scanned': 4,
  'duplicates': [
    {
      'keep': {'trackId': 'k1', 'title': 'Keep', 'artist': 'A'},
      'duplicates': [
        {'trackId': 'x1', 'title': 'Keep', 'artist': 'A'},
      ],
      'crossProvider': true,
    },
  ],
  'replacements': [
    {
      'item': {'trackId': 'old', 'title': 'Old', 'artist': 'A'},
      'reason': 'no_sources',
      'suggestion': waveItem('new', title: 'New'),
    },
    {
      'item': {'trackId': 'off', 'title': 'Off', 'artist': 'A'},
      'reason': 'provider_disabled',
      'suggestion': waveItem('alt', title: 'Alt'),
    },
  ],
  'truncated': false,
};

void main() {
  group('#1/#2/#4 smart cleanup', () {
    testWidgets(
      'nothing preselected, provider_disabled excluded from bulk, confirm, '
      'in-place replace and undo',
      (tester) async {
        final transport = FakeFeatureTransport({
          'GET /api/v1/features': flags(['library.cleanup']),
          'POST /api/v1/library/cleanup': json(_cleanupResponse()),
        });
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final other = _track('other');
        final before = LocalLibrarySnapshot(
          favorites: [_track('k1'), _track('x1'), _track('old')],
          playlists: [
            LocalPlaylistSnapshot(
              id: 'p1',
              name: 'Mix',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
              tracks: [other, _track('x1'), _track('z'), _track('old')],
            ),
          ],
        );
        await database.replaceLocalLibrary(before);

        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1000, 1600);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              featureTransportProvider.overrideWithValue(transport),
              secureKeyValueStoreProvider.overrideWithValue(
                MemoryKeyValueStore(),
              ),
              appDatabaseProvider.overrideWithValue(database),
            ],
            child: const MaterialApp(
              home: Scaffold(body: LibraryCleanupScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // #4: contract body.
        final scan = transport.calls.firstWhere(
          (call) => call.path == '/api/v1/library/cleanup',
        );
        final body = scan.body! as Map;
        expect(body['enabledProviders'], contains('soundcloud'));
        expect(body.containsKey('unavailableTrackIds'), isFalse);

        // #1: nothing is selected by default.
        expect(find.textContaining('выбрано 0 из 3'), findsOneWidget);
        await tester.tap(find.text('Выбрать все'));
        await tester.pump();
        // provider_disabled is never bulk-selected.
        expect(find.textContaining('выбрано 2 из 3'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('cleanup-apply')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Будет заменено 2 треков в 4 местах'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('cleanup-confirm')));
        await tester.pumpAndSettle();

        final after = await database.loadLocalLibrarySnapshot();
        expect(after.favorites.map((track) => track.id), [
          'k1',
          'soundcloud:new',
        ]);
        // #2: replaced in place, other entries keep their positions.
        expect(after.playlists.single.tracks.map((track) => track.id), [
          'other',
          'k1',
          'z',
          'soundcloud:new',
        ]);

        await tester.tap(find.text('Отменить'));
        await tester.pumpAndSettle();
        final restored = await database.loadLocalLibrarySnapshot();
        expect(restored.favorites.map((track) => track.id), [
          'k1',
          'x1',
          'old',
        ]);
        expect(restored.playlists.single.tracks.map((track) => track.id), [
          'other',
          'x1',
          'z',
          'old',
        ]);
      },
    );

    test(
      '#2 duplicate entry is dropped only where the kept track exists',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            secureKeyValueStoreProvider.overrideWithValue(
              MemoryKeyValueStore(),
            ),
          ],
        );
        addTearDown(container.dispose);
        await database.replaceLocalLibrary(
          LocalLibrarySnapshot(
            favorites: const [],
            playlists: [
              LocalPlaylistSnapshot(
                id: 'p',
                name: 'P',
                createdAt: DateTime.utc(2026),
                updatedAt: DateTime.utc(2026),
                tracks: [_track('k1'), _track('a'), _track('x1')],
              ),
            ],
          ),
        );
        await container.read(libraryControllerProvider.future);
        await container
            .read(libraryControllerProvider.notifier)
            .replaceTracks({'x1': _track('k1')}, duplicateIds: {'x1'});
        final after = await database.loadLocalLibrarySnapshot();
        // Only the x1 duplicate entry goes; the rest keeps its order.
        expect(after.playlists.single.tracks.map((track) => track.id), [
          'k1',
          'a',
        ]);
      },
    );

    test('#4 unavailable ids and Blend body follow API-5.0', () async {
      expect(
        unavailableTrackIds([
          _track('ok'),
          _track('bare').copyWith(sources: const []),
        ]),
        ['bare'],
      );
      final transport = FakeFeatureTransport({
        'POST /api/v1/social/blend/u1': json({'title': 'Blend', 'mixes': []}),
      });
      await SocialApi(
        transport,
      ).blend('u1', enabledProviders: ['soundcloud', 'yandex']);
      final body = transport.calls.single.body! as Map;
      expect(body['enabledProviders'], ['soundcloud', 'yandex']);
      expect(body['tzOffsetMinutes'], isA<int>());
    });
  });

  group('#3 errors', () {
    test('403 is not "sign in"; 401 / AUTH_REQUIRED is', () {
      const forbidden = FeatureUnavailableException(
        'Только для друзей',
        statusCode: 403,
        code: 'NOT_FRIENDS',
      );
      expect(forbidden.authRequired, isFalse);
      expect(forbidden.userMessage, 'Только для друзей');
      expect(
        const FeatureUnavailableException('x', statusCode: 401).authRequired,
        isTrue,
      );
      expect(
        const FeatureUnavailableException(
          'x',
          statusCode: 400,
          code: 'AUTH_REQUIRED',
        ).authRequired,
        isTrue,
      );
    });

    test('429 uses retry-after', () {
      expect(parseRetryAfter('30'), const Duration(seconds: 30));
      final now = DateTime.utc(2026, 1, 1, 12);
      expect(
        parseRetryAfter('Thu, 01 Jan 2026 12:00:10 GMT', now: now),
        const Duration(seconds: 10),
      );
      expect(
        const FeatureUnavailableException(
          'x',
          statusCode: 429,
          retryAfter: Duration(seconds: 30),
        ).userMessage,
        'Слишком часто, попробуйте через 30 с',
      );
    });

    testWidgets('view shows the server message and the 429 text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FeatureUnavailableView(
                  error: FeatureUnavailableException(
                    'Только для друзей',
                    statusCode: 403,
                  ),
                ),
                FeatureUnavailableView(
                  error: FeatureUnavailableException(
                    'x',
                    statusCode: 429,
                    retryAfter: Duration(seconds: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Только для друзей'), findsOneWidget);
      expect(find.text('Слишком часто, попробуйте через 12 с'), findsOneWidget);
      expect(find.text('Войдите в аккаунт Resonance'), findsNothing);
    });
  });

  group('#5 path radio', () {
    final snapshot = const MusicGraphBuilder().build([_track('1')]);

    testWidgets('hidden without an account session', (tester) async {
      await _pump(
        tester,
        FakeFeatureTransport({
          'GET /api/v1/features': flags(['graph.pathRadio']),
        }),
        SingleChildScrollView(child: MusicGraphMapSection(snapshot: snapshot)),
      );
      expect(find.text('Радио по пути A → B'), findsNothing);
    });

    testWidgets('reports "Путь не найден" when nothing was found', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeFeatureTransport({
          'GET /api/v1/features': flags(['graph.pathRadio']),
          'GET /api/v1/graph/path': json({
            'found': false,
            'nodes': [
              {'artist': 'A'},
              {'artist': 'B'},
            ],
            'queries': <Object>[],
          }),
        }),
        SingleChildScrollView(child: MusicGraphMapSection(snapshot: snapshot)),
        overrides: [featureAccountIdProvider.overrideWithValue('u1')],
      );
      expect(find.text('Радио по пути A → B'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'От (A)'), 'A');
      await tester.enterText(find.widgetWithText(TextField, 'К (B)'), 'B');
      await tester.tap(find.text('Запустить'));
      await tester.pumpAndSettle();
      expect(find.text('Путь не найден'), findsOneWidget);
    });
  });

  group('#6 flags', () {
    test('saved channel is sent on startup', () async {
      final store = MemoryKeyValueStore()
        ..values[updateChannelStorageKey] = 'beta';
      final transport = FakeFeatureTransport({
        'GET /api/v1/features': (query, _) => {
          'channel': query?['channel'],
          'flags': query?['channel'] == 'beta' ? ['social.blend'] : <String>[],
        },
      });
      final container = ProviderContainer(
        overrides: [
          featureTransportProvider.overrideWithValue(transport),
          secureKeyValueStoreProvider.overrideWithValue(store),
          featureAccountIdProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
      final flags = await container.read(featureFlagsProvider.future);
      expect(flags.isEnabled(FeatureFlag.socialBlend), isTrue);
      expect(transport.calls.single.query, {'channel': 'beta'});
    });

    test('flags are refetched when the account changes', () async {
      final account = StateProvider<String?>((ref) => null);
      final transport = FakeFeatureTransport({
        'GET /api/v1/features': flags([]),
      });
      final container = ProviderContainer(
        overrides: [
          featureTransportProvider.overrideWithValue(transport),
          secureKeyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          featureAccountIdProvider.overrideWith((ref) => ref.watch(account)),
        ],
      );
      addTearDown(container.dispose);
      container.listen(featureFlagsProvider, (_, _) {});
      await container.read(featureFlagsProvider.future);
      container.read(account.notifier).state = 'u1';
      await container.read(featureFlagsProvider.future);
      expect(transport.calls, hasLength(2));
    });
  });

  test('#10 server keys merge into existing local artist nodes', () {
    final data = GraphMapData.fromLibrary(
      const MusicGraphBuilder().build([
        _track('1').copyWith(artist: 'Кино', normalizedArtist: 'кино'),
        _track('2').copyWith(artist: 'Ёлка', normalizedArtist: 'елка'),
      ]),
    );
    final kino = GraphMapData.artistId(graphArtistKey('Кино'));
    data.mergeArtistNeighbors(kino, {
      'key': 'kino',
      'neighbors': [
        {
          'artist': 'Ёлка',
          'key': 'elka',
          'kinds': {'similar': 1},
        },
      ],
    });
    final artists = data.nodes.values.where(
      (node) => node.kind == GraphNodeKind.artist,
    );
    expect(artists, hasLength(2));
    expect(data.resolveArtist('kino', 'Kino'), kino);
  });

  test('#9 graph retry backoff honors retry-after and caps', () {
    expect(graphRetryDelay(1), const Duration(seconds: 5));
    expect(graphRetryDelay(3), const Duration(seconds: 20));
    expect(graphRetryDelay(20), const Duration(minutes: 5));
    expect(
      graphRetryDelay(1, retryAfter: const Duration(seconds: 42)),
      const Duration(seconds: 42),
    );
  });
}
