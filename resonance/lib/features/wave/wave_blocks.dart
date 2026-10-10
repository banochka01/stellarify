import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/auth/account_api.dart';

enum WaveBlockKind { track, artist }

/// "Не предлагать": a track or an artist the listener never wants in Wave,
/// daily mixes or radio. Removals are kept as tombstones so devices merge by
/// last write through Resonance ID.
final class WaveBlock {
  const WaveBlock({
    required this.kind,
    required this.key,
    required this.label,
    required this.updatedAt,
    this.removed = false,
  });

  factory WaveBlock.fromJson(Map<String, dynamic> json) => WaveBlock(
    kind: json['kind'] == 'artist' ? WaveBlockKind.artist : WaveBlockKind.track,
    key: json['key'] as String,
    label: json['label'] as String? ?? json['key'] as String,
    removed: json['removed'] == true,
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  final WaveBlockKind kind;
  final String key;
  final String label;
  final bool removed;
  final DateTime updatedAt;

  String get id => '${kind.name}|$key';

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'key': key,
    'label': label,
    'removed': removed,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

/// Same normalization as the server (`normalize` in wave.ts).
String normalizeWaveKey(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

String waveTrackKey(UnifiedTrack track) =>
    '${normalizeWaveKey(track.artist)}::${normalizeWaveKey(track.title)}';

/// Merges two block lists; the newest write for a key wins.
List<WaveBlock> mergeWaveBlocks(
  Iterable<WaveBlock> left,
  Iterable<WaveBlock> right,
) {
  final merged = <String, WaveBlock>{};
  for (final block in [...left, ...right]) {
    final old = merged[block.id];
    if (old == null || block.updatedAt.isAfter(old.updatedAt)) {
      merged[block.id] = block;
    }
  }
  final result = merged.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return result.take(500).toList(growable: false);
}

final waveBlocksProvider =
    StateNotifierProvider<WaveBlocksController, List<WaveBlock>>((ref) {
      final controller = WaveBlocksController(
        ref.watch(secureKeyValueStoreProvider),
        ref.watch(accountApiProvider),
      );
      unawaited(controller.load());
      return controller;
    });

class WaveBlocksController extends StateNotifier<List<WaveBlock>> {
  WaveBlocksController(this._store, this._account, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const []);

  static const _key = 'resonance.wave.blocks';
  final SecureKeyValueStore _store;
  final AccountApi? _account;
  final DateTime Function() _now;
  bool _loaded = false;

  List<WaveBlock> get active =>
      state.where((block) => !block.removed).toList(growable: false);

  List<String> get blockedArtists => [
    for (final block in active)
      if (block.kind == WaveBlockKind.artist) block.key,
  ];

  List<String> get blockedTracks => [
    for (final block in active)
      if (block.kind == WaveBlockKind.track) block.key,
  ];

  bool isBlocked(UnifiedTrack track) =>
      blockedArtists.contains(normalizeWaveKey(track.artist)) ||
      blockedTracks.contains(waveTrackKey(track));

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await _store.read(_key);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        state = mergeWaveBlocks(state, [
          for (final item in list)
            WaveBlock.fromJson(Map<String, dynamic>.from(item as Map)),
        ]);
      }
    } on Object {
      // A corrupt cache is replaced on the next write.
    }
    await sync();
  }

  Future<void> blockTrack(UnifiedTrack track) => _put(
    WaveBlock(
      kind: WaveBlockKind.track,
      key: waveTrackKey(track),
      label: '${track.artist} — ${track.title}',
      updatedAt: _now().toUtc(),
    ),
  );

  Future<void> blockArtist(String artist) => _put(
    WaveBlock(
      kind: WaveBlockKind.artist,
      key: normalizeWaveKey(artist),
      label: artist.trim(),
      updatedAt: _now().toUtc(),
    ),
  );

  Future<void> unblock(WaveBlock block) => _put(
    WaveBlock(
      kind: block.kind,
      key: block.key,
      label: block.label,
      removed: true,
      updatedAt: _now().toUtc(),
    ),
  );

  Future<void> _put(WaveBlock block) async {
    if (block.key.isEmpty || block.key == '::') return;
    state = mergeWaveBlocks(state, [block]);
    await _persist();
    await sync();
  }

  /// Best-effort sync through the Resonance ID account.
  Future<void> sync() async {
    final account = _account;
    if (account == null) return;
    try {
      if (await account.accessToken() == null) return;
      final remote = await account.mergeWaveBlocks([
        for (final block in state) block.toJson(),
      ]);
      state = mergeWaveBlocks(state, remote.map(WaveBlock.fromJson));
      await _persist();
    } on Object {
      // Guests and offline devices keep the local list; next change retries.
    }
  }

  Future<void> _persist() => _store.write(
    _key,
    jsonEncode([for (final block in state) block.toJson()]),
  );
}
