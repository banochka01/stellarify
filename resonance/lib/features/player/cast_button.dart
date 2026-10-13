import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/cast/cast_controller.dart';
import 'package:resonance/core/cast/cast_providers.dart';

/// Кнопка трансляции в плеере. Скрыта, если на платформе нет ни одного
/// протокола (iOS).
class CastButton extends ConsumerWidget {
  const CastButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cast = ref.watch(castControllerProvider);
    if (!cast.available) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    return IconButton(
      tooltip: cast.casting
          ? 'Трансляция: ${cast.active!.name}'
          : 'Передать на устройство',
      onPressed: () => unawaited(showCastSheet(context)),
      icon: Icon(
        cast.casting ? Icons.cast_connected_rounded : Icons.cast_rounded,
        color: cast.casting ? accent : null,
      ),
    );
  }
}

Future<void> showCastSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => const _CastSheet(),
  );
}

class _CastSheet extends ConsumerStatefulWidget {
  const _CastSheet();

  @override
  ConsumerState<_CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends ConsumerState<_CastSheet> {
  @override
  void initState() {
    super.initState();
    final cast = ref.read(castControllerProvider);
    if (!cast.casting) {
      unawaited(ref.read(castControllerProvider.notifier).discover());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cast = ref.watch(castControllerProvider);
    final controller = ref.read(castControllerProvider.notifier);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Передать на устройство',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Chromecast и DLNA-приёмники в этой Wi‑Fi сети. Устройство само открывает поток по ссылке.',
              style: TextStyle(color: muted),
            ),
            if (cast.message != null) ...[
              const SizedBox(height: 10),
              Text(
                cast.message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            if (cast.casting) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cast_connected_rounded),
                title: Text(cast.active!.name),
                subtitle: Text(cast.active!.protocol.label),
                trailing: IconButton.filledTonal(
                  tooltip: cast.playing ? 'Пауза' : 'Играть',
                  onPressed: () => unawaited(controller.togglePlay()),
                  icon: Icon(
                    cast.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.volume_down_rounded),
                  Expanded(
                    child: Slider(
                      value: cast.volume,
                      onChanged: (value) =>
                          unawaited(controller.setVolume(value)),
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded),
                ],
              ),
              TextButton.icon(
                onPressed: () => unawaited(controller.disconnect()),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Остановить трансляцию'),
              ),
            ] else ...[
              for (final target in cast.targets)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    target.protocol == CastProtocol.chromecast
                        ? Icons.cast_rounded
                        : Icons.speaker_group_rounded,
                  ),
                  title: Text(target.name),
                  subtitle: Text(target.protocol.label),
                  enabled: !cast.connecting,
                  onTap: () => unawaited(controller.connect(target)),
                ),
              if (cast.discovering || cast.connecting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                )
              else if (cast.targets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Устройства не найдены. Проверьте, что телефон или компьютер в той же сети.',
                    style: TextStyle(color: muted),
                  ),
                ),
              if (!cast.discovering)
                TextButton.icon(
                  onPressed: () => unawaited(controller.discover()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Искать снова'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
