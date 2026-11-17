import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/recap/listening_recap.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';
import 'package:resonance_alpha/design/accent.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/design/widgets.dart';
import 'package:resonance_alpha/screens/artist_screen.dart';
import 'package:resonance_alpha/screens/track_row.dart';
import 'package:resonance_alpha/state.dart';

final _periodProvider = StateProvider.autoDispose<RecapPeriod>(
  (ref) => RecapPeriod.week,
);

/// Listening in numbers, counted from the local history on this device.
/// One giant figure, a strip of days, then the people and songs behind it.
class RecapScreen extends ConsumerWidget {
  const RecapScreen({super.key});

  static Route<void> route() => alphaRoute(const RecapScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pad = wide ? 48.0 : 20.0;
    final period = ref.watch(_periodProvider);
    final recap = ref.watch(listeningRecapProvider(period));
    final data = recap.valueOrNull;
    final cover = data?.topTracks.firstOrNull?.track;
    final accent = cover == null
        ? Pal.acid
        : ref.watch(trackAccentProvider(cover));

    return Scaffold(
      backgroundColor: Pal.stage,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Knob(
                          icon: Icons.arrow_back_rounded,
                          size: 44,
                          tooltip: 'Назад',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                        for (final item in RecapPeriod.values) ...[
                          const SizedBox(width: 8),
                          Pill(
                            label: item.label,
                            active: item == period,
                            accent: accent,
                            onTap: () =>
                                ref.read(_periodProvider.notifier).state = item,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: wide ? 72 : 44),
                    Text(
                      'ИТОГИ · ${period.phrase.toUpperCase()}',
                      style: Txt.mono(12, color: Pal.paper),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (recap.isLoading && data == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(64),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (data == null || data.empty)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              sliver: const SliverToBoxAdapter(
                child: Hollow(
                  title: 'Пока нечего считать',
                  body:
                      'Итоги собираются из того, что ты слушаешь в α на этом '
                      'устройстве. Включи музыку — цифры появятся.',
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              sliver: SliverToBoxAdapter(
                child: _Headline(recap: data, accent: accent, wide: wide),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 36, pad, 0),
              sliver: SliverToBoxAdapter(
                child: _Days(daily: data.daily, accent: accent, wide: wide),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 36, pad, 0),
              sliver: SliverToBoxAdapter(child: _Facts(recap: data)),
            ),
            if (data.topArtists.isNotEmpty) ...[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 56, pad, 0),
                sliver: const SliverToBoxAdapter(
                  child: SectionHead(index: '01', title: 'Артисты'),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                sliver: SliverList.list(
                  children: [
                    for (final (i, artist) in data.topArtists.take(5).indexed)
                      _ArtistLine(
                        place: i + 1,
                        artist: artist,
                        accent: accent,
                        wide: wide,
                      ),
                  ],
                ),
              ),
            ],
            if (data.topTracks.isNotEmpty) ...[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 56, pad, 0),
                sliver: SliverToBoxAdapter(
                  child: SectionHead(
                    index: data.topArtists.isEmpty ? '01' : '02',
                    title: 'Треки',
                    trailing: Pill(
                      label: 'Слушать',
                      icon: Icons.play_arrow_rounded,
                      onTap: () => run(
                        context,
                        () => playList(ref, [
                          for (final item in data.topTracks) item.track,
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: pad - 12),
                sliver: SliverList.builder(
                  itemCount: data.topTracks.take(10).length,
                  itemBuilder: (context, index) => TrackRow(
                    track: data.topTracks[index].track,
                    index: index,
                    onTap: () => run(
                      context,
                      () => playList(ref, [
                        for (final item in data.topTracks) item.track,
                      ], index: index),
                    ),
                  ),
                ),
              ),
            ],
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 180)),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({
    required this.recap,
    required this.accent,
    required this.wide,
  });

  final ListeningRecap recap;
  final Color accent;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final minutes = recap.minutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('$minutes', style: Txt.display(wide ? 180 : 112)),
        ),
        Text(
          '${plural(minutes, 'минута', 'минуты', 'минут')} музыки',
          style: Txt.title(wide ? 30 : 22),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Color.lerp(accent, Pal.stage, .82),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            recap.persona,
            style: Txt.body(15, weight: 750, color: Pal.paper),
          ),
        ),
      ],
    );
  }
}

/// One bar per day; today on the right. Quiet days stay as a thin line.
class _Days extends StatelessWidget {
  const _Days({required this.daily, required this.accent, required this.wide});

  final List<int> daily;
  final Color accent;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) return const SizedBox.shrink();
    final peak = daily.fold(1, (max, v) => v > max ? v : max);
    final height = wide ? 140.0 : 100.0;
    final bar = Color.lerp(accent, Pal.stage, .25)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, minutes) in daily.indexed)
                Expanded(
                  child: Tooltip(
                    message: '$minutes мин',
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: daily.length > 14 ? 1.5 : 4,
                      ),
                      child: AnimatedContainer(
                        duration: Motion.slow,
                        curve: Motion.curve,
                        height: minutes == 0
                            ? 3
                            : 6 + (height - 6) * minutes / peak,
                        decoration: BoxDecoration(
                          color: minutes == 0
                              ? Pal.line
                              : (i == daily.length - 1
                                    ? bar
                                    : bar.withValues(alpha: .62)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('${daily.length} ДН. НАЗАД', style: Txt.mono(10)),
            const Spacer(),
            Text('СЕГОДНЯ', style: Txt.mono(10)),
          ],
        ),
      ],
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.recap});

  final ListeningRecap recap;

  @override
  Widget build(BuildContext context) {
    final hour = recap.peakHour;
    final facts = <(String, String)>[
      (
        '${recap.plays}',
        plural(recap.plays, 'прослушивание', 'прослушивания', 'прослушиваний'),
      ),
      (
        '${recap.uniqueTracks}',
        plural(recap.uniqueTracks, 'трек', 'трека', 'треков'),
      ),
      (
        '${recap.uniqueArtists}',
        plural(recap.uniqueArtists, 'артист', 'артиста', 'артистов'),
      ),
      ('${recap.activeDays}', 'дней с музыкой'),
      ('${recap.longestStreak}', 'дней подряд'),
      if (hour != null)
        ('${hour.toString().padLeft(2, '0')}:00', 'любимый час'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final (value, label) in facts)
          Container(
            constraints: const BoxConstraints(minWidth: 140),
            padding: const EdgeInsets.fromLTRB(18, 14, 22, 16),
            decoration: BoxDecoration(
              border: Border.all(color: Pal.line),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: Txt.display(34)),
                const SizedBox(height: 2),
                Text(label, style: Txt.body(13, color: Pal.muted)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ArtistLine extends StatelessWidget {
  const _ArtistLine({
    required this.place,
    required this.artist,
    required this.accent,
    required this.wide,
  });

  final int place;
  final RecapArtist artist;
  final Color accent;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final cover = artist.cover;
    return Press(
      scale: .98,
      onTap: () => openArtist(context, artist.name),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Pal.line)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                place.toString().padLeft(2, '0'),
                style: Txt.mono(12, color: place == 1 ? accent : Pal.muted),
              ),
            ),
            if (cover != null) ...[
              TrackArtwork(track: cover, size: 52, borderRadius: 26),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Txt.title(
                  place == 1 ? (wide ? 38 : 28) : (wide ? 28 : 21),
                ),
              ),
            ),
            Text(
              '${artist.listened.inMinutes} мин',
              style: Txt.mono(12, color: Pal.paper),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_outward_rounded, color: Pal.muted),
          ],
        ),
      ),
    );
  }
}
