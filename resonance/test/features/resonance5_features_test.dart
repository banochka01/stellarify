import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/artist/artist_overview.dart';
import 'package:resonance/features/changelog/changelog.dart';
import 'package:resonance/features/library_cleanup/library_cleanup.dart';
import 'package:resonance/features/music_graph/graph_map.dart';
import 'package:resonance/features/music_graph/music_graph.dart';
import 'package:resonance/features/platform/feature_api.dart';
import 'package:resonance/features/platform/feature_flags.dart';
import 'package:resonance/features/playlists/collaborative_playlist.dart';
import 'package:resonance/features/rooms/dj_mode.dart';
import 'package:resonance/features/social/social_screen.dart';

import '../helpers/fake_feature_transport.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeFeatureTransport transport,
  Widget child,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1400);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        featureTransportProvider.overrideWithValue(transport),
        secureKeyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
}

UnifiedTrack _track(String id, String artist, {String? album}) => UnifiedTrack(
  id: id,
  title: 'Track $id',
  normalizedTitle: 'track $id',
  artist: artist,
  normalizedArtist: artist.toLowerCase(),
  album: album,
  sources: [
    TrackSource(
      provider: MusicProvider.soundcloud,
      externalId: id,
      externalUrl: Uri.parse('https://soundcloud.com/x/$id'),
    ),
  ],
);

void main() {
  group('feature flags', () {
    test('server keys gate sections; missing endpoint hides them', () async {
      final flags = FeatureFlags.fromJson({
        'channel': 'stable',
        'flags': ['social.profiles', 'artists.page2'],
      });
      expect(flags.isEnabled(FeatureFlag.social), isTrue);
      expect(flags.isEnabled(FeatureFlag.socialBlend), isFalse);
      expect(FeatureFlags.none.isEnabled(FeatureFlag.social), isFalse);
      expect(FeatureFlags.none.isEnabled(FeatureFlag.graphMap), isTrue);

      final container = ProviderContainer(
        overrides: [
          featureTransportProvider.overrideWithValue(FakeFeatureTransport({})),
        ],
      );
      addTearDown(container.dispose);
      final resolved = await container.read(featureFlagsProvider.future);
      expect(resolved.isEnabled(FeatureFlag.artistPage), isFalse);
    });

    test('server track payloads parse as wave items', () {
      final track = jsonTrack(waveItem('42', title: 'Signal'));
      expect(track?.id, 'soundcloud:42');
      expect(track?.title, 'Signal');
    });
  });

  group('music graph map', () {
    test('viewport respects the node limit and expands on tap', () {
      final tracks = [
        for (var a = 0; a < 10; a++)
          for (var t = 0; t < 8; t++)
            _track('$a-$t', 'Artist $a', album: 'A$a'),
      ];
      final data = GraphMapData.fromLibrary(
        const MusicGraphBuilder().build(tracks),
      );
      final viewport = GraphViewport(data, maxNodes: 20)..seed();
      expect(viewport.visibleCount, lessThanOrEqualTo(20));
      final artist = viewport.visible.first;
      expect(viewport.expand(artist), greaterThan(0));
      expect(viewport.visibleCount, lessThanOrEqualTo(20));
      expect(viewport.expanded, contains(artist));
      expect(viewport.hitTest(viewport.positions[artist]!), artist);
    });

    test('server neighbors add typed links around the tapped artist', () {
      final data = GraphMapData()
        ..addNode(
          const GraphMapNode(
            id: 'artist:a',
            label: 'A',
            kind: GraphNodeKind.artist,
            personal: true,
          ),
        )
        ..mergeArtistNeighbors('artist:a', {
          'neighbors': [
            {
              'artist': 'B',
              'key': 'b',
              'weight': 3,
              'kinds': {'colisten': 4, 'feat': 1},
              'listened': true,
            },
          ],
        });
      expect(
        data.edges.map((edge) => edge.type),
        containsAll([GraphLinkType.colisten, GraphLinkType.collaboration]),
      );
      expect(data.nodes['artist:b']!.personal, isTrue);
    });
  });

  test('DJ crossfade fades out, switches and fades back in', () async {
    final volumes = <double>[];
    var switchedAt = -1;
    await const DjCrossfader(steps: 4).run(
      volume: 80,
      duration: const Duration(seconds: 2),
      setVolume: (value) async => volumes.add(value),
      switchTrack: () async => switchedAt = volumes.length,
      wait: (_) async {},
    );
    expect(volumes.sublist(0, 4), [60, 40, 20, 0]);
    expect(switchedAt, 4);
    expect(volumes.last, 80);
  });

  testWidgets('social section hides itself when the server lacks it', (
    tester,
  ) async {
    await _pump(tester, FakeFeatureTransport({}), const SocialScreen());
    expect(find.text('Раздел временно недоступен'), findsOneWidget);
    expect(find.text('Лента'), findsNothing);
  });

  testWidgets('social feed offers to join a friend room', (tester) async {
    await _pump(
      tester,
      FakeFeatureTransport({
        'GET /api/v1/features': flags([
          'social.profiles',
          'social.feed',
          'social.rooms',
        ]),
        'GET /api/v1/social/feed': json({
          'items': [
            {
              'friend': {'userId': 'u1', 'displayName': 'Аня', 'handle': null},
              'nowPlaying': {'title': 'Signal', 'artist': 'Night', 'at': 1},
              'recent': <Object>[],
              'room': {
                'code': 'ABC123',
                'isPrivate': false,
                'participants': 3,
                'track': null,
              },
            },
          ],
        }),
      }),
      const SocialScreen(),
    );
    expect(find.text('Аня'), findsOneWidget);
    expect(find.textContaining('Signal'), findsOneWidget);
    expect(find.text('Присоединиться'), findsOneWidget);
  });

  testWidgets('artist page follows releases and shows the new badge', (
    tester,
  ) async {
    final transport = FakeFeatureTransport({
      'GET /api/v1/features': flags([
        'artists.page2',
        'artists.followReleases',
        'artists.setlists',
      ]),
      'GET /api/v1/artists/overview': json({
        'artist': 'Night',
        'following': false,
        'topTracks': <Object>[],
        'releases': {
          'available': true,
          'items': [
            {'id': 'r1', 'title': 'Fresh', 'type': 'single'},
          ],
        },
        'clips': <Object>[],
        'concerts': {'available': false, 'items': <Object>[]},
        'setlists': {
          'available': true,
          'setlists': [
            {
              'id': 's1',
              'eventDate': '2026-05-01',
              'venue': 'Клуб',
              'city': 'Москва',
              'tracks': [
                {'title': 'Signal', 'query': 'Night Signal'},
              ],
            },
          ],
        },
      }),
      'GET /api/v1/artists/releases/unread': json({
        'available': true,
        'count': 1,
        'releases': [
          {'id': 'r1', 'title': 'Fresh', 'followedArtist': 'Night'},
        ],
      }),
      'POST /api/v1/artists/releases/seen': json({'marked': 1}),
      'PUT /api/v1/artists/follows': json({}),
    });
    await _pump(
      tester,
      transport,
      const SingleChildScrollView(
        child: ArtistOverviewSection(artist: 'Night'),
      ),
    );
    expect(find.text('Fresh'), findsOneWidget);
    expect(find.text('Новый релиз'), findsOneWidget);
    expect(find.text('Послушать сет-лист'), findsOneWidget);
    await tester.tap(find.text('Следить за релизами'));
    await tester.pumpAndSettle();
    expect(
      transport.calls.map((call) => '${call.method} ${call.path}'),
      contains('PUT /api/v1/artists/follows'),
    );
    expect(find.text('Вы следите за релизами'), findsOneWidget);
  });

  testWidgets('library cleanup lists server suggestions selectively', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeFeatureTransport({
        'GET /api/v1/features': flags(['library.cleanup']),
        'POST /api/v1/library/cleanup': json({
          'scanned': 3,
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
              'item': {'trackId': 'gone', 'title': 'Gone', 'artist': 'A'},
              'reason': 'provider_disabled',
              'suggestion': null,
            },
          ],
          'truncated': false,
        }),
      }),
      const LibraryCleanupScreen(),
    );
    expect(find.textContaining('Keep'), findsOneWidget);
    expect(find.textContaining('Заменить на: New'), findsOneWidget);
    expect(find.textContaining('Замена не найдена'), findsOneWidget);
    expect(find.textContaining('выбрано 2 из 2'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.textContaining('выбрано 1 из 2'), findsOneWidget);
  });

  testWidgets('changelog lists entries for the chosen channel', (tester) async {
    await _pump(
      tester,
      FakeFeatureTransport({
        'GET /api/v1/changelog': (query, _) => {
          'channel': query?['channel'],
          'entries': [
            {
              'version': query?['channel'] == 'beta' ? '5.1.0-beta' : '5.0.0',
              'title': 'Resonance 5',
              'highlights': ['Друзья и Blend'],
            },
          ],
        },
      }),
      const ChangelogScreen(),
    );
    expect(find.text('5.0.0'), findsOneWidget);
    expect(find.textContaining('Друзья и Blend'), findsOneWidget);
    await tester.tap(find.text('Бета'));
    await tester.pumpAndSettle();
    expect(find.text('5.1.0-beta'), findsOneWidget);
  });

  testWidgets('collaborative playlist shows members and revertible history', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeFeatureTransport({
        'GET /api/v1/features': flags(['playlists.collab']),
        'GET /api/v1/collab-playlists/p1': json({
          'playlist': {
            'id': 'p1',
            'name': 'Вечеринка',
            'role': 'owner',
            'version': 3,
            'members': [
              {'userId': 'u1', 'displayName': 'Аня', 'role': 'owner'},
              {'userId': 'u2', 'displayName': 'Боря', 'role': 'editor'},
            ],
            'tracks': [
              {'entryId': 'e1', 'track': waveItem('1', title: 'Signal')},
            ],
          },
        }),
        'GET /api/v1/collab-playlists/p1/history': json({
          'history': [
            {
              'id': 'h1',
              'userId': 'u2',
              'action': 'remove',
              'track': {'title': 'Echo'},
              'revertedBy': null,
            },
          ],
        }),
      }),
      const CollaborativePlaylistScreen(playlistId: 'p1'),
    );
    expect(find.text('Вечеринка'), findsOneWidget);
    expect(find.text('Боря'), findsOneWidget);
    expect(find.text('Signal'), findsOneWidget);
    expect(find.text('Боря удалил(а) «Echo»'), findsOneWidget);
    expect(find.text('Откатить'), findsOneWidget);
  });
}
