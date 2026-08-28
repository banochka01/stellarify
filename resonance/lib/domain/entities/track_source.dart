import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:resonance/domain/entities/json_converters.dart';
import 'package:resonance/domain/entities/music_enums.dart';

part 'track_source.freezed.dart';
part 'track_source.g.dart';

@freezed
abstract class TrackSource with _$TrackSource {
  const factory TrackSource({
    required MusicProvider provider,
    required String externalId,
    @UriStringConverter() required Uri externalUrl,
    @Default(<String, dynamic>{}) Map<String, dynamic> metadata,
  }) = _TrackSource;

  factory TrackSource.fromJson(Map<String, dynamic> json) =>
      _$TrackSourceFromJson(json);
}
