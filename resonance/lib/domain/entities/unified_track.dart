import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:resonance/domain/entities/json_converters.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/track_source.dart';

part 'unified_track.freezed.dart';
part 'unified_track.g.dart';

@freezed
abstract class UnifiedTrack with _$UnifiedTrack {
  const UnifiedTrack._();

  const factory UnifiedTrack({
    required String id,
    required String title,
    required String normalizedTitle,
    required String artist,
    required String normalizedArtist,
    String? album,
    @DurationMillisecondsConverter() Duration? duration,
    @NullableUriStringConverter() Uri? artworkUrl,
    @Default(<TrackSource>[]) List<TrackSource> sources,
    MusicProvider? preferredProvider,
  }) = _UnifiedTrack;

  factory UnifiedTrack.fromJson(Map<String, dynamic> json) =>
      _$UnifiedTrackFromJson(json);

  TrackSource? sourceFor(MusicProvider provider) {
    for (final source in sources) {
      if (source.provider == provider) {
        return source;
      }
    }
    return null;
  }
}
