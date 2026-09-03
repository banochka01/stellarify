import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/demo_track.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/lyrics/lyrics_service.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';
import 'package:window_manager/window_manager.dart';

enum VisualStageMode { video, lyrics }

class VisualStageScreen extends ConsumerStatefulWidget {
  const VisualStageScreen({
    this.initialMode = VisualStageMode.lyrics,
    super.key,
  });

  final VisualStageMode initialMode;

  @override
  ConsumerState<VisualStageScreen> createState() => _VisualStageScreenState();
}

class _VisualStageScreenState extends ConsumerState<VisualStageScreen> {
  late VisualStageMode _mode = widget.initialMode;
  bool _desktopWasFullscreen = false;

  @override
  void initState() {
    super.initState();
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      unawaited(_enterFullscreen());
    }
  }

  Future<void> _enterFullscreen() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      _desktopWasFullscreen = await windowManager.isFullScreen();
      if (!_desktopWasFullscreen) await windowManager.setFullScreen(true);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> _leaveFullscreen() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      if (!_desktopWasFullscreen) await windowManager.setFullScreen(false);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      unawaited(_leaveFullscreen());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(playbackStateProvider).valueOrNull ??
        const ResonancePlaybackState();
    final track = state.currentTrack ?? demoTrack;
    final hasVideo =
        ref.watch(playbackVideoAvailableProvider).valueOrNull ?? false;
    final effectiveMode = _mode == VisualStageMode.video && !hasVideo
        ? VisualStageMode.lyrics
        : _mode;
    return PopScope(
      onPopInvokedWithResult: (_, _) => unawaited(_leaveFullscreen()),
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _StageBackground(
              track: track,
              showVideo: effectiveMode == VisualStageMode.video && hasVideo,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Color(0x22000000),
                    Color(0xD9000000),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _StageHeader(
                    mode: effectiveMode,
                    hasVideo: hasVideo,
                    onModeChanged: (value) => setState(() => _mode = value),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) =>
                          constraints.maxWidth >= 700
                          ? _DesktopStage(
                              state: state,
                              track: track,
                              videoMode: effectiveMode == VisualStageMode.video,
                            )
                          : _MobileStage(state: state, track: track),
                    ),
                  ),
                  _StageTransport(state: state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageBackground extends ConsumerWidget {
  const _StageBackground({required this.track, required this.showVideo});

  final UnifiedTrack track;
  final bool showVideo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(playbackVideoControllerProvider);
    if (showVideo && controller != null) {
      return AnimatedOpacity(
        opacity: 1,
        duration: ResonanceMotion.standard,
        child: Video(
          controller: controller,
          controls: NoVideoControls,
          fit: BoxFit.cover,
          fill: const Color(0xFF050505),
        ),
      );
    }
    final artwork = track.artworkUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (artwork != null)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 44, sigmaY: 44),
            child: Transform.scale(
              scale: 1.14,
              child: Image.network(
                artwork.toString(),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        const DecoratedBox(decoration: BoxDecoration(color: Color(0x99000000))),
      ],
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({
    required this.mode,
    required this.hasVideo,
    required this.onModeChanged,
  });

  final VisualStageMode mode;
  final bool hasVideo;
  final ValueChanged<VisualStageMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 10 : 18, 12, compact ? 10 : 18, 8),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'Закрыть полноэкранный режим',
            onPressed: context.pop,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          const Spacer(),
          SegmentedButton<VisualStageMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: VisualStageMode.video,
                enabled: hasVideo,
                icon: const Tooltip(
                  message: 'Клип',
                  child: Icon(Icons.videocam_rounded),
                ),
                label: compact ? null : Text(hasVideo ? 'Клип' : 'Нет клипа'),
              ),
              ButtonSegment(
                value: VisualStageMode.lyrics,
                icon: const Tooltip(
                  message: 'Lyrics',
                  child: Icon(Icons.lyrics_rounded),
                ),
                label: compact ? null : const Text('Lyrics'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) => onModeChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

class _DesktopStage extends StatelessWidget {
  const _DesktopStage({
    required this.state,
    required this.track,
    required this.videoMode,
  });

  final ResonancePlaybackState state;
  final UnifiedTrack track;
  final bool videoMode;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(48, 18, 48, 18),
    child: Row(
      children: [
        Expanded(
          flex: 8,
          child: Align(
            alignment: Alignment.center,
            child: _StageIdentity(
              track: track,
              compact: videoMode || MediaQuery.sizeOf(context).height < 600,
            ),
          ),
        ),
        const SizedBox(width: 54),
        Expanded(
          flex: 12,
          child: _FullscreenLyrics(track: track, position: state.position),
        ),
      ],
    ),
  );
}

class _MobileStage extends StatelessWidget {
  const _MobileStage({required this.state, required this.track});

  final ResonancePlaybackState state;
  final UnifiedTrack track;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
    child: Column(
      children: [
        _StageIdentity(track: track, compact: true),
        const SizedBox(height: 18),
        Expanded(
          child: _FullscreenLyrics(track: track, position: state.position),
        ),
      ],
    ),
  );
}

class _StageIdentity extends StatelessWidget {
  const _StageIdentity({required this.track, required this.compact});

  final UnifiedTrack track;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final short = viewport.height < 600;
    final width = min(
      viewport.width * .32,
      short ? viewport.height * .15 : (compact ? 220.0 : 440.0),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Hero(
          tag: 'stage-art-${track.id}',
          child: TrackArtwork(track: track, size: width, borderRadius: 24),
        ),
        SizedBox(height: short ? 12 : 22),
        Text(
          track.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: short ? 20 : (compact ? 24 : 34),
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
        ),
        SizedBox(height: short ? 5 : 8),
        Text(
          track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFFB9B3AB),
            fontSize: short ? 13 : 16,
          ),
        ),
      ],
    );
  }
}

class _FullscreenLyrics extends ConsumerStatefulWidget {
  const _FullscreenLyrics({required this.track, required this.position});

  final UnifiedTrack track;
  final Duration position;

  @override
  ConsumerState<_FullscreenLyrics> createState() => _FullscreenLyricsState();
}

class _FullscreenLyricsState extends ConsumerState<_FullscreenLyrics> {
  final _controller = ScrollController();
  List<GlobalKey> _keys = const [];
  int _lastActive = -2;

  @override
  void didUpdateWidget(covariant _FullscreenLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) {
      _keys = const [];
      _lastActive = -2;
      if (_controller.hasClients) _controller.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = ref.watch(lyricsProvider(widget.track));
    return lyrics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _StageMessage(
        icon: Icons.cloud_off_rounded,
        label: 'Текст сейчас недоступен',
        onRetry: () => ref.invalidate(lyricsProvider(widget.track)),
      ),
      data: (document) {
        if (document == null) {
          return const _StageMessage(
            icon: Icons.lyrics_outlined,
            label: 'Текст пока не найден',
          );
        }
        if (document.instrumental && document.lines.isEmpty) {
          return const _StageMessage(
            icon: Icons.graphic_eq_rounded,
            label: 'Инструментальная композиция',
          );
        }
        if (_keys.length != document.lines.length) {
          _keys = List.generate(document.lines.length, (_) => GlobalKey());
        }
        final active = document.synced
            ? _activeLine(document.lines, widget.position)
            : -1;
        _reveal(active);
        return ListView.builder(
          controller: _controller,
          padding: const EdgeInsets.symmetric(vertical: 90),
          itemCount: document.lines.length,
          itemBuilder: (context, index) {
            final selected = active == index || !document.synced;
            final distance = active < 0 ? 0 : (index - active).abs();
            final narrow = MediaQuery.sizeOf(context).width < 600;
            return Semantics(
              button: document.lines[index].start != null,
              selected: selected,
              child: InkWell(
                key: _keys[index],
                borderRadius: BorderRadius.circular(14),
                onTap: document.lines[index].start == null
                    ? null
                    : () => unawaited(
                        ref
                            .read(playbackServiceProvider.future)
                            .then(
                              (service) =>
                                  service.seek(document.lines[index].start!),
                            ),
                      ),
                child: AnimatedDefaultTextStyle(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : ResonanceMotion.standard,
                  curve: ResonanceMotion.curve,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: selected
                        ? const Color(0xFFF7F2E9)
                        : Color.lerp(
                            const Color(0xFF77716A),
                            const Color(0xFF35312E),
                            min(distance / 5, 1),
                          ),
                    fontSize: selected && document.synced
                        ? (narrow ? 30 : 48)
                        : (narrow ? 23 : 34),
                    height: 1.12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: selected ? -1.8 : -1.2,
                    shadows: selected
                        ? const [
                            Shadow(color: Color(0x99000000), blurRadius: 18),
                          ]
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                    child: Text(document.lines[index].text),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  int _activeLine(List<LyricLine> lines, Duration position) {
    var result = -1;
    for (var index = 0; index < lines.length; index++) {
      final start = lines[index].start;
      if (start == null || start > position) break;
      result = index;
    }
    return result;
  }

  void _reveal(int active) {
    if (active < 0 || active == _lastActive || active >= _keys.length) return;
    _lastActive = active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _keys[active].currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: .45,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : ResonanceMotion.gentle,
        curve: ResonanceMotion.curve,
      );
    });
  }
}

class _StageMessage extends StatelessWidget {
  const _StageMessage({required this.icon, required this.label, this.onRetry});

  final IconData icon;
  final String label;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: const Color(0xFFAAA39B)),
        const SizedBox(height: 16),
        Text(
          label,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ],
    ),
  );
}

class _StageTransport extends ConsumerWidget {
  const _StageTransport({required this.state});

  final ResonancePlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = state.duration.inMilliseconds > 0
        ? state.duration.inMilliseconds
        : 1;
    final position = state.position.inMilliseconds.clamp(0, duration);
    Future<void> run(Future<void> Function(dynamic service) action) async {
      await action(await ref.read(playbackServiceProvider.future));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 8, 34, 24),
      child: Column(
        children: [
          Slider(
            value: position.toDouble(),
            max: duration.toDouble(),
            onChanged: (value) => unawaited(
              run(
                (service) =>
                    service.seek(Duration(milliseconds: value.round())),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Предыдущий трек',
                iconSize: 34,
                onPressed: () =>
                    unawaited(run((service) => service.previous())),
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              const SizedBox(width: 14),
              IconButton.filled(
                tooltip: state.playing ? 'Пауза' : 'Воспроизвести',
                iconSize: 38,
                padding: const EdgeInsets.all(15),
                onPressed: () => unawaited(
                  run(
                    (service) =>
                        state.playing ? service.pause() : service.play(),
                  ),
                ),
                icon: AnimatedSwitcher(
                  duration: ResonanceMotion.quick,
                  child: Icon(
                    state.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    key: ValueKey(state.playing),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              IconButton(
                tooltip: 'Следующий трек',
                iconSize: 34,
                onPressed: () => unawaited(run((service) => service.next())),
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
