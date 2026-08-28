import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/core/networking/resonance_http_client.dart';
import 'package:resonance/core/networking/soundcloud_proxy_preference.dart';
import 'package:resonance/core/playback/audio_focus_coordinator.dart';
import 'package:resonance/core/playback/demo_audio_source_resolver.dart';
import 'package:resonance/core/playback/playback_engine.dart';
import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/core/playback/resolved_source_cache.dart';
import 'package:resonance/core/playback/resonance_audio_handler.dart';
import 'package:resonance/core/playback/windows_media_controls.dart';
import 'package:resonance/core/preferences/appearance_preferences.dart';
import 'package:resonance/core/preferences/onboarding_preferences.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/core/update/app_update_service.dart';
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

final appearancePreferencesProvider = Provider<AppearancePreferences>((ref) {
  return AppearancePreferences(ref.watch(secureKeyValueStoreProvider));
});

final onboardingPreferencesProvider = Provider<OnboardingPreferences>((ref) {
  return OnboardingPreferences(ref.watch(secureKeyValueStoreProvider));
});

final onboardingSettingsProvider = FutureProvider<OnboardingSettings>((ref) {
  return ref.watch(onboardingPreferencesProvider).read();
});

final appearanceControllerProvider =
    StateNotifierProvider<AppearanceController, AppearanceSettings>((ref) {
      return AppearanceController(ref.watch(appearancePreferencesProvider));
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

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService(
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
  final onboarding = await ref.watch(onboardingPreferencesProvider).read();
  final service = PlaybackService(
    engine: ref.watch(playbackEngineProvider),
    providers: ref.watch(providerRegistryProvider),
    sourceSelectionPolicy: ref.watch(sourceSelectionPolicyProvider),
    persistence: ref.watch(playbackPersistenceProvider),
    sourceCache: ref.watch(resolvedSourceCacheProvider),
    quality: onboarding.quality,
  );
  await service.initialize();
  AudioFocusCoordinator? focusCoordinator;
  ResonanceAudioHandler? audioHandler;
  WindowsMediaControls? windowsMediaControls;
  if (Platform.isAndroid || Platform.isIOS) {
    focusCoordinator = AudioFocusCoordinator(service);
    await focusCoordinator.initialize();
    await AudioService.init(
      builder: () => audioHandler = ResonanceAudioHandler(service),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'app.resonance.playback',
        androidNotificationChannelName: 'Воспроизведение Resonance',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
      ),
    );
  } else if (Platform.isWindows) {
    windowsMediaControls = WindowsMediaControls(service);
  }
  ref.onDispose(() {
    final coordinator = focusCoordinator;
    final handler = audioHandler;
    final windowsControls = windowsMediaControls;
    if (coordinator != null) unawaited(coordinator.dispose());
    if (handler != null) unawaited(handler.close());
    if (windowsControls != null) unawaited(windowsControls.dispose());
    unawaited(service.dispose());
  });
  return service;
});

final playbackStateProvider = StreamProvider<ResonancePlaybackState>((
  ref,
) async* {
  final service = await ref.watch(playbackServiceProvider.future);
  yield service.state;
  yield* service.states;
});
