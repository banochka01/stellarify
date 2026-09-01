import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/errors/app_exception.dart';
import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_session.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/providers/audio_source_resolver.dart';
import 'package:resonance/domain/repositories/playback_persistence.dart';
import 'package:resonance/domain/services/source_selection_policy.dart';
import 'package:resonance/providers/common/provider_registry.dart';

import '../helpers/fake_playback_engine.dart';

void main() {
  late FakePlaybackEngine engine;
  late _MemoryPlaybackPersistence persistence;

  setUp(() {
    engine = FakePlaybackEngine();
    persistence = _MemoryPlaybackPersistence();
  });

  test('controls queue, playback, seek, volume, next, and previous', () async {
    final resolver = _FakeResolver(MusicProvider.soundcloud);
    final service = _createService(engine, persistence, [resolver]);
    final first = _track('first', [MusicProvider.soundcloud]);
    final second = _track('second', [MusicProvider.soundcloud]);

    await service.setQueue([first, second], autoplay: true);
    expect(service.state.currentTrack, first);
    expect(engine.openedSources, hasLength(1));

    await service.seek(const Duration(seconds: 12));
    await service.setVolume(33);
    await service.next();
    expect(service.state.currentTrack, second);
    await service.previous();
    expect(service.state.currentTrack, first);
    await service.pause();

    expect(engine.currentPosition, Duration.zero);
    expect(engine.currentVolume, 33);
    expect(engine.isPlaying, isFalse);
    expect(persistence.session.queue, [first, second]);
    await service.dispose();
  });

  test('falls back when preferred provider cannot resolve', () async {
    final youtube = _FakeResolver(
      MusicProvider.youtube,
      error: const AudioResolutionException('region blocked'),
    );
    final yandex = _FakeResolver(MusicProvider.yandex);
    final service = _createService(engine, persistence, [youtube, yandex]);
    final track = _track('fallback', [
      MusicProvider.youtube,
      MusicProvider.yandex,
    ], preferred: MusicProvider.youtube);

    await service.playTrack(track);

    expect(youtube.calls, 1);
    expect(yandex.calls, 1);
    expect(service.state.activeTrackSource?.provider, MusicProvider.yandex);
    expect(service.state.errorMessage, isNull);
    await service.dispose();
  });

  test('re-resolves an already expired URL before opening', () async {
    final resolver = _FakeResolver(
      MusicProvider.soundcloud,
      firstExpired: true,
    );
    final service = _createService(engine, persistence, [resolver]);

    await service.playTrack(_track('expiring', [MusicProvider.soundcloud]));

    expect(resolver.calls, 2);
    expect(engine.openedSources, hasLength(1));
    expect(engine.openedSources.single.isExpired(), isFalse);
    await service.dispose();
  });

  test('supports repeat all and deterministic shuffle', () async {
    final resolver = _FakeResolver(MusicProvider.soundcloud);
    final service = _createService(engine, persistence, [
      resolver,
    ], random: Random(7));
    final tracks = [
      _track('one', [MusicProvider.soundcloud]),
      _track('two', [MusicProvider.soundcloud]),
      _track('three', [MusicProvider.soundcloud]),
    ];

    await service.setQueue(tracks, startIndex: 2);
    await service.setRepeatMode(PlaybackRepeatMode.all);
    await service.next();
    expect(service.state.currentIndex, 0);

    await service.setShuffle(true);
    final previousIndex = service.state.currentIndex;
    await service.next();
    expect(service.state.currentIndex, isNot(previousIndex));
    expect(engine.shuffle, isTrue);
    expect(engine.repeatMode, PlaybackRepeatMode.all);
    await service.dispose();
  });

  test('subscription guard blocks cached source reuse and resume', () async {
    var allowed = true;
    final resolver = _FakeResolver(MusicProvider.soundcloud);
    final service = PlaybackService(
      engine: engine,
      providers: ProviderRegistry(resolvers: [resolver]),
      sourceSelectionPolicy: SourceSelectionPolicy(),
      authorizeSource: (_) async { if (!allowed) throw StateError('subscription expired'); },
    );
    final track = _track('guarded', [MusicProvider.soundcloud]);
    await service.playTrack(track);
    await service.pause();
    allowed = false;
    await expectLater(service.play(), throwsStateError);
    await expectLater(service.playTrack(track), throwsA(isA<PlaybackFailedException>()));
    expect(engine.openedSources, hasLength(1));
    expect(engine.isPlaying, false);
    await service.dispose();
  });
}

PlaybackService _createService(
  FakePlaybackEngine engine,
  PlaybackPersistence persistence,
  List<AudioSourceResolver> resolvers, {
  Random? random,
}) {
  return PlaybackService(
    engine: engine,
    providers: ProviderRegistry(resolvers: resolvers),
    sourceSelectionPolicy: SourceSelectionPolicy(),
    persistence: persistence,
    random: random,
  );
}

final class _FakeResolver implements AudioSourceResolver {
  _FakeResolver(this.provider, {this.error, this.firstExpired = false});

  @override
  final MusicProvider provider;
  final Object? error;
  final bool firstExpired;
  var calls = 0;

  @override
  Future<ResolvedAudioSource> resolve(
    TrackSource source, {
    AudioQuality quality = AudioQuality.high,
  }) async {
    calls += 1;
    if (error case final error?) {
      throw error;
    }
    return ResolvedAudioSource(
      streamUrl: Uri.parse(
        'https://stream.example/${source.externalId}/$calls',
      ),
      protocol: StreamProtocol.progressive,
      expiresAt: firstExpired && calls == 1
          ? DateTime.now().toUtc().subtract(const Duration(seconds: 1))
          : DateTime.now().toUtc().add(const Duration(hours: 1)),
    );
  }
}

final class _MemoryPlaybackPersistence implements PlaybackPersistence {
  PlaybackSession session = const PlaybackSession();

  @override
  Future<PlaybackSession> load() async => session;

  @override
  Future<void> save(PlaybackSession session) async {
    this.session = session;
  }
}

UnifiedTrack _track(
  String id,
  List<MusicProvider> providers, {
  MusicProvider? preferred,
}) => UnifiedTrack(
  id: id,
  title: 'Track $id',
  normalizedTitle: 'track $id',
  artist: 'Artist',
  normalizedArtist: 'artist',
  preferredProvider: preferred,
  sources: [
    for (final provider in providers)
      TrackSource(
        provider: provider,
        externalId: '$id-${provider.name}',
        externalUrl: Uri.parse('https://example.com/$id/${provider.name}'),
      ),
  ],
);
