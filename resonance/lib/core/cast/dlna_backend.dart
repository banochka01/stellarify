import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:dlna_dart/xmlParser.dart';
import 'package:resonance/core/cast/cast_controller.dart';

/// DLNA/UPnP (Windows, Android): поиск MediaRenderer через SSDP и
/// управление через AVTransport/RenderingControl.
final class DlnaBackend implements CastBackend {
  final _devices = <String, DLNADevice>{};

  @override
  CastProtocol get protocol => CastProtocol.dlna;

  @override
  Stream<List<CastTarget>> discover({
    Duration timeout = const Duration(seconds: 8),
  }) {
    final controller = StreamController<List<CastTarget>>();
    final manager = DLNAManager();
    StreamSubscription<Map<String, DLNADevice>>? subscription;

    Future<void> finish() async {
      await subscription?.cancel();
      try {
        manager.stop();
      } on Object {
        // Сокеты уже закрыты.
      }
      if (!controller.isClosed) await controller.close();
    }

    Future<void> run() async {
      try {
        final devices = await manager.start();
        subscription = devices.devices.stream.listen((found) {
          final targets = <CastTarget>[];
          for (final entry in found.entries) {
            final info = entry.value.info;
            final renderer =
                info.deviceType.contains('MediaRenderer') ||
                info.serviceList.any(
                  (service) =>
                      service is Map &&
                      '${service['serviceId']}'.contains('AVTransport'),
                );
            if (!renderer) continue;
            _devices[entry.key] = entry.value;
            targets.add(
              CastTarget(
                id: entry.key,
                name: info.friendlyName.trim().isEmpty
                    ? Uri.tryParse(entry.key)?.host ?? entry.key
                    : info.friendlyName.trim(),
                protocol: CastProtocol.dlna,
              ),
            );
          }
          if (!controller.isClosed) controller.add(targets);
        });
        await Future<void>.delayed(timeout);
      } on Object catch (error) {
        if (!controller.isClosed) controller.addError(error);
      } finally {
        await finish();
      }
    }

    controller.onListen = () => unawaited(run());
    controller.onCancel = finish;
    return controller.stream;
  }

  @override
  Future<CastLink> connect(CastTarget target) async {
    final device = _devices[target.id];
    if (device == null) throw StateError('Устройство пропало из сети');
    return _DlnaLink(device);
  }
}

final class _DlnaLink implements CastLink {
  _DlnaLink(this._device);

  final DLNADevice _device;

  @override
  Future<void> load(CastMedia media) async {
    await _device
        .setUrl(
          media.url.toString(),
          title: '${media.artist} — ${media.title}',
          type: _mime(media.contentType),
        )
        .timeout(const Duration(seconds: 8));
    await _device.play().timeout(const Duration(seconds: 8));
    if (media.start > const Duration(seconds: 2)) {
      try {
        await seek(media.start);
      } on Object {
        // Не все рендереры умеют перематывать до начала воспроизведения.
      }
    }
  }

  static PlayType _mime(String contentType) => switch (contentType) {
    'audio/flac' => AudioMime.xFlac,
    'audio/mp4' => AudioMime.mp4,
    'audio/mpeg' => AudioMime.mpeg,
    _ => AudioMime.any,
  };

  @override
  Future<void> play() => _device.play().timeout(const Duration(seconds: 6));

  @override
  Future<void> pause() => _device.pause().timeout(const Duration(seconds: 6));

  @override
  Future<void> seek(Duration position) =>
      _device.seek(_hms(position)).timeout(const Duration(seconds: 6));

  @override
  Future<void> setVolume(double volume) => _device
      .volume((volume.clamp(0, 1) * 100).round())
      .timeout(const Duration(seconds: 6));

  @override
  Future<void> close() async {
    try {
      await _device.stop().timeout(const Duration(seconds: 4));
    } finally {
      _device.dispose();
    }
  }

  static String _hms(Duration value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.inHours)}:${two(value.inMinutes % 60)}:'
        '${two(value.inSeconds % 60)}';
  }
}
