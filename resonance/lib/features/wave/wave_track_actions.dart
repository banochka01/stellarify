import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/wave/wave_blocks.dart';
import 'package:resonance/features/wave/wave_controller.dart';

/// Popup values shared by every track context menu.
abstract final class WaveTrackAction {
  static const radio = 'wave.radio';
  static const blockTrack = 'wave.block_track';
  static const blockArtist = 'wave.block_artist';

  static bool handles(String value) =>
      value == radio || value == blockTrack || value == blockArtist;
}

List<PopupMenuEntry<String>> waveTrackMenuItems() => const [
  PopupMenuItem(
    value: WaveTrackAction.radio,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.radio_rounded),
      title: Text('Запустить радио'),
    ),
  ),
  PopupMenuItem(
    value: WaveTrackAction.blockTrack,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.block_rounded),
      title: Text('Не предлагать трек'),
    ),
  ),
  PopupMenuItem(
    value: WaveTrackAction.blockArtist,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.person_off_outlined),
      title: Text('Не предлагать артиста'),
    ),
  ),
];

/// Runs a [WaveTrackAction]; returns false for values it does not own.
bool handleWaveTrackAction(
  BuildContext context,
  WidgetRef ref,
  UnifiedTrack track,
  String value,
) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  switch (value) {
    case WaveTrackAction.radio:
      messenger?.showSnackBar(
        SnackBar(content: Text('Радио по треку «${track.title}»')),
      );
      unawaited(ref.read(waveControllerProvider.notifier).startRadio(track));
      return true;
    case WaveTrackAction.blockTrack:
      unawaited(ref.read(waveBlocksProvider.notifier).blockTrack(track));
      messenger?.showSnackBar(
        const SnackBar(content: Text('Больше не предложим этот трек')),
      );
      return true;
    case WaveTrackAction.blockArtist:
      unawaited(
        ref.read(waveBlocksProvider.notifier).blockArtist(track.artist),
      );
      messenger?.showSnackBar(
        SnackBar(content: Text('Больше не предложим ${track.artist}')),
      );
      return true;
  }
  return false;
}

/// Compact "⋯" button with only the Wave actions, for rows without a menu.
class WaveTrackMenuButton extends ConsumerWidget {
  const WaveTrackMenuButton({required this.track, super.key});

  final UnifiedTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    tooltip: 'Ещё',
    icon: const Icon(Icons.more_vert_rounded),
    onSelected: (value) => handleWaveTrackAction(context, ref, track, value),
    itemBuilder: (_) => waveTrackMenuItems(),
  );
}
