import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/provider_capabilities.dart';

const soundCloudProvider = MusicProvider.soundcloud;

const soundCloudStageOneCapabilities = ProviderCapabilities(
  supportsSearch: true,
  supportsDirectResolution: true,
);
