import 'dart:async';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/playback_state.dart';

/// Состояние плеера без позиции. Движок присылает позицию десятки раз в
/// секунду; экраны, которым она не нужна, не должны перестраиваться целиком на
/// каждый тик — иначе анимации рвутся на тяжёлых фонах.
final playbackFrameProvider = Provider<ResonancePlaybackState>(
  (ref) => ref.watch(
    playbackStateProvider.select(
      (value) => (value.valueOrNull ?? const ResonancePlaybackState()).copyWith(
        position: Duration.zero,
      ),
    ),
  ),
);

/// Последняя позиция, которую сообщил движок.
final playbackPositionProvider = Provider<Duration>(
  (ref) => ref.watch(
    playbackStateProvider.select(
      (value) => value.valueOrNull?.position ?? Duration.zero,
    ),
  ),
);

typedef PlaybackPositionWidgetBuilder =
    Widget Function(BuildContext context, Duration position, Duration duration);

/// Позиция воспроизведения, которая идёт плавно, кадр за кадром.
///
/// Движок сообщает позицию рывками и с дрожанием по времени. Между отчётами
/// позиция экстраполируется по часам, а расхождение гасится подстройкой
/// скорости, а не прыжком назад. Перестраивается только [builder].
class SmoothPlaybackPosition extends ConsumerStatefulWidget {
  const SmoothPlaybackPosition({
    required this.builder,
    this.fallbackDuration,
    super.key,
  });

  final PlaybackPositionWidgetBuilder builder;

  /// Длительность, если движок её ещё не знает (метаданные трека).
  final Duration? fallbackDuration;

  @override
  ConsumerState<SmoothPlaybackPosition> createState() =>
      _SmoothPlaybackPositionState();
}

class _SmoothPlaybackPositionState extends ConsumerState<SmoothPlaybackPosition>
    with SingleTickerProviderStateMixin {
  static final _inTests = Platform.environment.containsKey('FLUTTER_TEST');

  /// Больше этого расхождения — это перемотка или смена трека: прыгаем сразу.
  static const _snapThresholdMs = 700;

  Ticker? _ticker;
  final _clock = Stopwatch()..start();
  late final ValueNotifier<Duration> _shown;

  int _anchorMs = 0;
  int _anchorAtUs = 0;
  double _rate = 1;
  bool _running = false;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _anchorMs = ref.read(playbackPositionProvider).inMilliseconds;
    _anchorAtUs = _clock.elapsedMicroseconds;
    _shown = ValueNotifier(Duration(milliseconds: _anchorMs));
  }

  int _extrapolatedMs() {
    if (!_running) return _anchorMs;
    final elapsedMs = (_clock.elapsedMicroseconds - _anchorAtUs) / 1000;
    final value = _anchorMs + elapsedMs * _rate;
    final limit = _duration.inMilliseconds;
    return (limit > 0 ? value.clamp(0, limit) : value).round();
  }

  void _report(Duration reported) {
    final now = _clock.elapsedMicroseconds;
    final current = _extrapolatedMs();
    final error = reported.inMilliseconds - current;
    if (!_running || error.abs() > _snapThresholdMs) {
      _anchorMs = reported.inMilliseconds;
      _rate = 1;
    } else {
      // Догоняем или притормаживаем примерно за секунду, без шага назад.
      _anchorMs = current;
      _rate = (1 + error / 1000).clamp(.5, 1.5);
    }
    _anchorAtUs = now;
    _publish();
  }

  void _setRunning(bool running) {
    if (_running == running) return;
    _anchorMs = _extrapolatedMs();
    _anchorAtUs = _clock.elapsedMicroseconds;
    _rate = 1;
    _running = running;
    if (running && !_inTests) {
      final ticker = _ticker ??= createTicker(_onTick);
      if (!ticker.isActive) unawaited(ticker.start());
    } else if (_ticker?.isActive ?? false) {
      _ticker!.stop();
    }
  }

  void _onTick(Duration _) => _publish();

  void _publish() {
    final next = Duration(milliseconds: _extrapolatedMs());
    if (next != _shown.value) _shown.value = next;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _shown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = ref.watch(playbackFrameProvider);
    _duration = frame.duration > Duration.zero
        ? frame.duration
        : widget.fallbackDuration ?? Duration.zero;
    _setRunning(
      frame.playing &&
          !frame.buffering &&
          !(MediaQuery.maybeOf(context)?.disableAnimations ?? false),
    );
    ref.listen<Duration>(playbackPositionProvider, (_, next) => _report(next));
    // Отдельный слой: покадровая перерисовка прогресса не тянет за собой
    // обложку, тени и фон экрана.
    return RepaintBoundary(
      child: ValueListenableBuilder<Duration>(
        valueListenable: _shown,
        builder: (context, position, _) =>
            widget.builder(context, position, _duration),
      ),
    );
  }
}
