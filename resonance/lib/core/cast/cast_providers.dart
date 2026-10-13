import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/cast/cast_controller.dart';
import 'package:resonance/core/cast/chromecast_backend.dart';
import 'package:resonance/core/cast/dlna_backend.dart';
import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/domain/entities/playback_state.dart';

/// Протоколы передачи на этой платформе: Chromecast — только Android,
/// DLNA — Android и Windows. На iOS трансляции нет: AirPlay требует нативный
/// AVRoutePickerView, а без проверки на устройстве мы его не включаем.
final castBackendsProvider = Provider<List<CastBackend>>((ref) {
  if (Platform.isAndroid) return [ChromecastBackend(), DlnaBackend()];
  if (Platform.isWindows) return [DlnaBackend()];
  return const [];
});

final castControllerProvider = StateNotifierProvider<CastController, CastState>(
  (ref) {
    return CastController(
      ref.watch(castBackendsProvider),
      () => ref
          .read(playbackServiceProvider.future)
          .then<CastPlayback>(_ServiceCastPlayback.new),
    );
  },
);

final class _ServiceCastPlayback implements CastPlayback {
  const _ServiceCastPlayback(this._service);

  final PlaybackService _service;

  @override
  ResonancePlaybackState get state => _service.state;

  @override
  Stream<ResonancePlaybackState> get states => _service.states;

  @override
  Future<void> pause() => _service.pause();
}
