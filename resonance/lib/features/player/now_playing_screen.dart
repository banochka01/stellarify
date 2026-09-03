import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/demo_track.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/lyrics/lyrics_service.dart';
import 'package:resonance/shared/widgets/provider_badges.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';
import 'package:url_launcher/url_launcher.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(playbackStateProvider).valueOrNull ??
        const ResonancePlaybackState();
    final track = state.currentTrack ?? demoTrack;
    final next = _nextTrack(state);
    final hasVideo =
        ref.watch(playbackVideoAvailableProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _Header(current: track, next: next, hasVideo: hasVideo),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  if (compact) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
                      child: Column(
                        children: [
                          ResonanceTrackSwap(
                            child: TrackArtwork(
                              key: ValueKey(track.id),
                              track: track,
                              size: min(constraints.maxWidth - 44, 430),
                              borderRadius: 2,
                              fallbackAsset:
                                  'assets/images/resonance_fallback_cover.png',
                            ),
                          ),
                          const SizedBox(height: 30),
                          _Details(state: state, track: track, desktop: false),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(54, 34, 64, 42),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 9,
                          child: LayoutBuilder(
                            builder: (context, artworkConstraints) {
                              final size = min(
                                artworkConstraints.maxWidth,
                                artworkConstraints.maxHeight,
                              );
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: ResonanceTrackSwap(
                                  child: TrackArtwork(
                                    key: ValueKey(track.id),
                                    track: track,
                                    size: size,
                                    borderRadius: 2,
                                    fallbackAsset:
                                        'assets/images/resonance_fallback_cover.png',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 66),
                        Expanded(
                          flex: 11,
                          child: SingleChildScrollView(
                            child: _Details(
                              state: state,
                              track: track,
                              desktop: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  UnifiedTrack? _nextTrack(ResonancePlaybackState state) {
    if (state.queue.isEmpty || state.currentIndex < 0) return null;
    final index = state.currentIndex + 1;
    if (index < state.queue.length) return state.queue[index];
    return state.repeatMode == PlaybackRepeatMode.all
        ? state.queue.first
        : null;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.current,
    required this.next,
    required this.hasVideo,
  });

  final UnifiedTrack current;
  final UnifiedTrack? next;
  final bool hasVideo;

  @override
  Widget build(BuildContext context) {
    final label = next == null
        ? 'Далее: —'
        : 'Далее: ${next!.title} — ${next!.artist}';
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF292724))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Назад',
            onPressed: context.pop,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
          const Text(
            'RESONANCE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFBBB7B0),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 24),
          IconButton(
            tooltip: hasVideo ? 'Открыть клип' : 'У трека нет клипа',
            onPressed: hasVideo
                ? () => context.push('/stage?mode=video')
                : null,
            icon: const Icon(Icons.videocam_rounded),
          ),
          IconButton(
            tooltip: 'Lyrics на весь экран',
            onPressed: () => context.push('/stage?mode=lyrics'),
            icon: const Icon(Icons.lyrics_rounded),
          ),
          const SizedBox(width: 8),
          ProviderBadge(
            provider:
                current.preferredProvider ?? current.sources.first.provider,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({
    required this.state,
    required this.track,
    required this.desktop,
  });

  final ResonancePlaybackState state;
  final UnifiedTrack track;
  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(playbackFlowControllerProvider);
    final fallbackDuration = track.duration ?? const Duration(seconds: 1);
    final duration = state.duration > Duration.zero
        ? state.duration
        : fallbackDuration;
    final maxMs = max(1, duration.inMilliseconds);
    final positionMs = state.position.inMilliseconds.clamp(0, maxMs);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResonanceTrackSwap(
          child: Align(
            key: ValueKey('title-${track.id}'),
            alignment: Alignment.centerLeft,
            child: Text(
              track.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFF3EFE7),
                fontSize: desktop ? 58 : 40,
                height: 0.96,
                letterSpacing: desktop ? -3.2 : -2.2,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF9B9690),
            fontSize: desktop ? 20 : 17,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: desktop ? 58 : 38),
        _Waveform(
          value: positionMs / maxMs,
          phase: state.position.inMilliseconds / 1000,
          alive: state.playing && flow.visualizer,
          activeColor: Theme.of(context).colorScheme.primary,
          onSeek: (value) => unawaited(
            ref
                .read(playbackServiceProvider.future)
                .then(
                  (service) => service.seek(
                    Duration(milliseconds: (maxMs * value).round()),
                  ),
                ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(_time(state.position)), Text(_time(duration))],
        ),
        SizedBox(height: desktop ? 34 : 26),
        _Controls(state: state, desktop: desktop),
        SizedBox(height: desktop ? 34 : 28),
        _LyricsPanel(track: track, position: state.position, desktop: desktop),
      ],
    );
  }

  String _time(Duration value) {
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${value.inMinutes}:$seconds';
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.state, required this.desktop});

  final ResonancePlaybackState state;
  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> run(FutureOr<void> Function(dynamic) action) async {
      final service = await ref.read(playbackServiceProvider.future);
      await action(service);
    }

    return Row(
      children: [
        _Control(
          tooltip: 'Перемешать',
          icon: Icons.shuffle_rounded,
          active: state.shuffle,
          onPressed: () =>
              unawaited(run((service) => service.setShuffle(!state.shuffle))),
        ),
        const Spacer(),
        _Control(
          tooltip: 'Предыдущий',
          icon: Icons.skip_previous_rounded,
          size: desktop ? 38 : 34,
          onPressed: () => unawaited(run((service) => service.previous())),
        ),
        SizedBox(width: desktop ? 22 : 12),
        IconButton.filled(
          tooltip: state.playing ? 'Пауза' : 'Воспроизвести',
          iconSize: desktop ? 38 : 34,
          padding: EdgeInsets.all(desktop ? 18 : 15),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: const Color(0xFF080706),
          ),
          onPressed: () => unawaited(
            run((service) {
              if (state.currentTrack == null) {
                return service.playTrack(demoTrack);
              }
              return state.playing ? service.pause() : service.play();
            }),
          ),
          icon: state.buffering
              ? const SizedBox.square(
                  dimension: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF080706),
                  ),
                )
              : AnimatedSwitcher(
                  duration: ResonanceMotion.quick,
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    state.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    key: ValueKey(state.playing),
                  ),
                ),
        ),
        SizedBox(width: desktop ? 22 : 12),
        _Control(
          tooltip: 'Следующий',
          icon: Icons.skip_next_rounded,
          size: desktop ? 38 : 34,
          onPressed: () => unawaited(run((service) => service.next())),
        ),
        const Spacer(),
        _Control(
          tooltip: 'Повтор',
          icon: state.repeatMode == PlaybackRepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          active: state.repeatMode != PlaybackRepeatMode.off,
          onPressed: () => unawaited(
            run(
              (service) => service.setRepeatMode(switch (state.repeatMode) {
                PlaybackRepeatMode.off => PlaybackRepeatMode.all,
                PlaybackRepeatMode.all => PlaybackRepeatMode.one,
                PlaybackRepeatMode.one => PlaybackRepeatMode.off,
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.size = 26,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: size,
      color: active
          ? Theme.of(context).colorScheme.primary
          : const Color(0xFFD4D0C9),
      icon: Icon(icon),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.value,
    required this.phase,
    required this.alive,
    required this.activeColor,
    required this.onSeek,
  });

  final double value;
  final double phase;
  final bool alive;
  final Color activeColor;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void seek(Offset point) =>
            onSeek((point.dx / constraints.maxWidth).clamp(0, 1));
        return Semantics(
          slider: true,
          label: 'Позиция воспроизведения',
          value: '${(value * 100).round()}%',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => seek(details.localPosition),
            onHorizontalDragUpdate: (details) => seek(details.localPosition),
            child: SizedBox(
              height: 72,
              width: double.infinity,
              child: CustomPaint(
                painter: _WaveformPainter(value, activeColor, phase, alive),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter(this.value, this.activeColor, this.phase, this.alive);

  final double value;
  final Color activeColor;
  final double phase;
  final bool alive;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 74;
    const gap = 3.0;
    final width = (size.width - gap * (bars - 1)) / bars;
    final played = Paint()..color = activeColor;
    final remaining = Paint()..color = const Color(0xFF3A3733);

    for (var index = 0; index < bars; index++) {
      final wave =
          0.25 +
          0.75 *
              (sin(index * 0.71).abs() * 0.58 +
                  sin(index * 0.17 + 1.4).abs() * 0.42);
      final pulse = alive ? .92 + sin(phase * 3.1 + index * .42) * .08 : 1.0;
      final height = max(7.0, wave * size.height * pulse);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          index * (width + gap),
          (size.height - height) / 2,
          width,
          height,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, index / (bars - 1) <= value ? played : remaining);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.phase != phase ||
      oldDelegate.alive != alive;
}

class _LyricsPanel extends ConsumerStatefulWidget {
  const _LyricsPanel({
    required this.track,
    required this.position,
    required this.desktop,
  });

  final UnifiedTrack track;
  final Duration position;
  final bool desktop;

  @override
  ConsumerState<_LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends ConsumerState<_LyricsPanel> {
  final _scrollController = ScrollController();
  List<GlobalKey> _lineKeys = const [];
  int _lastActive = -2;

  @override
  void didUpdateWidget(covariant _LyricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) {
      _lineKeys = const [];
      _lastActive = -2;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = ref.watch(lyricsProvider(widget.track));
    return Container(
      height: widget.desktop ? 270 : 320,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF11100F).withValues(alpha: .78),
        border: Border.all(color: const Color(0xFF302E2A)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: lyrics.when(
        loading: () => const _LyricsMessage(
          icon: Icons.lyrics_outlined,
          title: 'Ищем текст…',
          loading: true,
        ),
        error: (_, _) => _LyricsMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Текст сейчас недоступен',
          subtitle: 'Можно продолжать слушать — плеер работает независимо.',
          action: () => ref.invalidate(lyricsProvider(widget.track)),
        ),
        data: (document) {
          if (document == null) {
            return const _LyricsMessage(
              icon: Icons.lyrics_outlined,
              title: 'Текст пока не найден',
              subtitle: 'Он появится автоматически, когда будет доступен.',
            );
          }
          if (document.instrumental && document.lines.isEmpty) {
            return const _LyricsMessage(
              icon: Icons.graphic_eq_rounded,
              title: 'Инструментальная композиция',
              subtitle: 'Здесь музыка говорит без слов.',
            );
          }
          if (_lineKeys.length != document.lines.length) {
            _lineKeys = List.generate(
              document.lines.length,
              (_) => GlobalKey(),
            );
          }
          final active = document.synced
              ? _activeLine(document.lines, widget.position)
              : -1;
          _ensureActiveVisible(active);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
                child: Row(
                  children: [
                    const Icon(Icons.lyrics_rounded, size: 20),
                    const SizedBox(width: 9),
                    const Text(
                      'Текст',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    if (document.synced) const _LyricsChip(label: 'Синхронно'),
                    TextButton(
                      onPressed: () => launchUrl(document.sourceUrl),
                      child: Text(document.sourceName),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0, .12, .86, 1],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 48),
                    itemCount: document.lines.length,
                    itemBuilder: (context, index) {
                      final selected = index == active || !document.synced;
                      final reduced =
                          MediaQuery.maybeOf(context)?.disableAnimations ??
                          false;
                      return Padding(
                        key: _lineKeys[index],
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: AnimatedDefaultTextStyle(
                          duration: reduced
                              ? Duration.zero
                              : ResonanceMotion.standard,
                          curve: ResonanceMotion.curve,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: selected
                                ? const Color(0xFFF5F1E9)
                                : const Color(0xFF716D67),
                            fontSize: selected && document.synced ? 22 : 17,
                            height: 1.25,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          child: Text(document.lines[index].text),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _activeLine(List<LyricLine> lines, Duration position) {
    var active = -1;
    for (var index = 0; index < lines.length; index++) {
      final start = lines[index].start;
      if (start == null || start > position) break;
      active = index;
    }
    return active;
  }

  void _ensureActiveVisible(int active) {
    if (active < 0 || active == _lastActive || active >= _lineKeys.length) {
      return;
    }
    _lastActive = active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _lineKeys[active].currentContext;
      if (context == null) return;
      final reduced =
          MediaQuery.maybeOf(this.context)?.disableAnimations ?? false;
      Scrollable.ensureVisible(
        context,
        alignment: .42,
        duration: reduced ? Duration.zero : ResonanceMotion.gentle,
        curve: ResonanceMotion.curve,
      );
    });
  }
}

class _LyricsChip extends StatelessWidget {
  const _LyricsChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _LyricsMessage extends StatelessWidget {
  const _LyricsMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.loading = false,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool loading;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: const Color(0xFF8D8881)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            const SizedBox(height: 7),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8D8881)),
            ),
          ],
          if (loading) ...[
            const SizedBox(height: 18),
            const SizedBox(
              width: 120,
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: action,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ],
      ),
    ),
  );
}
