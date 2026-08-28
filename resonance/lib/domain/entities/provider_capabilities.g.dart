// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_capabilities.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProviderCapabilities _$ProviderCapabilitiesFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_ProviderCapabilities', json, ($checkedConvert) {
  final val = _ProviderCapabilities(
    supportsSearch: $checkedConvert(
      'supportsSearch',
      (v) => v as bool? ?? false,
    ),
    supportsAuthentication: $checkedConvert(
      'supportsAuthentication',
      (v) => v as bool? ?? false,
    ),
    supportsLibrary: $checkedConvert(
      'supportsLibrary',
      (v) => v as bool? ?? false,
    ),
    supportsPlaylists: $checkedConvert(
      'supportsPlaylists',
      (v) => v as bool? ?? false,
    ),
    supportsRecommendations: $checkedConvert(
      'supportsRecommendations',
      (v) => v as bool? ?? false,
    ),
    supportsDirectResolution: $checkedConvert(
      'supportsDirectResolution',
      (v) => v as bool? ?? false,
    ),
  );
  return val;
});

Map<String, dynamic> _$ProviderCapabilitiesToJson(
  _ProviderCapabilities instance,
) => <String, dynamic>{
  'supportsSearch': instance.supportsSearch,
  'supportsAuthentication': instance.supportsAuthentication,
  'supportsLibrary': instance.supportsLibrary,
  'supportsPlaylists': instance.supportsPlaylists,
  'supportsRecommendations': instance.supportsRecommendations,
  'supportsDirectResolution': instance.supportsDirectResolution,
};
