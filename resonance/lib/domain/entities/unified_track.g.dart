// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unified_track.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UnifiedTrack _$UnifiedTrackFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_UnifiedTrack', json, ($checkedConvert) {
  final val = _UnifiedTrack(
    id: $checkedConvert('id', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
    normalizedTitle: $checkedConvert('normalizedTitle', (v) => v as String),
    artist: $checkedConvert('artist', (v) => v as String),
    normalizedArtist: $checkedConvert('normalizedArtist', (v) => v as String),
    album: $checkedConvert('album', (v) => v as String?),
    duration: $checkedConvert(
      'duration',
      (v) =>
          const DurationMillisecondsConverter().fromJson((v as num?)?.toInt()),
    ),
    artworkUrl: $checkedConvert(
      'artworkUrl',
      (v) => const NullableUriStringConverter().fromJson(v as String?),
    ),
    sources: $checkedConvert(
      'sources',
      (v) =>
          (v as List<dynamic>?)
              ?.map((e) => TrackSource.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <TrackSource>[],
    ),
    preferredProvider: $checkedConvert(
      'preferredProvider',
      (v) => $enumDecodeNullable(_$MusicProviderEnumMap, v),
    ),
  );
  return val;
});

Map<String, dynamic> _$UnifiedTrackToJson(
  _UnifiedTrack instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'normalizedTitle': instance.normalizedTitle,
  'artist': instance.artist,
  'normalizedArtist': instance.normalizedArtist,
  'album': instance.album,
  'duration': const DurationMillisecondsConverter().toJson(instance.duration),
  'artworkUrl': const NullableUriStringConverter().toJson(instance.artworkUrl),
  'sources': instance.sources.map((e) => e.toJson()).toList(),
  'preferredProvider': _$MusicProviderEnumMap[instance.preferredProvider],
};

const _$MusicProviderEnumMap = {
  MusicProvider.youtube: 'youtube',
  MusicProvider.yandex: 'yandex',
  MusicProvider.soundcloud: 'soundcloud',
};
