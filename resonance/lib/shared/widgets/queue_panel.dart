import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/provider_badges.dart';

class QueuePanel extends ConsumerWidget {
  const QueuePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(playbackStateProvider).valueOrNull ??
        const ResonancePlaybackState();
    return Container(
      width: 286,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: ResonanceColors.surface,
        border: Border(left: BorderSide(color: ResonanceColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.queue_music_rounded, color: ResonanceColors.primary),
              SizedBox(width: 10),
              Text(
                'Очередь',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              Spacer(),
              Text(
                'Локально',
                style: TextStyle(color: ResonanceColors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (state.queue.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Очередь пуста.\nЗапустите тестовый трек.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ResonanceColors.muted, height: 1.5),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: state.queue.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final track = state.queue[index];
                  final isCurrent = index == state.currentIndex;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: isCurrent
                        ? const Icon(
                            Icons.graphic_eq_rounded,
                            color: ResonanceColors.primary,
                          )
                        : Text('${index + 1}'),
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: track.sources.isEmpty
                        ? null
                        : ProviderBadge(
                            provider: track.sources.first.provider,
                            compact: true,
                          ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
