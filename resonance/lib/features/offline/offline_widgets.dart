import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/offline_downloads.dart';
import 'package:resonance/features/offline/offline_controller.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

/// Пилюля «Только скачанное»: видна, пока нет сети.
class OfflineModeBanner extends ConsumerWidget {
  const OfflineModeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isOfflineProvider)) return const SizedBox.shrink();
    final count = ref.watch(offlineDownloadsProvider).availableEntries.length;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ResonanceColors.surfaceRaised,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: ResonanceColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 18,
              color: ResonanceColors.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Только скачанное · нет сети · доступно $count',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Список того, что играет без сети: загрузки и автокэш.
class OfflineAvailableList extends ConsumerWidget {
  const OfflineAvailableList({super.key, this.limit});

  final int? limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(offlineDownloadsProvider);
    final all = downloads.availableEntries;
    final entries = limit == null ? all : all.take(limit!).toList();
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Пока ничего не скачано. Когда сеть появится, частые треки '
          'сохранятся автоматически.',
          style: TextStyle(color: ResonanceColors.muted),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: TrackArtwork(
              track: entry.track,
              size: 48,
              borderRadius: 4,
            ),
            title: Text(entry.track.title, overflow: TextOverflow.ellipsis),
            subtitle: Text(entry.track.artist, overflow: TextOverflow.ellipsis),
            trailing: Icon(
              entry.kind == OfflineKind.manual
                  ? Icons.download_done_rounded
                  : Icons.offline_bolt_rounded,
              size: 18,
              color: ResonanceColors.muted,
            ),
            onTap: () => unawaited(_play(context, ref, all, entry)),
          ),
      ],
    );
  }

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    List<OfflineEntry> all,
    OfflineEntry entry,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final service = await ref.read(playbackServiceProvider.future);
      final tracks = [for (final item in all) item.track];
      await service.setQueue(
        tracks,
        startIndex: tracks.indexWhere((t) => t.id == entry.track.id),
        autoplay: true,
      );
    } on Object {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Не удалось включить трек')),
      );
    }
  }
}
