import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class RoomParticipant {
  const RoomParticipant({required this.id, required this.name});

  final String id;
  final String name;
}

class ListeningRoomState {
  const ListeningRoomState({
    this.connected = false,
    this.code,
    this.hostId,
    this.participants = const [],
    this.error,
    this.busy = false,
  });

  final bool connected;
  final String? code;
  final String? hostId;
  final List<RoomParticipant> participants;
  final String? error;
  final bool busy;

  bool get inRoom => code != null;

  ListeningRoomState copyWith({
    bool? connected,
    String? code,
    String? hostId,
    List<RoomParticipant>? participants,
    String? error,
    bool clearError = false,
    bool? busy,
    bool clearRoom = false,
  }) => ListeningRoomState(
    connected: connected ?? this.connected,
    code: clearRoom ? null : code ?? this.code,
    hostId: clearRoom ? null : hostId ?? this.hostId,
    participants: clearRoom ? const [] : participants ?? this.participants,
    error: clearError ? null : error ?? this.error,
    busy: busy ?? this.busy,
  );
}

final roomControllerProvider =
    StateNotifierProvider<RoomController, ListeningRoomState>((ref) {
      final controller = RoomController(ref);
      ref.onDispose(controller.dispose);
      return controller;
    });

class RoomController extends StateNotifier<ListeningRoomState> {
  RoomController(this._ref) : super(const ListeningRoomState()) {
    final endpoint = BackendEndpoint.requireCurrent();
    _socket = io.io(
      endpoint.toString(),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .disableReconnection()
          .build(),
    );
    _socket.onConnect((_) {
      _connecting = false;
      _reconnectTimer?.cancel();
      state = state.copyWith(connected: true, clearError: true);
      if (state.inRoom) unawaited(_resumeRoom());
    });
    _socket.onDisconnect((_) {
      _connecting = false;
      state = state.copyWith(connected: false);
      _scheduleReconnect();
    });
    _socket.onConnectError((_) {
      _connecting = false;
      state = state.copyWith(
        connected: false,
        error: 'Не удалось подключиться к серверу комнат.',
      );
      _scheduleReconnect();
    });
    _socket.on('room:state', _applyRoom);
    _socket.on('room:access-denied', (_) {
      state = state.copyWith(
        busy: false,
        error:
            'Создание комнат доступно в Plus и Family. Откройте раздел «Подписка».',
      );
    });
    unawaited(_connectAuthorized());
    unawaited(_watchPlayback());
  }

  final Ref _ref;
  late final io.Socket _socket;
  StreamSubscription<ResonancePlaybackState>? _playbackSubscription;
  PlaybackService? _playbackService;
  DateTime _lastPublishedAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastTrackId;
  bool? _lastPlaying;
  int _appliedVersion = -1;
  Timer? _reconnectTimer;
  bool _connecting = false;
  bool _disposed = false;
  String _participantName = 'Слушатель';

  bool get isHost => state.inRoom && state.hostId == _socket.id;

  Future<void> _connectAuthorized() async {
    if (_disposed || _connecting || _socket.connected) return;
    _connecting = true;
    try {
      final service = _ref.read(subscriptionServiceProvider);
      final headers = await service.headers();
      final authorization = headers['Authorization'];
      if (authorization == null) {
        throw StateError('Account authorization is required');
      }
      _socket.auth = {
        'authorization': authorization,
        'deviceId': headers['X-Device-Id'],
      };
      if (_disposed) return;
      _socket.connect();
    } on Object {
      _connecting = false;
      state = state.copyWith(
        error: 'Войдите в аккаунт с действующей подпиской.',
      );
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(
      const Duration(seconds: 3),
      () => unawaited(_connectAuthorized()),
    );
  }

  Future<void> _resumeRoom() async {
    final code = state.code;
    if (code == null || !_socket.connected || _disposed) return;
    _socket.emitWithAck(
      'room:join',
      {'code': code, 'name': _participantName},
      ack: (raw) {
        if (_disposed) return;
        final response = _stringMap(raw);
        if (response['ok'] == true) {
          _applyRoom(response['room']);
          return;
        }
        _appliedVersion = -1;
        state = state.copyWith(
          clearRoom: true,
          error: response['error']?.toString() ?? 'Комната больше недоступна.',
        );
      },
    );
  }

  Future<void> _watchPlayback() async {
    final service = await _ref.read(playbackServiceProvider.future);
    _playbackService = service;
    _playbackSubscription = service.states.listen(_publishPlayback);
  }

  void create(String name) {
    _participantName = name.trim().isEmpty ? 'Слушатель' : name.trim();
    _perform('room:create', {'name': _participantName});
  }

  void join(String code, String name) {
    _participantName = name.trim().isEmpty ? 'Слушатель' : name.trim();
    _perform('room:join', {
      'code': code.trim().toUpperCase(),
      'name': _participantName,
    });
  }

  void leave() {
    _socket.emitWithAck('room:leave', const {}, ack: (_) {});
    _appliedVersion = -1;
    _participantName = 'Слушатель';
    state = state.copyWith(clearRoom: true, clearError: true, busy: false);
  }

  void _perform(String event, Map<String, dynamic> payload) {
    if (!_socket.connected) {
      unawaited(_connectAuthorized());
      state = state.copyWith(
        error: 'Сервер ещё подключается. Попробуйте снова.',
      );
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    _socket.emitWithAck(
      event,
      payload,
      ack: (raw) {
        final response = _stringMap(raw);
        if (response['ok'] != true) {
          state = state.copyWith(
            busy: false,
            error:
                response['error']?.toString() ?? 'Не удалось открыть комнату.',
          );
          return;
        }
        _applyRoom(response['room']);
        state = state.copyWith(busy: false, clearError: true);
        final playback = _playbackService?.state;
        if (playback != null && isHost) _publishPlayback(playback, force: true);
      },
    );
  }

  void _applyRoom(dynamic raw) {
    final room = _stringMap(raw);
    final participants = (room['participants'] as List? ?? const [])
        .map(_stringMap)
        .map(
          (item) => RoomParticipant(
            id: item['id']?.toString() ?? '',
            name: item['name']?.toString() ?? 'Слушатель',
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
    state = state.copyWith(
      code: room['code']?.toString(),
      hostId: room['hostId']?.toString(),
      participants: participants,
      busy: false,
      clearError: true,
    );

    final playback = _stringMap(room['playback']);
    final version = (playback['version'] as num?)?.toInt() ?? -1;
    if (isHost || version <= _appliedVersion) return;
    _appliedVersion = version;
    unawaited(_applyPlayback(playback));
  }

  Future<void> _applyPlayback(Map<String, dynamic> playback) async {
    final rawTrack = playback['track'];
    if (rawTrack == null) return;
    final PlaybackService service =
        _playbackService ?? await _ref.read(playbackServiceProvider.future);
    final track = UnifiedTrack.fromJson(_stringMap(rawTrack));
    final paused = playback['paused'] != false;
    var positionMs = (playback['positionMs'] as num?)?.toInt() ?? 0;
    if (!paused) {
      final updatedAt = (playback['updatedAt'] as num?)?.toInt() ?? 0;
      positionMs += DateTime.now().millisecondsSinceEpoch - updatedAt;
    }

    if (service.state.currentTrack?.id != track.id) {
      await service.playTrack(track);
    }
    final target = Duration(milliseconds: positionMs.clamp(0, 1 << 31));
    if ((service.state.position - target).abs() >
        const Duration(milliseconds: 1200)) {
      await service.seek(target);
    }
    if (paused && service.state.playing) {
      await service.pause();
    } else if (!paused && !service.state.playing) {
      await service.play();
    }
  }

  void _publishPlayback(ResonancePlaybackState playback, {bool force = false}) {
    if (!isHost) return;
    final now = DateTime.now();
    final trackChanged = playback.currentTrack?.id != _lastTrackId;
    final playChanged = playback.playing != _lastPlaying;
    if (!force &&
        !trackChanged &&
        !playChanged &&
        now.difference(_lastPublishedAt) < const Duration(seconds: 3)) {
      return;
    }
    _lastPublishedAt = now;
    _lastTrackId = playback.currentTrack?.id;
    _lastPlaying = playback.playing;
    _socket.emit('playback:update', {
      'code': state.code,
      'track': playback.currentTrack?.toJson(),
      'paused': !playback.playing,
      'positionMs': playback.position.inMilliseconds,
    });
  }

  Map<String, dynamic> _stringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    unawaited(_playbackSubscription?.cancel());
    _socket.dispose();
    super.dispose();
  }
}
