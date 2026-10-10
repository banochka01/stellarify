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

/// Роль в комнате: ведущий управляет всем, диджей — воспроизведением и
/// очередью, слушатель — предлагает треки, голосует, пишет в чат.
enum RoomRole {
  host('Ведущий'),
  dj('Диджей'),
  listener('Слушатель');

  const RoomRole(this.label);
  final String label;

  static RoomRole parse(Object? raw) => switch (raw) {
    'host' => RoomRole.host,
    'dj' => RoomRole.dj,
    _ => RoomRole.listener,
  };
}

class RoomParticipant {
  const RoomParticipant({
    required this.id,
    required this.name,
    this.role = RoomRole.listener,
  });

  final String id;
  final String name;
  final RoomRole role;
}

class RoomChatMessage {
  const RoomChatMessage({
    required this.id,
    required this.fromId,
    required this.fromName,
    required this.text,
    required this.at,
  });

  final String id;
  final String fromId;
  final String fromName;
  final String text;
  final DateTime at;

  static RoomChatMessage? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final text = json['text']?.toString() ?? '';
    if (id.isEmpty || text.isEmpty) return null;
    final from = _asStringMap(json['from']);
    return RoomChatMessage(
      id: id,
      fromId: from['id']?.toString() ?? '',
      fromName: from['name']?.toString() ?? 'Слушатель',
      text: text,
      at: DateTime.fromMillisecondsSinceEpoch(
        (json['at'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

/// Живая реакция: живёт несколько секунд поверх Stage и OBS-оверлея.
class RoomReaction {
  const RoomReaction({
    required this.id,
    required this.emoji,
    required this.fromName,
    required this.at,
  });

  final String id;
  final String emoji;
  final String fromName;
  final DateTime at;
}

/// Прошлая сессия комнаты из истории для «Переслушать».
class RoomSessionSummary {
  const RoomSessionSummary({
    required this.id,
    required this.code,
    required this.startedAt,
    required this.tracks,
  });

  final String id;
  final String code;
  final DateTime startedAt;
  final List<UnifiedTrack> tracks;
}

const roomReactionEmojis = ['🔥', '❤️', '👏', '😂', '😮', '🎉', '💃', '🙌'];
const roomChatMaxLength = 280;

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
    this.isPrivate = false,
    this.invite,
    this.played = const [],
    this.chat = const [],
    this.reactions = const [],
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

  /// Приватная комната пускает только по ссылке-приглашению.
  final bool isPrivate;

  /// Токен приглашения; известен ведущему и диджеям.
  final String? invite;

  /// Всё, что прозвучало в этой сессии, — можно сохранить себе одним тапом.
  final List<UnifiedTrack> played;
  final List<RoomChatMessage> chat;
  final List<RoomReaction> reactions;

  RoomRole get selfRole =>
      participants.where((item) => item.id == selfId).firstOrNull?.role ??
      (isHost ? RoomRole.host : RoomRole.listener);
  bool get canControl =>
      isHost || selfRole == RoomRole.host || selfRole == RoomRole.dj;

  bool get inRoom => code != null;
  bool get isHost => inRoom && selfId != null && hostId == selfId;

  bool votedFor(RoomQueueEntry entry) =>
      selfId != null && entry.voters.contains(selfId);

  bool canRemove(RoomQueueEntry entry) =>
      canControl || (selfId != null && entry.addedById == selfId);

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
    bool? isPrivate,
    String? invite,
    bool clearInvite = false,
    List<UnifiedTrack>? played,
    List<RoomChatMessage>? chat,
    List<RoomReaction>? reactions,
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
    isPrivate: clearRoom ? false : isPrivate ?? this.isPrivate,
    invite: clearRoom || clearInvite ? null : invite ?? this.invite,
    played: clearRoom ? const [] : played ?? this.played,
    chat: clearRoom ? const [] : chat ?? this.chat,
    reactions: clearRoom ? const [] : reactions ?? this.reactions,
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
    _socket.on('room:chat', _applyChat);
    _socket.on('room:reaction', _applyReaction);
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
  String? _pendingInvite;
  Timer? _reactionSweep;

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
      {
        'code': code,
        'name': _participantName,
        if (_pendingInvite != null) 'invite': _pendingInvite,
      },
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

  void create(String name, {bool private = false}) {
    _participantName = name.trim().isEmpty ? 'Слушатель' : name.trim();
    _pendingInvite = null;
    _perform('room:create', {'name': _participantName, 'private': private});
  }

  /// Принимает код комнаты или ссылку-приглашение целиком.
  void join(String codeOrLink, String name, {String? invite}) {
    _participantName = name.trim().isEmpty ? 'Слушатель' : name.trim();
    final parsed = parseRoomInvite(codeOrLink);
    final code = parsed?.code ?? codeOrLink.trim().toUpperCase();
    _pendingInvite = invite ?? parsed?.invite;
    _perform('room:join', {
      'code': code,
      'name': _participantName,
      if (_pendingInvite != null) 'invite': _pendingInvite,
    });
  }

  /// Ссылка-приглашение для приватной комнаты (или код для открытой).
  Future<String?> inviteLink() async {
    final code = state.code;
    if (code == null) return null;
    if (!state.isPrivate) return roomInviteLink(code);
    final response = await _request('room:invite', {'code': code});
    if (!_reportFailure(response, 'Приглашение недоступно.')) return null;
    final token = response['invite']?.toString();
    if (token != null) state = state.copyWith(invite: token);
    return roomInviteLink(code, invite: token);
  }

  Future<void> setPrivate(bool private) async {
    final response = await _request('room:set-private', {
      'code': state.code,
      'private': private,
    });
    if (!_reportFailure(response, 'Не удалось изменить доступ.')) return;
    final token = response['invite']?.toString();
    state = token == null
        ? state.copyWith(isPrivate: private, clearInvite: true)
        : state.copyWith(isPrivate: private, invite: token);
  }

  Future<void> setRole(String participantId, RoomRole role) async {
    final response = await _request('room:set-role', {
      'code': state.code,
      'participantId': participantId,
      'role': role.name,
    });
    _reportFailure(response, 'Не удалось изменить роль.');
  }

  /// Короткое сообщение в чат комнаты. Возвращает текст ошибки или `null`.
  Future<String?> sendChat(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.runes.length > roomChatMaxLength) {
      return 'Не длиннее $roomChatMaxLength символов.';
    }
    final response = await _request('room:chat', {
      'code': state.code,
      'text': trimmed,
    });
    return response['ok'] == true
        ? null
        : response['error']?.toString() ?? 'Сообщение не отправлено.';
  }

  Future<void> react(String emoji) async {
    if (!roomReactionEmojis.contains(emoji)) return;
    await _request('room:react', {'code': state.code, 'emoji': emoji});
  }

  /// Сохраняет всё, что звучало в комнате, отдельным плейлистом.
  Future<int> savePlayedToLibrary() async {
    final tracks = state.played;
    if (tracks.isEmpty) return 0;
    final library = _ref.read(libraryControllerProvider.notifier);
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final id = await library.createPlaylist(
      'Комната ${state.code ?? ''} · $day.$month',
    );
    for (final track in tracks) {
      await library.addToPlaylist(id, track);
    }
    return tracks.length;
  }

  /// Прошлые сессии комнат, где был пользователь.
  Future<List<RoomSessionSummary>> history() async {
    if (!_socket.connected) {
      unawaited(_connectAuthorized());
      return const [];
    }
    final completer = Completer<Map<String, dynamic>>();
    _socket.emitWithAck(
      'room:history',
      const <String, dynamic>{},
      ack: (raw) {
        if (!completer.isCompleted) completer.complete(_stringMap(raw));
      },
    );
    final response = await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => const {'ok': false},
    );
    return parseRoomHistory(response['sessions']);
  }

  /// «Переслушать»: ставит треки прошлой сессии в локальную очередь.
  Future<void> replay(RoomSessionSummary session) async {
    if (session.tracks.isEmpty) return;
    final PlaybackService service =
        _playbackService ?? await _ref.read(playbackServiceProvider.future);
    await service.setQueue(session.tracks, autoplay: true);
  }

  void leave() {
    _socket.emitWithAck('room:leave', const {}, ack: (_) {});
    _appliedVersion = -1;
    _participantName = 'Слушатель';
    _pendingInvite = null;
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

  /// Ведущий или диджей включает трек, набравший больше всего голосов.
  Future<void> playNextFromQueue() async {
    if (!state.canControl) return;
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
        final invite = response['invite']?.toString();
        state = state.copyWith(busy: false, clearError: true, invite: invite);
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
            role: RoomRole.parse(item['role']),
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
      isPrivate: room['private'] == true,
      played: parseRoomPlayed(room['played']),
      chat: parseRoomChat(room['chat']),
      busy: false,
      clearError: true,
    );

    final playback = _stringMap(room['playback']);
    final version = (playback['version'] as num?)?.toInt() ?? -1;
    if (version <= _appliedVersion) return;
    // Ведущий применяет только чужие изменения — например, «дальше» от диджея.
    if (isHost && playback['by'] == _socket.id) {
      _appliedVersion = version;
      return;
    }
    if (isHost && playback['by'] == null) return;
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

  void _applyChat(dynamic raw) {
    final message = RoomChatMessage.fromJson(_stringMap(raw));
    if (message == null || state.chat.any((item) => item.id == message.id)) {
      return;
    }
    final chat = [...state.chat, message];
    state = state.copyWith(
      chat: chat.length > 50 ? chat.sublist(chat.length - 50) : chat,
    );
  }

  void _applyReaction(dynamic raw) {
    final json = _stringMap(raw);
    final emoji = json['emoji']?.toString() ?? '';
    if (!roomReactionEmojis.contains(emoji)) return;
    final reaction = RoomReaction(
      id: json['id']?.toString() ?? '${DateTime.now().microsecondsSinceEpoch}',
      emoji: emoji,
      fromName: _stringMap(json['from'])['name']?.toString() ?? '',
      at: DateTime.now(),
    );
    final recent = [...state.reactions, reaction];
    state = state.copyWith(
      reactions: recent.length > 24
          ? recent.sublist(recent.length - 24)
          : recent,
    );
    try {
      _ref.read(obsOverlayControllerProvider.notifier).pushReaction(emoji);
    } on Object {
      // OBS-оверлей необязателен.
    }
    _reactionSweep ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => _sweepReactions(),
    );
  }

  void _sweepReactions() {
    final cutoff = DateTime.now().subtract(roomReactionLifetime);
    final alive = state.reactions
        .where((item) => item.at.isAfter(cutoff))
        .toList(growable: false);
    if (alive.length != state.reactions.length) {
      state = state.copyWith(reactions: alive);
    }
    if (alive.isEmpty) {
      _reactionSweep?.cancel();
      _reactionSweep = null;
    }
  }

  Map<String, dynamic> _stringMap(dynamic value) => _asStringMap(value);

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reactionSweep?.cancel();
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

const roomReactionLifetime = Duration(seconds: 4);

/// Схема ссылок-приглашений: `resonance://rooms?code=A1B2C3&invite=…`.
String roomInviteLink(String code, {String? invite}) => Uri(
  scheme: 'resonance',
  host: 'rooms',
  queryParameters: {'code': code, 'invite': ?invite},
).toString();

final _roomCodePattern = RegExp(r'^[0-9a-fA-F]{6}$');

/// Разбирает ссылку-приглашение или голый код комнаты.
({String code, String? invite})? parseRoomInvite(String raw) {
  final text = raw.trim();
  if (_roomCodePattern.hasMatch(text)) {
    return (code: text.toUpperCase(), invite: null);
  }
  final uri = Uri.tryParse(text);
  final code = uri?.queryParameters['code']?.trim() ?? '';
  if (!_roomCodePattern.hasMatch(code)) return null;
  final invite = uri?.queryParameters['invite']?.trim();
  return (
    code: code.toUpperCase(),
    invite: invite == null || invite.isEmpty ? null : invite,
  );
}

List<RoomChatMessage> parseRoomChat(dynamic raw) => List.unmodifiable([
  for (final value in raw is List ? raw : const [])
    ?RoomChatMessage.fromJson(_asStringMap(value)),
]);

List<UnifiedTrack> parseRoomPlayed(dynamic raw) {
  final tracks = <UnifiedTrack>[];
  final seen = <String>{};
  for (final value in raw is List ? raw : const []) {
    try {
      final track = UnifiedTrack.fromJson(
        _asStringMap(_asStringMap(value)['track']),
      );
      if (seen.add(track.id)) tracks.add(track);
    } on Object {
      continue;
    }
  }
  return List.unmodifiable(tracks);
}

List<RoomSessionSummary> parseRoomHistory(dynamic raw) {
  final sessions = <RoomSessionSummary>[];
  for (final value in raw is List ? raw : const []) {
    final item = _asStringMap(value);
    final id = item['id']?.toString() ?? '';
    final tracks = parseRoomPlayed(item['tracks']);
    if (id.isEmpty || tracks.isEmpty) continue;
    sessions.add(
      RoomSessionSummary(
        id: id,
        code: item['code']?.toString() ?? '',
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          (item['startedAt'] as num?)?.toInt() ?? 0,
        ),
        tracks: tracks,
      ),
    );
  }
  return List.unmodifiable(sessions);
}
