import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/wave/wave_controller.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';
import 'package:resonance_alpha/design/accent.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/design/widgets.dart';
import 'package:resonance_alpha/state.dart';

/// One line of a list: index in mono, cover, title and artist. The playing
/// row is flooded with the accent instead of getting a small icon.
class TrackRow extends ConsumerWidget {
  const TrackRow({
    required this.track,
    required this.index,
    required this.onTap,
    super.key,
  });

  final UnifiedTrack track;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentTrackProvider)?.id == track.id;
    final accent = ref.watch(currentAccentProvider);
    final liked = ref.watch(favoriteIdsProvider).contains(track.id);
    final ink = current ? accent : Pal.paper;
    final sub = Pal.muted;
    return Press(
      onTap: onTap,
      onLongPress: () => showTrackMenu(context, ref, track),
      scale: .98,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.curve,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: current
              ? Color.lerp(accent, Pal.stage, .84)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                (index + 1).toString().padLeft(2, '0'),
                style: Txt.mono(12, color: sub),
              ),
            ),
            TrackArtwork(track: track, size: 48, borderRadius: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Txt.body(16, color: ink, weight: 700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Txt.body(13.5, color: sub),
                  ),
                ],
              ),
            ),
            if (track.duration case final duration?)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(clock(duration), style: Txt.mono(12, color: sub)),
              ),
            Press(
              onTap: () => run(context, () => toggleFavorite(ref, track)),
              tooltip: liked ? 'Убрать из коллекции' : 'В коллекцию',
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 20,
                  color: liked ? (current ? ink : accent) : sub,
                ),
              ),
            ),
            Press(
              onTap: () => showTrackMenu(context, ref, track),
              tooltip: 'Ещё',
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.more_horiz_rounded, size: 20, color: sub),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showTrackMenu(
  BuildContext context,
  WidgetRef ref,
  UnifiedTrack track,
) {
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    backgroundColor: Pal.raised,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheet) {
      void act(Future<void> Function() action, [String? done]) {
        Navigator.of(sheet).pop();
        run(context, () async {
          await action();
          if (done != null && context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(done)));
          }
        });
      }

      Future<void> withService(
        Future<void> Function(PlaybackService) body,
      ) async {
        final service = await ref.read(playbackServiceProvider.future);
        await body(service);
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TrackArtwork(track: track, size: 64, borderRadius: 14),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title, maxLines: 2, style: Txt.title(18)),
                        const SizedBox(height: 4),
                        Text(
                          track.artist,
                          style: Txt.body(14, color: Pal.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _MenuLine(
                icon: Icons.play_arrow_rounded,
                label: 'Играть следующим',
                onTap: () => act(
                  () => withService((s) => s.playNext(track)),
                  'Сыграет следующим',
                ),
              ),
              _MenuLine(
                icon: Icons.queue_music_rounded,
                label: 'В конец очереди',
                onTap: () => act(
                  () => withService((s) => s.addToQueue(track)),
                  'Добавлено в очередь',
                ),
              ),
              _MenuLine(
                icon: Icons.radio_rounded,
                label: 'Поток по треку',
                onTap: () => act(
                  () => ref
                      .read(waveControllerProvider.notifier)
                      .startRadio(track),
                ),
              ),
              _MenuLine(
                icon: Icons.playlist_add_rounded,
                label: 'В плейлист…',
                onTap: () {
                  Navigator.of(sheet).pop();
                  showPlaylistPicker(context, ref, track);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showPlaylistPicker(
  BuildContext context,
  WidgetRef ref,
  UnifiedTrack track,
) async {
  final library = await ref.read(libraryControllerProvider.future);
  if (!context.mounted) return;
  final controller = TextEditingController();
  await showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    backgroundColor: Pal.raised,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheet) => Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(sheet).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('В плейлист', style: Txt.title(22)),
          const SizedBox(height: 16),
          for (final playlist in library.playlists)
            _MenuLine(
              icon: Icons.album_rounded,
              label: playlist.name,
              onTap: () {
                Navigator.of(sheet).pop();
                run(
                  context,
                  () => ref
                      .read(libraryControllerProvider.notifier)
                      .addToPlaylist(playlist.id, track),
                );
              },
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: Txt.body(16),
                  decoration: const InputDecoration(
                    hintText: 'Новый плейлист',
                    border: InputBorder.none,
                  ),
                ),
              ),
              Pill(
                label: 'Создать',
                active: true,
                onTap: () {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;
                  Navigator.of(sheet).pop();
                  run(context, () async {
                    final notifier = ref.read(
                      libraryControllerProvider.notifier,
                    );
                    final id = await notifier.createPlaylist(name);
                    await notifier.addToPlaylist(id, track);
                  });
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}

class _MenuLine extends StatelessWidget {
  const _MenuLine({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: onTap,
      scale: .98,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Pal.paper),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: Txt.body(16, weight: 650))),
          ],
        ),
      ),
    );
  }
}
