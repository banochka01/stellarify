import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/player/track_action.dart';

/// Replaces the queue with [tracks] and starts playback. Returns how many
/// tracks were queued (metadata-only tracks are skipped).
Future<int> playTrackList(WidgetRef ref, Iterable<UnifiedTrack> tracks) async {
  final playable = playableQueueTracks(tracks);
  if (playable.isEmpty) return 0;
  final service = await ref.read(playbackServiceProvider.future);
  await service.setQueue(playable, autoplay: true);
  return playable.length;
}
