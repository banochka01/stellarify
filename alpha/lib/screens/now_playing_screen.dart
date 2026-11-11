import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/lyrics/lyrics_service.dart';
import 'package:resonance/features/wave/wave_controller.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';
import 'package:resonance_alpha/design/accent.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/design/widgets.dart';
import 'package:resonance_alpha/screens/queue_sheet.dart';
import 'package:resonance_alpha/screens/track_row.dart';
import 'package:resonance_alpha/state.dart';

final _lyricsOpenProvider = StateProvider<bool>((ref) => false);

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: Motion.slow,
    reverseTransitionDuration: Motion.base,
    pageBuilder: (_, _, _) => const NowPlayingScreen(),
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutExpo,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    final accent = ref.watch(currentAccentProvider);
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900;
    if (track == null) {
      return Scaffold(
        backgroundColor: Pal.stage,
        body: Center(
          child: Pill(
            label: 'Ничего не играет — назад',
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
      );
    }

    final top = SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(wide ? 40 : 16, 8, wide ? 40 : 16, 0),
        child: Row(
          children: [
            Knob(
              icon: Icons.keyboard_arrow_down_rounded,
              size: 44,
              tooltip: 'Свернуть',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const Spacer(),
            Consumer(
              builder: (context, ref, _) {
                final wave = ref.watch(waveControllerProvider);
                return Text(
                  wave.active ? 'МОЙ ПОТОК' : 'СЕЙЧАС ИГРАЕТ',
                  style: Txt.mono(12, color: Pal.paper),
                );
              },
            ),
            const Spacer(),
            Knob(
              icon: Icons.queue_music_rounded,
              size: 44,
              tooltip: 'Очередь',
              onTap: () => showQueueSheet(context),
            ),
          ],
        ),
      ),
    );

    final cover = LayoutBuilder(
      builder: (context, box) {
        final side = box.biggest.shortestSide.clamp(160.0, 620.0);
        return Center(
          child: Hero(
            tag: 'cover',
            child: AnimatedSwitcher(
              duration: Motion.base,
              child: DecoratedBox(
                key: ValueKey(track.id),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(side * .07),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: .45),
                      blurRadius: 80,
                      spreadRadius: -10,
                      offset: const Offset(0, 30),
                    ),
                  ],
                ),
                child: TrackArtwork(
                  track: track,
                  size: side,
                  borderRadius: side * .07,
                ),
              ),
            ),
          ),
        );
      },
    );

    final info = _Info(track: track, accent: accent, wide: wide);

    final lyricsOpen = ref.watch(_lyricsOpenProvider);

    Widget stage;
    if (wide) {
      stage = Padding(
        padding: const EdgeInsets.fromLTRB(56, 24, 56, 40),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: lyricsOpen
                  ? _Lyrics(track: track, accent: accent, size: 44)
                  : cover,
            ),
            const SizedBox(width: 56),
            Expanded(flex: 6, child: info),
          ],
        ),
      );
    } else {
      stage = Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: Column(
          children: [
            Expanded(
              child: lyricsOpen
                  ? _Lyrics(track: track, accent: accent, size: 30)
                  : cover,
            ),
            const SizedBox(height: 22),
            info,
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Pal.stage,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                duration: Motion.slow,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(accent, Pal.stage, .45)!,
                      Color.lerp(accent, Pal.stage, .82)!,
                      Pal.stage,
                    ],
                    stops: const [0, .5, 1],
                  ),
                ),
              ),
              CustomScrollView(
                slivers: [
                  SliverFillViewport(
                    delegate: SliverChildListDelegate([
                      Column(
                        children: [
                          top,
                          Expanded(child: stage),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Pal.paper.withValues(alpha: .4),
                            ),
                          ),
                        ],
                      ),
                    ]),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 44 : 10,
                      24,
                      wide ? 44 : 10,
                      80,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _MoreByArtist(artist: track.artist),
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

class _Info extends ConsumerWidget {
  const _Info({required this.track, required this.accent, required this.wide});

  final UnifiedTrack track;
  final Color accent;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(favoriteIdsProvider).contains(track.id);
    final lyricsOpen = ref.watch(_lyricsOpenProvider);
    final titleSize = wide
        ? (track.title.length > 24 ? 48.0 : 72.0)
        : (track.title.length > 22 ? 28.0 : 38.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          maxLines: wide ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: Txt.display(titleSize),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                track.artist.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Txt.body(wide ? 17 : 14, color: Pal.muted, weight: 700),
              ),
            ),
            Press(
              tooltip: 'Текст',
              onTap: () =>
                  ref.read(_lyricsOpenProvider.notifier).state = !lyricsOpen,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: lyricsOpen ? Pal.paper : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Pal.paper.withValues(alpha: .4)),
                ),
                child: Text(
                  'ТЕКСТ',
                  style: Txt.mono(
                    11,
                    color: lyricsOpen ? Pal.stage : Pal.paper,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Press(
              tooltip: 'Ещё',
              onTap: () => showTrackMenu(context, ref, track),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.more_horiz_rounded, color: Pal.paper),
              ),
            ),
          ],
        ),
        SizedBox(height: wide ? 40 : 22),
        _Seek(accent: accent),
        SizedBox(height: wide ? 32 : 18),
        _Transport(accent: accent, liked: liked, track: track, wide: wide),
      ],
    );
  }
}

/// A thick bar you can grab anywhere; elapsed / left in mono.
class _Seek extends ConsumerStatefulWidget {
  const _Seek({required this.accent});

  final Color accent;

  @override
  ConsumerState<_Seek> createState() => _SeekState();
}

class _SeekState extends ConsumerState<_Seek> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackStateProvider).valueOrNull;
    final position = state?.position ?? Duration.zero;
    final duration = state?.duration ?? Duration.zero;
    final total = duration.inMilliseconds;
    final live = total <= 0 ? 0.0 : position.inMilliseconds / total;
    final value = (_drag ?? live).clamp(0.0, 1.0);

    void seekTo(double fraction) {
      if (total <= 0) return;
      run(context, () async {
        final service = await ref.read(playbackServiceProvider.future);
        await service.seek(Duration(milliseconds: (total * fraction).round()));
      });
    }

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, box) {
            double at(Offset local) =>
                (local.dx / box.maxWidth).clamp(0.0, 1.0);
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => seekTo(at(details.localPosition)),
                onHorizontalDragStart: (details) =>
                    setState(() => _drag = at(details.localPosition)),
                onHorizontalDragUpdate: (details) =>
                    setState(() => _drag = at(details.localPosition)),
                onHorizontalDragEnd: (_) {
                  final target = _drag;
                  setState(() => _drag = null);
                  if (target != null) seekTo(target);
                },
                child: SizedBox(
                  height: 28,
                  child: Center(
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      height: _drag == null ? 8 : 14,
                      decoration: BoxDecoration(
                        color: Pal.paper.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: value,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: widget.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              clock(Duration(milliseconds: (total * value).round())),
              style: Txt.mono(12),
            ),
            const Spacer(),
            if (state?.buffering ?? false)
              Text('ЗАГРУЗКА', style: Txt.mono(11, color: widget.accent)),
            const Spacer(),
            Text(
              '−${clock(duration - Duration(milliseconds: (total * value).round()))}',
              style: Txt.mono(12),
            ),
          ],
        ),
      ],
    );
  }
}

class _Transport extends ConsumerWidget {
  const _Transport({
    required this.accent,
    required this.liked,
    required this.track,
    required this.wide,
  });

  final Color accent;
  final bool liked;
  final UnifiedTrack track;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      playbackStateProvider.select(
        (value) => value.valueOrNull ?? const ResonancePlaybackState(),
      ),
    );
    final wave = ref.watch(waveControllerProvider);
    Future<void> service(
      Future<void> Function(PlaybackService s) action,
    ) async {
      final s = await ref.read(playbackServiceProvider.future);
      await action(s);
    }

    final small = wide ? 56.0 : 48.0;
    final big = wide ? 92.0 : 78.0;
    final repeatIcon = switch (state.repeatMode) {
      PlaybackRepeatMode.one => Icons.repeat_one_rounded,
      _ => Icons.repeat_rounded,
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (wave.active)
          Knob(
            icon: Icons.heart_broken_rounded,
            size: small,
            tooltip: 'Не то',
            onTap: () => run(
              context,
              () => ref
                  .read(waveControllerProvider.notifier)
                  .rateCurrent(liked: false),
            ),
          )
        else
          Knob(
            icon: Icons.shuffle_rounded,
            size: small,
            tooltip: 'Перемешать',
            color: state.shuffle ? accent : Pal.paper,
            onTap: () => run(
              context,
              () => service((s) => s.setShuffle(!state.shuffle)),
            ),
          ),
        Knob(
          icon: Icons.skip_previous_rounded,
          size: small,
          tooltip: 'Назад',
          onTap: () => run(context, () => service((s) => s.previous())),
        ),
        Knob(
          icon: state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: big,
          filled: true,
          color: Pal.paper,
          tooltip: state.playing ? 'Пауза' : 'Играть',
          onTap: () => run(context, () => togglePlay(ref)),
        ),
        Knob(
          icon: Icons.skip_next_rounded,
          size: small,
          tooltip: 'Дальше',
          onTap: () => run(context, () => service((s) => s.next())),
        ),
        if (wave.active)
          Knob(
            icon: liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            size: small,
            color: liked ? accent : Pal.paper,
            tooltip: 'Нравится',
            onTap: () => run(context, () => toggleFavorite(ref, track)),
          )
        else
          Knob(
            icon: repeatIcon,
            size: small,
            tooltip: 'Повтор',
            color: state.repeatMode == PlaybackRepeatMode.off
                ? Pal.paper
                : accent,
            onTap: () => run(
              context,
              () => service(
                (s) => s.setRepeatMode(
                  PlaybackRepeatMode.values[(state.repeatMode.index + 1) %
                      PlaybackRepeatMode.values.length],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Synced lyrics as a stage: the current line huge, neighbours whispering.
class _Lyrics extends ConsumerWidget {
  const _Lyrics({
    required this.track,
    required this.accent,
    required this.size,
  });

  final UnifiedTrack track;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyrics = ref.watch(lyricsProvider(track));
    return lyrics.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) =>
          Center(child: Text('Текст не загрузился', style: Txt.title(20))),
      data: (document) {
        if (document == null || document.lines.isEmpty) {
          return Center(
            child: Text(
              document?.instrumental == true ? 'Без слов' : 'Текста нет',
              style: Txt.display(size),
            ),
          );
        }
        if (!document.synced) {
          return ListView(
            children: [
              for (final line in document.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(line.text, style: Txt.title(size * .55)),
                ),
            ],
          );
        }
        return _SyncedLyrics(document: document, accent: accent, size: size);
      },
    );
  }
}

class _SyncedLyrics extends ConsumerWidget {
  const _SyncedLyrics({
    required this.document,
    required this.accent,
    required this.size,
  });

  final LyricsDocument document;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(
      playbackStateProvider.select(
        (value) => value.valueOrNull?.position ?? Duration.zero,
      ),
    );
    final lines = document.lines;
    var current = -1;
    for (var i = 0; i < lines.length; i++) {
      final start = lines[i].start;
      if (start != null && start <= position) current = i;
    }
    String at(int i) => i >= 0 && i < lines.length ? lines[i].text : '';

    Future<void> jump(int i) async {
      final start = i >= 0 && i < lines.length ? lines[i].start : null;
      if (start == null) return;
      final service = await ref.read(playbackServiceProvider.future);
      await service.seek(start);
    }

    Widget line(int i, double scale, double alpha) => Press(
      scale: .98,
      onTap: () => run(context, () => jump(i)),
      child: AnimatedDefaultTextStyle(
        duration: Motion.base,
        curve: Motion.curve,
        style: Txt.display(
          size * scale,
          color: Pal.paper.withValues(alpha: alpha),
        ),
        child: Text(at(i), maxLines: 3, overflow: TextOverflow.ellipsis),
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line(current - 1, .5, .3),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: Motion.base,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, .3),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(current),
            child: Text(
              current < 0 ? '♪' : at(current),
              style: Txt.display(size, color: accent),
            ),
          ),
        ),
        const SizedBox(height: 18),
        line(current + 1, .5, .55),
        const SizedBox(height: 10),
        line(current + 2, .4, .3),
      ],
    );
  }
}

class _MoreByArtist extends ConsumerWidget {
  const _MoreByArtist({required this.artist});

  final String artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(artistTracksProvider(artist));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SectionHead(index: '→', title: 'Ещё: $artist'),
        ),
        tracks.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (list) => Column(
            children: [
              for (final (i, track) in list.indexed)
                TrackRow(
                  track: track,
                  index: i,
                  onTap: () =>
                      run(context, () => playList(ref, list, index: i)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
