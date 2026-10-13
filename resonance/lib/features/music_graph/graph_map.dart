import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/music_graph/music_graph.dart';
import 'package:resonance/features/platform/feature_api.dart';

enum GraphNodeKind { artist, track, genre }

enum GraphLinkType {
  sameRecording('Одна запись'),
  sameArtist('Артист'),
  sameAlbum('Альбом'),
  similar('Похожие'),
  colisten('Слушают вместе'),
  collaboration('Совместные'),
  genre('Жанр');

  const GraphLinkType(this.label);

  final String label;

  static GraphLinkType parse(Object? value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => GraphLinkType.similar,
  );
}

final class GraphMapNode {
  const GraphMapNode({
    required this.id,
    required this.label,
    required this.kind,
    this.personal = false,
    this.track,
  });

  factory GraphMapNode.fromJson(Map<String, dynamic> json) => GraphMapNode(
    id: jsonString(json['id']),
    label: jsonString(json['label'] ?? json['name']),
    kind: GraphNodeKind.values.firstWhere(
      (item) => item.name == json['kind'],
      orElse: () => GraphNodeKind.artist,
    ),
    personal: jsonBool(json['personal']),
    track: jsonTrack(json['track']),
  );

  final String id;
  final String label;
  final GraphNodeKind kind;

  /// Part of the user's own library ("personal layer").
  final bool personal;
  final UnifiedTrack? track;

  GraphMapNode merge(GraphMapNode other) => GraphMapNode(
    id: id,
    label: label.isEmpty ? other.label : label,
    kind: kind,
    personal: personal || other.personal,
    track: track ?? other.track,
  );
}

final class GraphMapEdge {
  const GraphMapEdge(this.from, this.to, this.type);

  factory GraphMapEdge.fromJson(Map<String, dynamic> json) => GraphMapEdge(
    jsonString(json['from']),
    jsonString(json['to']),
    GraphLinkType.parse(json['type']),
  );

  final String from;
  final String to;
  final GraphLinkType type;

  String get key {
    final ordered = from.compareTo(to) <= 0 ? '$from|$to' : '$to|$from';
    return '$ordered|${type.name}';
  }
}

/// The full known graph: local library plus whatever the server added.
final class GraphMapData {
  GraphMapData();

  final Map<String, GraphMapNode> nodes = {};
  final Map<String, GraphMapEdge> _edges = {};
  final Map<String, Set<String>> _adjacency = {};

  Iterable<GraphMapEdge> get edges => _edges.values;

  /// Bumped on every structural change (used for render caches).
  int version = 0;

  /// Server artist key -> node id, and normalized label -> artist node id.
  /// Server keys may differ from local normalization (e.g. transliteration),
  /// so both indexes are consulted before creating a new node.
  final Map<String, String> _serverKeys = {};
  final Map<String, String> _artistLabels = {};

  void addNode(GraphMapNode node) {
    final existing = nodes[node.id];
    nodes[node.id] = existing == null ? node : existing.merge(node);
    if (node.kind == GraphNodeKind.artist) {
      _artistLabels.putIfAbsent(graphArtistKey(node.label), () => node.id);
    }
    version++;
  }

  void addEdge(GraphMapEdge edge) {
    if (edge.from == edge.to) return;
    if (!nodes.containsKey(edge.from) || !nodes.containsKey(edge.to)) return;
    if (!identical(_edges.putIfAbsent(edge.key, () => edge), edge)) return;
    _adjacency.putIfAbsent(edge.from, () => {}).add(edge.to);
    _adjacency.putIfAbsent(edge.to, () => {}).add(edge.from);
    version++;
  }

  /// Node id for a server artist: known server key, then the same
  /// normalized name, then a new id from the server key.
  String resolveArtist(String serverKey, String name) =>
      _serverKeys[serverKey] ??
      _artistLabels[graphArtistKey(name)] ??
      artistId(serverKey);

  void mergeJson(Map<String, dynamic> json) {
    for (final node in jsonList(json['nodes']).map(GraphMapNode.fromJson)) {
      if (node.id.isNotEmpty) addNode(node);
    }
    for (final edge in jsonList(json['edges']).map(GraphMapEdge.fromJson)) {
      addEdge(edge);
    }
  }

  /// Merges `GET /api/v1/graph/artist` (`{ key, neighbors: GraphNeighbor[] }`)
  /// around the tapped node [centerId].
  void mergeArtistNeighbors(String centerId, Map<String, dynamic> json) {
    final centerKey = jsonOptString(json['key']);
    if (centerKey != null) _serverKeys[centerKey] = centerId;
    for (final neighbor in jsonList(json['neighbors'])) {
      final key = jsonString(neighbor['key']);
      final name = jsonString(neighbor['artist']);
      if (key.isEmpty || name.isEmpty) continue;
      final id = resolveArtist(key, name);
      _serverKeys[key] = id;
      addNode(
        GraphMapNode(
          id: id,
          label: name,
          kind: GraphNodeKind.artist,
          personal: jsonBool(neighbor['listened']),
        ),
      );
      final kinds = jsonMap(neighbor['kinds']);
      final types = [
        if (kinds['colisten'] != null) GraphLinkType.colisten,
        if (kinds['feat'] != null) GraphLinkType.collaboration,
        if (kinds['similar'] != null) GraphLinkType.similar,
      ];
      for (final type in types.isEmpty ? [GraphLinkType.similar] : types) {
        addEdge(GraphMapEdge(centerId, id, type));
      }
    }
  }

  Set<String> neighborsOf(String id) => _adjacency[id] ?? const {};

  int degreeOf(String id) => neighborsOf(id).length;

  static String artistId(String normalizedArtist) => 'artist:$normalizedArtist';

  /// Builds the personal layer from the local Music Graph snapshot.
  factory GraphMapData.fromLibrary(MusicGraphSnapshot snapshot) {
    final data = GraphMapData();
    for (final node in snapshot.nodes) {
      final artistKey = graphArtistKey(node.track.artist);
      if (artistKey.isEmpty) continue;
      data
        ..addNode(
          GraphMapNode(
            id: artistId(artistKey),
            label: node.track.artist,
            kind: GraphNodeKind.artist,
            personal: true,
          ),
        )
        ..addNode(
          GraphMapNode(
            id: 'track:${node.track.id}',
            label: node.track.title,
            kind: GraphNodeKind.track,
            personal: true,
            track: node.track,
          ),
        )
        ..addEdge(
          GraphMapEdge(
            'track:${node.track.id}',
            artistId(artistKey),
            GraphLinkType.sameArtist,
          ),
        );
    }
    for (final edge in snapshot.edges) {
      if (edge.relation != MusicGraphRelation.sameAlbum) continue;
      data.addEdge(
        GraphMapEdge(
          'track:${edge.fromId}',
          'track:${edge.toId}',
          GraphLinkType.sameAlbum,
        ),
      );
    }
    return data;
  }
}

/// Which part of the graph is on screen. Rendering cost is bounded by
/// [maxNodes], which keeps weak Android devices responsive.
final class GraphViewport {
  GraphViewport(this.data, {required this.maxNodes});

  final GraphMapData data;
  final int maxNodes;
  final Map<String, Offset> positions = {};
  final Set<String> expanded = {};
  final List<String> _order = [];

  Iterable<String> get visible => _order;

  int get visibleCount => _order.length;

  bool isVisible(String id) => positions.containsKey(id);

  /// Seeds the view with the best connected artists.
  void seed() {
    final ranked =
        data.nodes.values
            .where((node) => node.kind != GraphNodeKind.track)
            .toList()
          ..sort((a, b) => data.degreeOf(b.id).compareTo(data.degreeOf(a.id)));
    final pool = ranked.isEmpty ? data.nodes.values.toList() : ranked;
    final count = math.min(pool.length, math.max(1, maxNodes ~/ 3));
    for (var index = 0; index < count; index++) {
      final angle = index * 2.399963; // golden angle spiral
      final radius = 40.0 * math.sqrt(index + 1);
      _show(pool[index].id, Offset(math.cos(angle), math.sin(angle)) * radius);
    }
    relax();
  }

  /// Reveals the neighbors of [id]; evicts the oldest unexpanded nodes when
  /// the limit is reached. Returns the number of newly shown nodes.
  int expand(String id) {
    if (!isVisible(id)) return 0;
    expanded.add(id);
    final origin = positions[id]!;
    final candidates =
        data.neighborsOf(id).where((other) => !isVisible(other)).toList()
          ..sort((a, b) => data.degreeOf(b).compareTo(data.degreeOf(a)));
    final budget = math.min(candidates.length, math.max(1, maxNodes ~/ 4));
    final keep = {id, ...data.neighborsOf(id)};
    var added = 0;
    for (var index = 0; index < budget; index++) {
      if (_order.length >= maxNodes && !_evictOne(keep)) break;
      final angle = (index / budget) * 2 * math.pi;
      _show(
        candidates[index],
        origin + Offset(math.cos(angle), math.sin(angle)) * 70,
      );
      added++;
    }
    relax(iterations: 40);
    return added;
  }

  bool _evictOne(Set<String> keep) {
    for (final candidate in _order) {
      if (!keep.contains(candidate) && !expanded.contains(candidate)) {
        _order.remove(candidate);
        positions.remove(candidate);
        _version++;
        return true;
      }
    }
    return false;
  }

  void _show(String id, Offset position) {
    if (positions.containsKey(id)) return;
    positions[id] = position;
    _order.add(id);
    _version++;
  }

  int _version = 0;
  (int, int)? _edgesKey;
  List<GraphMapEdge> _edgesCache = const [];

  /// Cached until either the visible set or the data changes.
  List<GraphMapEdge> visibleEdges() {
    final key = (_version, data.version);
    if (_edgesKey == key) return _edgesCache;
    _edgesKey = key;
    return _edgesCache = data.edges
        .where((edge) => isVisible(edge.from) && isVisible(edge.to))
        .toList(growable: false);
  }

  /// Small deterministic force layout; O(n²) per iteration with n ≤ maxNodes.
  void relax({int iterations = 60}) {
    final ids = _order.toList(growable: false);
    if (ids.length < 2) return;
    final edges = visibleEdges();
    for (var step = 0; step < iterations; step++) {
      final forces = {for (final id in ids) id: Offset.zero};
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final delta = positions[ids[i]]! - positions[ids[j]]!;
          final distance = math.max(delta.distance, 1.0);
          final push = delta / distance * (1800 / (distance * distance));
          forces[ids[i]] = forces[ids[i]]! + push;
          forces[ids[j]] = forces[ids[j]]! - push;
        }
      }
      for (final edge in edges) {
        final delta = positions[edge.to]! - positions[edge.from]!;
        final pull = delta * 0.02;
        forces[edge.from] = forces[edge.from]! + pull;
        forces[edge.to] = forces[edge.to]! - pull;
      }
      for (final id in ids) {
        final force = forces[id]! - positions[id]! * 0.004;
        final limited = force.distance > 12
            ? force / force.distance * 12
            : force;
        positions[id] = positions[id]! + limited;
      }
    }
  }

  String? hitTest(Offset point, {double radius = 18}) {
    String? best;
    var bestDistance = radius;
    for (final id in _order) {
      final distance = (positions[id]! - point).distance;
      if (distance <= bestDistance) {
        bestDistance = distance;
        best = id;
      }
    }
    return best;
  }
}

// ---- /api/v1/graph/* ----

final class GraphPathResult {
  const GraphPathResult({
    required this.found,
    required this.tracks,
    this.via = const [],
  });

  factory GraphPathResult.fromJson(Map<String, dynamic> json) =>
      GraphPathResult(
        found: jsonBool(json['found']),
        tracks: jsonTracks(json['tracks']),
        via: jsonList(
          json['nodes'],
        ).map((node) => jsonString(node['artist'])).toList(),
      );

  final bool found;
  final List<UnifiedTrack> tracks;
  final List<String> via;
}

/// An "unexplored" neighbor from `GET /api/v1/graph/me`.
final class BlindSpot {
  const BlindSpot({required this.artist, this.from});

  factory BlindSpot.fromJson(Map<String, dynamic> json) => BlindSpot(
    artist: jsonString(json['artist']),
    from: jsonOptString(json['from']),
  );

  final String artist;

  /// The listened artist this recommendation grew from.
  final String? from;
}

/// Wire contract for /api/v1/graph/* (docs/API-5.0.md §2).
abstract final class GraphPaths {
  static const artist = '/api/v1/graph/artist';
  static const path = '/api/v1/graph/path';
  static const me = '/api/v1/graph/me';
}

final class GraphApi {
  const GraphApi(this._transport);

  final FeatureTransport _transport;

  Future<Map<String, dynamic>> artistNeighbors(String name) =>
      _transport.request(
        'GET',
        GraphPaths.artist,
        query: {'name': name, 'limit': '20'},
        providerTokens: true,
      );

  Future<GraphPathResult> path(String from, String to) async =>
      GraphPathResult.fromJson(
        await _transport.request(
          'GET',
          GraphPaths.path,
          query: {
            'from': from.trim(),
            'to': to.trim(),
            'tracks': '1',
            'provider': 'soundcloud',
          },
          providerTokens: true,
        ),
      );

  Future<List<BlindSpot>> blindSpots() async => jsonList(
    (await _transport.request('GET', GraphPaths.me))['unexplored'],
  ).map(BlindSpot.fromJson).where((spot) => spot.artist.isNotEmpty).toList();
}

final graphApiProvider = Provider<GraphApi>(
  (ref) => GraphApi(ref.watch(featureTransportProvider)),
);

final blindSpotsProvider = FutureProvider.autoDispose<List<BlindSpot>>(
  (ref) => ref.watch(graphApiProvider).blindSpots(),
);

/// Artist normalization shared by the local layer and server merges.
String graphArtistKey(String name) => name
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

/// Backoff for transient server-graph failures (errors other than a missing
/// endpoint). Honors `retry-after`; capped at five minutes.
Duration graphRetryDelay(int failures, {Duration? retryAfter}) {
  if (retryAfter != null && retryAfter > Duration.zero) return retryAfter;
  final seconds = 5 * (1 << (failures - 1).clamp(0, 6));
  return Duration(seconds: seconds > 300 ? 300 : seconds);
}
