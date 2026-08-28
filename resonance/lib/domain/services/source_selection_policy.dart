import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';

final class SourceSelectionPolicy {
  SourceSelectionPolicy({List<MusicProvider>? fallbackOrder})
    : fallbackOrder = List.unmodifiable(
        fallbackOrder ??
            const [
              MusicProvider.yandex,
              MusicProvider.soundcloud,
              MusicProvider.youtube,
            ],
      );

  final List<MusicProvider> fallbackOrder;

  List<TrackSource> orderedSources(
    UnifiedTrack track, {
    MusicProvider? lastSuccessfulProvider,
    Set<MusicProvider> disabledProviders = const {},
  }) {
    final providerOrder = <MusicProvider>[
      ?track.preferredProvider,
      ?lastSuccessfulProvider,
      ...fallbackOrder,
    ];
    final seenProviders = <MusicProvider>{};
    final result = <TrackSource>[];

    for (final provider in providerOrder) {
      if (!seenProviders.add(provider) ||
          disabledProviders.contains(provider)) {
        continue;
      }
      final source = track.sourceFor(provider);
      if (source != null) {
        result.add(source);
      }
    }

    for (final source in track.sources) {
      if (seenProviders.add(source.provider) &&
          !disabledProviders.contains(source.provider)) {
        result.add(source);
      }
    }
    return result;
  }
}
