import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/core/networking/network_status.dart';
import 'package:resonance/core/preferences/offline_preferences.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/offline/offline_controller.dart';
import 'package:resonance/features/settings/storage_screen.dart';

void main() {
  test('most played: count, then recency, skips short listens', () {
    final base = DateTime(2026, 10, 1);
    ListeningRecord r(String id, int minute, {int seconds = 120}) =>
        ListeningRecord(
          track: _track(id),
          playedAt: base.add(Duration(minutes: minute)),
          listened: Duration(seconds: seconds),
        );
    final ids = mostPlayedTrackIds([
      r('a', 1),
      r('b', 2),
      r('b', 3),
      r('c', 4),
      r('d', 5, seconds: 5),
      r('d', 6, seconds: 5),
      r('d', 7, seconds: 5),
    ], limit: 3);
    expect(ids, ['b', 'c', 'a']);
  });

  test('network kind maps connectivity results', () {
    expect(networkKindOf([ConnectivityResult.none]), NetworkKind.offline);
    expect(networkKindOf([]), NetworkKind.offline);
    expect(networkKindOf([ConnectivityResult.mobile]), NetworkKind.mobile);
    expect(
      networkKindOf([ConnectivityResult.mobile, ConnectivityResult.wifi]),
      NetworkKind.wifi,
    );
    expect(networkKindOf([ConnectivityResult.ethernet]), NetworkKind.wifi);
  });

  test('quality and background fetch follow the network', () {
    const settings = OfflineSettings(mobileQuality: AudioQuality.low);
    expect(
      settings.qualityFor(NetworkKind.mobile, AudioQuality.lossless),
      AudioQuality.low,
    );
    expect(
      settings.qualityFor(NetworkKind.wifi, AudioQuality.lossless),
      AudioQuality.lossless,
    );
    expect(settings.allowsBackgroundFetch(NetworkKind.mobile), isFalse);
    expect(settings.allowsBackgroundFetch(NetworkKind.wifi), isTrue);
    expect(settings.allowsBackgroundFetch(NetworkKind.offline), isFalse);
    expect(settings.copyWith(autoCache: false).autoCacheLimitBytes, 0);
  });

  test('offline preferences round-trip', () async {
    final preferences = OfflinePreferences(_MemoryStore());
    expect((await preferences.read()).autoCacheLimitMb, 2048);
    await preferences.write(
      const OfflineSettings(
        mobileQuality: AudioQuality.low,
        autoCache: false,
        autoCacheLimitMb: 512,
        autoCacheOnMobile: true,
        preloadNext: false,
      ),
    );
    final read = await preferences.read();
    expect(read.mobileQuality, AudioQuality.low);
    expect(read.autoCache, isFalse);
    expect(read.autoCacheLimitMb, 512);
    expect(read.autoCacheOnMobile, isTrue);
    expect(read.preloadNext, isFalse);
  });

  test('auto cache worker is sequential and pauses without network', () async {
    var allowed = true;
    final cached = <String>[];
    final worker = AutoCacheWorker(
      cache: (track) async {
        cached.add(track.id);
        if (track.id == 'b') allowed = false;
        return true;
      },
      canFetch: () => allowed,
    );
    await worker.enqueue([_track('a'), _track('b'), _track('c')]);
    expect(cached, ['a', 'b']);
    expect(worker.pending, 1);
    allowed = true;
    await worker.enqueue([_track('a')]);
    expect(cached, ['a', 'b', 'c']);
  });

  test('bytes are formatted in Russian units', () {
    expect(formatBytes(512), '512 Б');
    expect(formatBytes(1536), '1,5 КБ');
    expect(formatBytes(340 * 1024 * 1024), '340 МБ');
    expect(formatBytes(1288490189), '1,2 ГБ');
  });
}

UnifiedTrack _track(String id) => UnifiedTrack(
  id: id,
  title: id,
  normalizedTitle: id,
  artist: 'Artist',
  normalizedArtist: 'artist',
  sources: [
    TrackSource(
      provider: MusicProvider.soundcloud,
      externalId: id,
      externalUrl: Uri.parse('https://soundcloud.com/a/$id'),
    ),
  ],
);

final class _MemoryStore implements SecureKeyValueStore {
  final _values = <String, String>{};
  @override
  Future<void> delete(String key) async => _values.remove(key);
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
