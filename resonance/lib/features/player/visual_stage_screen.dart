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
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/lyrics/lyrics_follow.dart';
import 'package:resonance/features/player/clip_service.dart';
import 'package:resonance/features/player/stage_clip_video.dart';
import 'package:resonance/features/rooms/room_controller.dart';
import 'package:resonance/features/rooms/room_queue_panel.dart';
import 'package:resonance/shared/widgets/ambient.dart';
import 'package:resonance/shared/widgets/playback_position.dart';
import 'package:resonance/shared/widgets/provider_badges.dart';
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
  bool _queueOpen = true;
  Future<void>? _fullscreenEntry;
  final Map<String, Duration> _offsets = {};
  Timer? _offsetVote;
  Timer? _idleTimer;
  bool _idle = false;

  bool _fullscreenScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fullscreenScheduled ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    _fullscreenScheduled = true;
    // Окно разворачивается после анимации входа: ресайз посреди перехода
    // заставляет каждый кадр заново раскладывать сцену, и переход рвётся.
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _fullscreenEntry = _enterFullscreen();
      return;
    }
    final entered = Completer<void>();
    _fullscreenEntry = entered.future;
    void onStatus(AnimationStatus status) {
      if (status != AnimationStatus.completed &&
          status != AnimationStatus.dismissed) {
        return;
      }
      animation.removeStatusListener(onStatus);
      if (mounted && status == AnimationStatus.completed) {
        entered.complete(_enterFullscreen());
      } else {
        entered.complete();
      }
    }

    animation.addStatusListener(onStatus);
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

  /// Кинорежим: во время клипа управление уходит, движение его возвращает.
  void _wake() {
    _idleTimer?.cancel();
    if (_idle) setState(() => _idle = false);
    _idleTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_idle) setState(() => _idle = true);
    });
  }

  void _nudgeOffset(UnifiedTrack track, StageClip clip, Duration delta) {
    final next = delta == Duration.zero
        ? Duration.zero
        : (_offsets[clip.key] ?? clip.offset) + delta;
    setState(() => _offsets[clip.key] = next);
    _wake();
    _offsetVote?.cancel();
    _offsetVote = Timer(const Duration(seconds: 2), () {
      unawaited(
        ref
            .read(clipServiceProvider)
            .voteOffset(track, clip, next)
            .catchError((_) {}),
      );
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _offsetVote?.cancel();
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      unawaited(_leaveFullscreen());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackFrameProvider);
    final track = state.currentTrack ?? demoTrack;
    if (_trackId != track.id) {
      _trackId = track.id;
      _selectedUrl = null;
      _failedUrls.clear();
      _offsets.clear();
    }
    final nativeVideo =
        (ref.watch(playbackVideoAvailableProvider).valueOrNull ?? false) &&
        _selectedUrl == null;
    final clips = ref.watch(stageClipsProvider(track));
    final available = (clips.valueOrNull ?? <StageClip>[])
        .where(
          (clip) =>
              clip.playable &&
              (clip.url != null || clip.embedded) &&
              !_failedUrls.contains(clip.key),
        )
        .toList();
    final picked =
        available.where((clip) => clip.key == _selectedUrl).firstOrNull ??
        available.firstOrNull;
    final selected = picked?.withOffset(_offsets[picked.key] ?? picked.offset);
    final hasVideo = _backgroundEnabled && (nativeVideo || selected != null);
    final effectiveMode = _mode == VisualStageMode.video && !hasVideo
        ? VisualStageMode.lyrics
        : _mode;
    final inRoom = ref.watch(
      roomPresenceProvider.select((room) => room.inRoom),
    );
    final cinema =
        effectiveMode == VisualStageMode.video &&
        hasVideo &&
        !nativeVideo &&
        selected != null &&
        !selected.ambient;
    final cinemaIdle = cinema && _idle && state.playing;
    final hideChrome = _focusMode || cinemaIdle;
    if (cinema && _idleTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _wake();
      });
    }
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
        child: MouseRegion(
          onHover: (_) {
            if (cinema) _wake();
          },
          child: Listener(
            onPointerDown: (_) {
              if (cinema) _wake();
            },
            child: Scaffold(
              backgroundColor: const Color(0xFF050406),
              body: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: _StageBackground(
                      track: track,
                      video:
                          hasVideo &&
                              nativeVideo &&
                              effectiveMode == VisualStageMode.video
                          ? _StageVideo.bright
                          : _StageVideo.none,
                    ),
                  ),
                  if (hasVideo &&
                      !nativeVideo &&
                      selected != null &&
                      effectiveMode == VisualStageMode.video)
                    ref.watch(stageVideoBuilderProvider)(
                      selected,
                      state,
                      () => setState(() => _failedUrls.add(selected.key)),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x66060408),
                          Color(0x14060408),
                          Color(0xCC060408),
                        ],
                        stops: [0, .45, 1],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        _Collapsible(
                          visible: !hideChrome,
                          child: _StageHeader(
                            mode: effectiveMode,
                            hasVideo: hasVideo,
                            queueOpen: _queueOpen,
                            onModeChanged: (value) =>
                                setState(() => _mode = value),
                            onSources: () => _showSources(track),
                            onFocus: () => setState(() => _focusMode = true),
                            onQueue: () {
                              if (MediaQuery.sizeOf(context).width >= 1100) {
                                setState(() => _queueOpen = !_queueOpen);
                              } else {
                                unawaited(showRoomQueueSheet(context));
                              }
                            },
                          ),
                        ),
                        _Collapsible(
                          visible: !cinemaIdle,
                          child: _sourceStatus(
                            clips,
                            selected,
                            nativeVideo,
                            track,
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) =>
                                ResonanceAnimatedSwap(
                                  child: KeyedSubtree(
                                    key: ValueKey(
                                      '$effectiveMode-$_focusMode-'
                                      '${constraints.maxWidth >= 700}',
                                    ),
                                    child: _focusMode
                                        ? const SizedBox.expand()
                                        : effectiveMode == VisualStageMode.video
                                        ? _ClipDeck(
                                            track: track,
                                            clips: available,
                                            selected: selected,
                                            compact: hideChrome,
                                            onSelect: (clip) => setState(() {
                                              _selectedUrl = clip.key;
                                              _wake();
                                            }),
                                            onNudge: (delta) => _nudgeOffset(
                                              track,
                                              picked!,
                                              delta,
                                            ),
                                          )
                                        : constraints.maxWidth >= 700
                                        ? _DesktopStage(
                                            state: state,
                                            track: track,
                                            videoMode:
                                                effectiveMode ==
                                                VisualStageMode.video,
                                            showQueue:
                                                inRoom &&
                                                _queueOpen &&
                                                constraints.maxWidth >= 1100,
                                          )
                                        : _MobileStage(
                                            state: state,
                                            track: track,
                                          ),
                                  ),
                                ),
                          ),
                        ),
                        _Collapsible(
                          visible: !hideChrome,
                          child: _StageTransport(
                            state: state,
                            showProgress:
                                effectiveMode == VisualStageMode.video,
                          ),
                        ),
                        _Collapsible(
                          visible: _focusMode,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: RoundControl(
                              tooltip: 'Показать управление',
                              icon: Icons.unfold_more_rounded,
                              onPressed: () =>
                                  setState(() => _focusMode = false),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
    final hasExternal =
        clips.valueOrNull?.any((clip) => !clip.playable) ?? false;
    final label = !_backgroundEnabled
        ? 'Видео выключено'
        : nativeVideo
        ? 'Видео из текущего источника'
        : selected != null
        ? '${selected.ambient
              ? 'Атмосферный фон'
              : selected.preview
              ? 'Видео-превью'
              : 'Музыкальный клип'} · ${selected.source}'
        : clips.isLoading
        ? 'Ищем видео на сервере…'
        : clips.hasError
        ? 'Источники недоступны · Повторить'
        : _failedUrls.isNotEmpty
        ? 'Видео не загрузилось · Повторить'
        : hasExternal
        ? 'Клип найден во внешнем источнике · Открыть'
        : 'Для этого трека пока нет видео · Источники';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFB0A7BA),
          visualDensity: VisualDensity.compact,
          shape: const StadiumBorder(),
        ),
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
          size: 14,
        ),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFB0A7BA), fontSize: 11),
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
                                  !clip.playable
                                      ? Icons.open_in_new_rounded
                                      : clip.ambient
                                      ? Icons.blur_on_rounded
                                      : Icons.music_video_rounded,
                                ),
                                title: Text(clip.title),
                                subtitle: Text(
                                  '${clip.source} · ${!clip.playable
                                      ? 'Открыть источник'
                                      : clip.ambient
                                      ? 'Фон'
                                      : clip.preview
                                      ? 'Видео-превью'
                                      : 'Клип'}',
                                ),
                                trailing:
                                    clip.playable &&
                                        _failedUrls.contains(clip.key)
                                    ? const Icon(Icons.error_outline)
                                    : !clip.playable
                                    ? const Icon(Icons.open_in_new_rounded)
                                    : null,
                                onTap: () {
                                  if (!clip.playable) {
                                    unawaited(
                                      launchUrl(
                                        clip.sourceUrl,
                                        mode: LaunchMode.externalApplication,
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    _backgroundEnabled = true;
                                    _selectedUrl = clip.key;
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

/// Плавно убирает и возвращает полосы управления в режиме фокуса.
class _Collapsible extends StatelessWidget {
  const _Collapsible({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = ResonanceMotion.durationOf(
      context,
      ResonanceMotion.standard,
    );
    return AnimatedSize(
      duration: duration,
      curve: ResonanceMotion.curve,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: ResonanceMotion.curve,
        switchOutCurve: ResonanceMotion.exitCurve,
        child: visible
            ? KeyedSubtree(key: const ValueKey(true), child: child)
            : const SizedBox(
                key: ValueKey(false),
                width: double.infinity,
                height: 0,
              ),
      ),
    );
  }
}

/// Подпись клипа, быстрый выбор источника и подстройка синхронизации.
class _ClipDeck extends StatelessWidget {
  const _ClipDeck({
    required this.track,
    required this.clips,
    required this.selected,
    required this.compact,
    required this.onSelect,
    required this.onNudge,
  });
  final UnifiedTrack track;
  final List<StageClip> clips;
  final StageClip? selected;
  final bool compact;
  final ValueChanged<StageClip> onSelect;
  final ValueChanged<Duration> onNudge;

  static String _label(StageClip clip) {
    final source = clip.source.split(' · ').first;
    return clip.ambient
        ? 'Фон'
        : clip.preview
        ? 'Превью · $source'
        : 'Клип · ${clip.embedded ? 'YouTube' : source}';
  }

  @override
  Widget build(BuildContext context) {
    final current = selected;
    final syncable = current != null && !current.ambient && !current.preview;
    final duration = ResonanceMotion.durationOf(
      context,
      ResonanceMotion.standard,
    );
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedOpacity(
              opacity: compact ? .72 : 1,
              duration: duration,
              child: Row(
                children: [
                  TrackArtwork(
                    track: track,
                    size: compact ? 44 : 64,
                    borderRadius: compact ? 12 : 16,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: duration,
                          style: TextStyle(
                            fontSize: compact ? 18 : 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: const [
                              Shadow(color: Color(0x99000000), blurRadius: 16),
                            ],
                          ),
                          child: Text(
                            track.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFD1C1E1),
                            shadows: [
                              Shadow(color: Color(0x99000000), blurRadius: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _Collapsible(
              visible: !compact && (clips.length > 1 || syncable),
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (clips.length > 1)
                      for (final clip in clips.take(5))
                        _GlassChip(
                          icon: clip.ambient
                              ? Icons.blur_on_rounded
                              : clip.preview
                              ? Icons.slow_motion_video_rounded
                              : Icons.music_video_rounded,
                          label: _label(clip),
                          selected: clip.key == current?.key,
                          onTap: () => onSelect(clip),
                        ),
                    if (syncable) _SyncControl(clip: current, onNudge: onNudge),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? const Color(0x33FFFFFF) : const Color(0x1AFFFFFF),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? const Color(0x80FFFFFF) : const Color(0x26FFFFFF),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Клип редко совпадает с альбомной версией: ±0,5 с и сброс.
/// Исправление уходит на сервер, и следующий слушатель получает его сразу.
class _SyncControl extends StatelessWidget {
  const _SyncControl({required this.clip, required this.onNudge});
  final StageClip clip;
  final ValueChanged<Duration> onNudge;

  @override
  Widget build(BuildContext context) {
    final seconds = clip.offset.inMilliseconds / 1000;
    final value = seconds == 0
        ? 'Синхронно'
        : '${seconds > 0 ? '+' : '−'}${seconds.abs().toStringAsFixed(1)} с';
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: Color(0x1AFFFFFF),
        shape: StadiumBorder(side: BorderSide(color: Color(0x26FFFFFF))),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Клип раньше на 0,5 с',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            color: Colors.white,
            onPressed: () => onNudge(const Duration(milliseconds: -500)),
            icon: const Icon(Icons.fast_rewind_rounded),
          ),
          Tooltip(
            message: 'Сбросить синхронизацию',
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: clip.offset == Duration.zero
                  ? null
                  : () => onNudge(Duration.zero),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sync_rounded,
                      size: 14,
                      color: Color(0xFFD1C1E1),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Клип позже на 0,5 с',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            color: Colors.white,
            onPressed: () => onNudge(const Duration(milliseconds: 500)),
            icon: const Icon(Icons.fast_forward_rounded),
          ),
        ],
      ),
    );
  }
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
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: ResonanceMotion.durationOf(
              context,
              ResonanceMotion.gentle * 2,
            ),
            curve: Curves.easeOutCubic,
            builder: (context, opacity, child) =>
                Opacity(opacity: opacity, child: child),
            child: Video(
              controller: controller,
              controls: NoVideoControls,
              fit: BoxFit.cover,
              fill: const Color(0xFF050406),
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
    // Тёплый ambient по палитре обложки; размытая обложка — лишь фактура.
    return Stack(
      fit: StackFit.expand,
      children: [
        AmbientBackdrop(track: track, intensity: 1.15),
        if (artwork != null)
          Opacity(
            opacity: .22,
            child: ResonanceCrossfade(
              child: ImageFiltered(
                key: ValueKey(artwork),
                imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Transform.scale(
                  scale: 1.2,
                  child: Image.network(
                    highQualityArtworkUrl(artwork, targetSize: 400),
                    fit: BoxFit.cover,
                    // Маленькая декодированная копия: размытие всё равно
                    // съедает детали, а памяти и кадров нужно меньше.
                    cacheWidth: 200,
                    frameBuilder: (context, child, frame, sync) =>
                        AnimatedOpacity(
                          opacity: sync || frame != null ? 1 : 0,
                          duration: ResonanceMotion.gentle,
                          child: child,
                        ),
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StageHeader extends ConsumerWidget {
  const _StageHeader({
    required this.mode,
    required this.hasVideo,
    required this.queueOpen,
    required this.onModeChanged,
    required this.onSources,
    required this.onFocus,
    required this.onQueue,
  });

  final VisualStageMode mode;
  final bool hasVideo;
  final bool queueOpen;
  final ValueChanged<VisualStageMode> onModeChanged;
  final VoidCallback onSources;
  final VoidCallback onFocus;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 560;
    final room = ref.watch(roomPresenceProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 10 : 22, 12, compact ? 10 : 22, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Закрыть полноэкранный режим',
            onPressed: context.pop,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0x1AFFFFFF),
              side: const BorderSide(color: Color(0x1FFFFFFF)),
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          const SizedBox(width: 12),
          if (room.inRoom)
            Flexible(
              child: RoomChip(compact: compact, onTap: onQueue),
            )
          else if (width >= 800)
            const Text(
              'RESONANCE / STAGE',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD1C1E1),
              ),
            ),
          const Spacer(),
          if (room.inRoom)
            IconButton(
              tooltip: queueOpen ? 'Скрыть очередь зала' : 'Очередь зала',
              isSelected: queueOpen && width >= 1100,
              onPressed: onQueue,
              icon: Badge.count(
                count: room.queue.length,
                isLabelVisible: room.queue.isNotEmpty,
                backgroundColor: const Color(0xFFB499FF),
                child: const Icon(Icons.queue_music_rounded),
              ),
            ),
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
          const SizedBox(width: 4),
          SegmentedButton<VisualStageMode>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: const Color(0x14FFFFFF),
              selectedBackgroundColor: const Color(0x33B499FF),
              selectedForegroundColor: const Color(0xFFEAE2F1),
              side: const BorderSide(color: Color(0x24FFFFFF)),
            ),
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
    required this.showQueue,
  });

  final ResonancePlaybackState state;
  final UnifiedTrack track;
  final bool videoMode;
  final bool showQueue;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(56, 18, showQueue ? 28 : 56, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 8,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: _StageIdentity(
                state: state,
                track: track,
                compact: videoMode || MediaQuery.sizeOf(context).height < 600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 56),
        Expanded(flex: 12, child: _FullscreenLyrics(track: track)),
        AnimatedSize(
          duration: ResonanceMotion.standard,
          curve: ResonanceMotion.curve,
          child: showQueue
              ? const Padding(
                  padding: EdgeInsets.only(left: 28, bottom: 12),
                  child: SizedBox(width: 340, child: RoomQueuePanel()),
                )
              : const SizedBox(height: double.infinity),
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
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: _StageIdentity(state: state, track: track, compact: true),
        ),
        const SizedBox(height: 6),
        Expanded(child: _FullscreenLyrics(track: track)),
      ],
    ),
  );
}

class _StageIdentity extends ConsumerWidget {
  const _StageIdentity({
    required this.state,
    required this.track,
    required this.compact,
  });

  final ResonancePlaybackState state;
  final UnifiedTrack track;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewport = MediaQuery.sizeOf(context);
    final short = viewport.height < 600;
    // Обложка должна занимать заметную часть экрана: до 440px на десктопе,
    // ~62% ширины в портрете и до 40% высоты в сжатых (ландшафт) сценариях.
    final width = short
        ? min(viewport.height * .32, 260.0)
        : compact
        ? min(viewport.width * .62, 320.0)
        : min(viewport.width * .27, 420.0);
    final palette = watchTrackPalette(ref, track);
    final provider =
        state.activeTrackSource?.provider ??
        track.preferredProvider ??
        track.sources.firstOrNull?.provider;
    final duration = state.duration > Duration.zero
        ? state.duration
        : track.duration ?? Duration.zero;
    return SizedBox(
      width: max(width, 280),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: AnimatedContainer(
              duration: ResonanceMotion.durationOf(
                context,
                ResonanceMotion.gentle * 2,
              ),
              curve: ResonanceMotion.curve,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: palette.glow.withValues(alpha: .38),
                    blurRadius: 64,
                    offset: const Offset(0, 24),
                  ),
                ],
              ),
              child: ResonanceTrackSwap(
                child: TrackArtwork(
                  key: ValueKey('stage-art-${track.id}'),
                  track: track,
                  size: width,
                  borderRadius: 26,
                ),
              ),
            ),
          ),
          SizedBox(height: short ? 16 : 26),
          ResonanceAnimatedSwap(
            alignment: AlignmentDirectional.topStart,
            child: Column(
              key: ValueKey('stage-copy-${track.id}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: short ? 24 : (compact ? 26 : 32),
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: const Color(0xFFF0EBF5),
                  ),
                ),
                SizedBox(height: short ? 6 : 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFB2A9BB),
                          fontSize: short ? 13 : 15,
                        ),
                      ),
                    ),
                    if (provider != null) ...[
                      const SizedBox(width: 10),
                      ProviderBadge(provider: provider, compact: true),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: short ? 12 : 20),
          AmbientProgress(
            duration: duration,
            accent: palette.accent,
            onSeek: (value) => fireAndForget(
              () => ref
                  .read(playbackServiceProvider.future)
                  .then((service) => service.seek(value)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenLyrics extends ConsumerStatefulWidget {
  const _FullscreenLyrics({required this.track});

  final UnifiedTrack track;

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
    final Widget body = lyrics.when(
      loading: () => const Center(
        key: ValueKey('loading'),
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Color(0xFFB0A7BA),
          ),
        ),
      ),
      error: (_, _) => _StageMessage(
        key: const ValueKey('error'),
        icon: Icons.cloud_off_rounded,
        label: 'Текст сейчас недоступен',
        onRetry: () => ref.invalidate(lyricsProvider(widget.track)),
      ),
      data: (document) {
        if (document == null) {
          return const _StageMessage(
            key: ValueKey('empty'),
            icon: Icons.lyrics_outlined,
            label: 'Текст пока не найден',
          );
        }
        if (document.instrumental && document.lines.isEmpty) {
          return const _StageMessage(
            key: ValueKey('instrumental'),
            icon: Icons.graphic_eq_rounded,
            label: 'Инструментальная композиция',
          );
        }
        if (_keys.length != document.lines.length) {
          _keys = List.generate(document.lines.length, (_) => GlobalKey());
        }
        // Перестраиваемся только когда меняется строка, а не на каждый тик.
        final active = document.synced
            ? ref.watch(
                playbackPositionProvider.select(
                  (position) => activeLyricLine(document.lines, position),
                ),
              )
            : -1;
        _reveal(active);
        final narrow = MediaQuery.sizeOf(context).width < 600;
        final style = TextStyle(
          fontFamily: 'Manrope',
          fontSize: narrow ? 30 : 46,
          height: 1.14,
          fontWeight: FontWeight.w800,
          letterSpacing: narrow ? -1.1 : -1.8,
          shadows: const [Shadow(color: Color(0x80000000), blurRadius: 18)],
        );
        return ShaderMask(
          key: ValueKey('lyrics-${widget.track.id}'),
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0, .14, .82, 1],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            controller: _controller,
            padding: const EdgeInsets.symmetric(vertical: 120),
            itemCount: document.lines.length,
            itemBuilder: (context, index) {
              final line = document.lines[index];
              final selected = active == index || !document.synced;
              final distance = active < 0 ? 0 : (index - active).abs();
              return Semantics(
                button: line.start != null,
                selected: selected,
                child: InkWell(
                  key: _keys[index],
                  borderRadius: BorderRadius.circular(14),
                  onTap: line.start == null
                      ? null
                      : () => unawaited(
                          ref
                              .read(playbackServiceProvider.future)
                              .then((service) => service.seek(line.start!)),
                        ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: narrow ? 10 : 12,
                    ),
                    child: LyricLineText(
                      text: line.text,
                      style: style,
                      active: selected,
                      dimColor: Color.lerp(
                        const Color(0xB3B3AABC),
                        const Color(0x597B6D8A),
                        min(distance / 5, 1),
                      )!,
                      inactiveScale: document.synced ? .8 : 1,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    // Один список на экране: новый трек мягко проявляется, без двух
    // ListView с общим контроллером.
    return ResonanceEntrance(
      key: ValueKey('stage-lyrics-${widget.track.id}'),
      offset: const Offset(0, .02),
      child: body,
    );
  }

  void _reveal(int active) {
    if (active < 0 || active == _lastActive || active >= _keys.length) return;
    final first = _lastActive < 0;
    _lastActive = active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      followLyricLine(
        controller: _controller,
        line: _keys[active],
        index: active,
        count: _keys.length,
        alignment: .42,
        duration: first
            ? Duration.zero
            : ResonanceMotion.durationOf(context, ResonanceMotion.gentle * 2),
      );
    });
  }
}

class _StageMessage extends StatelessWidget {
  const _StageMessage({
    required this.icon,
    required this.label,
    this.onRetry,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: const Color(0xFFA297AE)),
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
  const _StageTransport({required this.state, required this.showProgress});
  final ResonancePlaybackState state;
  final bool showProgress;
  @override
  ConsumerState<_StageTransport> createState() => _StageTransportState();
}

class _StageTransportState extends ConsumerState<_StageTransport> {
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
    final track = state.currentTrack ?? demoTrack;
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 500 || size.width < 420;
    final control = compact ? 44.0 : 52.0;
    final gap = compact ? 12.0 : 20.0;
    final favorite =
        ref
            .watch(libraryControllerProvider)
            .valueOrNull
            ?.favoriteIds
            .contains(track.id) ??
        false;
    final accent = watchTrackPalette(ref, track).accent;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, compact ? 12 : 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showProgress)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AmbientProgress(
                  duration: state.duration > Duration.zero
                      ? state.duration
                      : track.duration ?? Duration.zero,
                  accent: accent,
                  onSeek: (value) =>
                      unawaited(_run((service) => service.seek(value))),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RoundControl(
                tooltip: favorite ? 'Убрать из избранного' : 'В избранное',
                icon: favorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                active: favorite,
                size: control,
                onPressed: () => unawaited(
                  ref
                      .read(libraryControllerProvider.notifier)
                      .toggleFavorite(track),
                ),
              ),
              SizedBox(width: gap),
              RoundControl(
                tooltip: 'Предыдущий трек',
                icon: Icons.skip_previous_rounded,
                size: control,
                onPressed: () =>
                    unawaited(_run((service) => service.previous())),
              ),
              SizedBox(width: gap),
              CreamPlayButton(
                playing: state.playing,
                buffering: state.buffering,
                size: compact ? 60 : 68,
                onPressed: () => unawaited(
                  _run(
                    (service) => state.currentTrack == null
                        ? service.playTrack(demoTrack)
                        : state.playing
                        ? service.pause()
                        : service.play(),
                  ),
                ),
              ),
              SizedBox(width: gap),
              RoundControl(
                tooltip: 'Следующий трек',
                icon: Icons.skip_next_rounded,
                size: control,
                onPressed: () => unawaited(_run((service) => service.next())),
              ),
              SizedBox(width: gap),
              RoundControl(
                tooltip: switch (state.repeatMode) {
                  PlaybackRepeatMode.off => 'Повтор выключен',
                  PlaybackRepeatMode.all => 'Повтор очереди',
                  PlaybackRepeatMode.one => 'Повтор трека',
                },
                icon: state.repeatMode == PlaybackRepeatMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                active: state.repeatMode != PlaybackRepeatMode.off,
                size: control,
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}
