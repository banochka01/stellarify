import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/core/networking/resonance_http_client.dart';
import 'package:resonance/core/networking/soundcloud_proxy_preference.dart';
import 'package:resonance/core/playback/demo_audio_source_resolver.dart';
import 'package:resonance/core/playback/playback_engine.dart';
import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/core/playback/resolved_source_cache.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/repositories/playback_persistence.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';
import 'package:resonance/domain/services/source_selection_policy.dart';
import 'package:resonance/features/library/playlist_import_service.dart';
import 'package:resonance/providers/common/provider_registry.dart';
import 'package:resonance/providers/soundcloud/backend_soundcloud_provider.dart';
import 'package:resonance/providers/yandex/backend_yandex_provider.dart';
import 'package:resonance/providers/youtube/backend_youtube_provider.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() {
    unawaited(database.close());
  });
  return database;
});

final playbackPersistenceProvider = Provider<PlaybackPersistence?>((ref) {
  return DriftPlaybackPersistence(ref.watch(appDatabaseProvider));
});

final secureKeyValueStoreProvider = Provider<SecureKeyValueStore>((ref) {
  return FlutterSecureKeyValueStore();
});

final secureTokenRepositoryProvider = Provider<SecureTokenRepository>((ref) {
  return FlutterSecureTokenRepository(ref.watch(secureKeyValueStoreProvider));
});

final soundCloudProxyPreferenceProvider = Provider<SoundCloudProxyPreference>((
  ref,
) {
  return SecureSoundCloudProxyPreference(
    ref.watch(secureKeyValueStoreProvider),
  );
});

final resonanceHttpClientProvider = Provider<ResonanceHttpClient>((ref) {
  final client = ResonanceHttpClient();
  ref.onDispose(client.close);
  return client;
});

final resonanceBackendClientProvider = Provider<ResonanceBackendClient>((ref) {
  return DioResonanceBackendClient(
    ref.watch(resonanceHttpClientProvider).dio,
    BackendEndpoint.requireCurrent,
  );
});

final sourceSelectionPolicyProvider = Provider<SourceSelectionPolicy>((ref) {
  return SourceSelectionPolicy();
});

final resolvedSourceCacheProvider = Provider<ResolvedSourceCache>((ref) {
  return ResolvedSourceCache();
});

final providerRegistryProvider = Provider<ProviderRegistry>((ref) {
  final demoResolver = DemoAudioSourceResolver();
  final soundCloud = BackendSoundCloudProvider(
    ref.watch(resonanceBackendClientProvider),
    ref.watch(secureTokenRepositoryProvider),
    ref.watch(soundCloudProxyPreferenceProvider),
    demoResolver,
  );
  final yandex = BackendYandexProvider(
    DioYandexBackendClient(
      ref.watch(resonanceHttpClientProvider).dio,
      BackendEndpoint.requireCurrent,
    ),
    ref.watch(secureTokenRepositoryProvider),
  );
  final youtube = BackendYouTubeProvider(
    ref.watch(resonanceHttpClientProvider).dio,
    BackendEndpoint.requireCurrent,
    ref.watch(secureTokenRepositoryProvider),
  );
  return ProviderRegistry(
    catalogs: [soundCloud, yandex, youtube],
    resolvers: [soundCloud, yandex],
  );
});

final playlistImportServiceProvider = Provider<PlaylistImportService>((ref) {
  return PlaylistImportService(
    ref.watch(resonanceHttpClientProvider).dio,
    BackendEndpoint.requireCurrent,
    ref.watch(secureTokenRepositoryProvider),
  );
});

final playbackEngineProvider = Provider<PlaybackEngine>((ref) {
  return MediaKitPlaybackEngine();
});

final playbackServiceProvider = FutureProvider<PlaybackService>((ref) async {
  final service = PlaybackService(
    engine: ref.watch(playbackEngineProvider),
    providers: ref.watch(providerRegistryProvider),
    sourceSelectionPolicy: ref.watch(sourceSelectionPolicyProvider),
    persistence: ref.watch(playbackPersistenceProvider),
    sourceCache: ref.watch(resolvedSourceCacheProvider),
  );
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  await service.initialize();
  return service;
});

final playbackStateProvider = StreamProvider<ResonancePlaybackState>((
  ref,
) async* {
  final service = await ref.watch(playbackServiceProvider.future);
  yield service.state;
  yield* service.states;
});
