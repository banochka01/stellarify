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
import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/lyrics/lyrics_service.dart';
import 'package:resonance/features/player/clip_service.dart';
import 'package:resonance/features/player/stage_clip_video.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String? _trackId;
  String? _selectedUrl;
  final Set<String> _failedUrls = {};
  bool _backgroundEnabled = true;
  bool _focusMode = false;
  Future<void>? _fullscreenEntry;

  @override
  void initState() {
    super.initState();
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _fullscreenEntry = _enterFullscreen();
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
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    await _fullscreenEntry;
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
    if (_trackId != track.id) {
      _trackId = track.id;
      _selectedUrl = null;
      _failedUrls.clear();
    }
    final nativeVideo =
        (ref.watch(playbackVideoAvailableProvider).valueOrNull ?? false) &&
        _selectedUrl == null;
    final clips = ref.watch(stageClipsProvider(track));
    final available = (clips.valueOrNull ?? <StageClip>[])
        .where((clip) => !_failedUrls.contains(clip.url.toString()))
        .toList();
    final selected =
        available
            .where((clip) => clip.url.toString() == _selectedUrl)
            .firstOrNull ??
        available.firstOrNull;
    final hasVideo = _backgroundEnabled && (nativeVideo || selected != null);
    final effectiveMode = _mode == VisualStageMode.video && !hasVideo
        ? VisualStageMode.lyrics
        : _mode;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_focusMode) {
            setState(() => _focusMode = false);
          } else {
            context.pop();
          }
        },
        const SingleActivator(LogicalKeyboardKey.space): () => unawaited(
          ref
              .read(playbackServiceProvider.future)
              .then(
                (service) => state.playing ? service.pause() : service.play(),
              ),
        ),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF050505),
          body: Stack(
            fit: StackFit.expand,
            children: [
              _StageBackground(
                track: track,
                video: hasVideo && nativeVideo
                    ? (effectiveMode == VisualStageMode.video
                          ? _StageVideo.bright
                          : _StageVideo.dimmed)
                    : _StageVideo.none,
              ),
              if (hasVideo && !nativeVideo && selected != null)
                ref.watch(stageVideoBuilderProvider)(
                  selected,
                  state,
                  () =>
                      setState(() => _failedUrls.add(selected.url.toString())),
                ),
              if (hasVideo &&
                  !nativeVideo &&
                  effectiveMode == VisualStageMode.lyrics &&
                  !_focusMode)
                const ColoredBox(color: Color(0x8007070C)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x9907070C),
                      Color(0x5507070C),
                      Color(0xF207070C),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    if (!_focusMode)
                      _StageHeader(
                        mode: effectiveMode,
                        hasVideo: hasVideo,
                        onModeChanged: (value) => setState(() => _mode = value),
                        onSources: () => _showSources(track),
                        onFocus: () => setState(() => _focusMode = true),
                      ),
                    _sourceStatus(clips, selected, nativeVideo, track),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => _focusMode
                            ? const SizedBox.expand()
                            : effectiveMode == VisualStageMode.video
                            ? _ClipIdentity(track: track)
                            : constraints.maxWidth >= 700
                            ? _DesktopStage(
                                state: state,
                                track: track,
                                videoMode:
                                    effectiveMode == VisualStageMode.video,
                              )
                            : _MobileStage(state: state, track: track),
                      ),
                    ),
                    if (!_focusMode) _StageTransport(state: state),
                    if (_focusMode)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: IconButton.filledTonal(
                          tooltip: 'Показать управление',
                          onPressed: () => setState(() => _focusMode = false),
                          icon: const Icon(Icons.unfold_more_rounded),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceStatus(
    AsyncValue<List<StageClip>> clips,
    StageClip? selected,
    bool nativeVideo,
    UnifiedTrack track,
  ) {
    final label = !_backgroundEnabled
        ? 'Видео выключено'
        : nativeVideo
        ? 'Видео из текущего источника'
        : selected != null
        ? '${selected.ambient ? 'Атмосферный фон' : 'Музыкальный клип'} · ${selected.source}'
        : clips.isLoading
        ? 'Ищем видео на сервере…'
        : clips.hasError
        ? 'Источники недоступны · Повторить'
        : _failedUrls.isNotEmpty
        ? 'Видео не загрузилось · Повторить'
        : 'Для этого трека пока нет видео · Источники';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextButton.icon(
        onPressed: () {
          if (clips.hasError || _failedUrls.isNotEmpty && selected == null) {
            setState(_failedUrls.clear);
            ref.invalidate(stageClipsProvider(track));
          } else if (selected != null && !nativeVideo && _backgroundEnabled) {
            unawaited(
              launchUrl(
                selected.sourceUrl,
                mode: LaunchMode.externalApplication,
              ),
            );
          } else {
            _showSources(track);
          }
        },
        icon: Icon(
          clips.isLoading ? Icons.hourglass_top_rounded : Icons.movie_outlined,
          size: 16,
        ),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFD3CED4), fontSize: 12),
        ),
      ),
    );
  }

  Future<void> _showSources(UnifiedTrack track) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final clips = ref.watch(stageClipsProvider(track));
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                Text(
                  'Видеоисточники',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Клип играет без звука. Музыка продолжает звучать из выбранного сервиса.',
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.auto_awesome_rounded),
                  title: const Text('Автоматически'),
                  subtitle: const Text('Клип трека, затем атмосферный фон'),
                  onTap: () {
                    setState(() {
                      _backgroundEnabled = true;
                      _selectedUrl = null;
                      _failedUrls.clear();
                    });
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Только обложка'),
                  onTap: () {
                    setState(() => _backgroundEnabled = false);
                    Navigator.pop(sheetContext);
                  },
                ),
                const Divider(),
                ...clips.when(
                  loading: () => [
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (_, _) => [
                    ListTile(
                      title: const Text('Не удалось загрузить источники'),
                      trailing: const Icon(Icons.refresh),
                      onTap: () => ref.invalidate(stageClipsProvider(track)),
                    ),
                  ],
                  data: (items) => items.isEmpty
                      ? [
                          const ListTile(
                            title: Text('Источники пока не найдены'),
                            subtitle: Text(
                              'Продолжайте слушать музыку. Видео появится, когда для трека будет доступен источник.',
                            ),
                          ),
                        ]
                      : items
                            .map(
                              (clip) => ListTile(
                                leading: Icon(
                                  clip.ambient
                                      ? Icons.blur_on_rounded
                                      : Icons.music_video_rounded,
                                ),
                                title: Text(clip.title),
                                subtitle: Text(
                                  '${clip.source} · ${clip.ambient ? 'Фон' : 'Клип'}',
                                ),
                                trailing:
                                    _failedUrls.contains(clip.url.toString())
                                    ? const Icon(Icons.error_outline)
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _backgroundEnabled = true;
                                    _selectedUrl = clip.url.toString();
                                    _failedUrls.remove(_selectedUrl);
                                  });
                                  Navigator.pop(sheetContext);
                                },
                              ),
                            )
                            .toList(),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ClipIdentity extends StatelessWidget {
  const _ClipIdentity({required this.track});
  final UnifiedTrack track;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomLeft,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          TrackArtwork(track: track, size: 64, borderRadius: 16),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFD3CED4)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

enum _StageVideo { none, dimmed, bright }

class _StageBackground extends ConsumerWidget {
  const _StageBackground({required this.track, required this.video});

  final UnifiedTrack track;
  final _StageVideo video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(playbackVideoControllerProvider);
    if (video != _StageVideo.none && controller != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: 1,
            duration: ResonanceMotion.standard,
            child: Video(
              controller: controller,
              controls: NoVideoControls,
              fit: BoxFit.cover,
              fill: const Color(0xFF050505),
            ),
          ),
          // Слои поверх клипа: затемнение, чтобы обложка, текст и кнопки
          // оставались читаемыми (в режиме клипа — минимальное).
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color.fromRGBO(
                0,
                0,
                0,
                video == _StageVideo.dimmed ? 0.62 : 0.28,
              ),
            ),
          ),
        ],
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
                errorBuilder: (_, _, _) => _ambientGradient(track),
              ),
            ),
          )
        else
          _ambientGradient(track),
        const DecoratedBox(decoration: BoxDecoration(color: Color(0x99000000))),
      ],
    );
  }

  Widget _ambientGradient(UnifiedTrack track) {
    final colors = ArtworkFallback.gradientFor(track);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.first.withValues(alpha: 0.55), colors.last],
        ),
      ),
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({
    required this.mode,
    required this.hasVideo,
    required this.onModeChanged,
    required this.onSources,
    required this.onFocus,
  });

  final VisualStageMode mode;
  final bool hasVideo;
  final ValueChanged<VisualStageMode> onModeChanged;
  final VoidCallback onSources;
  final VoidCallback onFocus;

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
          if (MediaQuery.sizeOf(context).width >= 800) ...[
            const SizedBox(width: 16),
            const Text(
              'RESONANCE / STAGE',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD3CED4),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            tooltip: 'Видеоисточники',
            onPressed: onSources,
            icon: const Icon(Icons.video_library_outlined),
          ),
          IconButton(
            tooltip: 'Скрыть управление',
            onPressed: onFocus,
            icon: const Icon(Icons.center_focus_strong_rounded),
          ),
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
                label: compact ? null : const Text('Текст'),
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
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
        FittedBox(
          fit: BoxFit.scaleDown,
          child: _StageIdentity(track: track, compact: true),
        ),
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
    // Обложка должна занимать заметную часть экрана: до 440px на десктопе,
    // ~60% ширины в портрете и до 40% высоты в сжатых (ландшафт) сценариях.
    final width = short
        ? min(viewport.height * .32, 260.0)
        : compact
        ? min(viewport.width * .58, 300.0)
        : min(viewport.width * .3, 440.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Hero(
          tag: 'stage-art-${track.id}',
          child: TrackArtwork(track: track, size: width, borderRadius: 24),
        ),
        SizedBox(height: short ? 14 : 22),
        Text(
          track.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: short ? 24 : (compact ? 26 : 34),
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
            color: const Color(0xFFF7F2E9),
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
                            const Color(0xFFB9B3AD),
                            const Color(0xFF817B76),
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

class _StageTransport extends ConsumerStatefulWidget {
  const _StageTransport({required this.state});
  final ResonancePlaybackState state;
  @override
  ConsumerState<_StageTransport> createState() => _StageTransportState();
}

class _StageTransportState extends ConsumerState<_StageTransport> {
  double? _dragPosition;
  String _time(int ms) =>
      '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}';

  @override
  void didUpdateWidget(covariant _StageTransport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.currentTrack?.id != widget.state.currentTrack?.id) {
      _dragPosition = null;
    }
  }

  Future<void> _run(Future<void> Function(PlaybackService) action) async {
    try {
      await action(await ref.read(playbackServiceProvider.future));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось выполнить действие. Попробуйте ещё раз.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final duration = max(
      1,
      (state.duration > Duration.zero
              ? state.duration
              : state.currentTrack?.duration ?? Duration.zero)
          .inMilliseconds,
    );
    final position = (_dragPosition ?? state.position.inMilliseconds.toDouble())
        .clamp(0.0, duration.toDouble());
    final compact = MediaQuery.sizeOf(context).height < 500;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Container(
          margin: EdgeInsets.fromLTRB(16, 8, 16, compact ? 8 : 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xB31A191F),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x26FFFFFF)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    _time(position.round()),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Expanded(
                    child: Slider(
                      value: position,
                      max: duration.toDouble(),
                      semanticFormatterCallback: (value) =>
                          _time(value.round()),
                      onChangeStart: (value) =>
                          setState(() => _dragPosition = value),
                      onChanged: duration <= 1
                          ? null
                          : (value) => setState(() => _dragPosition = value),
                      onChangeEnd: (value) {
                        setState(() => _dragPosition = null);
                        unawaited(
                          _run(
                            (service) => service.seek(
                              Duration(milliseconds: value.round()),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Text(
                    _time(duration),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Перемешать',
                    isSelected: state.shuffle,
                    onPressed: () => unawaited(
                      _run((service) => service.setShuffle(!state.shuffle)),
                    ),
                    icon: const Icon(Icons.shuffle_rounded),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Предыдущий трек',
                    iconSize: 32,
                    onPressed: () =>
                        unawaited(_run((service) => service.previous())),
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: state.playing ? 'Пауза' : 'Воспроизвести',
                    iconSize: compact ? 28 : 36,
                    padding: EdgeInsets.all(compact ? 8 : 16),
                    onPressed: () => unawaited(
                      _run(
                        (service) => state.currentTrack == null
                            ? service.playTrack(demoTrack)
                            : state.playing
                            ? service.pause()
                            : service.play(),
                      ),
                    ),
                    icon: state.buffering
                        ? const SizedBox.square(
                            dimension: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            state.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Следующий трек',
                    iconSize: 32,
                    onPressed: () =>
                        unawaited(_run((service) => service.next())),
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: switch (state.repeatMode) {
                      PlaybackRepeatMode.off => 'Повтор выключен',
                      PlaybackRepeatMode.all => 'Повтор очереди',
                      PlaybackRepeatMode.one => 'Повтор трека',
                    },
                    isSelected: state.repeatMode != PlaybackRepeatMode.off,
                    onPressed: () => unawaited(
                      _run(
                        (service) =>
                            service.setRepeatMode(switch (state.repeatMode) {
                              PlaybackRepeatMode.off => PlaybackRepeatMode.all,
                              PlaybackRepeatMode.all => PlaybackRepeatMode.one,
                              PlaybackRepeatMode.one => PlaybackRepeatMode.off,
                            }),
                      ),
                    ),
                    icon: Icon(
                      state.repeatMode == PlaybackRepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
