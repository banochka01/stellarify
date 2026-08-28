sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

final class ProviderUnavailableException extends AppException {
  const ProviderUnavailableException(super.message, {super.cause});
}

final class AudioResolutionException extends AppException {
  const AudioResolutionException(super.message, {super.cause});
}

final class InvalidExternalUrlException extends AppException {
  const InvalidExternalUrlException(super.message);
}

final class PlaybackFailedException extends AppException {
  const PlaybackFailedException(super.message, {super.cause});
}
