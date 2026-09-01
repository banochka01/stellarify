import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';

Future<void> playTrackOrOpenOfficial(WidgetRef ref, UnifiedTrack track) async {
  final provider =
      track.preferredProvider ?? track.sources.firstOrNull?.provider;
  if (provider == MusicProvider.youtube &&
      !track.sources.any((s) => s.provider != MusicProvider.youtube)) {
    ScaffoldMessenger.of(ref.context).showSnackBar(
      const SnackBar(
        content: Text(
          'Этот трек доступен только как метаданные. В Resonance используется исключительно собственный плеер.',
        ),
      ),
    );
    return;
  }
  try {
    final service = await ref.read(playbackServiceProvider.future);
    await service.playTrack(track);
  } on Object catch (_) {
    if (ref.context.mounted) {
      ScaffoldMessenger.of(ref.context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось включить трек. Проверьте источник и подписку.',
          ),
        ),
      );
    }
  }
}
