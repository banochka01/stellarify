import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/playback/offline_downloads.dart';
import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/providers/audio_source_resolver.dart';
import 'package:resonance/domain/services/source_selection_policy.dart';
import 'package:resonance/providers/common/provider_registry.dart';

import '../helpers/fake_playback_engine.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('resonance-offline-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('completed file survives restart and opens without network', () async {
    final adapter = _AudioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final resolver = _Resolver();
    final registry = ProviderRegistry(resolvers: [resolver]);
    final track = _track();
    final downloads = OfflineDownloads(
      providers: registry,
      authorizeSource: (_) async {},
      dio: dio,
      directory: () async => directory,
    );

    await downloads.download(track);
    expect(downloads.contains(track.id), isTrue);
    expect(adapter.calls, 1);

    final reopened = OfflineDownloads(
      providers: registry,
      authorizeSource: (_) => throw StateError('offline'),
      dio: dio,
      directory: () async => directory,
    );
    final local = await reopened.localSource(track);
    expect(local?.streamUrl.isScheme('file'), isTrue);
    expect(await File.fromUri(local!.streamUrl).readAsBytes(), [1, 2, 3, 4]);
    expect(adapter.calls, 1);

    final engine = FakePlaybackEngine();
    final playback = PlaybackService(
      engine: engine,
      providers: ProviderRegistry(),
      sourceSelectionPolicy: SourceSelectionPolicy(),
      offlineDownloads: reopened,
      authorizeSource: (_) => throw StateError('offline'),
    );
    await playback.playTrack(track);
    expect(engine.openedSources.single.streamUrl.isScheme('file'), isTrue);
    await playback.pause();
    await playback.play();
    expect(engine.isPlaying, isTrue);
    await playback.dispose();

    await reopened.remove(track.id);
    expect(await File.fromUri(local.streamUrl).exists(), isFalse);
    expect(reopened.contains(track.id), isFalse);
  });

  test('HLS is not saved as a misleading offline file', () async {
    final resolver = _Resolver(protocol: StreamProtocol.hls);
    final downloads = OfflineDownloads(
      providers: ProviderRegistry(resolvers: [resolver]),
      authorizeSource: (_) async {},
      directory: () async => directory,
    );
    await expectLater(downloads.download(_track()), throwsStateError);
    expect(downloads.entries, isEmpty);
  });
}

UnifiedTrack _track() => UnifiedTrack(
  id: 'track-1',
  title: 'Test track',
  normalizedTitle: 'test track',
  artist: 'Artist',
  normalizedArtist: 'artist',
  sources: [
    TrackSource(
      provider: MusicProvider.soundcloud,
      externalId: '123',
      externalUrl: Uri.parse('https://soundcloud.com/a/b'),
    ),
  ],
);

final class _Resolver implements AudioSourceResolver {
  _Resolver({this.protocol = StreamProtocol.progressive});
  final StreamProtocol protocol;
  @override
  MusicProvider get provider => MusicProvider.soundcloud;
  @override
  Future<ResolvedAudioSource> resolve(
    TrackSource source, {
    AudioQuality quality = AudioQuality.high,
  }) async => ResolvedAudioSource(
    streamUrl: Uri.parse('https://audio.example/track.mp3'),
    protocol: protocol,
  );
}

final class _AudioAdapter implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromBytes(
      [1, 2, 3, 4],
      200,
      headers: {
        Headers.contentTypeHeader: ['audio/mpeg'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
