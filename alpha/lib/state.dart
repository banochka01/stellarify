import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/offline/offline_controller.dart';
import 'package:resonance/features/wave/wave_controller.dart';

/// Catalogs α searches. YouTube is metadata-only and never playable.
const searchProviders = [
  MusicProvider.yandex,
  MusicProvider.soundcloud,
  MusicProvider.spotify,
  MusicProvider.vk,
];

final class SearchOutcome {
  const SearchOutcome(this.tracks, this.failed);

  final List<UnifiedTrack> tracks;

  /// Providers that answered with an error (not signed in, offline…).
  final List<MusicProvider> failed;
}

/// Searches every catalog in parallel and interleaves the answers, so the
/// first screen is not owned by one provider. Duplicates collapse.
final searchProvider = FutureProvider.autoDispose.family<SearchOutcome, String>(
  (ref, query) async {
    final text = query.trim();
    if (text.isEmpty) return const SearchOutcome([], []);
    final registry = ref.watch(providerRegistryProvider);
    final lists = <List<UnifiedTrack>>[];
    final failed = <MusicProvider>[];
    await Future.wait([
      for (final provider in searchProviders)
        if (registry.catalogFor(provider) case final catalog?)
          catalog
              .searchTracks(text, limit: 20)
              .timeout(const Duration(seconds: 15))
              .then<void>((found) {
                lists.add(found);
              })
              .catchError((Object _) {
                failed.add(provider);
              }),
    ]);
    return SearchOutcome(interleave(lists), failed);
  },
);

List<UnifiedTrack> interleave(List<List<UnifiedTrack>> lists) {
  final seen = <String>{};
  final result = <UnifiedTrack>[];
  final longest = lists.fold(
    0,
    (max, list) => list.length > max ? list.length : max,
  );
  for (var i = 0; i < longest; i++) {
    for (final list in lists) {
      if (i >= list.length) continue;
      final track = list[i];
      final key = '${track.normalizedArtist}|${track.normalizedTitle}';
      if (seen.add(key)) result.add(track);
    }
  }
  return result;
}

/// More by the artist of a track, for the end of the player.
final artistTracksProvider = FutureProvider.autoDispose
    .family<List<UnifiedTrack>, String>((ref, artist) async {
      final outcome = await ref.watch(searchProvider(artist).future);
      final needle = artist.toLowerCase();
      return outcome.tracks
          .where((track) => track.artist.toLowerCase().contains(needle))
          .take(12)
          .toList(growable: false);
    });

final favoriteIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(
        libraryControllerProvider.select(
          (value) => value.valueOrNull?.favoriteIds,
        ),
      ) ??
      const {};
});

/// Plays [tracks] from [index]. Leaving Wave is explicit: a list is a list.
Future<void> playList(
  WidgetRef ref,
  List<UnifiedTrack> tracks, {
  int index = 0,
}) async {
  if (tracks.isEmpty) return;
  final wave = ref.read(waveControllerProvider);
  if (wave.active) await ref.read(waveControllerProvider.notifier).stop();
  final service = await ref.read(playbackServiceProvider.future);
  await service.setQueue(tracks, startIndex: index, autoplay: true);
}

Future<void> togglePlay(WidgetRef ref) async {
  final service = await ref.read(playbackServiceProvider.future);
  if (service.state.playing) {
    await service.pause();
  } else if (service.state.currentTrack != null) {
    await service.play();
  }
}

Future<void> toggleFavorite(WidgetRef ref, UnifiedTrack track) =>
    ref.read(libraryControllerProvider.notifier).toggleFavorite(track);

/// Fire-and-forget with a visible error instead of a silent failure.
void run(BuildContext context, Future<void> Function() action) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  unawaited(
    action().catchError((Object error) {
      messenger?.showSnackBar(SnackBar(content: Text(_humane(error))));
    }),
  );
}

String _humane(Object error) {
  final text = error.toString();
  if (text.contains('SocketException') || text.contains('connection')) {
    return 'Нет связи с сервером';
  }
  return text.length > 140 ? '${text.substring(0, 140)}…' : text;
}

/// Applies the chosen stream quality (and network-aware auto mode) to the
/// player. The main app does this in its offline coordinator, which α skips
/// because it also runs background caching.
final qualitySyncProvider = FutureProvider<void>((ref) async {
  final service = await ref.watch(playbackServiceProvider.future);
  service.setQuality(ref.read(effectiveQualityProvider));
  ref.listen(effectiveQualityProvider, (_, quality) {
    service.setQuality(quality);
  });
});
