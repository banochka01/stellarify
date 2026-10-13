import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
// Только сессия и устройство: discovery_service из пакета `cast` собран под
// старый bonsoir, поэтому обнаружение сделано здесь напрямую.
import 'package:cast/device.dart';
import 'package:cast/session.dart';
import 'package:resonance/core/cast/cast_controller.dart';

/// Chromecast (Android): поиск `_googlecast._tcp` через mDNS и протокол
/// Cast v2 со стандартным медиаприёмником.
final class ChromecastBackend implements CastBackend {
  /// Default Media Receiver от Google: играет поток по URL без своего приложения.
  static const _defaultReceiverAppId = 'CC1AD845';

  final _devices = <String, CastDevice>{};

  @override
  CastProtocol get protocol => CastProtocol.chromecast;

  @override
  Stream<List<CastTarget>> discover({
    Duration timeout = const Duration(seconds: 8),
  }) {
    final controller = StreamController<List<CastTarget>>();
    final targets = <String, CastTarget>{};
    BonsoirDiscovery? discovery;
    StreamSubscription<BonsoirDiscoveryEvent>? subscription;

    Future<void> finish() async {
      await subscription?.cancel();
      try {
        await discovery?.stop();
      } on Object {
        // Уже остановлено.
      }
      if (!controller.isClosed) await controller.close();
    }

    Future<void> run() async {
      try {
        final active = BonsoirDiscovery(type: '_googlecast._tcp');
        discovery = active;
        await active.initialize();
        subscription = active.eventStream?.listen((event) {
          switch (event) {
            case BonsoirDiscoveryServiceFoundEvent(:final service):
              unawaited(service.resolve(active.serviceResolver));
            case BonsoirDiscoveryServiceResolvedEvent(:final service):
              final host = service.hostAddress ?? service.hostname;
              if (host == null) return;
              final name = service.attributes['fn']?.trim().isNotEmpty == true
                  ? service.attributes['fn']!.trim()
                  : service.name;
              _devices[service.name] = CastDevice(
                serviceName: service.name,
                name: name,
                host: host,
                port: service.port,
                extras: service.attributes,
              );
              targets[service.name] = CastTarget(
                id: service.name,
                name: name,
                protocol: CastProtocol.chromecast,
              );
              if (!controller.isClosed) {
                controller.add(targets.values.toList(growable: false));
              }
            default:
              break;
          }
        });
        await active.start();
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
    final session = await CastSession.connect(
      'resonance-${DateTime.now().millisecondsSinceEpoch}',
      device,
      const Duration(seconds: 8),
    );
    final link = _ChromecastLink(session);
    await link._launch();
    return link;
  }
}

final class _ChromecastLink implements CastLink {
  _ChromecastLink(this._session) {
    _messages = _session.messageStream.listen((message) {
      if (message['type'] == 'MEDIA_STATUS') {
        final status = message['status'];
        if (status is List && status.isNotEmpty && status.first is Map) {
          final id = (status.first as Map)['mediaSessionId'];
          if (id is int) _mediaSessionId = id;
        }
      }
    });
  }

  final CastSession _session;
  late final StreamSubscription<Map<String, dynamic>> _messages;
  int? _mediaSessionId;
  var _requestId = 1;

  Future<void> _launch() async {
    final connected = _session.stateStream
        .firstWhere((state) => state == CastSessionState.connected)
        .timeout(const Duration(seconds: 12));
    _session.sendMessage(CastSession.kNamespaceReceiver, {
      'type': 'LAUNCH',
      'appId': ChromecastBackend._defaultReceiverAppId,
      'requestId': _requestId++,
    });
    await connected;
  }

  void _media(Map<String, dynamic> payload) {
    _session.sendMessage(CastSession.kNamespaceMedia, {
      ...payload,
      'requestId': _requestId++,
      if (_mediaSessionId != null && payload['type'] != 'LOAD')
        'mediaSessionId': _mediaSessionId,
    });
  }

  @override
  Future<void> load(CastMedia media) async {
    _mediaSessionId = null;
    _media({
      'type': 'LOAD',
      'autoplay': true,
      'currentTime': media.start.inMilliseconds / 1000,
      'media': {
        'contentId': media.url.toString(),
        'contentType': media.contentType,
        'streamType': 'BUFFERED',
        'metadata': {
          'metadataType': 3,
          'title': media.title,
          'artist': media.artist,
          if (media.artworkUrl != null)
            'images': [
              {'url': media.artworkUrl.toString()},
            ],
        },
      },
    });
  }

  @override
  Future<void> play() async => _media({'type': 'PLAY'});

  @override
  Future<void> pause() async => _media({'type': 'PAUSE'});

  @override
  Future<void> seek(Duration position) async =>
      _media({'type': 'SEEK', 'currentTime': position.inMilliseconds / 1000});

  @override
  Future<void> setVolume(double volume) async {
    _session.sendMessage(CastSession.kNamespaceReceiver, {
      'type': 'SET_VOLUME',
      'volume': {'level': volume.clamp(0, 1)},
      'requestId': _requestId++,
    });
  }

  @override
  Future<void> close() async {
    await _messages.cancel();
    try {
      _session.sendMessage(CastSession.kNamespaceReceiver, {
        'type': 'STOP',
        'requestId': _requestId++,
      });
    } on Object {
      // Сессия могла уже закрыться.
    }
    await _session.close();
  }
}
