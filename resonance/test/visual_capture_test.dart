import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/app/resonance_app.dart';
import 'package:resonance/app/router.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/provider_capabilities.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/providers/music_catalog_provider.dart';
import 'package:resonance/features/lyrics/lyrics_service.dart';
import 'package:resonance/providers/common/provider_registry.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

import 'helpers/fake_playback_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;

  setUpAll(() async {
    database = AppDatabase(NativeDatabase.memory());
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([inter.load(), materialIcons.load()]);
  });

  tearDownAll(() => database.close());

  testWidgets('desktop home visual', (tester) async {
    _setViewport(tester, const Size(1440, 1024));
    resonanceRouter.go('/');
    final tracks = [
      _makeTrack(
        provider: MusicProvider.yandex,
        index: 0,
        title: 'Star Shopping',
        artist: 'Lil Peep',
      ),
      _makeTrack(
        provider: MusicProvider.yandex,
        index: 1,
        title: 'Save That Shit',
        artist: 'Lil Peep',
      ),
      _makeTrack(
        provider: MusicProvider.yandex,
        index: 2,
        title: 'Crybaby',
        artist: 'Lil Peep',
      ),
      _makeTrack(
        provider: MusicProvider.soundcloud,
        index: 3,
        title: 'White Tee',
        artist: 'Lil Peep',
      ),
      _makeTrack(
        provider: MusicProvider.soundcloud,
        index: 4,
        title: 'Gym Class',
        artist: 'Lil Peep',
      ),
      _makeTrack(
        provider: MusicProvider.yandex,
        index: 5,
        title: 'Around the World',
        artist: 'Daft Punk',
      ),
    ];
    await tester.pumpWidget(
      _testApp(
        database: database,
        playbackState: ResonancePlaybackState(
          queue: tracks,
          currentIndex: 0,
          playing: true,
          position: const Duration(seconds: 40),
          duration: const Duration(minutes: 2, seconds: 21),
          activeTrackSource: tracks.first.sources.first,
        ),
      ),
    );
    await tester.runAsync(
      () => Future.wait([
        precacheImage(
          const AssetImage('assets/images/resonance_cinematic_background.png'),
          tester.element(find.byType(MaterialApp)),
        ),
        precacheImage(
          const AssetImage('assets/images/resonance_fallback_cover.png'),
          tester.element(find.byType(MaterialApp)),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(MaterialApp)), const Size(1440, 1024));
    expect(find.byTooltip('Главная'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/resonance-home-desktop.png'),
    );
  });

  testWidgets('mobile search visual', (tester) async {
    _setViewport(tester, const Size(390, 844));
    resonanceRouter.go('/search');
    await tester.pumpWidget(
      _testApp(
        database: database,
        registry: ProviderRegistry(
          catalogs: const [
            _FakeCatalogProvider(MusicProvider.yandex),
            _FakeCatalogProvider(MusicProvider.soundcloud),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Lil Peep');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/resonance-search-mobile.png'),
    );
    resonanceRouter.go('/');
  });

  testWidgets('mobile home visual', (tester) async {
    _setViewport(tester, const Size(390, 844));
    resonanceRouter.go('/');
    final track = _makeTrack(
      provider: MusicProvider.yandex,
      index: 0,
      title: 'Star Shopping',
      artist: 'Lil Peep',
    );
    await tester.pumpWidget(
      _testApp(
        database: database,
        playbackState: ResonancePlaybackState(
          queue: [track],
          currentIndex: 0,
          playing: true,
          position: const Duration(seconds: 40),
          duration: const Duration(minutes: 2, seconds: 21),
          activeTrackSource: track.sources.first,
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/resonance_fallback_cover.png'),
        tester.element(find.byType(MaterialApp)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/resonance-home-mobile.png'),
    );
  });

  testWidgets('desktop player visual', (tester) async {
    _setViewport(tester, const Size(1280, 800));
    resonanceRouter.go('/player');
    final track = _makeTrack(
      provider: MusicProvider.yandex,
      index: 0,
      title: 'Star Shopping',
      artist: 'Lil Peep',
    );
    final nextTrack = _makeTrack(
      provider: MusicProvider.soundcloud,
      index: 1,
      title: 'Around the World',
      artist: 'Daft Punk',
    );
    await tester.pumpWidget(
      _testApp(
        database: database,
        lyrics: LyricsDocument(
          id: 7,
          synced: true,
          instrumental: false,
          lines: const [
            LyricLine(text: 'Город гасит фонари', start: Duration(seconds: 32)),
            LyricLine(
              text: 'Мы остаёмся в музыке',
              start: Duration(seconds: 39),
            ),
            LyricLine(
              text: 'До рассвета ещё далеко',
              start: Duration(seconds: 48),
            ),
          ],
          sourceUrl: Uri.parse('https://lrclib.net'),
        ),
        playbackState: ResonancePlaybackState(
          queue: [track, nextTrack],
          currentIndex: 0,
          playing: true,
          position: const Duration(seconds: 40),
          duration: const Duration(minutes: 2, seconds: 21),
          activeTrackSource: track.sources.first,
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/resonance_fallback_cover.png'),
        tester.element(find.byType(MaterialApp)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(TrackArtwork)).width, greaterThan(400));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/resonance-player-desktop.png'),
    );
    resonanceRouter.go('/');
  });

  testWidgets('desktop visual stage lyrics', (tester) async {
    _setViewport(tester, const Size(1440, 900));
    resonanceRouter.go('/stage?mode=lyrics');
    final track = _makeTrack(
      provider: MusicProvider.yandex,
      index: 0,
      title: 'Star Shopping',
      artist: 'Lil Peep',
    );
    await tester.pumpWidget(
      _testApp(
        database: database,
        lyrics: LyricsDocument(
          id: 8,
          synced: true,
          instrumental: false,
          lines: const [
            LyricLine(text: 'Wait right here', start: Duration(seconds: 18)),
            LyricLine(
              text: 'I\'ll be back in the morning',
              start: Duration(seconds: 25),
            ),
            LyricLine(
              text: 'I know that I\'m not that important to you',
              start: Duration(seconds: 34),
            ),
            LyricLine(
              text: 'But to me, girl, you\'re so much more than gorgeous',
              start: Duration(seconds: 40),
            ),
            LyricLine(
              text: 'So much more than perfect',
              start: Duration(seconds: 47),
            ),
          ],
          sourceUrl: Uri.parse('https://lrclib.net'),
        ),
        playbackState: ResonancePlaybackState(
          queue: [track],
          currentIndex: 0,
          playing: true,
          position: const Duration(seconds: 41),
          duration: const Duration(minutes: 2, seconds: 22),
          activeTrackSource: track.sources.first,
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/resonance_fallback_cover.png'),
        tester.element(find.byType(MaterialApp)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/resonance-visual-stage-desktop.png'),
    );
    resonanceRouter.go('/');
  });

  for (final viewport in const [Size(390, 844), Size(844, 390)]) {
    testWidgets('player stays usable at ${viewport.width}x${viewport.height}', (
      tester,
    ) async {
      _setViewport(tester, viewport);
      resonanceRouter.go('/player');
      final track = _makeTrack(
        provider: MusicProvider.soundcloud,
        index: 0,
        title: 'Night Drive',
        artist: 'Resonance',
      );
      await tester.pumpWidget(
        _testApp(
          database: database,
          lyrics: _sampleLyrics(),
          playbackState: ResonancePlaybackState(
            queue: [track],
            currentIndex: 0,
            playing: true,
            position: const Duration(seconds: 40),
            duration: const Duration(minutes: 3),
            activeTrackSource: track.sources.first,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Текст'), findsOneWidget);
      expect(find.byTooltip('Пауза'), findsOneWidget);
      resonanceRouter.go('/');
    });
  }
}

LyricsDocument _sampleLyrics() => LyricsDocument(
  id: 7,
  synced: true,
  instrumental: false,
  lines: const [
    LyricLine(text: 'Город гасит фонари', start: Duration(seconds: 32)),
    LyricLine(text: 'Мы остаёмся в музыке', start: Duration(seconds: 39)),
    LyricLine(text: 'До рассвета ещё далеко', start: Duration(seconds: 48)),
  ],
  sourceUrl: Uri.parse('https://lrclib.net'),
);

Widget _testApp({
  required AppDatabase database,
  ProviderRegistry? registry,
  ResonancePlaybackState? playbackState,
  LyricsDocument? lyrics,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      if (registry != null)
        providerRegistryProvider.overrideWithValue(registry),
      if (playbackState != null)
        playbackStateProvider.overrideWith(
          (ref) => Stream.value(playbackState),
        ),
      if (lyrics != null)
        lyricsProvider.overrideWith((ref, track) async => lyrics),
      playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
      playbackPersistenceProvider.overrideWithValue(null),
    ],
    child: const ResonanceApp(),
  );
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _FakeCatalogProvider implements MusicCatalogProvider {
  const _FakeCatalogProvider(this.provider);

  @override
  final MusicProvider provider;

  @override
  ProviderCapabilities get capabilities =>
      const ProviderCapabilities(supportsSearch: true);

  @override
  Future<List<UnifiedTrack>> searchTracks(
    String query, {
    int limit = 20,
    String? cursor,
  }) async {
    final titles = provider == MusicProvider.yandex
        ? const ['Star Shopping', 'Save That Shit', 'Crybaby']
        : const ['White Tee', 'Gym Class', 'Beamer Boy'];
    return [
      for (var index = 0; index < titles.length; index++)
        _makeTrack(
          provider: provider,
          index: index,
          title: titles[index],
          artist: index.isEven ? 'Lil Peep' : 'Lil Peep · Lil Tracy',
        ),
    ];
  }

  @override
  Future<UnifiedTrack?> getTrack(String externalId) async => null;

  @override
  Future<List<UnifiedTrack>> getPlaylistTracks(String playlistId) async =>
      const [];

  @override
  Future<UnifiedTrack?> resolvePublicUrl(Uri url) async => null;
}

UnifiedTrack _makeTrack({
  required MusicProvider provider,
  required int index,
  required String title,
  required String artist,
}) {
  return UnifiedTrack(
    id: '${provider.name}-$index',
    title: title,
    normalizedTitle: title.toLowerCase(),
    artist: artist,
    normalizedArtist: artist.toLowerCase(),
    duration: Duration(minutes: 3, seconds: 12 + index * 9),
    sources: [
      TrackSource(
        provider: provider,
        externalId: '${provider.name}-$index',
        externalUrl: Uri.parse(
          'https://example.invalid/${provider.name}/$index',
        ),
      ),
    ],
    preferredProvider: provider,
  );
}
