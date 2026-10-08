import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/artist/artist_screen.dart';
import 'package:resonance/features/recap/listening_recap.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/ambient.dart';
import 'package:resonance/shared/widgets/aurora_backdrop.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

/// «Итоги»: что и сколько слушали за неделю или месяц, с карточкой,
/// которую можно сохранить картинкой и выложить.
class RecapScreen extends ConsumerStatefulWidget {
  const RecapScreen({super.key});

  @override
  ConsumerState<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends ConsumerState<RecapScreen> {
  final _cardKey = GlobalKey();
  RecapPeriod _period = RecapPeriod.week;
  bool _saving = false;

  Future<void> _saveImage(ListeningRecap recap) async {
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('png');
      final stamp = DateTime.now();
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Сохранить итоги',
        fileName:
            'resonance-itogi-${recap.period.name}-'
            '${stamp.year}-${_two(stamp.month)}-${_two(stamp.day)}.png',
        bytes: data.buffer.asUint8List(),
        mimeType: 'image/png',
        type: FileType.custom,
        allowedExtensions: const ['png'],
      );
      if (saved != null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Картинка с итогами сохранена')),
        );
      }
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить картинку')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _playTop(ListeningRecap recap) async {
    final tracks = [for (final item in recap.topTracks) item.track];
    if (tracks.isEmpty) return;
    final service = await ref.read(playbackServiceProvider.future);
    await service.setQueue(tracks, autoplay: true);
  }

  @override
  Widget build(BuildContext context) {
    final recap = ref.watch(listeningRecapProvider(_period));
    final value = recap.valueOrNull;
    final hero = value?.topTracks.firstOrNull?.track;
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Material(
      color: ResonanceColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hero != null)
            AuroraBackdrop(track: hero, intensity: .9, animate: false)
          else
            const ColoredBox(color: ResonanceColors.background),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x330E0B14), ResonanceColors.background],
                stops: [0, .8],
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 16 : 40,
                    12,
                    compact ? 16 : 40,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Назад',
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/'),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Итоги',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        SegmentedButton<RecapPeriod>(
                          showSelectedIcon: false,
                          segments: [
                            for (final period in RecapPeriod.values)
                              ButtonSegment(
                                value: period,
                                label: Text(period.label),
                              ),
                          ],
                          selected: {_period},
                          onSelectionChanged: (value) =>
                              setState(() => _period = value.first),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 16 : 40,
                    vertical: 24,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: recap.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(80),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (_, _) => const _RecapEmpty(
                            text: 'Не получилось прочитать историю.',
                          ),
                          data: (recap) => recap.empty
                              ? _RecapEmpty(
                                  text:
                                      'Итоги ${recap.period.phrase} появятся, когда '
                                      'вы послушаете что-нибудь хотя бы 30 секунд.',
                                )
                              : ResonanceEntrance(
                                  key: ValueKey(recap.period),
                                  child: _RecapBody(
                                    recap: recap,
                                    cardKey: _cardKey,
                                    compact: compact,
                                    saving: _saving,
                                    onSave: () => _saveImage(recap),
                                    onPlayTop: () => _playTop(recap),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapBody extends StatelessWidget {
  const _RecapBody({
    required this.recap,
    required this.cardKey,
    required this.compact,
    required this.saving,
    required this.onSave,
    required this.onPlayTop,
  });

  final ListeningRecap recap;
  final GlobalKey cardKey;
  final bool compact;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onPlayTop;

  @override
  Widget build(BuildContext context) {
    // Карточка всегда рисуется в одном логическом размере и масштабируется
    // под экран: на узком телефоне ничего не переполняется, а сохранённая
    // картинка выглядит одинаково везде.
    final card = AspectRatio(
      aspectRatio: 4 / 5,
      child: FittedBox(
        child: RepaintBoundary(
          key: cardKey,
          child: SizedBox(
            width: RecapCard.width,
            height: RecapCard.height,
            child: RecapCard(recap: recap),
          ),
        ),
      ),
    );
    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share_rounded),
          label: const Text('Сохранить картинку'),
        ),
        OutlinedButton.icon(
          onPressed: onPlayTop,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Слушать топ'),
        ),
      ],
    );
    final details = _RecapDetails(recap: recap);
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: card,
            ),
          ),
          const SizedBox(height: 18),
          actions,
          const SizedBox(height: 28),
          details,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 420, child: card),
        const SizedBox(width: 40),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [actions, const SizedBox(height: 28), details],
          ),
        ),
      ],
    );
  }
}

/// Карточка 4:5 для соцсетей — всё самое важное за период.
class RecapCard extends ConsumerWidget {
  const RecapCard({required this.recap, super.key});

  static const width = 420.0;
  static const height = 525.0;

  final ListeningRecap recap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = recap.topTracks.firstOrNull?.track;
    final palette = hero == null ? null : watchTrackPalette(ref, hero);
    final accent = palette?.accent ?? ResonanceColors.primary;
    final glow = palette?.glow ?? ResonanceColors.primary;
    final artist = recap.topArtists.firstOrNull;
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(glow, const Color(0xFF0E0B14), .35)!,
                const Color(0xFF120D1A),
                const Color(0xFF0B0810),
              ],
              stops: const [0, .55, 1],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/resonance_mark.png',
                      width: 22,
                      height: 22,
                      errorBuilder: (_, _, _) => const SizedBox(),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'RESONANCE · ИТОГИ ${recap.period.phrase.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w800,
                          color: Color(0xCCEFE9F5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  recap.persona,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: _formatNumber(recap.minutes)),
                        const TextSpan(
                          text: ' мин',
                          style: TextStyle(
                            fontSize: 22,
                            letterSpacing: 0,
                            color: Color(0xB3EFE9F5),
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 64,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2.5,
                      color: Color(0xFFF4EFF8),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _DailyBars(values: recap.daily, color: accent),
                const SizedBox(height: 18),
                if (artist != null)
                  Row(
                    children: [
                      if (artist.cover case final cover?)
                        TrackArtwork(track: cover, size: 46, borderRadius: 23)
                      else
                        const CircleAvatar(
                          radius: 23,
                          child: Icon(Icons.person_rounded),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Артист периода',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0x99EFE9F5),
                              ),
                            ),
                            Text(
                              artist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFF4EFF8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 14),
                Expanded(
                  child: ClipRect(
                    child: Column(
                      children: [
                        for (final (index, item)
                            in recap.topTracks.take(3).indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: index == 0
                                          ? accent
                                          : const Color(0x99EFE9F5),
                                    ),
                                  ),
                                ),
                                TrackArtwork(
                                  track: item.track,
                                  size: 34,
                                  borderRadius: 8,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${item.track.title} — ${item.track.artist}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xE6EFE9F5),
                                    ),
                                  ),
                                ),
                                Text(
                                  '×${item.plays}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0x99EFE9F5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    _CardStat(value: '${recap.plays}', label: 'прослушиваний'),
                    _CardStat(
                      value: '${recap.uniqueArtists}',
                      label: 'артистов',
                    ),
                    _CardStat(
                      value: '${recap.longestStreak}',
                      label: recap.longestStreak == 1
                          ? 'день подряд'
                          : 'дн. подряд',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  const _CardStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFFF4EFF8),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0x99EFE9F5)),
        ),
      ],
    ),
  );
}

class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final peak = values.fold<int>(0, max);
    return SizedBox(
      height: 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final value in values)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: values.length > 14 ? .8 : 2.5,
                ),
                child: FractionallySizedBox(
                  heightFactor: peak == 0 ? .08 : max(.08, value / peak),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: value == 0
                          ? const Color(0x22FFFFFF)
                          : color.withValues(
                              alpha: .35 + .65 * value / max(1, peak),
                            ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecapDetails extends StatelessWidget {
  const _RecapDetails({required this.recap});

  final ListeningRecap recap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peak = recap.peakHour;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatTile(
              icon: Icons.schedule_rounded,
              value: _formatHours(recap.listened),
              label: 'в наушниках ${recap.period.phrase}',
            ),
            _StatTile(
              icon: Icons.library_music_rounded,
              value: '${recap.uniqueTracks}',
              label: 'разных треков',
            ),
            _StatTile(
              icon: Icons.calendar_today_rounded,
              value: '${recap.activeDays} из ${recap.period.days}',
              label: 'дней с музыкой',
            ),
            if (peak != null)
              _StatTile(
                icon: Icons.nightlight_round,
                value: '${_two(peak)}:00',
                label: 'любимый час',
              ),
          ],
        ),
        const SizedBox(height: 28),
        Text('Топ артистов', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        for (final (index, artist) in recap.topArtists.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: artist.cover == null
                ? CircleAvatar(child: Text('${index + 1}'))
                : TrackArtwork(
                    track: artist.cover!,
                    size: 44,
                    borderRadius: 22,
                  ),
            title: Text(artist.name),
            subtitle: Text(
              '${artist.plays} прослуш. · ${_formatHours(artist.listened)}',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => openArtist(context, artist.name),
          ),
        const SizedBox(height: 18),
        Text('Топ треков', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        for (final item in recap.topTracks) _TopTrackTile(item: item),
      ],
    );
  }
}

class _TopTrackTile extends ConsumerWidget {
  const _TopTrackTile({required this.item});

  final RecapTrack item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnifiedTrack track = item.track;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: TrackArtwork(track: track, size: 44, borderRadius: 10),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${track.artist} · ${item.plays} раз',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: 'Слушать',
        icon: const Icon(Icons.play_arrow_rounded),
        onPressed: () => unawaited(
          ref
              .read(playbackServiceProvider.future)
              .then((service) => service.playTrack(track)),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: 200,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0x14FFFFFF),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x1FFFFFFF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: ResonanceColors.primary),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        Text(label, style: const TextStyle(color: ResonanceColors.muted)),
      ],
    ),
  );
}

class _RecapEmpty extends StatelessWidget {
  const _RecapEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 80),
    child: Column(
      children: [
        const Icon(
          Icons.insights_rounded,
          size: 48,
          color: ResonanceColors.muted,
        ),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ResonanceColors.muted, fontSize: 16),
        ),
      ],
    ),
  );
}

String _two(int value) => value.toString().padLeft(2, '0');

String _formatNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

String _formatHours(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes % 60;
  if (hours == 0) return '$minutes мин';
  return minutes == 0 ? '$hours ч' : '$hours ч $minutes мин';
}
