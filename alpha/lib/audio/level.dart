import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/playback_engine.dart';

/// Reads how loud the music is right now, 0…1.
///
/// Windows: the system audio-session meter of this process (native channel
/// in the runner). iOS: an `astats` filter in libmpv's chain. Anything else,
/// or a build without either, answers `null` and visuals fall back to their
/// own idle motion.
typedef LevelSampler = Future<double?> Function();

const _channel = MethodChannel('alpha/audio_level');

final levelSamplerProvider = Provider<LevelSampler?>((ref) {
  if (Platform.isWindows) {
    var broken = false;
    return () async {
      if (broken) return null;
      try {
        final peak = await _channel.invokeMethod<double>('peak');
        if (peak == null || peak < 0) return null;
        return peak.clamp(0.0, 1.0);
      } on MissingPluginException {
        broken = true;
        return null;
      } on Object {
        return null;
      }
    };
  }
  final engine = ref.watch(playbackEngineProvider);
  if (engine is MediaKitPlaybackEngine && MediaKitPlaybackEngine.levelMeter) {
    return engine.outputLevel;
  }
  return null;
});
