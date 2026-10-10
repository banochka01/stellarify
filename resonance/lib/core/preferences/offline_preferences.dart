import 'package:resonance/core/networking/network_status.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/music_enums.dart';

/// Настройки умного офлайна. Качество по Wi‑Fi хранится в онбординге
/// (историческое «качество воспроизведения»), здесь — всё остальное.
final class OfflineSettings {
  const OfflineSettings({
    this.mobileQuality = AudioQuality.medium,
    this.autoCache = true,
    this.autoCacheLimitMb = 2048,
    this.autoCacheOnMobile = false,
    this.preloadNext = true,
  });

  static const limitStepsMb = [0, 512, 1024, 2048, 4096, 8192, 16384];

  final AudioQuality mobileQuality;
  final bool autoCache;
  final int autoCacheLimitMb;
  final bool autoCacheOnMobile;
  final bool preloadNext;

  int get autoCacheLimitBytes => autoCache ? autoCacheLimitMb * 1024 * 1024 : 0;

  /// Можно ли сейчас тратить трафик на фоновые загрузки.
  bool allowsBackgroundFetch(NetworkKind network) => switch (network) {
    NetworkKind.wifi => true,
    NetworkKind.mobile => autoCacheOnMobile,
    NetworkKind.offline => false,
  };

  AudioQuality qualityFor(NetworkKind network, AudioQuality wifiQuality) =>
      network == NetworkKind.mobile ? mobileQuality : wifiQuality;

  OfflineSettings copyWith({
    AudioQuality? mobileQuality,
    bool? autoCache,
    int? autoCacheLimitMb,
    bool? autoCacheOnMobile,
    bool? preloadNext,
  }) => OfflineSettings(
    mobileQuality: mobileQuality ?? this.mobileQuality,
    autoCache: autoCache ?? this.autoCache,
    autoCacheLimitMb: autoCacheLimitMb ?? this.autoCacheLimitMb,
    autoCacheOnMobile: autoCacheOnMobile ?? this.autoCacheOnMobile,
    preloadNext: preloadNext ?? this.preloadNext,
  );
}

final class OfflinePreferences {
  OfflinePreferences(this._store);

  static const _mobileQualityKey = 'resonance.offline.mobile_quality';
  static const _autoCacheKey = 'resonance.offline.auto_cache';
  static const _limitKey = 'resonance.offline.limit_mb';
  static const _mobileFetchKey = 'resonance.offline.auto_cache_mobile';
  static const _preloadKey = 'resonance.offline.preload_next';
  final SecureKeyValueStore _store;

  Future<OfflineSettings> read() async {
    final values = await Future.wait([
      _store.read(_mobileQualityKey),
      _store.read(_autoCacheKey),
      _store.read(_limitKey),
      _store.read(_mobileFetchKey),
      _store.read(_preloadKey),
    ]);
    final limit = int.tryParse(values[2] ?? '');
    return OfflineSettings(
      mobileQuality: AudioQuality.values.firstWhere(
        (value) => value.name == values[0],
        orElse: () => AudioQuality.medium,
      ),
      autoCache: values[1] != 'false',
      autoCacheLimitMb: OfflineSettings.limitStepsMb.contains(limit)
          ? limit!
          : 2048,
      autoCacheOnMobile: values[3] == 'true',
      preloadNext: values[4] != 'false',
    );
  }

  Future<void> write(OfflineSettings value) => Future.wait([
    _store.write(_mobileQualityKey, value.mobileQuality.name),
    _store.write(_autoCacheKey, value.autoCache.toString()),
    _store.write(_limitKey, value.autoCacheLimitMb.toString()),
    _store.write(_mobileFetchKey, value.autoCacheOnMobile.toString()),
    _store.write(_preloadKey, value.preloadNext.toString()),
  ]);
}
