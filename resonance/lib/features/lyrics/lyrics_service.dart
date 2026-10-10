import 'package:dio/dio.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';

/// Слово с собственной отметкой времени (Enhanced LRC). Есть не у всех
/// источников — без них караоке подсвечивает строку целиком.
final class LyricWord {
  const LyricWord({required this.text, required this.start});

  final String text;
  final Duration start;

  static LyricWord? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final text = json['text'];
    final start = json['startMs'];
    if (text is! String || start is! num) return null;
    return LyricWord(
      text: text,
      start: Duration(milliseconds: start.round()),
    );
  }
}

final class LyricLine {
  const LyricLine({required this.text, this.start, this.words = const []});

  final String text;
  final Duration? start;
  final List<LyricWord> words;

  bool get hasWordTiming => words.length >= 2;

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
    text: json['text'] as String? ?? '',
    start: switch (json['startMs']) {
      final num value => Duration(milliseconds: value.round()),
      _ => null,
    },
    words: (json['words'] as List<dynamic>? ?? const [])
        .map(LyricWord.tryParse)
        .whereType<LyricWord>()
        .toList(growable: false),
  );
}

final class LyricsDocument {
  const LyricsDocument({
    required this.id,
    required this.synced,
    required this.instrumental,
    required this.lines,
    required this.sourceUrl,
    this.sourceName = 'LRCLIB',
    this.translatable = false,
  });

  final int id;
  final bool synced;
  final bool instrumental;
  final List<LyricLine> lines;
  final Uri sourceUrl;
  final String sourceName;

  /// Сервер умеет переводить строки (у него настроен бесплатный переводчик).
  final bool translatable;

  bool get hasWordTiming => lines.any((line) => line.hasWordTiming);

  factory LyricsDocument.fromJson(Map<String, dynamic> json) {
    final source = json['source'] as Map<String, dynamic>? ?? const {};
    return LyricsDocument(
      id: (json['id'] as num).round(),
      synced: json['synced'] as bool? ?? false,
      instrumental: json['instrumental'] as bool? ?? false,
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LyricLine.fromJson)
          .where((line) => line.text.isNotEmpty)
          .toList(growable: false),
      sourceUrl:
          Uri.tryParse(source['url'] as String? ?? '') ??
          Uri.parse('https://lrclib.net'),
      sourceName: source['name'] as String? ?? 'Источник',
      translatable: json['translatable'] as bool? ?? false,
    );
  }
}

final class LyricsService {
  LyricsService(this._dio, this._baseUri, [this._tokens]);

  final Dio _dio;
  final Uri Function() _baseUri;
  final SecureTokenRepository? _tokens;

  Future<LyricsDocument?> find(UnifiedTrack track) async {
    try {
      final yandexSource = track.sourceFor(MusicProvider.yandex);
      final yandexToken = yandexSource == null
          ? null
          : await _tokens?.read(MusicProvider.yandex);
      final uri = _baseUri()
          .resolve('/api/v1/lyrics')
          .replace(
            queryParameters: {
              'title': track.title,
              'artist': track.artist,
              if (track.album?.trim().isNotEmpty == true) 'album': track.album,
              if (track.duration != null)
                'durationMs': track.duration!.inMilliseconds.toString(),
              if (yandexSource != null) 'yandexId': yandexSource.externalId,
            },
          );
      final response = await _dio.getUri<Map<String, dynamic>>(
        uri,
        options: yandexToken?.trim().isNotEmpty == true
            ? Options(headers: {'X-Provider-Token': yandexToken})
            : null,
      );
      final data = response.data;
      return data == null ? null : LyricsDocument.fromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Перевод строк вторым рядом. `null` — перевод на сервере недоступен или
  /// не удался; интерфейс тогда просто его не показывает.
  Future<List<String>?> translate(
    List<LyricLine> lines, {
    String target = 'ru',
  }) async {
    if (lines.isEmpty) return const [];
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        _baseUri().resolve('/api/v1/lyrics/translate'),
        data: {
          'target': target,
          'lines': [
            for (final line in lines.take(400))
              line.text.length > 500 ? line.text.substring(0, 500) : line.text,
          ],
        },
      );
      final output = response.data?['lines'];
      if (output is! List) return null;
      return [for (final item in output) item is String ? item : ''];
    } on DioException {
      return null;
    }
  }
}
