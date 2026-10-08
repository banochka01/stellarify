import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/wave/wave_controller.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class RoomParticipant {
  const RoomParticipant({required this.id, required this.name});

  final String id;
  final String name;
}

class RoomQueueEntry {
  const RoomQueueEntry({
    required this.id,
    required this.track,
    required this.addedById,
    required this.addedByName,
    required this.voters,
  });

  final String id;
  final UnifiedTrack track;
  final String addedById;
  final String addedByName;
  final List<String> voters;

  int get votes => voters.length;
}

class ListeningRoomState {
  const ListeningRoomState({
    this.connected = false,
    this.code,
    this.hostId,
    this.selfId,
    this.participants = const [],
    this.queue = const [],
    this.error,
    this.busy = false,
    this.autoWave = true,
    this.autoWaveRunning = false,
  });

  final bool connected;
  final String? code;
  final String? hostId;
  final String? selfId;
  final List<RoomParticipant> participants;

  /// Очередь зала, уже отсортированная сервером по голосам.
  final List<RoomQueueEntry> queue;
  final String? error;
  final bool busy;

  /// Когда очередь зала пуста, ведущий сам подмешивает общую волну по
  /// вкусам всех участников.
  final bool autoWave;
  final bool autoWaveRunning;

  bool get inRoom => code != null;
  bool get isHost => inRoom && selfId != null && hostId == selfId;

  bool votedFor(RoomQueueEntry entry) =>
      selfId != null && entry.voters.contains(selfId);

  bool canRemove(RoomQueueEntry entry) =>
      isHost || (selfId != null && entry.addedById == selfId);

  ListeningRoomState copyWith({
    bool? connected,
    String? code,
    String? hostId,
    String? selfId,
    List<RoomParticipant>? participants,
    List<RoomQueueEntry>? queue,
    String? error,
    bool clearError = false,
    bool? busy,
    bool clearRoom = false,
    bool? autoWave,
    bool? autoWaveRunning,
  }) => ListeningRoomState(
    connected: connected ?? this.connected,
    code: clearRoom ? null : code ?? this.code,
    hostId: clearRoom ? null : hostId ?? this.hostId,
    selfId: selfId ?? this.selfId,
    participants: clearRoom ? const [] : participants ?? this.participants,
    queue: clearRoom ? const [] : queue ?? this.queue,
    error: clearError ? null : error ?? this.error,
    busy: busy ?? this.busy,
    autoWave: autoWave ?? this.autoWave,
    autoWaveRunning: clearRoom
        ? false
        : autoWaveRunning ?? this.autoWaveRunning,
  );
}

/// Зеркало состояния комнаты для пассивных виджетов (сайдбар, Stage):
/// чтение не создаёт [RoomController] и не открывает сокет.
final roomPresenceProvider = StateProvider<ListeningRoomState>(
  (ref) => const ListeningRoomState(),
);

final roomControllerProvider =
    StateNotifierProvider<RoomController, ListeningRoomState>((ref) {
      final controller = RoomController(ref);
      ref.onDispose(controller.dispose);
      return controller;
    });

class RoomController extends StateNotifier<ListeningRoomState> {
  RoomController(this._ref) : super(const ListeningRoomState()) {
    addListener(
      (value) => _ref.read(roomPresenceProvider.notifier).state = value,
      fireImmediately: false,
    );
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
      state = state.copyWith(
        connected: true,
        selfId: _socket.id,
        clearError: true,
      );
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
        error: 'Не удалось подтвердить доступ к комнате.',
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
  String? _autoAdvancedFor;
  String? _autoWaveFor;

  void setAutoWave(bool enabled) {
    state = state.copyWith(autoWave: enabled);
  }

  bool get isHost => state.inRoom && state.hostId == _socket.id;

  Future<void> _connectAuthorized() async {
    if (_disposed || _connecting || _socket.connected) return;
    _connecting = true;
    try {
      final service = _ref.read(clientIdentityServiceProvider);
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
        error: 'Войдите в аккаунт Resonance, чтобы использовать комнаты.',
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

  /// Добавляет трек в очередь зала. Возвращает текст ошибки или `null`.
  Future<String?> addToQueue(UnifiedTrack track) async {
    final response = await _request('room:queue-add', {
      'code': state.code,
      'track': track.toJson(),
    });
    return response['ok'] == true
        ? null
        : response['error']?.toString() ?? 'Не удалось добавить трек.';
  }

  Future<void> vote(String entryId) async {
    final response = await _request('room:queue-vote', {
      'code': state.code,
      'entryId': entryId,
    });
    _reportFailure(response, 'Голос не засчитан.');
  }

  Future<void> removeFromQueue(String entryId) async {
    final response = await _request('room:queue-remove', {
      'code': state.code,
      'entryId': entryId,
    });
    _reportFailure(response, 'Не удалось убрать трек.');
  }

  /// Ведущий включает трек, набравший больше всего голосов.
  Future<void> playNextFromQueue() async {
    if (!isHost) return;
    final snapshot = state.queue;
    final response = await _request('room:queue-next', {'code': state.code});
    if (!_reportFailure(response, 'Очередь зала пуста.')) return;
    final trackId = response['trackId']?.toString();
    final track =
        snapshot
            .where((entry) => entry.track.id == trackId)
            .firstOrNull
            ?.track ??
        snapshot.firstOrNull?.track;
    if (track == null) return;
    final PlaybackService service =
        _playbackService ?? await _ref.read(playbackServiceProvider.future);
    await service.playTrack(track);
  }

  bool _reportFailure(Map<String, dynamic> response, String fallback) {
    if (response['ok'] == true) return true;
    state = state.copyWith(error: response['error']?.toString() ?? fallback);
    return false;
  }

  Future<Map<String, dynamic>> _request(
    String event,
    Map<String, dynamic> payload,
  ) {
    if (!state.inRoom || !_socket.connected) {
      unawaited(_connectAuthorized());
      return Future.value(const {
        'ok': false,
        'error': 'Сервер комнат ещё подключается.',
      });
    }
    final completer = Completer<Map<String, dynamic>>();
    _socket.emitWithAck(
      event,
      payload,
      ack: (raw) {
        if (!completer.isCompleted) completer.complete(_stringMap(raw));
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => const {'ok': false, 'error': 'Сервер не ответил.'},
    );
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
      selfId: _socket.id,
      participants: participants,
      queue: parseRoomQueue(room['queue']),
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
    _maybeAdvanceQueue(playback);
    _maybeStartRoomWave(playback);
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

  /// За пару секунд до конца трека ведущий передаёт слово очереди зала,
  /// чтобы локальная очередь не успела переключиться первой.
  void _maybeAdvanceQueue(ResonancePlaybackState playback) {
    final track = playback.currentTrack;
    final duration = playback.duration;
    if (track == null ||
        state.queue.isEmpty ||
        !playback.playing ||
        duration < const Duration(seconds: 5) ||
        _autoAdvancedFor == track.id ||
        duration - playback.position > const Duration(milliseconds: 1500)) {
      return;
    }
    _autoAdvancedFor = track.id;
    unawaited(playNextFromQueue());
  }

  /// Если голосовать не за что и локальная очередь вот-вот кончится,
  /// ведущий дописывает в неё общую волну зала.
  void _maybeStartRoomWave(ResonancePlaybackState playback) {
    final track = playback.currentTrack;
    final duration = playback.duration;
    final code = state.code;
    if (!state.autoWave ||
        code == null ||
        track == null ||
        state.queue.isNotEmpty ||
        state.participants.length < 2 ||
        !playback.playing ||
        _autoWaveFor == track.id ||
        duration <= Duration.zero ||
        duration - playback.position > const Duration(seconds: 45)) {
      return;
    }
    final hasNext =
        playback.currentIndex + 1 < playback.queue.length ||
        playback.repeatMode != PlaybackRepeatMode.off;
    if (hasNext || _ref.read(waveControllerProvider).active) return;
    _autoWaveFor = track.id;
    unawaited(_startRoomWave(code));
  }

  Future<void> _startRoomWave(String code) async {
    state = state.copyWith(autoWaveRunning: true);
    try {
      final favorites =
          _ref.read(libraryControllerProvider).valueOrNull?.favorites ??
          const <UnifiedTrack>[];
      await _ref
          .read(waveControllerProvider.notifier)
          .start(taste: favorites, roomCode: code, append: true);
    } on Object {
      // Волна — бонус; зал продолжает работать и без неё.
    } finally {
      if (!_disposed) state = state.copyWith(autoWaveRunning: false);
    }
  }

  Map<String, dynamic> _stringMap(dynamic value) => _asStringMap(value);

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    unawaited(_playbackSubscription?.cancel());
    _socket.dispose();
    super.dispose();
  }
}

Map<String, dynamic> _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

/// Разбирает очередь из `room:state`; повреждённые записи пропускаются,
/// чтобы одна из них не ломала всю комнату.
List<RoomQueueEntry> parseRoomQueue(dynamic raw) {
  final queue = <RoomQueueEntry>[];
  for (final value in raw is List ? raw : const []) {
    final item = _asStringMap(value);
    final addedBy = _asStringMap(item['addedBy']);
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    try {
      queue.add(
        RoomQueueEntry(
          id: id,
          track: UnifiedTrack.fromJson(_asStringMap(item['track'])),
          addedById: addedBy['id']?.toString() ?? '',
          addedByName: addedBy['name']?.toString() ?? 'Слушатель',
          voters: [
            for (final voter in item['voters'] as List? ?? const [])
              voter.toString(),
          ],
        ),
      );
    } on Object {
      continue;
    }
  }
  return List.unmodifiable(queue);
}
