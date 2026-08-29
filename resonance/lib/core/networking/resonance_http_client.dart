import 'package:dio/dio.dart';

final class ResonanceHttpClient {
  ResonanceHttpClient({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 12),
              followRedirects: true,
              maxRedirects: 4,
              responseType: ResponseType.json,
              headers: const {
                'Accept': 'application/json',
                'User-Agent': 'Resonance/0.3',
              },
            ),
          );

  final Dio dio;

  void close() => dio.close(force: true);
}
