import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/lyrics/lyrics_service.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/design/widgets.dart';
import 'package:resonance_alpha/state.dart';

/// Synced lyrics as a stage: the current line huge, neighbours whispering.
class LyricsView extends ConsumerWidget {
  const LyricsView({
    required this.track,
    required this.accent,
    required this.size,
    this.centered = false,
    super.key,
  });

  final UnifiedTrack track;
  final Color accent;
  final double size;

  /// Center the lines (the full-screen stage) instead of a left column.
  final bool centered;

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
        return SyncedLyrics(
          document: document,
          accent: accent,
          size: size,
          centered: centered,
        );
      },
    );
  }
}

class SyncedLyrics extends ConsumerWidget {
  const SyncedLyrics({
    required this.document,
    required this.accent,
    required this.size,
    this.centered = false,
    super.key,
  });

  final LyricsDocument document;
  final Color accent;
  final double size;
  final bool centered;

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
        child: Text(
          at(i),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: centered ? TextAlign.center : TextAlign.start,
        ),
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
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
              textAlign: centered ? TextAlign.center : TextAlign.start,
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
