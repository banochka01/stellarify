import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:resonance/domain/entities/json_converters.dart';
import 'package:resonance/domain/entities/music_enums.dart';

part 'resolved_audio_source.freezed.dart';
part 'resolved_audio_source.g.dart';

@freezed
abstract class ResolvedAudioSource with _$ResolvedAudioSource {
  const ResolvedAudioSource._();

  const factory ResolvedAudioSource({
    @UriStringConverter() required Uri streamUrl,
    required StreamProtocol protocol,
    String? codec,
    int? bitrate,

    /// Частота дискретизации и разрядность, если провайдер их сообщил
    /// (нужны для бейджа Hi-Res).
    int? sampleRate,
    int? bitDepth,

    /// Интегральная громкость (LUFS) и истинный пик (dBTP) из метаданных
    /// провайдера — для выравнивания громкости без анализа.
    double? loudnessLufs,
    double? truePeakDb,
    @Default(false) bool preview,
    DateTime? expiresAt,
    @Default(<String, String>{}) Map<String, String> headers,
  }) = _ResolvedAudioSource;

  factory ResolvedAudioSource.fromJson(Map<String, dynamic> json) =>
      _$ResolvedAudioSourceFromJson(json);

  bool isExpired([DateTime? now]) {
    final expiry = expiresAt;
    if (expiry == null) {
      return false;
    }
    return !expiry.isAfter(now ?? DateTime.now().toUtc());
  }
}
