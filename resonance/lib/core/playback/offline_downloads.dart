import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/providers/common/provider_registry.dart';
import 'package:uuid/uuid.dart';

/// Откуда взялся файл. Ручные загрузки никогда не вытесняются; автокэш и
/// предзагрузка живут по LRU и могут быть удалены в любой момент.
enum OfflineKind { manual, auto, preload }

/// Занятое место по категориям «Хранилища».
@immutable
final class OfflineUsage {
  const OfflineUsage({
    this.downloadsBytes = 0,
    this.downloadsCount = 0,
    this.autoCacheBytes = 0,
    this.autoCacheCount = 0,
    this.lyricsBytes = 0,
    this.lyricsCount = 0,
  });

  final int downloadsBytes;
  final int downloadsCount;
  final int autoCacheBytes;
  final int autoCacheCount;
  final int lyricsBytes;
  final int lyricsCount;
}

/// Completed downloads live in application support storage, outside OS caches.
/// The manifest is replaced atomically only after the audio file is complete.
final class OfflineDownloads extends ChangeNotifier {
  factory OfflineDownloads({
    required ProviderRegistry providers,
    required Future<void> Function(MusicProvider) authorizeSource,
    Dio? dio,
    Future<Directory> Function()? directory,
    AudioQuality Function()? quality,
    Future<Map<String, dynamic>?> Function(UnifiedTrack)? fetchLyrics,
    DateTime Function()? now,
  }) => OfflineDownloads._(
    providers,
    authorizeSource,
    dio ?? Dio(),
    directory ?? getApplicationSupportDirectory,
    quality ?? () => AudioQuality.high,
    fetchLyrics,
    now ?? DateTime.now,
  );

  OfflineDownloads._(
    this._providers,
    this._authorizeSource,
    this._dio,
    this._directory,
    this._quality,
    this._fetchLyrics,
    this._now,
  );

  static const maxBytes = 150 * 1024 * 1024;

  /// Сколько предзагруженных «следующих» треков держим одновременно.
  static const maxPreloaded = 3;

  final ProviderRegistry _providers;
  final Future<void> Function(MusicProvider) _authorizeSource;
  final Dio _dio;
  final Future<Directory> Function() _directory;
  final AudioQuality Function() _quality;
  final Future<Map<String, dynamic>?> Function(UnifiedTrack)? _fetchLyrics;
  final DateTime Function() _now;
  final Map<String, OfflineEntry> _entries = {};
  final Set<String> _downloading = {};
  Directory? _root;
  Future<void>? _loading;
  Future<void> _saving = Future<void>.value();
  int _autoCacheLimitBytes = 2 * 1024 * 1024 * 1024;

  /// Ручные загрузки — то, что пользователь явно сохранил.
  List<OfflineEntry> get entries => List.unmodifiable(
    _entries.values.where((entry) => entry.kind == OfflineKind.manual),
  );

  /// Автокэш и предзагрузка.
  List<OfflineEntry> get cachedEntries => List.unmodifiable(
    _entries.values.where((entry) => entry.kind != OfflineKind.manual),
  );

  /// Всё, что можно сыграть без сети: сначала ручные, затем свежий кэш.
  List<OfflineEntry> get availableEntries {
    final manual = entries;
    final cached = cachedEntries.toList()
      ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    return List.unmodifiable([...manual, ...cached]);
  }

  bool contains(String trackId) => _entries.containsKey(trackId);
  bool isManual(String trackId) =>
      _entries[trackId]?.kind == OfflineKind.manual;
  bool isDownloading(String trackId) => _downloading.contains(trackId);

  int get autoCacheLimitBytes => _autoCacheLimitBytes;

  Future<void> setAutoCacheLimitBytes(int bytes) async {
    _autoCacheLimitBytes = bytes < 0 ? 0 : bytes;
    await initialize();
    await _evict();
  }

  Future<void> initialize() => _loading ??= _load();

  Directory get _lyricsDir => Directory(p.join(_root!.path, 'lyrics'));

  Future<void> _load() async {
    final root = Directory(p.join((await _directory()).path, 'offline_audio'));
    await root.create(recursive: true);
    _root = root;
    var manifest = File(p.join(root.path, 'downloads.json'));
    if (!await manifest.exists()) {
      manifest = File('${manifest.path}.bak');
    }
    if (!await manifest.exists()) return;
    try {
      final records =
          jsonDecode(await manifest.readAsString()) as List<dynamic>;
      for (final value in records) {
        final entry = OfflineEntry.fromJson(value as Map<String, dynamic>);
        if (!_safeName(entry.fileName)) continue;
        final file = File(p.join(root.path, entry.fileName));
        if (await file.exists() && await file.length() > 0) {
          _entries[entry.track.id] = entry.sizeBytes > 0
              ? entry
              : entry.copyWith(sizeBytes: await file.length());
        }
      }
      notifyListeners();
    } on Object {
      // A damaged manifest must not prevent normal online playback.
    }
  }

  static bool _safeName(String name) => p.basename(name) == name;

  Future<ResolvedAudioSource?> localSource(UnifiedTrack track) async {
    await initialize();
    final entry = _entries[track.id];
    if (entry == null) return null;
    final file = File(p.join(_root!.path, entry.fileName));
    if (!await file.exists() || await file.length() == 0) {
      _entries.remove(track.id);
      notifyListeners();
      return null;
    }
    _entries[track.id] = entry.copyWith(lastUsedAt: _now().toUtc());
    _saveQuietly();
    return ResolvedAudioSource(
      streamUrl: Uri.file(file.path),
      protocol: StreamProtocol.progressive,
    );
  }

  TrackSource? downloadedSource(String trackId) => _entries[trackId]?.source;

  /// Текст песни, сохранённый вместе с загрузкой (JSON ответа /lyrics).
  /// Возвращает null, если трек не скачан или текста нет.
  Future<Map<String, dynamic>?> lyricsFor(String trackId) async {
    await initialize();
    final name = _entries[trackId]?.lyricsFileName;
    if (name == null || !_safeName(name)) return null;
    final file = File(p.join(_lyricsDir.path, name));
    try {
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }

  /// Ручная загрузка. Уже закэшированный автоматически трек просто
  /// становится «скачанным» без повторной загрузки.
  Future<void> download(UnifiedTrack track) async {
    await initialize();
    final existing = _entries[track.id];
    if (existing != null) {
      if (existing.kind != OfflineKind.manual) {
        _entries[track.id] = existing.copyWith(kind: OfflineKind.manual);
        await _save();
        notifyListeners();
        if (existing.lyricsFileName == null) await _attachLyrics(track);
      }
      return;
    }
    await _fetch(track, OfflineKind.manual, rethrowErrors: true);
  }

  /// Автокэш (частые треки, «Моя волна»). Ошибки не выбрасываются.
  Future<bool> cacheAutomatically(UnifiedTrack track) async {
    await initialize();
    if (_autoCacheLimitBytes <= 0) return false;
    final existing = _entries[track.id];
    if (existing != null) {
      if (existing.kind == OfflineKind.preload) {
        _entries[track.id] = existing.copyWith(kind: OfflineKind.auto);
        await _save();
      }
      return true;
    }
    return _fetch(track, OfflineKind.auto, rethrowErrors: false);
  }

  /// Предзагрузка следующего трека очереди, пока играет текущий.
  Future<bool> preload(UnifiedTrack track) async {
    await initialize();
    if (_entries.containsKey(track.id)) {
      _entries[track.id] = _entries[track.id]!.copyWith(
        lastUsedAt: _now().toUtc(),
      );
      return true;
    }
    return _fetch(track, OfflineKind.preload, rethrowErrors: false);
  }

  Future<bool> _fetch(
    UnifiedTrack track,
    OfflineKind kind, {
    required bool rethrowErrors,
  }) async {
    if (!_downloading.add(track.id)) return false;
    notifyListeners();
    File? part;
    try {
      final sources = [
        if (track.preferredProvider != null)
          ...track.sources.where((s) => s.provider == track.preferredProvider),
        ...track.sources.where((s) => s.provider != track.preferredProvider),
      ];
      String? failure;
      for (final source in sources) {
        final resolver = _providers.resolverFor(source.provider);
        if (resolver == null) continue;
        try {
          await _authorizeSource(source.provider);
          final resolved = await resolver.resolve(source, quality: _quality());
          final url = resolved.streamUrl;
          if (resolved.preview ||
              resolved.protocol != StreamProtocol.progressive ||
              !url.isScheme('https') ||
              resolved.isExpired()) {
            failure = 'Источник не предоставляет прямой файл для загрузки.';
            continue;
          }
          final name = '${const Uuid().v4()}.audio';
          part = File(p.join(_root!.path, '$name.part'));
          final token = CancelToken();
          final response = await _dio.download(
            url.toString(),
            part.path,
            options: Options(
              headers: resolved.headers,
              followRedirects: resolved.headers.isEmpty,
            ),
            cancelToken: token,
            onReceiveProgress: (received, total) {
              if (received > maxBytes || total > maxBytes) {
                token.cancel('Audio file exceeds 150 MB');
              }
            },
          );
          final type = response.headers.value(Headers.contentTypeHeader) ?? '';
          final size = await part.length();
          if (type.contains('text/html') ||
              type.contains('application/json') ||
              size == 0 ||
              size > maxBytes) {
            throw const FormatException(
              'Источник вернул неподдерживаемый файл.',
            );
          }
          final file = await part.rename(p.join(_root!.path, name));
          part = null;
          final now = _now().toUtc();
          final entry = OfflineEntry(
            track: track.copyWith(
              sources: track.sources
                  .map((item) => item.copyWith(metadata: const {}))
                  .toList(growable: false),
            ),
            source: source.copyWith(metadata: const {}),
            fileName: name,
            kind: kind,
            sizeBytes: size,
            addedAt: now,
            lastUsedAt: now,
          );
          _entries[track.id] = entry;
          try {
            await _save();
          } on Object {
            _entries.remove(track.id);
            await file.delete();
            rethrow;
          }
          notifyListeners();
          if (kind != OfflineKind.preload) await _attachLyrics(track);
          await _evict(keep: track.id);
          return true;
        } on Object catch (error) {
          failure = error.toString();
          if (part != null && await part.exists()) await part.delete();
          part = null;
        }
      }
      final error = StateError(failure ?? 'У трека нет доступного аудиофайла.');
      if (rethrowErrors) throw error;
      return false;
    } finally {
      if (part != null && await part.exists()) await part.delete();
      _downloading.remove(track.id);
      notifyListeners();
    }
  }

  /// Подтягивает текст песни рядом с аудиофайлом. Без текста загрузка
  /// всё равно считается успешной.
  Future<void> _attachLyrics(UnifiedTrack track) async {
    final fetch = _fetchLyrics;
    if (fetch == null) return;
    try {
      final lyrics = await fetch(track);
      final entry = _entries[track.id];
      if (lyrics == null || entry == null) return;
      await _lyricsDir.create(recursive: true);
      final name = '${const Uuid().v4()}.json';
      await File(
        p.join(_lyricsDir.path, name),
      ).writeAsString(jsonEncode(lyrics), flush: true);
      _entries[track.id] = entry.copyWith(lyricsFileName: name);
      await _save();
      notifyListeners();
    } on Object {
      // Текст — бонус к загрузке, его отсутствие не ошибка.
    }
  }

  /// LRU: вытесняет давно не звучавший автокэш сверх лимита и лишнюю
  /// предзагрузку. Ручные загрузки не трогает.
  Future<void> _evict({String? keep}) async {
    final victims = <String>[];
    final preloaded =
        _entries.values.where((e) => e.kind == OfflineKind.preload).toList()
          ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    for (final entry in preloaded.skip(maxPreloaded)) {
      if (entry.track.id != keep) victims.add(entry.track.id);
    }
    final auto = _entries.values
        .where(
          (e) => e.kind == OfflineKind.auto && !victims.contains(e.track.id),
        )
        .toList();
    var total = auto.fold<int>(0, (sum, e) => sum + e.sizeBytes);
    // Сначала самые старые; только что добавленный уходит последним.
    auto.sort((a, b) {
      if (a.track.id == keep) return 1;
      if (b.track.id == keep) return -1;
      return a.lastUsedAt.compareTo(b.lastUsedAt);
    });
    for (final entry in auto) {
      if (total <= _autoCacheLimitBytes) break;
      victims.add(entry.track.id);
      total -= entry.sizeBytes;
    }
    if (victims.isEmpty) return;
    await _removeAll(victims);
  }

  Future<void> remove(String trackId) async {
    await initialize();
    if (_downloading.contains(trackId)) return;
    if (!_entries.containsKey(trackId)) return;
    await _removeAll([trackId]);
  }

  Future<void> _removeAll(Iterable<String> trackIds) async {
    final removed = <OfflineEntry>[];
    for (final id in trackIds) {
      if (_downloading.contains(id)) continue;
      final entry = _entries.remove(id);
      if (entry != null) removed.add(entry);
    }
    if (removed.isEmpty) return;
    try {
      await _save();
    } on Object {
      for (final entry in removed) {
        _entries[entry.track.id] = entry;
      }
      rethrow;
    }
    for (final entry in removed) {
      await _deleteQuietly(File(p.join(_root!.path, entry.fileName)));
      final lyrics = entry.lyricsFileName;
      if (lyrics != null && _safeName(lyrics)) {
        await _deleteQuietly(File(p.join(_lyricsDir.path, lyrics)));
      }
    }
    notifyListeners();
  }

  /// Удаляет все ручные загрузки.
  Future<void> clearDownloads() async {
    await initialize();
    await _removeAll(entries.map((e) => e.track.id).toList());
  }

  /// Удаляет весь автокэш и предзагрузку.
  Future<void> clearAutoCache() async {
    await initialize();
    await _removeAll(cachedEntries.map((e) => e.track.id).toList());
  }

  /// Удаляет сохранённые тексты песен; аудио остаётся.
  Future<void> clearLyrics() async {
    await initialize();
    for (final entry in _entries.values.toList()) {
      if (entry.lyricsFileName != null) {
        _entries[entry.track.id] = entry.copyWith(clearLyrics: true);
      }
    }
    await _save();
    final dir = _lyricsDir;
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } on Object {
        // Файл может быть занят; попробуем при следующей очистке.
      }
    }
    notifyListeners();
  }

  Future<OfflineUsage> usage() async {
    await initialize();
    var downloadsBytes = 0, downloadsCount = 0;
    var autoBytes = 0, autoCount = 0;
    for (final entry in _entries.values) {
      if (entry.kind == OfflineKind.manual) {
        downloadsBytes += entry.sizeBytes;
        downloadsCount++;
      } else {
        autoBytes += entry.sizeBytes;
        autoCount++;
      }
    }
    var lyricsBytes = 0, lyricsCount = 0;
    final dir = _lyricsDir;
    if (await dir.exists()) {
      await for (final file in dir.list()) {
        if (file is File) {
          lyricsBytes += await file.length();
          lyricsCount++;
        }
      }
    }
    return OfflineUsage(
      downloadsBytes: downloadsBytes,
      downloadsCount: downloadsCount,
      autoCacheBytes: autoBytes,
      autoCacheCount: autoCount,
      lyricsBytes: lyricsBytes,
      lyricsCount: lyricsCount,
    );
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Object {
      // Остаток на диске не должен ломать манифест.
    }
  }

  void _saveQuietly() {
    _save().catchError((Object _) {});
  }

  Future<void> _save() {
    final snapshot = jsonEncode(
      _entries.values.map((entry) => entry.toJson()).toList(),
    );
    final operation = _saving.then((_) => _writeSnapshot(snapshot));
    _saving = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _writeSnapshot(String snapshot) async {
    final manifest = File(p.join(_root!.path, 'downloads.json'));
    final temporary = File('${manifest.path}.${const Uuid().v4()}.tmp');
    await temporary.writeAsString(snapshot, flush: true);
    final backup = File('${manifest.path}.bak');
    if (Platform.isWindows && await manifest.exists()) {
      if (await backup.exists()) await backup.delete();
      await manifest.rename(backup.path);
    }
    await temporary.rename(manifest.path);
    if (await backup.exists()) await backup.delete();
  }
}

final class OfflineEntry {
  OfflineEntry({
    required this.track,
    required this.source,
    required this.fileName,
    this.kind = OfflineKind.manual,
    this.sizeBytes = 0,
    this.lyricsFileName,
    DateTime? addedAt,
    DateTime? lastUsedAt,
  }) : addedAt = addedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
       lastUsedAt =
           lastUsedAt ??
           addedAt ??
           DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  final UnifiedTrack track;
  final TrackSource source;
  final String fileName;
  final OfflineKind kind;
  final int sizeBytes;
  final String? lyricsFileName;
  final DateTime addedAt;
  final DateTime lastUsedAt;

  OfflineEntry copyWith({
    OfflineKind? kind,
    int? sizeBytes,
    String? lyricsFileName,
    bool clearLyrics = false,
    DateTime? lastUsedAt,
  }) => OfflineEntry(
    track: track,
    source: source,
    fileName: fileName,
    kind: kind ?? this.kind,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    lyricsFileName: clearLyrics ? null : lyricsFileName ?? this.lyricsFileName,
    addedAt: addedAt,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
  );

  Map<String, dynamic> toJson() => {
    'track': track.toJson(),
    'source': source.toJson(),
    'fileName': fileName,
    'kind': kind.name,
    'sizeBytes': sizeBytes,
    'lyricsFileName': ?lyricsFileName,
    'addedAt': addedAt.toIso8601String(),
    'lastUsedAt': lastUsedAt.toIso8601String(),
  };

  // Записи 3.x не знают kind/size/даты: это ручные загрузки.
  factory OfflineEntry.fromJson(Map<String, dynamic> json) => OfflineEntry(
    track: UnifiedTrack.fromJson(json['track'] as Map<String, dynamic>),
    source: TrackSource.fromJson(json['source'] as Map<String, dynamic>),
    fileName: json['fileName'] as String,
    kind: OfflineKind.values.firstWhere(
      (value) => value.name == json['kind'],
      orElse: () => OfflineKind.manual,
    ),
    sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    lyricsFileName: json['lyricsFileName'] as String?,
    addedAt: DateTime.tryParse(json['addedAt'] as String? ?? ''),
    lastUsedAt: DateTime.tryParse(json['lastUsedAt'] as String? ?? ''),
  );
}
