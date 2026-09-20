import 'dart:async';

import 'package:dio/dio.dart';

final class SpotifyOAuthClient {
  SpotifyOAuthClient(this._dio, this._baseUri);

  final Dio _dio;
  final Uri Function() _baseUri;

  Future<String> connect(Future<bool> Function(Uri url) openBrowser) async {
    late final Response<Map<String, dynamic>> started;
    try {
      started = await _dio.postUri<Map<String, dynamic>>(
        _baseUri().resolve('/api/v1/auth/spotify/start'),
      );
    } on DioException catch (error) {
      throw StateError(_spotifyLoginError(error));
    }
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
      late final Response<Map<String, dynamic>> response;
      try {
        response = await _dio.getUri<Map<String, dynamic>>(
          _baseUri()
              .resolve('/api/v1/auth/spotify/status')
              .replace(queryParameters: {'requestId': requestId}),
          options: Options(
            validateStatus: (status) => status == 200 || status == 202,
          ),
        );
      } on DioException catch (error) {
        throw StateError(_spotifyLoginError(error));
      }
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

String _spotifyLoginError(DioException error) {
  final data = error.response?.data;
  final body = data is Map ? data['error'] : null;
  final code = body is Map ? body['code'] : null;
  final message = body is Map ? body['message'] : null;
  return switch (code) {
    'SPOTIFY_OAUTH_NOT_CONFIGURED' =>
      'Вход Spotify ещё не настроен на сервере.',
    'SPOTIFY_LOGIN_FAILED' when message is String && message.isNotEmpty =>
      message,
    'SPOTIFY_LOGIN_NOT_FOUND' =>
      'Сессия входа Spotify устарела. Попробуйте ещё раз.',
    _ => 'Сервер входа Spotify временно недоступен.',
  };
}
