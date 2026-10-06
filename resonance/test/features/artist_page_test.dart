import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/app/resonance_app.dart';
import 'package:resonance/app/router.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/provider_capabilities.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/providers/music_catalog_provider.dart';
import 'package:resonance/features/artist/artist_catalog.dart';
import 'package:resonance/features/artist/artist_screen.dart';
import 'package:resonance/providers/common/provider_registry.dart';
import 'package:resonance/shared/widgets/media_cards.dart';

import '../helpers/fake_playback_engine.dart';

void main() {
  group('artist credits', () {
    test('splits collaborations and keeps the main artist first', () {
      expect(artistCredits('Aarne & FEDUK feat. Scally Milano'), [
        'Aarne',
        'FEDUK',
        'Scally Milano',
      ]);
      expect(artistCredits('OG Buda x Scally Milano'), [
        'OG Buda',
        'Scally Milano',
      ]);
      expect(primaryArtist('MORGENSHTERN, Тимати'), 'MORGENSHTERN');
      expect(primaryArtist('PureSnow'), 'PureSnow');
    });

    test('normalizes titles without versions or features', () {
      expect(normalizeTitleKey('TEETH (feat. Someone)'), 'teeth');
      expect(normalizeTitleKey('Limbo - Remastered 2024'), 'limbo');
      expect(normalizeArtistKey('The Weeknd'), 'weeknd');
    });

    test('matches a catalog reference to the right playable track', () {
      final tracks = [
        _track('a', 'TEETH (Slowed)', 'Someone Else'),
        _track('b', 'TEETH', 'PureSnow feat. Friend'),
        _track('c', 'TEETH (Live)', 'PureSnow'),
      ];
      expect(bestTrackMatch('TEETH', 'PureSnow', tracks)?.id, 'b');
      expect(bestTrackMatch('Unknown', 'PureSnow', tracks), isNull);
    });

    test('parses profiles and skips malformed entries', () {
      final profile = ArtistProfile.fromJson({
        'artist': {
          'name': 'PureSnow',
          'fans': 151700,
          'pictureUrl': 'http://insecure.example/a.jpg',
        },
        'topTracks': [
          {'id': 'deezer:1', 'title': 'TEETH', 'artist': 'PureSnow'},
          {'broken': true},
        ],
        'albums': [
          {
            'id': 'deezer:2',
            'title': 'Oaths',
            'releaseDate': '2026-03-18',
            'type': 'album',
          },
          {'id': 'deezer:3', 'title': 'Limbo', 'type': 'single'},
        ],
      });
      expect(profile.pictureUrl, isNull);
      expect(profile.topTracks.single.title, 'TEETH');
      expect(profile.albums.first.releaseDate?.year, 2026);
      expect(profile.albums.last.isSingle, isTrue);
    });

    test('formats listener counts in Russian', () {
      expect(compactCount(151700), '151,7 тыс.');
      expect(compactCount(2000000), '2 млн');
      expect(compactCount(950), '950');
    });
  });

  testWidgets('artist page shows profile, releases and related artists', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    resonanceRouter.go('/artist/${Uri.encodeComponent('PureSnow')}');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
          playbackPersistenceProvider.overrideWithValue(null),
          artistBackendAvailableProvider.overrideWithValue(true),
          artistCatalogProvider.overrideWithValue(const _FakeArtistCatalog()),
          providerRegistryProvider.overrideWithValue(
            ProviderRegistry(catalogs: [const _FakeCatalog()]),
          ),
        ],
        child: const ResonanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('АРТИСТ'), findsOneWidget);
    expect(find.text('151,7 тыс. поклонников · 3 релизов'), findsOneWidget);
    expect(find.text('Слушать все'), findsOneWidget);
    expect(find.text('Популярные'), findsOneWidget);
    expect(find.text('TEETH'), findsOneWidget);
    expect(find.text('Альбомы'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Синглы и EP'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Похожие артисты'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Friend'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Friend'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((w) => w is ArtistScreen && w.name == 'Friend'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Назад').last);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((w) => w is ArtistScreen && w.name == 'Friend'),
      findsNothing,
    );
    resonanceRouter.go('/');
  });
}

UnifiedTrack _track(String id, String title, String artist) => UnifiedTrack(
  id: id,
  title: title,
  normalizedTitle: title.toLowerCase(),
  artist: artist,
  normalizedArtist: artist.toLowerCase(),
  sources: [
    TrackSource(
      provider: MusicProvider.yandex,
      externalId: id,
      externalUrl: Uri.parse('https://example.invalid/$id'),
    ),
  ],
  preferredProvider: MusicProvider.yandex,
);

class _FakeArtistCatalog implements ArtistCatalog {
  const _FakeArtistCatalog();

  @override
  Future<ArtistProfile?> profile(String name) async => ArtistProfile(
    name: name,
    fans: 151700,
    topTracks: const [
      ArtistTrackInfo(
        id: 'deezer:1',
        title: 'TEETH',
        artist: 'PureSnow',
        album: 'Oaths',
      ),
      ArtistTrackInfo(id: 'deezer:2', title: 'Over', artist: 'PureSnow'),
    ],
    albums: [
      ArtistAlbumInfo(
        id: 'deezer:10',
        title: 'Oaths',
        releaseDate: DateTime(2026, 3, 18),
      ),
      const ArtistAlbumInfo(id: 'deezer:11', title: 'Beverly'),
      const ArtistAlbumInfo(id: 'deezer:12', title: 'Limbo', type: 'single'),
    ],
    related: const [ArtistSummary(name: 'Friend', fans: 12)],
  );

  @override
  Future<ArtistAlbumDetails?> album(String id) async => null;
}

class _FakeCatalog implements MusicCatalogProvider {
  const _FakeCatalog();

  @override
  MusicProvider get provider => MusicProvider.yandex;

  @override
  ProviderCapabilities get capabilities =>
      const ProviderCapabilities(supportsSearch: true);

  @override
  Future<List<UnifiedTrack>> searchTracks(
    String query, {
    int limit = 20,
    String? cursor,
  }) async => [_track('y1', 'TEETH', 'PureSnow')];

  @override
  Future<UnifiedTrack?> getTrack(String externalId) async => null;

  @override
  Future<List<UnifiedTrack>> getPlaylistTracks(String playlistId) async =>
      const [];

  @override
  Future<UnifiedTrack?> resolvePublicUrl(Uri url) async => null;
}
