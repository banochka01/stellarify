import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/platform/feature_flags.dart';
import 'package:resonance/features/rooms/dj_mode.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

/// DJ deck for the host or a DJ: pick the next track and crossfade into it
/// manually. Listeners keep using the room reaction bar.
class RoomDjPanel extends ConsumerStatefulWidget {
  const RoomDjPanel({required this.canControl, super.key});

  final bool canControl;

  @override
  ConsumerState<RoomDjPanel> createState() => _RoomDjPanelState();
}

class _RoomDjPanelState extends ConsumerState<RoomDjPanel> {
  double _fadeSeconds = 6;
  bool _deck = false;
  bool _fading = false;

  Future<void> _crossfade(UnifiedTrack track) async {
    setState(() => _fading = true);
    try {
      final PlaybackService service = await ref.read(
        playbackServiceProvider.future,
      );
      await const DjCrossfader().run(
        volume: service.state.volume,
        duration: Duration(milliseconds: (_fadeSeconds * 1000).round()),
        setVolume: service.setVolume,
        switchTrack: () => service.playTrack(track),
      );
    } finally {
      if (mounted) setState(() => _fading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canControl ||
        !ref.watch(featureEnabledProvider(FeatureFlag.djRooms))) {
      return const SizedBox.shrink();
    }
    final playback = ref.watch(playbackStateProvider).valueOrNull;
    final queue = playback?.queue ?? const <UnifiedTrack>[];
    final current = playback?.currentIndex ?? -1;
    final upcoming = [
      for (var index = current + 1; index < queue.length; index++) queue[index],
    ].take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const ValueKey('room-dj-mode'),
          contentPadding: EdgeInsets.zero,
          title: const Text('DJ-режим'),
          subtitle: const Text('Выбирайте следующий трек и сводите вручную'),
          value: _deck,
          onChanged: (value) => setState(() => _deck = value),
        ),
        if (_deck) ...[
          Row(
            children: [
              const Text('Кроссфейд'),
              Expanded(
                child: Slider(
                  value: _fadeSeconds,
                  min: 1,
                  max: 12,
                  divisions: 11,
                  label: '${_fadeSeconds.round()} с',
                  onChanged: (value) => setState(() => _fadeSeconds = value),
                ),
              ),
              Text('${_fadeSeconds.round()} с'),
            ],
          ),
          if (upcoming.isEmpty)
            const Text(
              'Добавьте треки в очередь, чтобы сводить их вручную.',
              style: TextStyle(color: ResonanceColors.muted),
            )
          else
            for (final track in upcoming)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(track.title, maxLines: 1),
                subtitle: Text(track.artist, maxLines: 1),
                trailing: FilledButton.tonal(
                  onPressed: _fading
                      ? null
                      : () => unawaited(_crossfade(track)),
                  child: const Text('Свести'),
                ),
              ),
        ],
      ],
    );
  }
}
