import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:resonance/core/diagnostics/client_error_reporter.dart';
import 'package:resonance/core/playback/playback_service.dart';

final class AudioFocusCoordinator {
  AudioFocusCoordinator(this._playbackService);

  final PlaybackService _playbackService;
  final _subscriptions = <StreamSubscription<Object?>>[];
  AudioSession? _session;
  bool _resumeAfterInterruption = false;
  bool _routeReported = false;

  /// Возвращает сессии режим музыки и активирует её. Другие плагины (запись
  /// для распознавания) переводят общую сессию iOS в `playAndRecord`, и
  /// тогда трек «играет» беззвучно или в разговорный динамик.
  static Future<void> reassertPlayback() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await session.setActive(true);
  }

  Future<void> initialize() async {
    final session = await AudioSession.instance;
    _session = session;
    await session.configure(const AudioSessionConfiguration.music());
    _subscriptions.add(
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          _resumeAfterInterruption = _playbackService.state.playing;
          unawaited(_playbackService.pause());
        } else if (_resumeAfterInterruption) {
          _resumeAfterInterruption = false;
          unawaited(_playbackService.play());
        }
      }),
    );
    _subscriptions.add(
      session.becomingNoisyEventStream.listen((_) {
        _resumeAfterInterruption = false;
        unawaited(_playbackService.pause());
      }),
    );
    _subscriptions.add(
      _playbackService.states.map((state) => state.playing).distinct().listen((
        playing,
      ) {
        unawaited(_onPlaying(session, playing));
      }),
    );
    if (_playbackService.state.playing) {
      await session.setActive(true);
    }
  }

  Future<void> _onPlaying(AudioSession session, bool playing) async {
    try {
      if (playing && Platform.isIOS) {
        await reassertPlayback();
        unawaited(_reportRouteOnce());
      } else {
        await session.setActive(playing);
      }
    } on Object {
      // Сессию не удалось перенастроить: играем как есть.
    }
  }

  /// Один отчёт за запуск: категория сессии и куда идёт звук на iPhone.
  Future<void> _reportRouteOnce() async {
    if (_routeReported) return;
    _routeReported = true;
    await Future<void>.delayed(const Duration(seconds: 5));
    try {
      final av = AVAudioSession();
      final category = await av.category;
      final route = await av.currentRoute;
      final state = _playbackService.state;
      await ClientErrorReporter.instance.report(
        ClientReportKind.playback,
        'iOS audio route',
        context: {
          'category': category.name,
          'outputs': route.outputs.map((port) => port.portType.name).join(','),
          'playing': state.playing,
          'positionMs': state.position.inMilliseconds,
          'volume': state.volume,
        },
      );
    } on Object {
      // Диагностика не должна мешать воспроизведению.
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _session?.setActive(false);
  }
}
