final class SensitiveDataRedactor {
  const SensitiveDataRedactor();

  static const _sensitiveKeys = {
    'authorization',
    'cookie',
    'set-cookie',
    'token',
    'access_token',
    'refresh_token',
  };

  Map<String, Object?> redactMap(Map<String, Object?> input) {
    return input.map((key, value) {
      if (_sensitiveKeys.contains(key.toLowerCase())) {
        return MapEntry(key, '[REDACTED]');
      }
      return MapEntry(key, value);
    });
  }
}
