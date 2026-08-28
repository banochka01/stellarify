import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract final class BackendEndpoint {
  static const _storageKey = 'resonance.api.url';
  static const _compiledValue = String.fromEnvironment('RESONANCE_API_URL');
  static const _storage = FlutterSecureStorage();
  static Uri? _runtimeValue;

  static Future<void> initialize() async {
    final stored = await _storage.read(key: _storageKey);
    _runtimeValue = _parse(stored) ?? _parse(_compiledValue);
  }

  static Uri requireCurrent() {
    final value = _runtimeValue ?? _parse(_compiledValue);
    if (value == null) {
      throw StateError('Укажите адрес Resonance API в настройках.');
    }
    return value;
  }

  static String get displayValue =>
      (_runtimeValue ?? _parse(_compiledValue))?.toString() ?? '';

  static Future<void> save(String value) async {
    final parsed = _parse(value);
    if (parsed == null) {
      throw const FormatException('Нужен абсолютный HTTP(S) адрес сервера.');
    }
    await _storage.write(key: _storageKey, value: parsed.toString());
    _runtimeValue = parsed;
  }

  static Uri? _parse(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      return null;
    }
    return uri;
  }
}
