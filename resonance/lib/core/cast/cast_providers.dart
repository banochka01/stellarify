import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/cast/cast_controller.dart';
import 'package:resonance/core/cast/chromecast_backend.dart';
import 'package:resonance/core/cast/dlna_backend.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
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
      castUrl: (url) => issueCastUrl(url, (body) async {
        final response = await ref
            .read(resonanceHttpClientProvider)
            .dio
            .postUri<Map<String, dynamic>>(
              BackendEndpoint.requireCurrent().resolve(
                '/api/v1/playback/cast-ticket',
              ),
              data: body,
            );
        return response.data ?? const {};
      }),
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

  @override
  Future<void> next() => _service.next();

  @override
  Future<void> refreshExpiringSource() => _service.refreshExpiringSource();
}

/// Путь relay-потока сервера: такую ссылку клиента в сеть не отдаём, а
/// просим у сервера короткоживущий cast-тикет на тот же трек.
const _relayPathPrefix = '/api/v1/playback/soundcloud-relay/';

Future<Uri> issueCastUrl(
  Uri streamUrl,
  Future<Map<String, dynamic>> Function(Map<String, Object?> body) post,
) async {
  if (!streamUrl.path.startsWith(_relayPathPrefix)) return streamUrl;
  final json = await post({'streamUrl': streamUrl.toString()});
  final value = Uri.tryParse(json['streamUrl'] as String? ?? '');
  if (value == null || !value.isScheme('https') && !value.isScheme('http')) {
    throw const FormatException('Некорректный cast-тикет');
  }
  return value;
}
