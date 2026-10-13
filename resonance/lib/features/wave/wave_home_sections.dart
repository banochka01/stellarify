import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/wave/context_mixes.dart';
import 'package:resonance/features/wave/daily_mixes.dart';
import 'package:resonance/features/wave/new_releases.dart';
import 'package:resonance/features/wave/wave_blocks.dart';
import 'package:resonance/shared/russian_plural.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

Future<void> _playAll(
  BuildContext context,
  WidgetRef ref,
  List<UnifiedTrack> tracks,
) async {
  if (tracks.isEmpty) return;
  try {
    final service = await ref.read(playbackServiceProvider.future);
    await service.setQueue(tracks, autoplay: true);
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось включить подборку.')),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.gutter,
    this.badge = 0,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final double gutter;
  final int badge;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(gutter, 30, gutter, 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -.3,
            ),
          ),
        ),
        if (badge > 0) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: ResonanceColors.live,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$badge новых',
              style: const TextStyle(
                color: ResonanceColors.background,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        if (subtitle != null) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ResonanceColors.muted,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// «Ваш день»: утренние, рабочие, вечерние миксы и открытия.
class WaveDaySection extends ConsumerWidget {
  const WaveDaySection({
    required this.gutter,
    required this.compact,
    super.key,
  });

  final double gutter;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mixes = ref.watch(dailyMixesProvider).valueOrNull?.mixes ?? const [];
    if (mixes.isEmpty) return const SizedBox.shrink();
    final size = compact ? 150.0 : 176.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Ваш день',
          subtitle: 'обновляется каждое утро',
          gutter: gutter,
        ),
        ContextMixesRow(gutter: gutter),
        SizedBox(
          height: size + MediaQuery.textScalerOf(context).scale(64),
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 6),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: mixes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) =>
                _MixCard(mix: mixes[index], size: size),
          ),
        ),
      ],
    );
  }
}

class _MixCard extends ConsumerWidget {
  const _MixCard({required this.mix, required this.size});

  final DailyMix mix;
  final double size;

  static const _tints = {
    'morning': Color(0xFFFFC46B),
    'focus': Color(0xFF7FB8FF),
    'evening': Color(0xFFB69CFF),
    'discovery': ResonanceColors.live,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tint = _tints[mix.kind] ?? ResonanceColors.primary;
    return SizedBox(
      width: size,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => unawaited(_playAll(context, ref, mix.tracks)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                TrackArtwork(
                  track: mix.tracks.first,
                  size: size,
                  borderRadius: 8,
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          tint.withValues(alpha: .1),
                          tint.withValues(alpha: .65),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 10,
                  right: 12,
                  child: Text(
                    mix.title,
                    style: const TextStyle(
                      fontFamily: ResonanceFonts.display,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              mix.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ResonanceColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Новое от ваших артистов» и автоплейлист «Свежее за неделю».
class NewReleasesSection extends ConsumerWidget {
  const NewReleasesSection({
    required this.gutter,
    required this.compact,
    super.key,
  });

  final double gutter;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releases = ref.watch(newReleasesProvider).valueOrNull ?? const [];
    final fresh = ref.watch(freshWeekProvider).valueOrNull;
    final alerts = ref.watch(releaseAlertsProvider);
    if (releases.isEmpty && (fresh?.tracks.isEmpty ?? true)) {
      return const SizedBox.shrink();
    }
    final badge = unseenReleaseCount(releases, alerts, DateTime.now());
    final size = compact ? 128.0 : 150.0;
    final hasFresh = fresh != null && fresh.tracks.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Новое от ваших артистов',
          gutter: gutter,
          badge: badge,
        ),
        SizedBox(
          height: size + MediaQuery.textScalerOf(context).scale(66),
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 6),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: releases.length + (hasFresh ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              if (hasFresh && index == 0) {
                return _FreshWeekCard(fresh: fresh, size: size);
              }
              final release = releases[index - (hasFresh ? 1 : 0)];
              return _ReleaseCard(release: release, size: size);
            },
          ),
        ),
      ],
    );
  }
}

class _FreshWeekCard extends ConsumerWidget {
  const _FreshWeekCard({required this.fresh, required this.size});

  final FreshWeek fresh;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    width: size,
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        unawaited(ref.read(releaseAlertsProvider.notifier).markSeen());
        unawaited(_playAll(context, ref, fresh.tracks));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ResonanceColors.live, ResonanceColors.primary],
              ),
            ),
            alignment: Alignment.bottomLeft,
            child: const Text(
              'Свежее\nза неделю',
              style: TextStyle(
                fontFamily: ResonanceFonts.display,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ResonanceColors.background,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${tracksLabel(fresh.tracks.length)} · по пятницам',
            maxLines: 2,
            style: const TextStyle(color: ResonanceColors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _ReleaseCard extends ConsumerWidget {
  const _ReleaseCard({required this.release, required this.size});

  final NewRelease release;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artwork = release.artworkUrl;
    return SizedBox(
      width: size,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          unawaited(ref.read(releaseAlertsProvider.notifier).markSeen());
          final artist = release.artist.split(',').first.trim();
          unawaited(context.push('/artist/${Uri.encodeComponent(artist)}'));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: artwork == null
                  ? Container(
                      width: size,
                      height: size,
                      color: ResonanceColors.surfaceRaised,
                      child: const Icon(Icons.album_rounded, size: 40),
                    )
                  : Image.network(
                      artwork.toString(),
                      width: size,
                      height: size,
                      cacheWidth: artworkCacheBucket(
                        size * MediaQuery.devicePixelRatioOf(context),
                      ),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: size,
                        height: size,
                        color: ResonanceColors.surfaceRaised,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              release.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${release.kindLabel} · ${release.artist}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ResonanceColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings: "Не предлагать" list and release alerts.
class WaveSettingsCards extends ConsumerWidget {
  const WaveSettingsCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref
        .watch(waveBlocksProvider)
        .where((block) => !block.removed)
        .toList(growable: false);
    final alerts = ref.watch(releaseAlertsProvider);
    return Column(
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: ExpansionTile(
            leading: const Icon(Icons.block_rounded),
            title: const Text('Не предлагать'),
            subtitle: Text(
              blocks.isEmpty
                  ? 'Скрытые треки и артисты появятся здесь'
                  : '${blocks.length} в списке · синхронизируется с Resonance ID',
            ),
            children: [
              for (final block in blocks)
                ListTile(
                  dense: true,
                  leading: Icon(
                    block.kind == WaveBlockKind.artist
                        ? Icons.person_off_outlined
                        : Icons.music_off_outlined,
                  ),
                  title: Text(block.label),
                  trailing: IconButton(
                    tooltip: 'Вернуть в рекомендации',
                    icon: const Icon(Icons.undo_rounded),
                    onPressed: () => unawaited(
                      ref.read(waveBlocksProvider.notifier).unblock(block),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.new_releases_outlined),
                title: const Text('Новые релизы'),
                subtitle: const Text(
                  'Отмечать на главной новое от ваших артистов',
                ),
                value: alerts.enabled,
                onChanged: (value) => unawaited(
                  ref.read(releaseAlertsProvider.notifier).setEnabled(value),
                ),
              ),
              if (alerts.enabled)
                ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('Как часто'),
                  trailing: DropdownButton<ReleaseCheckFrequency>(
                    value: alerts.frequency,
                    underline: const SizedBox.shrink(),
                    onChanged: (value) {
                      if (value == null) return;
                      unawaited(
                        ref
                            .read(releaseAlertsProvider.notifier)
                            .setFrequency(value),
                      );
                    },
                    items: const [
                      DropdownMenuItem(
                        value: ReleaseCheckFrequency.daily,
                        child: Text('Каждый день'),
                      ),
                      DropdownMenuItem(
                        value: ReleaseCheckFrequency.weekly,
                        child: Text('По пятницам'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
