import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/design/widgets.dart';
import 'package:resonance_alpha/screens/track_row.dart';
import 'package:resonance_alpha/state.dart';

Future<void> showQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    backgroundColor: Pal.raised,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (_) =>
        const FractionallySizedBox(heightFactor: .8, child: _Queue()),
  );
}

class _Queue extends ConsumerWidget {
  const _Queue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      playbackStateProvider.select(
        (value) => (
          queue: value.valueOrNull?.queue ?? const [],
          index: value.valueOrNull?.currentIndex ?? -1,
        ),
      ),
    );
    final upcoming = state.index < 0
        ? state.queue
        : state.queue.sublist(state.index);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SectionHead(index: '${upcoming.length}', title: 'Очередь'),
          ),
          Expanded(
            child: upcoming.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Hollow(title: 'Очередь пуста'),
                  )
                : ListView.builder(
                    itemCount: upcoming.length,
                    itemBuilder: (context, i) {
                      final absolute = state.index < 0 ? i : state.index + i;
                      return TrackRow(
                        track: upcoming[i],
                        index: i,
                        onTap: () => run(context, () async {
                          final service = await ref.read(
                            playbackServiceProvider.future,
                          );
                          await service.skipToIndex(absolute);
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
