import 'package:dio/dio.dart';
import 'package:resonance/domain/entities/unified_track.dart';

final class LyricLine {
  const LyricLine({required this.text, this.start});

  final String text;
  final Duration? start;

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
    text: json['text'] as String? ?? '',
    start: switch (json['startMs']) {
      final num value => Duration(milliseconds: value.round()),
      _ => null,
    },
  );
}

final class LyricsDocument {
  const LyricsDocument({
    required this.id,
    required this.synced,
    required this.instrumental,
    required this.lines,
    required this.sourceUrl,
  });

  final int id;
  final bool synced;
  final bool instrumental;
  final List<LyricLine> lines;
  final Uri sourceUrl;

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
    );
  }
}

final class LyricsService {
  LyricsService(this._dio, this._baseUri);

  final Dio _dio;
  final Uri Function() _baseUri;

  Future<LyricsDocument?> find(UnifiedTrack track) async {
    try {
      final uri = _baseUri()
          .resolve('/api/v1/lyrics')
          .replace(
            queryParameters: {
              'title': track.title,
              'artist': track.artist,
              if (track.album?.trim().isNotEmpty == true) 'album': track.album,
              if (track.duration != null)
                'durationMs': track.duration!.inMilliseconds.toString(),
            },
          );
      final response = await _dio.getUri<Map<String, dynamic>>(uri);
      final data = response.data;
      return data == null ? null : LyricsDocument.fromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
