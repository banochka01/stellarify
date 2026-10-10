import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/desktop/quick_actions.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';
import 'package:window_manager/window_manager.dart';

/// Always-on-top mini player shown while [compactModeProvider] is on (Windows).
class CompactPlayer extends ConsumerWidget {
  const CompactPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackStateProvider).valueOrNull;
    final track = state?.currentTrack;
    final playing = state?.playing ?? false;
    final liked =
        track != null &&
        (ref
                .watch(libraryControllerProvider)
                .valueOrNull
                ?.favoriteIds
                .contains(track.id) ??
            false);
    final actions = ref.read(quickActionsProvider);
    void run(QuickAction action) => unawaited(actions.run(action));
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: ResonanceColors.background,
      child: DragToMoveArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (track != null)
                TrackArtwork(track: track, size: 72, borderRadius: 14)
              else
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: ResonanceColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: ResonanceColors.muted,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track?.title ?? 'Ничего не играет',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                    Text(
                      track?.artist ?? 'Включите «Мою волну»',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: ResonanceColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _CompactButton(
                          tooltip: 'Предыдущий',
                          icon: Icons.skip_previous_rounded,
                          onPressed: track == null
                              ? null
                              : () => run(QuickAction.previous),
                        ),
                        _CompactButton(
                          tooltip: playing ? 'Пауза' : 'Играть',
                          icon: playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          onPressed: track == null
                              ? () => run(QuickAction.wave)
                              : () => run(QuickAction.playPause),
                        ),
                        _CompactButton(
                          tooltip: 'Следующий',
                          icon: Icons.skip_next_rounded,
                          onPressed: track == null
                              ? null
                              : () => run(QuickAction.next),
                        ),
                        _CompactButton(
                          tooltip: 'Нравится',
                          icon: liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: liked ? ResonanceColors.primary : null,
                          onPressed: track == null
                              ? null
                              : () => run(QuickAction.like),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _CompactButton(
                tooltip: 'Развернуть',
                icon: Icons.open_in_full_rounded,
                onPressed: () => run(QuickAction.toggleCompact),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactButton extends StatelessWidget {
  const _CompactButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    iconSize: 22,
    color: color,
    onPressed: onPressed,
    icon: Icon(icon),
  );
}
