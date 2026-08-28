import 'package:resonance/domain/entities/resolved_audio_source.dart';
import 'package:resonance/domain/entities/track_source.dart';

final class ResolvedSourceCache {
  ResolvedSourceCache({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final _entries = <String, ResolvedAudioSource>{};

  String _key(TrackSource source) =>
      '${source.provider.name}:${source.externalId}';

  ResolvedAudioSource? get(TrackSource source, {DateTime? now}) {
    final key = _key(source);
    final value = _entries[key];
    if (value == null) {
      return null;
    }
    if (value.isExpired(now ?? _now().toUtc())) {
      _entries.remove(key);
      return null;
    }
    return value;
  }

  void put(TrackSource source, ResolvedAudioSource resolved) {
    if (resolved.isExpired(_now().toUtc())) {
      return;
    }
    _entries[_key(source)] = resolved;
  }

  void invalidate(TrackSource source) => _entries.remove(_key(source));

  void clear() => _entries.clear();
}
