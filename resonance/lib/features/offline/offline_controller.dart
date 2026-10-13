import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/core/networking/network_status.dart';
import 'package:resonance/core/playback/stream_quality.dart';
import 'package:resonance/core/preferences/offline_preferences.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/wave/wave_controller.dart';

/// Текущий тип сети. До первого ответа платформы считаем, что сеть есть.
final networkKindProvider = StreamProvider<NetworkKind>((ref) {
  return watchNetworkKind();
});

/// Офлайн-режим: сети нет — экраны показывают только скачанное.
final isOfflineProvider = Provider<bool>((ref) {
  return ref.watch(networkKindProvider).valueOrNull == NetworkKind.offline;
});

final offlinePreferencesProvider = Provider<OfflinePreferences>((ref) {
  return OfflinePreferences(ref.watch(secureKeyValueStoreProvider));
});

final offlineSettingsProvider =
    StateNotifierProvider<OfflineSettingsController, OfflineSettings>((ref) {
      return OfflineSettingsController(ref.watch(offlinePreferencesProvider));
    });

final class OfflineSettingsController extends StateNotifier<OfflineSettings> {
  OfflineSettingsController(this._preferences)
    : super(const OfflineSettings()) {
    unawaited(_load());
  }

  final OfflinePreferences _preferences;
  bool _edited = false;

  Future<void> _load() async {
    try {
      final stored = await _preferences.read();
      if (!_edited && mounted) state = stored;
    } on Object {
      // Безопасные значения по умолчанию, если хранилище недоступно.
    }
  }

  Future<void> update(OfflineSettings value) async {
    _edited = true;
    state = value;
    await _preferences.write(value);
  }
}

/// Качество потока с учётом сети: Wi‑Fi — из основной настройки,
/// мобильная сеть — отдельная (обычно ниже).
final effectiveQualityProvider = Provider<AudioQuality>((ref) {
  final wifi =
      ref.watch(onboardingSettingsProvider).valueOrNull?.quality ??
      AudioQuality.high;
  final network =
      ref.watch(networkKindProvider).valueOrNull ?? NetworkKind.wifi;
  return resolveStreamQuality(
    mode: ref.watch(
      playbackFlowControllerProvider.select((flow) => flow.qualityMode),
    ),
    network: network,
    wifiQuality: wifi,
    mobileQuality: ref.watch(offlineSettingsProvider).mobileQuality,
  );
});

/// Самые частые треки истории: по числу прослушиваний, при равенстве —
/// по свежести. Короткие пропуски (< 30 с) не считаются.
List<String> mostPlayedTrackIds(
  Iterable<ListeningRecord> history, {
  int limit = 50,
  Duration minListened = const Duration(seconds: 30),
}) {
  final counts = <String, int>{};
  final latest = <String, DateTime>{};
  for (final record in history) {
    if (record.listened < minListened) continue;
    final id = record.track.id;
    counts[id] = (counts[id] ?? 0) + 1;
    final seen = latest[id];
    if (seen == null || record.playedAt.isAfter(seen)) {
      latest[id] = record.playedAt;
    }
  }
  final ids = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : latest[b]!.compareTo(latest[a]!);
    });
  return ids.take(limit).toList(growable: false);
}

/// Фоновая очередь автокэша: по одному треку, только пока сеть позволяет.
final class AutoCacheWorker {
  AutoCacheWorker({required this.cache, required this.canFetch});

  final Future<bool> Function(UnifiedTrack) cache;
  final bool Function() canFetch;
  final _pending = <String, UnifiedTrack>{};
  final _done = <String>{};
  Future<void>? _running;
  bool _disposed = false;

  int get pending => _pending.length;

  /// Ставит треки в очередь; уже обработанные в этой сессии пропускает.
  Future<void> enqueue(Iterable<UnifiedTrack> tracks) {
    for (final track in tracks) {
      if (track.sources.isEmpty || _done.contains(track.id)) continue;
      _pending.putIfAbsent(track.id, () => track);
    }
    return _running ??= _drain().whenComplete(() => _running = null);
  }

  Future<void> _drain() async {
    while (!_disposed && _pending.isNotEmpty && canFetch()) {
      final id = _pending.keys.first;
      final track = _pending.remove(id)!;
      _done.add(id);
      try {
        await cache(track);
      } on Object {
        // Автокэш оппортунистичен: ошибка одного трека не останавливает очередь.
      }
    }
  }

  void dispose() {
    _disposed = true;
    _pending.clear();
  }
}

/// Связывает сеть, настройки, плеер и загрузки: качество по сети,
/// предзагрузка следующего трека и автокэш частых треков и «Моей волны».
final offlineCoordinatorProvider = FutureProvider<void>((ref) async {
  // Только сам объект, без подписки на notifyListeners: иначе каждая
  // загрузка пересоздавала координатор (и его очередь автокэша), а через
  // него — перестраивала ResonanceApp.
  final downloads = ref.watch(offlineDownloadsProvider.notifier);
  final database = ref.watch(appDatabaseProvider);
  final service = await ref.watch(playbackServiceProvider.future);

  NetworkKind network() =>
      ref.read(networkKindProvider).valueOrNull ?? NetworkKind.wifi;
  OfflineSettings settings() => ref.read(offlineSettingsProvider);

  bool allowed() =>
      settings().autoCache && settings().allowsBackgroundFetch(network());
  final worker = AutoCacheWorker(
    cache: downloads.cacheAutomatically,
    canFetch: allowed,
  );

  void applyPlayback() {
    service.setQuality(ref.read(effectiveQualityProvider));
    service.setPreloadNext(
      settings().preloadNext && network() != NetworkKind.offline,
    );
  }

  Future<void> cacheFrequent() async {
    if (!allowed()) return;
    try {
      final history = await database.loadListeningHistory(
        since: DateTime.now().subtract(const Duration(days: 30)),
      );
      final tracks = <UnifiedTrack>[];
      for (final id in mostPlayedTrackIds(history)) {
        final track = await database.getUnifiedTrack(id);
        if (track != null) tracks.add(track);
      }
      await worker.enqueue(tracks);
    } on Object {
      // История недоступна — автокэш просто подождёт следующего раза.
    }
  }

  void cacheWave(ResonancePlaybackState state) {
    if (!ref.read(waveControllerProvider).active) return;
    if (!allowed()) return;
    final start = state.currentIndex < 0 ? 0 : state.currentIndex;
    unawaited(worker.enqueue(state.queue.skip(start).take(12)));
  }

  Future<void> applyLimit() =>
      downloads.setAutoCacheLimitBytes(settings().autoCacheLimitBytes);

  ref.listen(effectiveQualityProvider, (_, _) => applyPlayback());
  ref.listen(onboardingSettingsProvider, (_, _) => applyPlayback());
  ref.listen(networkKindProvider, (previous, next) {
    applyPlayback();
    if (previous?.valueOrNull != next.valueOrNull) unawaited(cacheFrequent());
  });
  ref.listen(offlineSettingsProvider, (previous, next) {
    applyPlayback();
    unawaited(applyLimit());
    if (previous?.autoCache != next.autoCache ||
        previous?.autoCacheOnMobile != next.autoCacheOnMobile) {
      unawaited(cacheFrequent());
    }
  });
  var lastQueueKey = '';
  final subscription = service.states.listen((state) {
    final key = '${state.currentIndex}:${state.queue.length}';
    if (key == lastQueueKey) return;
    lastQueueKey = key;
    cacheWave(state);
  });
  // Автокэш раз в несколько часов: история меняется медленно.
  final timer = Timer.periodic(
    const Duration(hours: 6),
    (_) => unawaited(cacheFrequent()),
  );
  final startup = Timer(
    const Duration(seconds: 20),
    () => unawaited(cacheFrequent()),
  );
  ref.onDispose(() {
    timer.cancel();
    startup.cancel();
    worker.dispose();
    unawaited(subscription.cancel());
  });

  applyPlayback();
  await applyLimit();
});
