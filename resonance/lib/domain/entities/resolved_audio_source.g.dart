// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resolved_audio_source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ResolvedAudioSource _$ResolvedAudioSourceFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_ResolvedAudioSource', json, ($checkedConvert) {
      final val = _ResolvedAudioSource(
        streamUrl: $checkedConvert(
          'streamUrl',
          (v) => const UriStringConverter().fromJson(v as String),
        ),
        protocol: $checkedConvert(
          'protocol',
          (v) => $enumDecode(_$StreamProtocolEnumMap, v),
        ),
        codec: $checkedConvert('codec', (v) => v as String?),
        bitrate: $checkedConvert('bitrate', (v) => (v as num?)?.toInt()),
        sampleRate: $checkedConvert('sampleRate', (v) => (v as num?)?.toInt()),
        bitDepth: $checkedConvert('bitDepth', (v) => (v as num?)?.toInt()),
        loudnessLufs: $checkedConvert(
          'loudnessLufs',
          (v) => (v as num?)?.toDouble(),
        ),
        truePeakDb: $checkedConvert(
          'truePeakDb',
          (v) => (v as num?)?.toDouble(),
        ),
        preview: $checkedConvert('preview', (v) => v as bool? ?? false),
        expiresAt: $checkedConvert(
          'expiresAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
        headers: $checkedConvert(
          'headers',
          (v) =>
              (v as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, e as String),
              ) ??
              const <String, String>{},
        ),
      );
      return val;
    });

Map<String, dynamic> _$ResolvedAudioSourceToJson(
  _ResolvedAudioSource instance,
) => <String, dynamic>{
  'streamUrl': const UriStringConverter().toJson(instance.streamUrl),
  'protocol': _$StreamProtocolEnumMap[instance.protocol]!,
  'codec': instance.codec,
  'bitrate': instance.bitrate,
  'sampleRate': instance.sampleRate,
  'bitDepth': instance.bitDepth,
  'loudnessLufs': instance.loudnessLufs,
  'truePeakDb': instance.truePeakDb,
  'preview': instance.preview,
  'expiresAt': instance.expiresAt?.toIso8601String(),
  'headers': instance.headers,
};

const _$StreamProtocolEnumMap = {
  StreamProtocol.progressive: 'progressive',
  StreamProtocol.hls: 'hls',
  StreamProtocol.dash: 'dash',
};
