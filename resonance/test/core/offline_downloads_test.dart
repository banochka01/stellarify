import 'dart:convert';
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

  OfflineDownloads build(
    _AudioAdapter adapter, {
    DateTime Function()? now,
    AudioQuality Function()? quality,
    Future<Map<String, dynamic>?> Function(UnifiedTrack)? lyrics,
    _Resolver? resolver,
  }) => OfflineDownloads(
    providers: ProviderRegistry(resolvers: [resolver ?? _Resolver()]),
    authorizeSource: (_) async {},
    dio: Dio()..httpClientAdapter = adapter,
    directory: () async => directory,
    now: now,
    quality: quality,
    fetchLyrics: lyrics,
  );

  test('auto cache evicts least recently used, never manual', () async {
    var clock = DateTime.utc(2026, 10, 1);
    final downloads = build(_AudioAdapter(), now: () => clock);
    await downloads.setAutoCacheLimitBytes(8); // два файла по 4 байта
    await downloads.download(_track(id: 'manual'));
    for (final id in ['a', 'b']) {
      clock = clock.add(const Duration(minutes: 1));
      expect(await downloads.cacheAutomatically(_track(id: id)), isTrue);
    }
    clock = clock.add(const Duration(minutes: 1));
    await downloads.localSource(_track(id: 'a')); // a свежее b
    clock = clock.add(const Duration(minutes: 1));
    await downloads.cacheAutomatically(_track(id: 'c'));

    expect(downloads.contains('manual'), isTrue);
    expect(downloads.contains('a'), isTrue);
    expect(downloads.contains('b'), isFalse);
    expect(downloads.contains('c'), isTrue);
    expect(downloads.entries.map((e) => e.track.id), ['manual']);
    final usage = await downloads.usage();
    expect(usage.downloadsBytes, 4);
    expect(usage.autoCacheBytes, 8);

    await downloads.setAutoCacheLimitBytes(0);
    expect(downloads.cachedEntries, isEmpty);
    expect(downloads.contains('manual'), isTrue);
    expect(await downloads.cacheAutomatically(_track(id: 'd')), isFalse);
  });

  test('manual download promotes cached track without refetching', () async {
    final adapter = _AudioAdapter();
    final downloads = build(adapter);
    await downloads.cacheAutomatically(_track());
    expect(downloads.isManual('track-1'), isFalse);
    await downloads.download(_track());
    expect(downloads.isManual('track-1'), isTrue);
    expect(adapter.calls, 1);
    await downloads.setAutoCacheLimitBytes(0);
    expect(downloads.contains('track-1'), isTrue);
  });

  test('eviction never deletes the file that is playing right now', () async {
    var clock = DateTime.utc(2026, 10, 1);
    final downloads = build(_AudioAdapter(), now: () => clock);
    await downloads.setAutoCacheLimitBytes(4);
    expect(await downloads.cacheAutomatically(_track(id: 'playing')), isTrue);
    final local = await downloads.localSource(_track(id: 'playing'));
    downloads.setActiveTrackId('playing');
    clock = clock.add(const Duration(minutes: 1));
    expect(await downloads.cacheAutomatically(_track(id: 'newer')), isTrue);
    await downloads.setAutoCacheLimitBytes(0);

    expect(downloads.contains('playing'), isTrue);
    expect(await File.fromUri(local!.streamUrl).exists(), isTrue);
    expect(downloads.contains('newer'), isFalse);

    downloads.setActiveTrackId(null);
    await downloads.setAutoCacheLimitBytes(0);
    expect(downloads.contains('playing'), isFalse);
  });

  test('playback marks the opened track as protected from eviction', () async {
    final downloads = build(_AudioAdapter());
    await downloads.cacheAutomatically(_track(id: 'one'));
    final playback = PlaybackService(
      engine: FakePlaybackEngine(),
      providers: ProviderRegistry(resolvers: [_Resolver()]),
      sourceSelectionPolicy: SourceSelectionPolicy(),
      offlineDownloads: downloads,
    );
    await playback.playTrack(_track(id: 'one'));
    await downloads.setAutoCacheLimitBytes(0);
    expect(downloads.contains('one'), isTrue);
    await playback.dispose();
    // После остановки плеера защита снимается; заодно дожидаемся записи
    // манифеста, чтобы tearDown не упёрся в занятый файл.
    await downloads.setAutoCacheLimitBytes(0);
    expect(downloads.contains('one'), isFalse);
  });

  test('preload keeps only a few recent files', () async {
    var clock = DateTime.utc(2026, 10, 1);
    final downloads = build(_AudioAdapter(), now: () => clock);
    for (var i = 0; i <= OfflineDownloads.maxPreloaded; i++) {
      clock = clock.add(const Duration(seconds: 1));
      expect(await downloads.preload(_track(id: 'p$i')), isTrue);
    }
    expect(downloads.cachedEntries.length, OfflineDownloads.maxPreloaded);
    expect(downloads.contains('p0'), isFalse);
  });

  test('playback preloads the next queue track', () async {
    final adapter = _AudioAdapter();
    final downloads = build(adapter);
    final engine = FakePlaybackEngine();
    final resolver = _Resolver();
    final playback = PlaybackService(
      engine: engine,
      providers: ProviderRegistry(resolvers: [resolver]),
      sourceSelectionPolicy: SourceSelectionPolicy(),
      offlineDownloads: downloads,
    )..setPreloadNext(true);
    await playback.setQueue([
      _track(id: 'one'),
      _track(id: 'two'),
    ], autoplay: true);
    for (var i = 0; i < 100 && !downloads.contains('two'); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(downloads.contains('two'), isTrue);
    await playback.next();
    expect(engine.openedSources.last.streamUrl.isScheme('file'), isTrue);
    await playback.dispose();
  });

  test('lyrics are stored with the download and survive restart', () async {
    final downloads = build(
      _AudioAdapter(),
      lyrics: (_) async => {'id': 7, 'lines': <Object>[]},
    );
    await downloads.download(_track());
    expect((await downloads.lyricsFor('track-1'))?['id'], 7);
    final reopened = build(_AudioAdapter());
    expect((await reopened.lyricsFor('track-1'))?['id'], 7);
    expect((await reopened.usage()).lyricsCount, 1);
    await reopened.clearLyrics();
    expect(await reopened.lyricsFor('track-1'), isNull);
    expect(reopened.contains('track-1'), isTrue);
  });

  test('download uses the network-dependent quality', () async {
    final resolver = _Resolver();
    final downloads = build(
      _AudioAdapter(),
      resolver: resolver,
      quality: () => AudioQuality.low,
    );
    await downloads.download(_track());
    expect(resolver.lastQuality, AudioQuality.low);
  });

  test('legacy 3.x manifest entries load as manual downloads', () async {
    final root = Directory('${directory.path}/offline_audio')..createSync();
    File('${root.path}/x.audio').writeAsBytesSync([1, 2]);
    File('${root.path}/downloads.json').writeAsStringSync(
      jsonEncode([
        {
          'track': _track().toJson(),
          'source': _track().sources.single.toJson(),
          'fileName': 'x.audio',
        },
      ]),
    );
    final downloads = build(_AudioAdapter());
    await downloads.initialize();
    expect(downloads.isManual('track-1'), isTrue);
    expect((await downloads.usage()).downloadsBytes, 2);
  });
}

UnifiedTrack _track({String id = 'track-1'}) => UnifiedTrack(
  id: id,
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
  AudioQuality? lastQuality;
  @override
  MusicProvider get provider => MusicProvider.soundcloud;
  @override
  Future<ResolvedAudioSource> resolve(
    TrackSource source, {
    AudioQuality quality = AudioQuality.high,
  }) async {
    lastQuality = quality;
    return ResolvedAudioSource(
      streamUrl: Uri.parse('https://audio.example/track.mp3'),
      protocol: protocol,
    );
  }
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
