import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/wave/context_mixes.dart';
import 'package:resonance/features/wave/daily_mixes.dart';
import 'package:resonance/features/wave/wave_controller.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';
import 'package:resonance_alpha/audio/level.dart';
import 'package:resonance_alpha/design/accent.dart';
import 'package:resonance_alpha/design/blob.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/design/widgets.dart';
import 'package:resonance_alpha/screens/tracklist_screen.dart';
import 'package:resonance_alpha/state.dart';

enum FlowMood {
  any('Любое', 'all'),
  active('Бодрое', 'active'),
  fun('Весёлое', 'fun'),
  calm('Спокойное', 'calm');

  const FlowMood(this.label, this.wire);
  final String label;
  final String wire;
}

enum FlowNovelty {
  familiar('Знакомое', .12),
  mixed('Микс', .3),
  fresh('Незнакомое', .65);

  const FlowNovelty(this.label, this.discovery);
  final String label;
  final double discovery;
}

final flowMoodProvider = StateProvider<FlowMood>((ref) => FlowMood.any);
final flowNoveltyProvider = StateProvider<FlowNovelty>(
  (ref) => FlowNovelty.mixed,
);

class FlowScreen extends ConsumerStatefulWidget {
  const FlowScreen({super.key});

  @override
  ConsumerState<FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends ConsumerState<FlowScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final wave = ref.read(waveControllerProvider.notifier);
      run(context, wave.resume);
    });
  }

  Future<void> _start() async {
    final library = ref.read(libraryControllerProvider).valueOrNull;
    await ref
        .read(waveControllerProvider.notifier)
        .start(
          taste: library?.favorites.take(20) ?? const [],
          discovery: ref.read(flowNoveltyProvider).discovery,
          mood: ref.read(flowMoodProvider).wire,
        );
  }

  Future<void> _restartIfActive() async {
    final wave = ref.read(waveControllerProvider);
    if (!wave.active) return;
    await ref.read(waveControllerProvider.notifier).stop();
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    final wave = ref.watch(waveControllerProvider);
    final track = ref.watch(currentTrackProvider);
    final playing = ref.watch(
      playbackStateProvider.select((s) => s.valueOrNull?.playing ?? false),
    );
    final accent = ref.watch(currentAccentProvider);
    final mood = ref.watch(flowMoodProvider);
    final novelty = ref.watch(flowNoveltyProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final flowing = wave.active && track != null;
    final label = flowing ? track.title : 'Мой\nпоток';

    final hero = SizedBox(
      height: wide ? 560 : 440,
      child: Stack(
        children: [
          Positioned.fill(
            child: Press(
              scale: .985,
              onTap: () => run(context, () async {
                if (!wave.active) return _start();
                return togglePlay(ref);
              }),
              child: LivingBlob(
                color: accent,
                energy: playing ? 1 : (wave.loading ? .6 : .15),
                label: wave.loading ? 'Ищу…' : label,
                labelSize: _labelSize(label, wide),
                sampler: ref.watch(levelSamplerProvider),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 8,
            child: Text(
              wave.radioTitle != null
                  ? 'ПОТОК ПО ТРЕКУ'
                  : (waveContextLabel(wave.context)?.toUpperCase() ??
                        'ПОТОК · ${novelty.label.toUpperCase()}'),
              style: Txt.mono(12),
            ),
          ),
          if (flowing)
            Positioned(
              right: 0,
              top: 4,
              child: Press(
                onTap: () => run(
                  context,
                  ref.read(waveControllerProvider.notifier).stop,
                ),
                child: Text('СТОП ×', style: Txt.mono(12, color: Pal.paper)),
              ),
            ),
        ],
      ),
    );

    final controls = AnimatedSwitcher(
      duration: Motion.base,
      child: flowing
          ? Column(
              key: const ValueKey('flowing'),
              children: [
                Text(
                  track.artist,
                  textAlign: TextAlign.center,
                  style: Txt.body(17, color: Pal.muted, weight: 600),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Knob(
                      icon: Icons.heart_broken_rounded,
                      tooltip: 'Не то — дальше',
                      size: 56,
                      onTap: () => run(
                        context,
                        () => ref
                            .read(waveControllerProvider.notifier)
                            .rateCurrent(liked: false),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Knob(
                      icon: playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 76,
                      filled: true,
                      color: accent,
                      iconColor: onAccent(accent),
                      onTap: () => run(context, () => togglePlay(ref)),
                    ),
                    const SizedBox(width: 18),
                    Knob(
                      icon: Icons.skip_next_rounded,
                      tooltip: 'Следующий',
                      size: 56,
                      onTap: () => run(context, () async {
                        final service = await ref.read(
                          playbackServiceProvider.future,
                        );
                        await service.next();
                      }),
                    ),
                    const SizedBox(width: 18),
                    _LikeKnob(accent: accent),
                  ],
                ),
              ],
            )
          : Column(
              key: const ValueKey('idle'),
              children: [
                Text(
                  wave.error ??
                      'Бесконечный поток под твой вкус. Нажми на форму.',
                  textAlign: TextAlign.center,
                  style: Txt.body(
                    16,
                    color: wave.error == null ? Pal.muted : Pal.paper,
                  ),
                ),
                const SizedBox(height: 22),
                Pill(
                  large: true,
                  active: true,
                  accent: accent,
                  icon: Icons.play_arrow_rounded,
                  label: wave.loading ? 'Подбираю…' : 'Запустить поток',
                  onTap: wave.loading ? null : () => run(context, _start),
                ),
              ],
            ),
    );

    final tuning = Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in FlowMood.values)
              Pill(
                label: value.label,
                active: value == mood,
                accent: accent,
                onTap: () {
                  ref.read(flowMoodProvider.notifier).state = value;
                  run(context, _restartIfActive);
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in FlowNovelty.values)
              Pill(
                label: value.label,
                active: value == novelty,
                accent: Pal.paper,
                onTap: () {
                  ref.read(flowNoveltyProvider.notifier).state = value;
                  run(context, _restartIfActive);
                },
              ),
          ],
        ),
      ],
    );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            wide ? 48 : 20,
            wide ? 28 : 12,
            wide ? 48 : 20,
            0,
          ),
          sliver: SliverList.list(
            children: [
              hero,
              const SizedBox(height: 8),
              controls,
              const SizedBox(height: 28),
              tuning,
              const SizedBox(height: 64),
              const SectionHead(index: '02', title: 'Под занятие'),
              const _ContextMixes(),
              const SizedBox(height: 56),
              const SectionHead(index: '03', title: 'Миксы дня'),
              const _DailyMixes(),
              const SizedBox(height: 160),
            ],
          ),
        ),
      ],
    );
  }

  double _labelSize(String label, bool wide) {
    final longest = label
        .split(RegExp(r'\s+'))
        .fold(0, (max, word) => word.length > max ? word.length : max);
    final base = wide ? 92.0 : 56.0;
    if (longest <= 6) return base;
    return (base * 7 / longest).clamp(wide ? 40.0 : 28.0, base);
  }
}

class _LikeKnob extends ConsumerWidget {
  const _LikeKnob({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    final liked =
        track != null && ref.watch(favoriteIdsProvider).contains(track.id);
    return Knob(
      icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      tooltip: liked ? 'В коллекции' : 'Нравится',
      size: 56,
      color: liked ? accent : Pal.paper,
      onTap: track == null
          ? null
          : () => run(context, () async {
              if (!liked) {
                await ref
                    .read(waveControllerProvider.notifier)
                    .rateCurrent(liked: true);
              }
              await toggleFavorite(ref, track);
            }),
    );
  }
}

class _ContextMixes extends ConsumerWidget {
  const _ContextMixes();

  static const _tints = [
    Color(0xFFD39A84), // терракота
    Color(0xFF9DB0D6), // пыльный синий
    Color(0xFFD2BC8A), // охра
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final cards = [
      for (final (i, mix) in ContextMix.values.indexed)
        _MixCard(
          tint: _tints[i % _tints.length],
          number: '0${i + 1}',
          title: mix.title,
          subtitle: mix.subtitle,
          onTap: () => run(context, () async {
            final wave = ref.read(waveControllerProvider.notifier);
            await wave.stop();
            final library = ref.read(libraryControllerProvider).valueOrNull;
            await wave.start(
              taste: library?.favorites.take(20) ?? const [],
              discovery: mix.discovery,
              prompt: mix.prompt,
              mood: mix.mood,
              seedQueries: mix.seeds,
            );
          }),
        ),
    ];
    if (!wide) {
      return Column(
        children: [
          for (final card in cards)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: card),
        ],
      );
    }
    return Row(
      children: [
        for (final (i, card) in cards.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: card),
        ],
      ],
    );
  }
}

class _MixCard extends StatelessWidget {
  const _MixCard({
    required this.tint,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color tint;
  final String number;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: onTap,
      scale: .97,
      child: Container(
        height: 168,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // Dark card with a breath of the tint: calm next to each other.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(tint, Pal.stage, .74)!,
              Color.lerp(tint, Pal.stage, .9)!,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: tint.withValues(alpha: .18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(number, style: Txt.mono(12, color: tint)),
                const Spacer(),
                Icon(Icons.north_east_rounded, color: tint),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(title, style: Txt.display(34)),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Txt.body(13.5, color: Pal.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyMixes extends ConsumerWidget {
  const _DailyMixes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mixes = ref.watch(dailyMixesProvider);
    return mixes.when(
      loading: () => const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => Hollow(
        title: 'Миксы не загрузились',
        body: 'Проверь соединение — поток при этом работает.',
        action: Pill(
          label: 'Ещё раз',
          onTap: () => ref.invalidate(dailyMixesProvider),
        ),
      ),
      data: (data) {
        final list = data.mixes.where((mix) => mix.tracks.isNotEmpty).toList();
        if (list.isEmpty) {
          return const Hollow(
            title: 'Пока пусто',
            body: 'Лайкай треки в потоке — миксы соберутся из твоего вкуса.',
          );
        }
        return SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final mix = list[index];
              return Press(
                scale: .97,
                onTap: () => Navigator.of(context).push(
                  TracklistScreen.route(
                    title: mix.title,
                    subtitle: mix.subtitle,
                    load: () async => mix.tracks,
                  ),
                ),
                child: SizedBox(
                  width: 196,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Collage(tracks: mix.tracks),
                      const SizedBox(height: 12),
                      Text(
                        mix.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Txt.title(17),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        mix.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Txt.body(13, color: Pal.muted),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Four covers in a square: the mix's face.
class _Collage extends StatelessWidget {
  const _Collage({required this.tracks});

  final List<UnifiedTrack> tracks;

  @override
  Widget build(BuildContext context) {
    final covers = tracks.take(4).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox.square(
        dimension: 196,
        child: GridView.count(
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            for (var i = 0; i < 4; i++)
              i < covers.length
                  ? TrackArtwork(track: covers[i], size: 98, borderRadius: 0)
                  : const ColoredBox(color: Pal.raised),
          ],
        ),
      ),
    );
  }
}
