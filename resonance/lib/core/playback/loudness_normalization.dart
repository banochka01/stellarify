import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';

/// Режим выравнивания громкости между треками разных провайдеров.
enum LoudnessNormalizationMode {
  off('Выкл'),
  track('Трек'),
  album('Альбом');

  const LoudnessNormalizationMode(this.label);

  final String label;

  static LoudnessNormalizationMode byName(String? name) =>
      values.firstWhere((mode) => mode.name == name, orElse: () => track);
}

/// Откуда взялась оценка громкости трека.
enum LoudnessOrigin { provider, measured }

/// Интегральная громкость трека (LUFS) и, если известен, истинный пик (dBTP).
final class LoudnessStats {
  const LoudnessStats({
    required this.integratedLufs,
    this.truePeakDb,
    this.origin = LoudnessOrigin.measured,
    this.album,
  });

  final double integratedLufs;
  final double? truePeakDb;
  final LoudnessOrigin origin;

  /// Нормализованное название альбома: по нему собирается альбомный гейн.
  final String? album;

  Map<String, Object?> toJson() => {
    'lufs': integratedLufs,
    if (truePeakDb != null) 'peak': truePeakDb,
    'origin': origin.name,
    if (album != null) 'album': album,
  };

  static LoudnessStats? fromJson(Object? json) {
    if (json is! Map) return null;
    final lufs = json['lufs'];
    if (lufs is! num || !isPlausibleLufs(lufs.toDouble())) return null;
    final peak = json['peak'];
    return LoudnessStats(
      integratedLufs: lufs.toDouble(),
      truePeakDb: peak is num ? peak.toDouble() : null,
      origin: json['origin'] == LoudnessOrigin.provider.name
          ? LoudnessOrigin.provider
          : LoudnessOrigin.measured,
      album: json['album'] as String?,
    );
  }
}

/// Целевая громкость: как у большинства стримингов (-14 LUFS).
const loudnessTargetLufs = -14.0;

/// Ограничения гейна: тихие треки поднимаем осторожно, громкие — смелее.
const loudnessMaxBoostDb = 6.0;
const loudnessMaxCutDb = -15.0;

/// Пик после усиления не должен подходить к 0 dBFS ближе этого запаса.
const loudnessPeakCeilingDb = -1.0;

bool isPlausibleLufs(double value) =>
    value.isFinite && value > -70 && value < 0;

/// Громкость альбома по громкостям его треков: усреднение энергии, а не
/// децибел, как в ReplayGain/EBU R128.
double? albumLoudness(Iterable<double> trackLufs) {
  final values = trackLufs.where(isPlausibleLufs).toList(growable: false);
  if (values.isEmpty) return null;
  final energy =
      values.map((lufs) => math.pow(10, lufs / 10)).reduce((a, b) => a + b) /
      values.length;
  return 10 * math.log(energy) / math.ln10;
}

/// Сколько измеренных треков альбома нужно для альбомного гейна.
const minAlbumTracks = 3;

bool albumLoudnessReliable(List<LoudnessStats> known) =>
    known.isNotEmpty &&
    (known.every((stats) => stats.origin == LoudnessOrigin.provider) ||
        known.length >= minAlbumTracks);

/// Гейн в дБ, который нужно применить к треку, или `null`, если оценки нет
/// (тогда плеер играет как есть или включает динамический фильтр).
double? normalizationGainDb({
  required LoudnessNormalizationMode mode,
  LoudnessStats? track,
  double? albumLufs,
  double targetLufs = loudnessTargetLufs,
}) {
  if (mode == LoudnessNormalizationMode.off) return null;
  final measured = mode == LoudnessNormalizationMode.album && albumLufs != null
      ? albumLufs
      : track?.integratedLufs;
  if (measured == null || !isPlausibleLufs(measured)) return null;
  var gain = (targetLufs - measured).clamp(
    loudnessMaxCutDb,
    loudnessMaxBoostDb,
  );
  if (gain > 0) {
    // Без лимитера поднимать можно только при известном истинном пике,
    // и только так, чтобы он остался ниже потолка. Пик неизвестен — не
    // усиливаем вовсе: иначе громкий мастеринг клиппирует.
    final peak = track?.truePeakDb;
    gain = peak != null && peak.isFinite
        ? math.min(gain, math.max(0, loudnessPeakCeilingDb - peak))
        : 0;
  }
  return double.parse(gain.toStringAsFixed(2));
}

/// Гейн в дБ → множитель громкости libmpv. Громкость mpv кубическая:
/// амплитуда = (volume / 100)³, поэтому множитель = 10^(дБ / 60).
double gainDbToVolumeFactor(double? gainDb) =>
    gainDb == null ? 1 : math.pow(10, gainDb / 60).toDouble();

/// Оценка громкости из метаданных провайдера, если сервер её передал.
LoudnessStats? providerLoudness(
  ResolvedAudioSource source,
  UnifiedTrack track,
) {
  final lufs = source.loudnessLufs;
  if (lufs == null || !isPlausibleLufs(lufs)) return null;
  return LoudnessStats(
    integratedLufs: lufs,
    truePeakDb: source.truePeakDb,
    origin: LoudnessOrigin.provider,
    album: loudnessAlbumKey(track),
  );
}

String? loudnessAlbumKey(UnifiedTrack track) {
  final album = track.album?.trim().toLowerCase();
  if (album == null || album.isEmpty) return null;
  return '${track.normalizedArtist}|$album';
}

/// Сохранённая статистика громкости по трекам.
abstract interface class LoudnessStore {
  Future<LoudnessStats?> read(String trackId);
  Future<void> write(String trackId, LoudnessStats stats);

  /// Все известные треки альбома (для режима «Альбом»).
  Future<List<LoudnessStats>> readAlbum(String albumKey);
}

final class MemoryLoudnessStore implements LoudnessStore {
  final values = <String, LoudnessStats>{};

  @override
  Future<LoudnessStats?> read(String trackId) async => values[trackId];

  @override
  Future<void> write(String trackId, LoudnessStats stats) async {
    values[trackId] = stats;
  }

  @override
  Future<List<LoudnessStats>> readAlbum(String albumKey) async => [
    for (final stats in values.values)
      if (stats.album == albumKey) stats,
  ];
}

/// Хранит статистику в Drift, в общей таблице кэша метаданных
/// (ключ `loudness:<trackId>`), без отдельной миграции схемы.
final class DriftLoudnessStore implements LoudnessStore {
  DriftLoudnessStore(this._database);

  static const _prefix = 'loudness:';
  final AppDatabase _database;

  @override
  Future<LoudnessStats?> read(String trackId) async {
    final row =
        await (_database.select(_database.cachedMetadataEntries)
              ..where((table) => table.cacheKey.equals('$_prefix$trackId')))
            .getSingleOrNull();
    if (row == null) return null;
    try {
      return LoudnessStats.fromJson(jsonDecode(row.payloadJson));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(String trackId, LoudnessStats stats) async {
    await _database
        .into(_database.cachedMetadataEntries)
        .insertOnConflictUpdate(
          CachedMetadataEntriesCompanion.insert(
            cacheKey: '$_prefix$trackId',
            payloadJson: jsonEncode(stats.toJson()),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  @override
  Future<List<LoudnessStats>> readAlbum(String albumKey) async {
    final rows =
        await (_database.select(_database.cachedMetadataEntries)..where(
              (table) =>
                  table.cacheKey.like('$_prefix%') &
                  table.payloadJson.contains(jsonEncode(albumKey)),
            ))
            .get();
    final result = <LoudnessStats>[];
    for (final row in rows) {
      try {
        final stats = LoudnessStats.fromJson(jsonDecode(row.payloadJson));
        if (stats != null && stats.album == albumKey) result.add(stats);
      } on FormatException {
        // Повреждённая запись просто не участвует в альбомном гейне.
      }
    }
    return result;
  }
}

/// Решает, какой гейн применить к треку: метаданные провайдера →
/// сохранённая статистика → (режим «Альбом») средняя громкость альбома.
final class LoudnessNormalizer {
  LoudnessNormalizer(this._store);

  final LoudnessStore? _store;

  Future<double?> gainFor({
    required LoudnessNormalizationMode mode,
    required UnifiedTrack track,
    required ResolvedAudioSource source,
  }) async {
    if (mode == LoudnessNormalizationMode.off) return null;
    var stats = providerLoudness(source, track);
    final store = _store;
    try {
      if (stats != null) {
        await store?.write(track.id, stats);
      } else {
        stats = await store?.read(track.id);
      }
      double? album;
      final albumKey = loudnessAlbumKey(track);
      if (mode == LoudnessNormalizationMode.album &&
          albumKey != null &&
          store != null) {
        final known = await store.readAlbum(albumKey);
        // Альбомный гейн — только по надёжным данным: громкость альбома от
        // провайдера или измерения хотя бы [minAlbumTracks] треков. Иначе
        // средняя по 1–2 трекам врёт сильнее трекового гейна.
        if (albumLoudnessReliable(known)) {
          album = albumLoudness(known.map((value) => value.integratedLufs));
        }
      }
      return normalizationGainDb(mode: mode, track: stats, albumLufs: album);
    } on Object {
      // Хранилище недоступно — оцениваем только по метаданным.
      return normalizationGainDb(mode: mode, track: stats);
    }
  }

  /// Запоминает громкость, измеренную плеером во время воспроизведения.
  Future<void> remember(UnifiedTrack track, double lufs) async {
    if (!isPlausibleLufs(lufs)) return;
    try {
      final existing = await _store?.read(track.id);
      if (existing?.origin == LoudnessOrigin.provider) return;
      await _store?.write(
        track.id,
        LoudnessStats(integratedLufs: lufs, album: loudnessAlbumKey(track)),
      );
    } on Object {
      // Статистика оппортунистична.
    }
  }
}
