import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/preferences/playback_flow_preferences.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';

void main() {
  test('uses safe Flow defaults and persists every option', () async {
    final store = _MemoryStore();
    final preferences = PlaybackFlowPreferences(store);

    final defaults = await preferences.read();
    expect(defaults.enabled, true);
    expect(defaults.transitionMs, 1600);
    expect(defaults.normalizeLoudness, true);
    expect(defaults.visualizer, true);

    const changed = PlaybackFlowSettings(
      enabled: false,
      transitionMs: 4000,
      normalizeLoudness: false,
      visualizer: false,
    );
    await preferences.write(changed);
    final restored = await preferences.read();
    expect(restored.enabled, false);
    expect(restored.transitionMs, 4000);
    expect(restored.normalizeLoudness, false);
    expect(restored.visualizer, false);
  });

  test('rejects unsupported stored transition durations', () async {
    final store = _MemoryStore()
      ..values['resonance.flow.transition_ms'] = '999999';
    final settings = await PlaybackFlowPreferences(store).read();
    expect(settings.transitionMs, 1600);
  });
}

final class _MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
