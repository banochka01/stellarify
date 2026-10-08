import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/sleep_timer.dart';

/// Луна в шапке плеера: таймер сна с плавным затуханием.
class SleepTimerButton extends ConsumerStatefulWidget {
  const SleepTimerButton({super.key});

  @override
  ConsumerState<SleepTimerButton> createState() => _SleepTimerButtonState();
}

class _SleepTimerButtonState extends ConsumerState<SleepTimerButton> {
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker(SleepTimerState timer) {
    if (timer.endsAt != null) {
      _ticker ??= Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(sleepTimerProvider);
    _syncTicker(timer);
    final label = sleepTimerLabel(timer, DateTime.now());
    final accent = Theme.of(context).colorScheme.primary;
    return IconButton(
      tooltip: label == null ? 'Таймер сна' : 'Таймер сна · $label',
      isSelected: timer.active,
      onPressed: () => unawaited(showSleepTimerSheet(context)),
      icon: Badge(
        isLabelVisible: label != null,
        backgroundColor: accent,
        textColor: Theme.of(context).colorScheme.onPrimary,
        label: Text(label ?? ''),
        child: Icon(
          timer.active ? Icons.bedtime_rounded : Icons.bedtime_outlined,
          color: timer.active ? accent : null,
        ),
      ),
    );
  }
}

/// Короткая подпись для бейджа: «25», «⏵|» для конца трека, «…» во время затухания.
String? sleepTimerLabel(SleepTimerState timer, DateTime now) {
  if (timer.fading) return '…';
  if (timer.endOfTrack) return '1 тр';
  if (timer.endsAt == null) return null;
  final minutes = (timer.remaining(now).inSeconds / 60).ceil();
  return '$minutes';
}

Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final timer = ref.watch(sleepTimerProvider);
        final controller = ref.read(sleepTimerProvider.notifier);
        final now = DateTime.now();
        void close() => Navigator.of(context).pop();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Таймер сна',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  timer.endOfTrack
                      ? 'Музыка остановится в конце этого трека'
                      : timer.endsAt != null
                      ? 'Осталось ${_formatRemaining(timer.remaining(now))}'
                      : 'Музыка мягко затихнет и встанет на паузу',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in SleepTimerController.presets)
                      ChoiceChip(
                        label: Text('${preset.inMinutes} мин'),
                        selected: false,
                        onSelected: (_) {
                          unawaited(controller.startFor(preset));
                          close();
                        },
                      ),
                    ChoiceChip(
                      avatar: const Icon(Icons.last_page_rounded, size: 18),
                      label: const Text('В конце трека'),
                      selected: timer.endOfTrack,
                      onSelected: (_) {
                        unawaited(controller.startEndOfTrack());
                        close();
                      },
                    ),
                  ],
                ),
                if (timer.active) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      controller.cancel();
                      close();
                    },
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Выключить таймер'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

String _formatRemaining(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds % 60;
  if (minutes >= 1) return '$minutes мин';
  return '$seconds с';
}
