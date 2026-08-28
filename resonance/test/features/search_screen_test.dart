import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/app/resonance_app.dart';
import 'package:resonance/app/router.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/provider_capabilities.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/providers/music_catalog_provider.dart';
import 'package:resonance/providers/common/provider_registry.dart';

import '../helpers/fake_playback_engine.dart';

void main() {
  testWidgets('keeps results when one provider needs a token', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    resonanceRouter.go('/search');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerRegistryProvider.overrideWithValue(
            ProviderRegistry(
              catalogs: const [_SuccessCatalog(), _UnauthorizedCatalog()],
            ),
          ),
          playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
          playbackPersistenceProvider.overrideWithValue(null),
        ],
        child: const ResonanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Tycho');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Awake'), findsOneWidget);
    expect(find.text('Источник недоступен'), findsNothing);
    resonanceRouter.go('/');
  });
}

final class _SuccessCatalog implements MusicCatalogProvider {
  const _SuccessCatalog();

  @override
  MusicProvider get provider => MusicProvider.soundcloud;

  @override
  ProviderCapabilities get capabilities =>
      const ProviderCapabilities(supportsSearch: true);

  @override
  Future<List<UnifiedTrack>> searchTracks(
    String query, {
    int limit = 20,
    String? cursor,
  }) async => [
    UnifiedTrack(
      id: 'soundcloud:42',
      title: 'Awake',
      normalizedTitle: 'awake',
      artist: 'Tycho',
      normalizedArtist: 'tycho',
      sources: [
        TrackSource(
          provider: MusicProvider.soundcloud,
          externalId: 'soundcloud:tracks:42',
          externalUrl: Uri.parse('https://soundcloud.com/tycho/awake'),
        ),
      ],
      preferredProvider: MusicProvider.soundcloud,
    ),
  ];

  @override
  Future<UnifiedTrack?> getTrack(String externalId) async => null;

  @override
  Future<List<UnifiedTrack>> getPlaylistTracks(String playlistId) async =>
      const [];

  @override
  Future<UnifiedTrack?> resolvePublicUrl(Uri url) async => null;
}

final class _UnauthorizedCatalog implements MusicCatalogProvider {
  const _UnauthorizedCatalog();

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
  }) => Future.error(StateError('OAuth token is required'));

  @override
  Future<UnifiedTrack?> getTrack(String externalId) async => null;

  @override
  Future<List<UnifiedTrack>> getPlaylistTracks(String playlistId) async =>
      const [];

  @override
  Future<UnifiedTrack?> resolvePublicUrl(Uri url) async => null;
}
