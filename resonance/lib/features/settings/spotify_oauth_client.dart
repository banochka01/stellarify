import 'dart:async';

import 'package:dio/dio.dart';

final class SpotifyOAuthClient {
  SpotifyOAuthClient(this._dio, this._baseUri);

  final Dio _dio;
  final Uri Function() _baseUri;

  Future<String> connect(Future<bool> Function(Uri url) openBrowser) async {
    final started = await _dio.postUri<Map<String, dynamic>>(
      _baseUri().resolve('/api/v1/auth/spotify/start'),
    );
    final requestId = started.data?['requestId'];
    final authorizeUrl = Uri.tryParse(
      started.data?['authorizeUrl'] as String? ?? '',
    );
    if (requestId is! String ||
        authorizeUrl == null ||
        !authorizeUrl.isScheme('https')) {
      throw const FormatException('Сервер вернул некорректную ссылку Spotify.');
    }
    if (!await openBrowser(authorizeUrl)) {
      throw StateError('Не удалось открыть страницу входа Spotify.');
    }
    for (var attempt = 0; attempt < 150; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final response = await _dio.getUri<Map<String, dynamic>>(
        _baseUri()
            .resolve('/api/v1/auth/spotify/status')
            .replace(queryParameters: {'requestId': requestId}),
        options: Options(
          validateStatus: (status) => status == 200 || status == 202,
        ),
      );
      if (response.statusCode == 202) continue;
      final credential = response.data?['credential'];
      if (credential is String &&
          credential.startsWith('spotify-refresh-v1.')) {
        return credential;
      }
      throw const FormatException('Spotify не вернул данные подключения.');
    }
    throw TimeoutException('Время входа Spotify истекло. Попробуйте ещё раз.');
  }
}
