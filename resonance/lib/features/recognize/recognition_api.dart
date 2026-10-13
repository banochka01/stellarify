import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/domain/entities/unified_track.dart';

/// Трек, который сервер распознал по фрагменту с микрофона.
final class RecognizedTrack {
  const RecognizedTrack({
    required this.title,
    required this.artist,
    this.album,
    this.durationMs,
    this.isrc,
  });

  factory RecognizedTrack.fromJson(Map<String, dynamic> json) =>
      RecognizedTrack(
        title: (json['title'] as String).trim(),
        artist: (json['artist'] as String).trim(),
        album: json['album'] as String?,
        durationMs: (json['durationMs'] as num?)?.toInt(),
        isrc: json['isrc'] as String?,
      );

  final String title;
  final String artist;
  final String? album;
  final int? durationMs;
  final String? isrc;

  String get query => '$artist $title';
}

final class RecognitionException implements Exception {
  const RecognitionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Клиент к `/api/v1/recognize`. Сервер сам решает, настроено ли
/// распознавание (ключ AudD); без него кнопка в приложении скрыта.
final class RecognitionApi {
  RecognitionApi(this._dio, this._endpoint, this._accessToken);

  /// Длина фрагмента, который отправляем на распознавание.
  static const sampleDuration = Duration(seconds: 8);

  final Dio _dio;
  final Uri Function() _endpoint;
  final Future<String?> Function() _accessToken;

  Future<bool> available() async {
    try {
      final response = await _dio.getUri<dynamic>(
        _endpoint().resolve('/api/v1/recognize/status'),
      );
      final data = response.data;
      return data is Map && data['available'] == true;
    } on Object {
      return false;
    }
  }

  /// Отправляет фрагмент; `null` — трек не найден.
  Future<RecognizedTrack?> recognize(
    Uint8List sample, {
    String contentType = 'audio/mp4',
  }) async {
    final token = await _accessToken();
    if (token == null) {
      throw const RecognitionException(
        'Войдите в Resonance ID, чтобы распознавать треки.',
      );
    }
    try {
      final response = await _dio.postUri<dynamic>(
        _endpoint().resolve('/api/v1/recognize'),
        data: Stream.fromIterable([sample]),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            Headers.contentTypeHeader: contentType,
            Headers.contentLengthHeader: sample.length,
          },
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final data = response.data;
      final track = data is Map ? data['track'] : null;
      if (track is! Map) return null;
      final json = Map<String, dynamic>.from(track);
      if (json['title'] is! String || json['artist'] is! String) return null;
      return RecognizedTrack.fromJson(json);
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map && data['error'] is Map
          ? (data['error'] as Map)['message']?.toString()
          : null;
      throw RecognitionException(
        message ?? 'Сервис распознавания недоступен. Попробуйте позже.',
      );
    }
  }
}

final recognitionApiProvider = Provider<RecognitionApi>((ref) {
  return RecognitionApi(
    ref.watch(resonanceHttpClientProvider).dio,
    BackendEndpoint.requireCurrent,
    ref.watch(accountApiProvider).accessToken,
  );
});

/// Настроен ли сервис на сервере. Ошибка сети = «нет», кнопка скрыта.
final recognitionAvailableProvider = FutureProvider<bool>((ref) {
  return ref.watch(recognitionApiProvider).available();
});

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), ' ')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

/// Лучшее совпадение распознанного трека среди результатов каталогов:
/// совпадает название, и исполнитель пересекается.
UnifiedTrack? bestCatalogMatch(
  RecognizedTrack recognized,
  Iterable<UnifiedTrack> candidates,
) {
  final rawTitle = recognized.title.trim().toLowerCase();
  final title = _normalize(recognized.title);
  final artist = _normalize(recognized.artist);
  UnifiedTrack? normalized;
  UnifiedTrack? loose;
  for (final track in candidates) {
    if (track.sources.isEmpty) continue;
    final candidateArtist = _normalize(track.artist);
    if (candidateArtist.isEmpty ||
        !(candidateArtist.contains(artist) ||
            artist.contains(candidateArtist))) {
      continue;
    }
    // Точное название важнее версий вроде «(Remix)» или «(Live)».
    if (track.title.trim().toLowerCase() == rawTitle) return track;
    final candidateTitle = _normalize(track.title);
    if (candidateTitle == title) {
      normalized ??= track;
    } else if (candidateTitle.startsWith(title) ||
        title.startsWith(candidateTitle)) {
      loose ??= track;
    }
  }
  return normalized ?? loose;
}
