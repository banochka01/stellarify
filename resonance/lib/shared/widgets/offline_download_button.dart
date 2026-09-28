import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/offline_downloads.dart';
import 'package:resonance/domain/entities/unified_track.dart';

class OfflineDownloadButton extends ConsumerWidget {
  const OfflineDownloadButton({super.key, required this.track});

  final UnifiedTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(offlineDownloadsProvider);
    final saved = downloads.contains(track.id);
    final busy = downloads.isDownloading(track.id);
    return IconButton(
      tooltip: saved ? 'Удалить загрузку' : 'Скачать для офлайна',
      onPressed: busy
          ? null
          : () => unawaited(_toggle(context, downloads, saved)),
      icon: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(saved ? Icons.download_done_rounded : Icons.download_rounded),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    OfflineDownloads downloads,
    bool saved,
  ) async {
    try {
      if (saved) {
        await downloads.remove(track.id);
      } else {
        await downloads.download(track);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(saved ? 'Загрузка удалена' : 'Трек доступен офлайн'),
          ),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось скачать трек: $error')),
        );
      }
    }
  }
}
