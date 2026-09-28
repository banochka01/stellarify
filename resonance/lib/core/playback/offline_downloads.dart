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

/// Completed downloads live in application support storage, outside OS caches.
/// The manifest is replaced atomically only after the audio file is complete.
final class OfflineDownloads extends ChangeNotifier {
  factory OfflineDownloads({
    required ProviderRegistry providers,
    required Future<void> Function(MusicProvider) authorizeSource,
    Dio? dio,
    Future<Directory> Function()? directory,
  }) => OfflineDownloads._(
    providers,
    authorizeSource,
    dio ?? Dio(),
    directory ?? getApplicationSupportDirectory,
  );

  OfflineDownloads._(
    this._providers,
    this._authorizeSource,
    this._dio,
    this._directory,
  );

  static const maxBytes = 150 * 1024 * 1024;

  final ProviderRegistry _providers;
  final Future<void> Function(MusicProvider) _authorizeSource;
  final Dio _dio;
  final Future<Directory> Function() _directory;
  final Map<String, OfflineEntry> _entries = {};
  final Set<String> _downloading = {};
  Directory? _root;
  Future<void>? _loading;
  Future<void> _saving = Future<void>.value();

  List<OfflineEntry> get entries => List.unmodifiable(_entries.values);
  bool contains(String trackId) => _entries.containsKey(trackId);
  bool isDownloading(String trackId) => _downloading.contains(trackId);

  Future<void> initialize() => _loading ??= _load();

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
        if (p.basename(entry.fileName) != entry.fileName) continue;
        final file = File(p.join(root.path, entry.fileName));
        if (await file.exists() && await file.length() > 0) {
          _entries[entry.track.id] = entry;
        }
      }
      notifyListeners();
    } on Object {
      // A damaged manifest must not prevent normal online playback.
    }
  }

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
    return ResolvedAudioSource(
      streamUrl: Uri.file(file.path),
      protocol: StreamProtocol.progressive,
    );
  }

  TrackSource? downloadedSource(String trackId) => _entries[trackId]?.source;

  Future<void> download(UnifiedTrack track) async {
    await initialize();
    if (contains(track.id) || !_downloading.add(track.id)) return;
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
          final resolved = await resolver.resolve(source);
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
          if (type.contains('text/html') ||
              type.contains('application/json') ||
              await part.length() == 0 ||
              await part.length() > maxBytes) {
            throw const FormatException(
              'Источник вернул неподдерживаемый файл.',
            );
          }
          final file = await part.rename(p.join(_root!.path, name));
          part = null;
          final entry = OfflineEntry(
            track: track.copyWith(
              sources: track.sources
                  .map((item) => item.copyWith(metadata: const {}))
                  .toList(growable: false),
            ),
            source: source.copyWith(metadata: const {}),
            fileName: name,
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
          return;
        } on Object catch (error) {
          failure = error.toString();
          if (part != null && await part.exists()) await part.delete();
          part = null;
        }
      }
      throw StateError(failure ?? 'У трека нет доступного аудиофайла.');
    } finally {
      if (part != null && await part.exists()) await part.delete();
      _downloading.remove(track.id);
      notifyListeners();
    }
  }

  Future<void> remove(String trackId) async {
    await initialize();
    if (_downloading.contains(trackId)) return;
    final entry = _entries.remove(trackId);
    if (entry == null) return;
    try {
      await _save();
    } on Object {
      _entries[trackId] = entry;
      rethrow;
    }
    final file = File(p.join(_root!.path, entry.fileName));
    if (await file.exists()) await file.delete();
    notifyListeners();
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
  const OfflineEntry({
    required this.track,
    required this.source,
    required this.fileName,
  });

  final UnifiedTrack track;
  final TrackSource source;
  final String fileName;

  Map<String, dynamic> toJson() => {
    'track': track.toJson(),
    'source': source.toJson(),
    'fileName': fileName,
  };

  factory OfflineEntry.fromJson(Map<String, dynamic> json) => OfflineEntry(
    track: UnifiedTrack.fromJson(json['track'] as Map<String, dynamic>),
    source: TrackSource.fromJson(json['source'] as Map<String, dynamic>),
    fileName: json['fileName'] as String,
  );
}
