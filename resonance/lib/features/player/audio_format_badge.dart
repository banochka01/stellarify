import 'package:flutter/material.dart';
import 'package:resonance/core/playback/stream_quality.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';

/// Бейдж формата текущего потока: MP3 / AAC / FLAC / Hi-Res.
class AudioFormatBadgeChip extends StatelessWidget {
  const AudioFormatBadgeChip({required this.source, super.key});

  final ResolvedAudioSource? source;

  @override
  Widget build(BuildContext context) {
    final badge = audioFormatBadge(source);
    final label = audioFormatLabel(source);
    if (badge == null || label == null) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    final color = badge.lossless ? accent : const Color(0xFFA095AB);
    return Tooltip(
      message: badge.lossless
          ? 'Поток без потерь${badge == AudioFormatBadge.hiRes ? ' высокого разрешения' : ''}'
          : 'Формат потока',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: .6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .4,
          ),
        ),
      ),
    );
  }
}
