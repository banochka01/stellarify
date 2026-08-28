import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/provider_capabilities.dart';

const yandexProvider = MusicProvider.yandex;

const yandexStageOneCapabilities = ProviderCapabilities(
  supportsSearch: true,
  supportsAuthentication: true,
  supportsDirectResolution: true,
);
