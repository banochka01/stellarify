import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const _ProbeApp());
}

class _ProbeApp extends StatefulWidget {
  const _ProbeApp();

  @override
  State<_ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<_ProbeApp> {
  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://music.webcordes.ru',
        headers: const {'X-SoundCloud-Proxy': 'enabled'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    Player? player;
    try {
      final search = await dio.get<Map<String, dynamic>>(
        '/api/v1/catalog/search',
        queryParameters: {
          'provider': 'soundcloud',
          'q': 'Lil Peep',
          'limit': 1,
        },
      );
      final tracks = search.data?['tracks'] as List<dynamic>?;
      final track = Map<String, dynamic>.from(tracks!.first as Map);
      final resolved = await dio.post<Map<String, dynamic>>(
        '/api/v1/playback/resolve',
        data: {
          'provider': 'soundcloud',
          'externalId': track['id'],
          'quality': 'high',
        },
      );
      final source = Map<String, dynamic>.from(resolved.data?['source'] as Map);
      final streamUrl = source['streamUrl'] as String;
      debugPrint(
        'PROBE_RESOLVED protocol=${source['protocol']} host=${Uri.parse(streamUrl).host}',
      );

      player = Player(
        configuration: const PlayerConfiguration(
          title: 'Resonance SoundCloud probe',
          logLevel: MPVLogLevel.info,
        ),
      );
      final subscriptions = <StreamSubscription<Object?>>[
        player.stream.error.listen(
          (value) => debugPrint('PROBE_ERROR ${_redact(value)}'),
        ),
        player.stream.log.listen(
          (value) => debugPrint('PROBE_LOG ${_redact(value.toString())}'),
        ),
        player.stream.playing.listen(
          (value) => debugPrint('PROBE_PLAYING $value'),
        ),
        player.stream.duration.listen(
          (value) => debugPrint('PROBE_DURATION ${value.inMilliseconds}'),
        ),
      ];

      await player.open(Media(streamUrl), play: true);
      await Future<void>.delayed(const Duration(seconds: 18));
      final position = player.state.position.inMilliseconds;
      final duration = player.state.duration.inMilliseconds;
      debugPrint('PROBE_RESULT positionMs=$position durationMs=$duration');
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      await player.dispose();
      dio.close(force: true);
      exit(position > 1000 ? 0 : 2);
    } on Object catch (error, stackTrace) {
      debugPrint('PROBE_EXCEPTION ${_redact(error.toString())}');
      debugPrintStack(stackTrace: stackTrace);
      await player?.dispose();
      dio.close(force: true);
      exit(3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('SoundCloud playback probe'))),
    );
  }
}

String _redact(String value) =>
    value.replaceAll(RegExp(r'https://[^\s]+'), '<redacted-url>');
