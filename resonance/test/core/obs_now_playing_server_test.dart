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
