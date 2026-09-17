import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/app/resonance_app.dart';
import 'package:resonance/app/router.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';

import 'helpers/fake_playback_engine.dart';

void main() {
  testWidgets('renders adaptive Resonance shell', (tester) async {
    final engine = FakePlaybackEngine();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          playbackEngineProvider.overrideWithValue(engine),
          playbackPersistenceProvider.overrideWithValue(null),
        ],
        child: const ResonanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Midnight Signal'), findsWidgets);
    expect(find.text('Главная'), findsWidgets);
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
  });

  testWidgets('mobile navigation labels open the matching routes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    resonanceRouter.go('/search');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
          playbackPersistenceProvider.overrideWithValue(null),
        ],
        child: const ResonanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Главная'));
    await tester.pumpAndSettle();

    expect(find.text('Midnight Signal'), findsWidgets);
    expect(find.text('Какую музыку включить?'), findsOneWidget);
    resonanceRouter.go('/');
  });

  testWidgets('music graph route renders canonical cross-provider tracks', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.setFavorite(_graphTrack(MusicProvider.yandex), true);
    await database.createLocalPlaylistWithTracks('graph', 'Graph', [
      _graphTrack(MusicProvider.spotify),
    ]);
    resonanceRouter.go('/graph');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
          playbackPersistenceProvider.overrideWithValue(null),
        ],
        child: const ResonanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Музыка — это связи.'), findsOneWidget);
    expect(find.text('2 источника'), findsWidgets);
    expect(find.text('Объединить совпадения · 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    resonanceRouter.go('/');
  });
}

UnifiedTrack _graphTrack(MusicProvider provider) => UnifiedTrack(
  id: '${provider.name}:signal',
  title: 'Signal',
  normalizedTitle: 'signal',
  artist: 'Resonance',
  normalizedArtist: 'resonance',
  album: 'Night',
  duration: const Duration(minutes: 3),
  preferredProvider: provider,
  sources: [
    TrackSource(
      provider: provider,
      externalId: 'signal',
      externalUrl: Uri.parse('https://example.invalid/${provider.name}/signal'),
    ),
  ],
);
