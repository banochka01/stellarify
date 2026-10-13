import 'package:resonance/core/networking/network_status.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';

/// Выбор качества потока в настройках.
enum StreamQualityMode {
  /// Wi‑Fi — основное качество из настроек, мобильная сеть — экономное.
  auto('Авто'),
  high('Высокое'),

  /// Lossless там, где провайдер его отдаёт; иначе — лучшее доступное.
  lossless('Lossless');

  const StreamQualityMode(this.label);

  final String label;

  static StreamQualityMode byName(String? name) =>
      values.firstWhere((mode) => mode.name == name, orElse: () => auto);
}

/// Качество, которое запрашиваем у провайдера с учётом сети.
///
/// * «Авто»: Wi‑Fi — [wifiQuality], мобильная сеть — [mobileQuality].
/// * «Высокое»: всегда high; в мобильной сети не выше [mobileQuality],
///   если только [allowHighOnMobile].
/// * «Lossless»: Wi‑Fi — lossless; в мобильной сети lossless не тянем
///   (трафик ×5–10), а играем high.
AudioQuality resolveStreamQuality({
  required StreamQualityMode mode,
  required NetworkKind network,
  AudioQuality wifiQuality = AudioQuality.high,
  AudioQuality mobileQuality = AudioQuality.medium,
  bool allowHighOnMobile = true,
}) {
  final mobile = network == NetworkKind.mobile;
  switch (mode) {
    case StreamQualityMode.auto:
      return mobile ? mobileQuality : wifiQuality;
    case StreamQualityMode.high:
      if (!mobile || allowHighOnMobile) return AudioQuality.high;
      return mobileQuality;
    case StreamQualityMode.lossless:
      if (!mobile) return AudioQuality.lossless;
      return allowHighOnMobile ? AudioQuality.high : mobileQuality;
  }
}

/// Бейдж формата в плеере.
enum AudioFormatBadge {
  mp3('MP3'),
  aac('AAC'),
  opus('OPUS'),
  flac('FLAC'),
  hiRes('Hi-Res');

  const AudioFormatBadge(this.label);

  final String label;

  bool get lossless => this == flac || this == hiRes;
}

/// Формат по данным resolved source; `null`, если сервер не сообщил кодек.
AudioFormatBadge? audioFormatBadge(ResolvedAudioSource? source) {
  if (source == null) return null;
  final codec = source.codec?.toLowerCase().trim() ?? '';
  final path = source.streamUrl.path.toLowerCase();
  bool has(String value) => codec.contains(value);

  final lossless =
      has('flac') ||
      has('alac') ||
      has('wav') ||
      has('pcm') ||
      (codec.isEmpty && (path.endsWith('.flac') || path.endsWith('.wav')));
  if (lossless) {
    final sampleRate = source.sampleRate ?? 0;
    final bitDepth = source.bitDepth ?? 0;
    final hiRes = sampleRate > 48000 || bitDepth > 16;
    return hiRes ? AudioFormatBadge.hiRes : AudioFormatBadge.flac;
  }
  if (has('mp3') || has('mpeg') || (codec.isEmpty && path.endsWith('.mp3'))) {
    return AudioFormatBadge.mp3;
  }
  if (has('aac') || has('mp4a') || has('m4a')) return AudioFormatBadge.aac;
  if (has('opus') || has('vorbis') || has('webm')) {
    return AudioFormatBadge.opus;
  }
  return null;
}

/// Подпись для бейджа: «FLAC · 24/96», «AAC · 256».
String? audioFormatLabel(ResolvedAudioSource? source) {
  final badge = audioFormatBadge(source);
  if (badge == null || source == null) return null;
  if (badge.lossless) {
    final rate = source.sampleRate;
    final depth = source.bitDepth;
    if (rate != null && depth != null) {
      final khz = rate % 1000 == 0
          ? '${rate ~/ 1000}'
          : (rate / 1000).toStringAsFixed(1);
      return '${badge.label} · $depth/$khz';
    }
    return badge.label;
  }
  final bitrate = source.bitrate;
  if (bitrate != null && bitrate > 0) {
    final kbps = bitrate >= 1000 ? (bitrate / 1000).round() : bitrate;
    return '${badge.label} · $kbps';
  }
  return badge.label;
}
