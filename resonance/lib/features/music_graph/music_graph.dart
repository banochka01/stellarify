import 'dart:math' as math;

import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';

enum MusicGraphRelation { sameRecording, sameArtist, sameAlbum }

final class MusicGraphEdge {
  const MusicGraphEdge({
    required this.fromId,
    required this.toId,
    required this.relation,
  });

  final String fromId;
  final String toId;
  final MusicGraphRelation relation;
}

final class MusicGraphNode {
  const MusicGraphNode({required this.track, required this.memberIds});

  final UnifiedTrack track;
  final Set<String> memberIds;

  int get duplicateCount => math.max(0, memberIds.length - 1);
  int get sourceCount => track.sources.length;
}

final class MusicGraphSnapshot {
  const MusicGraphSnapshot({
    required this.nodes,
    required this.edges,
    required this.canonicalByTrackId,
  });

  final List<MusicGraphNode> nodes;
  final List<MusicGraphEdge> edges;
  final Map<String, UnifiedTrack> canonicalByTrackId;

  int get duplicateCount =>
      nodes.fold(0, (count, node) => count + node.duplicateCount);

  int get sourceCount => nodes
      .expand((node) => node.track.sources)
      .map((source) => '${source.provider.name}:${source.externalId}')
      .toSet()
      .length;

  int get artistCount => nodes
      .map((node) => node.track.normalizedArtist.trim())
      .where((artist) => artist.isNotEmpty)
      .toSet()
      .length;

  UnifiedTrack canonicalFor(UnifiedTrack track) =>
      canonicalByTrackId[track.id] ?? track;

  List<MusicGraphEdge> relationsFor(String trackId) => edges
      .where((edge) => edge.fromId == trackId || edge.toId == trackId)
      .toList(growable: false);
}

/// Builds a deterministic, local graph without sending the user's library to
/// another service. Matching is intentionally conservative: title and artist
/// must be equal after normalization and known durations must be close.
final class MusicGraphBuilder {
  const MusicGraphBuilder();

  MusicGraphSnapshot build(Iterable<UnifiedTrack> input) {
    final unique = <String, UnifiedTrack>{};
    for (final track in input) {
      unique[track.id] = track;
    }

    final groups = <String, List<UnifiedTrack>>{};
    for (final track in unique.values) {
      groups.putIfAbsent(_recordingKey(track), () => []).add(track);
    }

    final nodes = <MusicGraphNode>[];
    final canonicalByTrackId = <String, UnifiedTrack>{};
    for (final candidates in groups.values) {
      for (final durationGroup in _splitByDuration(candidates)) {
        final canonical = _merge(durationGroup);
        final memberIds = durationGroup.map((track) => track.id).toSet();
        nodes.add(MusicGraphNode(track: canonical, memberIds: memberIds));
        for (final id in memberIds) {
          canonicalByTrackId[id] = canonical;
        }
      }
    }

    nodes.sort((left, right) {
      final byArtist = left.track.normalizedArtist.compareTo(
        right.track.normalizedArtist,
      );
      return byArtist != 0
          ? byArtist
          : left.track.normalizedTitle.compareTo(right.track.normalizedTitle);
    });

    final edges = <MusicGraphEdge>[];
    for (final node in nodes) {
      if (node.memberIds.length > 1) {
        edges.add(
          MusicGraphEdge(
            fromId: node.track.id,
            toId: node.track.id,
            relation: MusicGraphRelation.sameRecording,
          ),
        );
      }
    }
    _connectNeighbors(
      nodes,
      edges,
      keyOf: (node) => node.track.normalizedArtist,
      relation: MusicGraphRelation.sameArtist,
    );
    _connectNeighbors(
      nodes.where((node) => (node.track.album ?? '').trim().isNotEmpty),
      edges,
      keyOf: (node) =>
          '${node.track.normalizedArtist}\u0000${_normalize(node.track.album!)}',
      relation: MusicGraphRelation.sameAlbum,
    );

    return MusicGraphSnapshot(
      nodes: List.unmodifiable(nodes),
      edges: List.unmodifiable(edges),
      canonicalByTrackId: Map.unmodifiable(canonicalByTrackId),
    );
  }

  List<UnifiedTrack> canonicalize(Iterable<UnifiedTrack> tracks) {
    final input = tracks.toList(growable: false);
    final graph = build(input);
    final result = <UnifiedTrack>[];
    final seen = <String>{};
    for (final track in input) {
      final canonical = graph.canonicalFor(track);
      if (seen.add(canonical.id)) result.add(canonical);
    }
    return result;
  }

  static String _recordingKey(UnifiedTrack track) =>
      '${_normalize(track.normalizedArtist)}\u0000${_normalize(track.normalizedTitle)}';

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  static List<List<UnifiedTrack>> _splitByDuration(List<UnifiedTrack> tracks) {
    final groups = <List<UnifiedTrack>>[];
    for (final track in tracks) {
      final duration = track.duration?.inSeconds;
      final match = groups.where((group) {
        final reference = group.first;
        final known = reference.duration?.inSeconds;
        if (duration != null && known != null) {
          return (duration - known).abs() <= 5;
        }
        final album = _normalize(track.album ?? '');
        final referenceAlbum = _normalize(reference.album ?? '');
        return album.isNotEmpty && album == referenceAlbum;
      }).firstOrNull;
      (match ?? (groups..add(<UnifiedTrack>[])).last).add(track);
    }
    return groups;
  }

  static UnifiedTrack _merge(List<UnifiedTrack> tracks) {
    final ranked = [...tracks]
      ..sort((left, right) {
        final sources = right.sources.length.compareTo(left.sources.length);
        if (sources != 0) return sources;
        final artwork = (right.artworkUrl == null ? 0 : 1).compareTo(
          left.artworkUrl == null ? 0 : 1,
        );
        return artwork != 0 ? artwork : left.id.compareTo(right.id);
      });
    final primary = ranked.first;
    final sources = <String, TrackSource>{};
    for (final track in ranked) {
      for (final source in track.sources) {
        sources['${source.provider.name}:${source.externalId}'] = source;
      }
    }
    return primary.copyWith(
      sources: sources.values.toList(growable: false),
      artworkUrl:
          primary.artworkUrl ??
          ranked.map((track) => track.artworkUrl).firstNonNull,
      album: primary.album ?? ranked.map((track) => track.album).firstNonNull,
      duration:
          primary.duration ??
          ranked.map((track) => track.duration).firstNonNull,
    );
  }

  static void _connectNeighbors(
    Iterable<MusicGraphNode> nodes,
    List<MusicGraphEdge> edges, {
    required String Function(MusicGraphNode node) keyOf,
    required MusicGraphRelation relation,
  }) {
    final groups = <String, List<MusicGraphNode>>{};
    for (final node in nodes) {
      final key = keyOf(node).trim();
      if (key.isNotEmpty) groups.putIfAbsent(key, () => []).add(node);
    }
    for (final group in groups.values) {
      // A chain keeps the graph connected without quadratic edge growth for
      // large artist catalogs.
      for (var index = 1; index < group.length; index++) {
        edges.add(
          MusicGraphEdge(
            fromId: group[index - 1].track.id,
            toId: group[index].track.id,
            relation: relation,
          ),
        );
      }
    }
  }
}

extension<T> on Iterable<T?> {
  T? get firstNonNull {
    for (final value in this) {
      if (value != null) return value;
    }
    return null;
  }
}
