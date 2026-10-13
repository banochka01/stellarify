import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/cast/cast_controller.dart';
import 'package:resonance/core/cast/cast_providers.dart';
import 'package:resonance/core/networking/network_status.dart';
import 'package:resonance/core/playback/audio_effects.dart';
import 'package:resonance/core/playback/loudness_normalization.dart';
import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/core/playback/stream_quality.dart';
import 'package:resonance/core/playback/transition_policy.dart';
import 'package:resonance/core/preferences/playback_flow_preferences.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/providers/audio_source_resolver.dart';
import 'package:resonance/domain/services/source_selection_policy.dart';
import 'package:resonance/features/recognize/recognition_api.dart';
import 'package:resonance/providers/common/provider_registry.dart';

import '../helpers/fake_playback_engine.dart';

void main() {
  group('loudness normalization', () {
    test('track mode brings loud and quiet masters to the target', () {
      expect(
        normalizationGainDb(
          mode: LoudnessNormalizationMode.track,
          track: const LoudnessStats(integratedLufs: -8),
        ),
        -6,
      );
      expect(
        normalizationGainDb(
          mode: LoudnessNormalizationMode.track,
          track: const LoudnessStats(integratedLufs: -18, truePeakDb: -6),
        ),
        4,
      );
    });

    test('without a known true peak quiet tracks are never boosted', () {
      expect(
        normalizationGainDb(
          mode: LoudnessNormalizationMode.track,
          track: const LoudnessStats(integratedLufs: -18),
        ),
        0,
      );
    });

    test('album gain needs provider data or enough measured tracks', () {
      const measured = LoudnessStats(integratedLufs: -10);
      const provider = LoudnessStats(
        integratedLufs: -10,
        origin: LoudnessOrigin.provider,
      );
      expect(albumLoudnessReliable(const []), isFalse);
      expect(albumLoudnessReliable(const [measured, measured]), isFalse);
      expect(
        albumLoudnessReliable(const [measured, measured, measured]),
        isTrue,
      );
      expect(albumLoudnessReliable(const [provider]), isTrue);
    });

    test('off mode and unknown loudness apply no gain', () {
      expect(
        normalizationGainDb(
          mode: LoudnessNormalizationMode.off,
          track: const LoudnessStats(integratedLufs: -8),
        ),
        isNull,
      );
      expect(
        normalizationGainDb(mode: LoudnessNormalizationMode.track),
        isNull,
      );
    });

    test('boost is limited by max boost and by the true peak', () {
      expect(
        normalizationGainDb(
          mode: LoudnessNormalizationMode.track,
          track: const LoudnessStats(integratedLufs: -30, truePeakDb: -12),
        ),
        loudnessMaxBoostDb,
      );
      expect(
        normalizationGainDb(
          mode: LoudnessNormalizationMode.track,
          track: const LoudnessStats(integratedLufs: -20, truePeakDb: -3),
        ),
        2,
      );
    });

    test('album mode uses one gain for the whole album', () {
      final album = albumLoudness([-10, -14, -12])!;
      expect(album, closeWith(-11.7, .2));
      final quiet = normalizationGainDb(
        mode: LoudnessNormalizationMode.album,
        track: const LoudnessStats(integratedLufs: -14),
        albumLufs: album,
      );
      final loud = normalizationGainDb(
        mode: LoudnessNormalizationMode.album,
        track: const LoudnessStats(integratedLufs: -10),
        albumLufs: album,
      );
      expect(quiet, loud);
    });

    test('mpv cubic volume factor matches the requested gain', () {
      expect(gainDbToVolumeFactor(null), 1);
      expect(gainDbToVolumeFactor(0), 1);
      // -6 дБ амплитуды = (factor)^3 → factor = 10^(-6/60).
      expect(gainDbToVolumeFactor(-6), closeWith(.794, .001));
    });

    test('normalizer prefers provider metadata and remembers it', () async {
      final store = MemoryLoudnessStore();
      final normalizer = LoudnessNormalizer(store);
      final track = _track('a', album: 'Album');
      final gain = await normalizer.gainFor(
        mode: LoudnessNormalizationMode.track,
        track: track,
        source: _source(loudness: -9),
      );
      expect(gain, -5);
      expect(store.values['a']?.origin, LoudnessOrigin.provider);

      // Измерение плеера не перетирает данные провайдера.
      await normalizer.remember(track, -20);
      expect(store.values['a']?.integratedLufs, -9);
    });

    test('normalizer falls back to stored measurements', () async {
      final store = MemoryLoudnessStore();
      final normalizer = LoudnessNormalizer(store);
      final track = _track('b');
      expect(
        await normalizer.gainFor(
          mode: LoudnessNormalizationMode.track,
          track: track,
          source: _source(),
        ),
        isNull,
      );
      await normalizer.remember(track, -11);
      expect(
        await normalizer.gainFor(
          mode: LoudnessNormalizationMode.track,
          track: track,
          source: _source(),
        ),
        -3,
      );
    });

    test('parses the ebur128 meter metadata from libmpv', () {
      expect(
        parseEbur128Integrated(
          '{"lavfi.r128.M":"-9.1","lavfi.r128.I":"-12.4"}',
        ),
        -12.4,
      );
      expect(parseEbur128Integrated('lavfi.r128.I=-70.0'), isNull);
      expect(parseEbur128Integrated(null), isNull);
    });

    test('filter chain puts the meter first and only when supported', () {
      const support = AudioFilterSupport(ebur128: true, loudnorm: true);
      expect(
        buildAudioFilterChain(support: support, normalize: true, measure: true),
        startsWith('@meter:ebur128'),
      );
      expect(
        buildAudioFilterChain(
          support: const AudioFilterSupport(),
          measure: true,
        ),
        isEmpty,
      );
    });

    test('Drift-free stats survive JSON round trip', () {
      const stats = LoudnessStats(
        integratedLufs: -10.5,
        truePeakDb: -.4,
        origin: LoudnessOrigin.provider,
        album: 'artist|album',
      );
      final restored = LoudnessStats.fromJson(stats.toJson())!;
      expect(restored.integratedLufs, -10.5);
      expect(restored.truePeakDb, -.4);
      expect(restored.origin, LoudnessOrigin.provider);
      expect(restored.album, 'artist|album');
      expect(LoudnessStats.fromJson({'lufs': 5}), isNull);
    });
  });

  group('quality selection', () {
    test('auto follows Wi-Fi and mobile settings', () {
      expect(
        resolveStreamQuality(
          mode: StreamQualityMode.auto,
          network: NetworkKind.wifi,
          wifiQuality: AudioQuality.lossless,
        ),
        AudioQuality.lossless,
      );
      expect(
        resolveStreamQuality(
          mode: StreamQualityMode.auto,
          network: NetworkKind.mobile,
          wifiQuality: AudioQuality.lossless,
          mobileQuality: AudioQuality.medium,
        ),
        AudioQuality.medium,
      );
    });

    test('lossless never streams lossless over mobile data', () {
      expect(
        resolveStreamQuality(
          mode: StreamQualityMode.lossless,
          network: NetworkKind.wifi,
        ),
        AudioQuality.lossless,
      );
      expect(
        resolveStreamQuality(
          mode: StreamQualityMode.lossless,
          network: NetworkKind.mobile,
          allowHighOnMobile: true,
        ),
        AudioQuality.high,
      );
      // Мобильное качество — потолок, пока высокое не разрешено явно.
      expect(
        resolveStreamQuality(
          mode: StreamQualityMode.lossless,
          network: NetworkKind.mobile,
          mobileQuality: AudioQuality.medium,
        ),
        AudioQuality.medium,
      );
      expect(
        resolveStreamQuality(
          mode: StreamQualityMode.auto,
          network: NetworkKind.mobile,
          wifiQuality: AudioQuality.low,
          mobileQuality: AudioQuality.high,
        ),
        AudioQuality.low,
      );
      expect(
        resolveStreamQuality(
          mode: StreamQualityMode.high,
          network: NetworkKind.mobile,
          allowHighOnMobile: false,
          mobileQuality: AudioQuality.low,
        ),
        AudioQuality.low,
      );
    });

    test('format badge reads codec, bitrate and resolution', () {
      expect(audioFormatBadge(null), isNull);
      expect(audioFormatBadge(_source(codec: 'mp3')), AudioFormatBadge.mp3);
      expect(
        audioFormatBadge(_source(codec: 'mp4a.40.2')),
        AudioFormatBadge.aac,
      );
      expect(audioFormatBadge(_source(codec: 'flac')), AudioFormatBadge.flac);
      expect(
        audioFormatBadge(
          _source(codec: 'flac', sampleRate: 96000, bitDepth: 24),
        ),
        AudioFormatBadge.hiRes,
      );
      expect(
        audioFormatLabel(_source(codec: 'aac', bitrate: 256000)),
        'AAC · 256',
      );
      expect(
        audioFormatLabel(
          _source(codec: 'flac', sampleRate: 44100, bitDepth: 16),
        ),
        'FLAC · 16/44.1',
      );
      expect(audioFormatBadge(_source()), isNull);
    });

    test('flow settings persist normalization, gapless and quality', () async {
      final store = _MemoryStore();
      final preferences = PlaybackFlowPreferences(store);
      expect(
        (await preferences.read()).normalization,
        LoudnessNormalizationMode.track,
      );
      await preferences.write(
        const PlaybackFlowSettings(
          normalization: LoudnessNormalizationMode.album,
          gapless: false,
          qualityMode: StreamQualityMode.lossless,
        ),
      );
      final restored = await preferences.read();
      expect(restored.normalization, LoudnessNormalizationMode.album);
      expect(restored.gapless, isFalse);
      expect(restored.qualityMode, StreamQualityMode.lossless);
      expect(restored.highQualityOnMobile, isFalse);
      await preferences.write(restored.copyWith(highQualityOnMobile: true));
      expect((await preferences.read()).highQualityOnMobile, isTrue);
      expect(
        restored.copyWith(normalizeLoudness: false).normalization,
        LoudnessNormalizationMode.off,
      );
    });
  });

  group('gapless', () {
    final one = _track('one', album: 'Album');
    final two = _track('two', album: 'Album');
    final other = _track('three', album: 'Other');

    test('only album order without crossfade is gapless', () {
      bool gapless({
        bool flow = true,
        bool smart = false,
        Duration transition = const Duration(seconds: 2),
        UnifiedTrack? next,
        bool shuffle = false,
      }) => shouldUseGapless(
        gaplessEnabled: true,
        flowEnabled: flow,
        smartTransitions: smart,
        transition: transition,
        current: one,
        next: next ?? two,
        shuffle: shuffle,
      );

      expect(gapless(flow: false), isTrue);
      expect(gapless(transition: Duration.zero), isTrue);
      expect(gapless(smart: true), isTrue, reason: 'умный переход не затухает');
      expect(gapless(), isFalse, reason: 'кроссфейд включён');
      expect(gapless(flow: false, next: other), isFalse);
      expect(gapless(flow: false, shuffle: true), isFalse);
    });

    test(
      'service queues the next album track and follows the engine',
      () async {
        final engine = FakePlaybackEngine();
        final service = PlaybackService(
          engine: engine,
          providers: ProviderRegistry(resolvers: [_Resolver()]),
          sourceSelectionPolicy: SourceSelectionPolicy(),
          flowSettings: const PlaybackFlowSettings(enabled: false),
        );
        addTearDown(service.dispose);
        await service.setQueue([one, two], autoplay: true);
        engine.emitDuration(const Duration(minutes: 3));
        await Future<void>.delayed(Duration.zero);
        await service.seek(const Duration(minutes: 2, seconds: 50));
        await _waitFor(() => engine.queuedNext.whereType<Object>().isNotEmpty);
        expect(engine.queuedNext.last?.streamUrl.path, contains('two'));

        // Плеер сам начал следующий трек — без повторного open.
        final opened = engine.openedSources.length;
        engine.emitCompleted();
        engine.emitAdvancedToQueued();
        await _waitFor(() => service.state.currentIndex == 1);
        expect(engine.openedSources, hasLength(opened));
        expect(
          service.state.activeAudioSource?.streamUrl.path,
          contains('two'),
        );
      },
    );

    test('gain is set before start and travels with the queued file', () async {
      final engine = FakePlaybackEngine();
      final store = MemoryLoudnessStore();
      await store.write('one', const LoudnessStats(integratedLufs: -10));
      await store.write('two', const LoudnessStats(integratedLufs: -8));
      final service = PlaybackService(
        engine: engine,
        providers: ProviderRegistry(resolvers: [_Resolver()]),
        sourceSelectionPolicy: SourceSelectionPolicy(),
        flowSettings: const PlaybackFlowSettings(enabled: false),
        normalizer: LoudnessNormalizer(store),
      );
      addTearDown(service.dispose);
      await service.setQueue([one, two], autoplay: true);
      expect(engine.events.take(2), ['gain', 'open']);
      expect(engine.replayGains.last, -4);

      engine.emitDuration(const Duration(minutes: 3));
      await Future<void>.delayed(Duration.zero);
      await service.seek(const Duration(minutes: 2, seconds: 50));
      await _waitFor(() => engine.queuedNext.whereType<Object>().isNotEmpty);
      expect(engine.queuedGains.last, -6);

      final gainCalls = engine.replayGains.length;
      engine.emitAdvancedToQueued(-12);
      await _waitFor(() => service.state.currentIndex == 1);
      // Гейн записи применил сам движок, сервис его не дублирует.
      expect(engine.replayGains, hasLength(gainCalls));
      expect(service.currentGainDb, -6);
      await _waitFor(() => store.values['one']?.integratedLufs == -12);
    });

    test('a failed queue is not treated as prepared', () async {
      final engine = FakePlaybackEngine()..queueSucceeds = false;
      final service = PlaybackService(
        engine: engine,
        providers: ProviderRegistry(resolvers: [_Resolver()]),
        sourceSelectionPolicy: SourceSelectionPolicy(),
        flowSettings: const PlaybackFlowSettings(enabled: false),
      );
      addTearDown(service.dispose);
      await service.setQueue([one, two], autoplay: true);
      engine.emitDuration(const Duration(minutes: 3));
      await Future<void>.delayed(Duration.zero);
      await service.seek(const Duration(minutes: 2, seconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final opened = engine.openedSources.length;
      engine.emitCompleted();
      await _waitFor(() => service.state.currentIndex == 1);
      expect(engine.openedSources.length, opened + 1);
    });

    test('missing advance after completion falls back to next()', () async {
      final engine = FakePlaybackEngine();
      final service = PlaybackService(
        engine: engine,
        providers: ProviderRegistry(resolvers: [_Resolver()]),
        sourceSelectionPolicy: SourceSelectionPolicy(),
        flowSettings: const PlaybackFlowSettings(enabled: false),
      );
      addTearDown(service.dispose);
      await service.setQueue([one, two], autoplay: true);
      engine.emitDuration(const Duration(minutes: 3));
      await Future<void>.delayed(Duration.zero);
      await service.seek(const Duration(minutes: 2, seconds: 50));
      await _waitFor(() => engine.queuedNext.whereType<Object>().isNotEmpty);
      engine.emitCompleted();
      await Future<void>.delayed(const Duration(milliseconds: 2300));
      expect(service.state.currentIndex, 1);
      expect(engine.queuedNext.last, isNull);
    });

    test('queue edits drop the prepared track', () async {
      final engine = FakePlaybackEngine();
      final service = PlaybackService(
        engine: engine,
        providers: ProviderRegistry(resolvers: [_Resolver()]),
        sourceSelectionPolicy: SourceSelectionPolicy(),
        flowSettings: const PlaybackFlowSettings(enabled: false),
      );
      addTearDown(service.dispose);
      await service.setQueue([one, two], autoplay: true);
      engine.emitDuration(const Duration(minutes: 3));
      await Future<void>.delayed(Duration.zero);
      await service.seek(const Duration(minutes: 2, seconds: 50));
      await _waitFor(() => engine.queuedNext.whereType<Object>().isNotEmpty);
      await service.playNext(other);
      expect(engine.queuedNext.last, isNull);
    });

    test('service applies the normalization gain to the engine', () async {
      final engine = FakePlaybackEngine();
      final store = MemoryLoudnessStore();
      await store.write('one', const LoudnessStats(integratedLufs: -10));
      final service = PlaybackService(
        engine: engine,
        providers: ProviderRegistry(resolvers: [_Resolver()]),
        sourceSelectionPolicy: SourceSelectionPolicy(),
        normalizer: LoudnessNormalizer(store),
      );
      addTearDown(service.dispose);
      await service.setQueue([one], autoplay: true);
      expect(engine.replayGains.last, -4);
      expect(service.currentGainDb, -4);

      await service.setFlowSettings(
        const PlaybackFlowSettings(
          normalization: LoudnessNormalizationMode.off,
        ),
      );
      expect(engine.replayGains.last, isNull);
    });
  });

  group('cast', () {
    test('only public stream URLs without auth headers can be cast', () {
      final track = _track('c');
      ResonancePlaybackState state(ResolvedAudioSource source) =>
          ResonancePlaybackState(
            queue: [track],
            currentIndex: 0,
            activeAudioSource: source,
          );
      expect(castableMedia(const ResonancePlaybackState()).media, isNull);
      final ok = castableMedia(state(_source(codec: 'mp3')));
      expect(ok.media?.contentType, 'audio/mpeg');
      expect(ok.media?.title, track.title);
      expect(
        castableMedia(
          state(_source().copyWith(headers: {'Authorization': 'x'})),
        ).media,
        isNull,
      );
      expect(
        castableMedia(
          state(_source().copyWith(streamUrl: Uri.file('C:/music/a.mp3'))),
        ).reason,
        contains('файла'),
      );
    });
  });

  group('cast tickets', () {
    test('relay streams are swapped for a short-lived cast ticket', () async {
      final calls = <Map<String, Object?>>[];
      Future<Map<String, dynamic>> post(Map<String, Object?> body) async {
        calls.add(body);
        return {
          'streamUrl':
              'https://music.example/api/v1/playback/soundcloud-relay/cast',
        };
      }

      final direct = Uri.parse('https://cdn.example/a.mp3');
      expect(await issueCastUrl(direct, post), direct);
      expect(calls, isEmpty);
      final relay = Uri.parse(
        'https://music.example/api/v1/playback/soundcloud-relay/long',
      );
      expect((await issueCastUrl(relay, post)).path, endsWith('/cast'));
      expect(calls.single['streamUrl'], relay.toString());
    });
  });

  group('recognition', () {
    test('matches the recognized track in catalog results', () {
      const recognized = RecognizedTrack(
        title: 'Warriors',
        artist: 'Imagine Dragons',
      );
      final wrong = _track('w', title: 'Warriors', artist: 'Someone Else');
      final remix = _track(
        'r',
        title: 'Warriors (Remix)',
        artist: 'Imagine Dragons',
      );
      final exact = _track('e', title: 'Warriors', artist: 'Imagine Dragons');
      expect(bestCatalogMatch(recognized, [wrong, remix, exact]), exact);
      expect(bestCatalogMatch(recognized, [wrong]), isNull);
      expect(catalogMatch(recognized, [exact])?.exact, isTrue);
      expect(catalogMatch(recognized, [remix])?.exact, isFalse);
      expect(
        catalogMatch(const RecognizedTrack(title: '!!!', artist: '???'), [
          exact,
        ]),
        isNull,
      );
    });
  });
}

Matcher closeWith(double value, double delta) => closeTo(value, delta);

ResolvedAudioSource _source({
  String? codec,
  int? bitrate,
  int? sampleRate,
  int? bitDepth,
  double? loudness,
}) => ResolvedAudioSource(
  streamUrl: Uri.parse('https://cdn.example/stream'),
  protocol: StreamProtocol.progressive,
  codec: codec,
  bitrate: bitrate,
  sampleRate: sampleRate,
  bitDepth: bitDepth,
  loudnessLufs: loudness,
);

UnifiedTrack _track(
  String id, {
  String? album,
  String? title,
  String artist = 'Artist',
}) => UnifiedTrack(
  id: id,
  title: title ?? 'Track $id',
  normalizedTitle: (title ?? 'track $id').toLowerCase(),
  artist: artist,
  normalizedArtist: artist.toLowerCase(),
  album: album,
  sources: [
    TrackSource(
      provider: MusicProvider.soundcloud,
      externalId: id,
      externalUrl: Uri.parse('https://example.com/$id'),
    ),
  ],
);

final class _Resolver implements AudioSourceResolver {
  @override
  MusicProvider get provider => MusicProvider.soundcloud;

  @override
  Future<ResolvedAudioSource> resolve(
    TrackSource source, {
    AudioQuality quality = AudioQuality.high,
  }) async => ResolvedAudioSource(
    streamUrl: Uri.parse('https://stream.example/${source.externalId}'),
    protocol: StreamProtocol.progressive,
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  );
}

final class _MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition was not reached in time');
}
