import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/playback/demo_track.dart';
import 'package:resonance/core/streaming/obs_now_playing_server.dart';
import 'package:resonance/domain/entities/playback_state.dart';

void main() {
  test('serves a transparent OBS page and sanitized track state', () async {
    final server = ObsNowPlayingServer(preferredPort: 0);
    addTearDown(server.stop);
    server.update(
      ResonancePlaybackState(
        queue: [demoTrack],
        currentIndex: 0,
        playing: true,
        position: const Duration(seconds: 12),
        duration: const Duration(minutes: 2),
      ),
    );
    await server.start();

    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final pageResponse = await _get(client, server.uri!);
    final page = pageResponse.body;
    final state =
        jsonDecode(
              (await _get(client, server.uri!.resolve('/state.json'))).body,
            )
            as Map<String, dynamic>;

    expect(page, contains('Сейчас играет'));
    expect(page, contains('background:transparent'));
    expect(pageResponse.contentSecurityPolicy, contains("connect-src 'self'"));
    expect(state['active'], isTrue);
    expect(state['title'], demoTrack.title);
    expect(state['positionMs'], 12000);
    expect(state, isNot(contains('streamUrl')));
    expect(state, isNot(contains('headers')));
  });

  test('streams state over SSE and proxies the cover locally', () async {
    final cdn = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => cdn.close(force: true));
    cdn.listen((request) async {
      request.response.headers.contentType = ContentType('image', 'png');
      request.response.add(const [137, 80, 78, 71]);
      await request.response.close();
    });
    final server = ObsNowPlayingServer(preferredPort: 0);
    addTearDown(server.dispose);
    await server.start();
    final track = demoTrack.copyWith(
      artworkUrl: Uri.parse('http://127.0.0.1:${cdn.port}/cover.png'),
    );
    server.update(
      ResonancePlaybackState(
        queue: [track],
        currentIndex: 0,
        playing: true,
        duration: const Duration(minutes: 2),
      ),
    );
    server.updateLyrics(track.id, const [ObsLyricLine(1000, 'Первая строка')]);

    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final events = await (await client.getUrl(
      server.uri!.resolve('/events'),
    )).close();
    expect(events.headers.contentType?.mimeType, 'text/event-stream');
    final first = await events.transform(utf8.decoder).first;
    expect(first, contains('event: state'));
    expect(first, contains('Первая строка'));

    final state =
        jsonDecode(
              (await _get(client, server.uri!.resolve('/state.json'))).body,
            )
            as Map<String, dynamic>;
    expect(state['artworkUrl'], startsWith('/art'));
    final art = await (await client.getUrl(
      server.uri!.resolve(state['artworkUrl'] as String),
    )).close();
    expect(art.statusCode, HttpStatus.ok);
    expect(await art.fold<int>(0, (sum, chunk) => sum + chunk.length), 4);
  });

  test('falls back to the next port when the preferred one is busy', () async {
    final busy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => busy.close(force: true));
    final server = ObsNowPlayingServer(preferredPort: busy.port);
    addTearDown(server.dispose);
    await server.start();
    expect(server.port, isNot(busy.port));
  });
}

Future<({String body, String? contentSecurityPolicy})> _get(
  HttpClient client,
  Uri uri,
) async {
  final request = await client.getUrl(uri);
  final response = await request.close();
  expect(response.statusCode, HttpStatus.ok);
  return (
    body: await response.transform(utf8.decoder).join(),
    contentSecurityPolicy: response.headers.value('content-security-policy'),
  );
}
