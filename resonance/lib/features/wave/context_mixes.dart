import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/wave/wave_controller.dart';

/// Контекстные авто-плейлисты. Это параметры Моей волны — настроение,
/// доля открытий, подсказка для интерпретатора и поисковые «зёрна» под
/// темп и энергию. Ни датчики, ни календарь не читаются: контекст
/// человек выбирает сам.
enum ContextMix {
  workout(
    title: 'Тренировка',
    subtitle: '120–150 BPM, высокая энергия',
    icon: Icons.fitness_center_rounded,
    mood: 'active',
    discovery: .25,
    prompt:
        'Энергичная музыка для тренировки: темп 120–150 BPM, плотный бит, '
        'высокая энергия, без медленных баллад',
    seeds: [
      'workout',
      'gym motivation',
      'drum and bass',
      'phonk',
      'hard techno',
    ],
  ),
  focus(
    title: 'Фокус',
    subtitle: 'ровный темп, минимум слов',
    icon: Icons.center_focus_strong_rounded,
    mood: 'calm',
    discovery: .2,
    prompt:
        'Музыка для концентрации и работы: инструментальная, ровный темп '
        '70–110 BPM, без резких переходов и громкого вокала',
    seeds: ['lofi beats', 'ambient focus', 'instrumental study', 'post rock'],
  ),
  road(
    title: 'Дорога',
    subtitle: 'драйв и хиты для поездки',
    icon: Icons.directions_car_rounded,
    mood: 'fun',
    discovery: .35,
    prompt:
        'Музыка в дорогу: драйвовые песни для поездки, средний и быстрый темп '
        '100–130 BPM, подпевать',
    seeds: ['road trip', 'driving music', 'indie rock', 'synthwave'],
  );

  const ContextMix({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.mood,
    required this.discovery,
    required this.prompt,
    required this.seeds,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// Настроение волны на сервере: fun / active / calm.
  final String mood;
  final double discovery;
  final String prompt;
  final List<String> seeds;
}

/// Запускает волну с параметрами контекста; вкус слушателя (любимые
/// исполнители) остаётся в зёрнах, чтобы подборка была своей.
Future<void> startContextMix(WidgetRef ref, ContextMix mix) async {
  final library = ref.read(libraryControllerProvider).valueOrNull;
  await ref
      .read(waveControllerProvider.notifier)
      .start(
        taste: library?.favorites.take(20) ?? const [],
        discovery: mix.discovery,
        prompt: mix.prompt,
        mood: mix.mood,
        seedQueries: mix.seeds,
      );
}

class ContextMixesRow extends ConsumerWidget {
  const ContextMixesRow({required this.gutter, super.key});

  final double gutter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(waveControllerProvider.select((s) => s.loading));
    return SizedBox(
      height: 64,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        scrollDirection: Axis.horizontal,
        itemCount: ContextMix.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final mix = ContextMix.values[index];
          return ActionChip(
            avatar: Icon(mix.icon, size: 18),
            label: Text('${mix.title} · ${mix.subtitle}'),
            onPressed: loading
                ? null
                : () => unawaited(startContextMix(ref, mix)),
          );
        },
      ),
    );
  }
}
