import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/provider_badges.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';

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
                  return AnimatedContainer(
                    duration: ResonanceMotion.standard,
                    curve: ResonanceMotion.curve,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? ResonanceColors.primary.withValues(alpha: .08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.only(right: 4),
                      dense: true,
                      onTap: isCurrent
                          ? null
                          : () => ref
                                .read(playbackServiceProvider.future)
                                .then((service) => service.skipToIndex(index)),
                      leading: _QueueMarker(
                        index: index,
                        count: state.queue.length,
                        current: isCurrent,
                        played: index < state.currentIndex,
                      ),
                      title: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
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

class _QueueMarker extends StatelessWidget {
  const _QueueMarker({
    required this.index,
    required this.count,
    required this.current,
    required this.played,
  });

  final int index;
  final int count;
  final bool current;
  final bool played;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 36,
    height: 48,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (index > 0)
          Positioned(
            top: 0,
            bottom: 24,
            child: Container(width: 2, color: _lineColor()),
          ),
        if (index + 1 < count)
          Positioned(
            top: 24,
            bottom: 0,
            child: Container(
              width: 2,
              color: current || played
                  ? ResonanceColors.primary.withValues(alpha: .45)
                  : ResonanceColors.border,
            ),
          ),
        AnimatedContainer(
          duration: ResonanceMotion.standard,
          curve: ResonanceMotion.curve,
          width: current ? 24 : 10,
          height: current ? 24 : 10,
          decoration: BoxDecoration(
            color: current || played
                ? ResonanceColors.primary
                : ResonanceColors.surfaceHigh,
            shape: BoxShape.circle,
            border: Border.all(
              color: current ? ResonanceColors.text : ResonanceColors.border,
              width: current ? 2 : 1,
            ),
          ),
          child: current
              ? const Icon(
                  Icons.graphic_eq_rounded,
                  size: 14,
                  color: Colors.black,
                )
              : null,
        ),
      ],
    ),
  );

  Color _lineColor() => played || current
      ? ResonanceColors.primary.withValues(alpha: .45)
      : ResonanceColors.border;
}
