import 'package:freezed_annotation/freezed_annotation.dart';

part 'provider_capabilities.freezed.dart';
part 'provider_capabilities.g.dart';

@freezed
abstract class ProviderCapabilities with _$ProviderCapabilities {
  const factory ProviderCapabilities({
    @Default(false) bool supportsSearch,
    @Default(false) bool supportsAuthentication,
    @Default(false) bool supportsLibrary,
    @Default(false) bool supportsPlaylists,
    @Default(false) bool supportsRecommendations,
    @Default(false) bool supportsDirectResolution,
  }) = _ProviderCapabilities;

  factory ProviderCapabilities.fromJson(Map<String, dynamic> json) =>
      _$ProviderCapabilitiesFromJson(json);
}
