// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TrackSource _$TrackSourceFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_TrackSource', json, ($checkedConvert) {
      final val = _TrackSource(
        provider: $checkedConvert(
          'provider',
          (v) => $enumDecode(_$MusicProviderEnumMap, v),
        ),
        externalId: $checkedConvert('externalId', (v) => v as String),
        externalUrl: $checkedConvert(
          'externalUrl',
          (v) => const UriStringConverter().fromJson(v as String),
        ),
        metadata: $checkedConvert(
          'metadata',
          (v) => v as Map<String, dynamic>? ?? const <String, dynamic>{},
        ),
      );
      return val;
    });

Map<String, dynamic> _$TrackSourceToJson(_TrackSource instance) =>
    <String, dynamic>{
      'provider': _$MusicProviderEnumMap[instance.provider]!,
      'externalId': instance.externalId,
      'externalUrl': const UriStringConverter().toJson(instance.externalUrl),
      'metadata': instance.metadata,
    };

const _$MusicProviderEnumMap = {
  MusicProvider.youtube: 'youtube',
  MusicProvider.yandex: 'yandex',
  MusicProvider.soundcloud: 'soundcloud',
};
