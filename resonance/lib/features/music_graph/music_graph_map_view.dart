import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/features/music_graph/graph_map.dart';
import 'package:resonance/features/music_graph/music_graph.dart';
import 'package:resonance/features/platform/feature_flags.dart';
import 'package:resonance/features/platform/feature_playback.dart';
import 'package:resonance/features/platform/feature_views.dart';
import 'package:resonance/features/player/track_action.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

/// Node cap: weak Android phones get a smaller canvas budget.
int defaultGraphNodeLimit() =>
    defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS
    ? 60
    : 140;

const _canvasSize = Size(1400, 1000);

Color graphLinkColor(GraphLinkType type) => switch (type) {
  GraphLinkType.sameRecording => ResonanceColors.success,
  GraphLinkType.sameArtist => ResonanceColors.primary,
  GraphLinkType.sameAlbum => ResonanceColors.yandex,
  GraphLinkType.similar => ResonanceColors.vk,
  GraphLinkType.colisten => ResonanceColors.soundcloud,
  GraphLinkType.collaboration => ResonanceColors.spotify,
  GraphLinkType.genre => ResonanceColors.muted,
};

/// Interactive canvas map for the Music Graph tab plus «radio by path» and
/// «blind spots» panels.
class MusicGraphMapSection extends ConsumerWidget {
  const MusicGraphMapSection({
    required this.snapshot,
    this.nodeLimit,
    super.key,
  });

  final MusicGraphSnapshot snapshot;
  final int? nodeLimit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureEnabledProvider(FeatureFlag.graphMap))) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MusicGraphCanvas(
          snapshot: snapshot,
          nodeLimit: nodeLimit ?? defaultGraphNodeLimit(),
        ),
        const SizedBox(height: 16),
        const FeatureGate(
          flag: FeatureFlag.graphPathRadio,
          child: GraphPathRadioPanel(),
        ),
        const FeatureGate(
          flag: FeatureFlag.graphExplore,
          child: BlindSpotsPanel(),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}

class MusicGraphCanvas extends ConsumerStatefulWidget {
  const MusicGraphCanvas({
    required this.snapshot,
    required this.nodeLimit,
    super.key,
  });

  final MusicGraphSnapshot snapshot;
  final int nodeLimit;

  @override
  ConsumerState<MusicGraphCanvas> createState() => _MusicGraphCanvasState();
}

class _MusicGraphCanvasState extends ConsumerState<MusicGraphCanvas> {
  late GraphViewport _viewport;
  String? _selected;
  bool _personalLayer = true;
  bool _serverAvailable = true;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(MusicGraphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.snapshot, widget.snapshot) ||
        oldWidget.nodeLimit != widget.nodeLimit) {
      _rebuild();
    }
  }

  void _rebuild() {
    _viewport = GraphViewport(
      GraphMapData.fromLibrary(widget.snapshot),
      maxNodes: widget.nodeLimit,
    )..seed();
    _selected = null;
    _revision++;
  }

  Offset _toGraph(Offset local) =>
      local - Offset(_canvasSize.width / 2, _canvasSize.height / 2);

  Future<void> _onTap(Offset local) async {
    final id = _viewport.hitTest(_toGraph(local));
    if (id == null) return;
    setState(() {
      _selected = id;
      _viewport.expand(id);
      _revision++;
    });
    final node = _viewport.data.nodes[id];
    if (node == null ||
        node.kind != GraphNodeKind.artist ||
        !_serverAvailable ||
        !ref.read(featureEnabledProvider(FeatureFlag.graphExplore))) {
      return;
    }
    try {
      final json = await ref.read(graphApiProvider).artistNeighbors(node.label);
      if (!mounted) return;
      setState(() {
        _viewport.data.mergeArtistNeighbors(id, json);
        _viewport.expand(id);
        _revision++;
      });
    } on Object {
      // Server graph is optional: keep the local personal layer only.
      _serverAvailable = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected == null
        ? null
        : _viewport.data.nodes[_selected!];
    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'КАРТА СВЯЗЕЙ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: ResonanceColors.muted,
                  ),
                ),
              ),
              Text(
                '${_viewport.visibleCount}/${widget.nodeLimit}',
                style: const TextStyle(color: ResonanceColors.muted),
              ),
              const SizedBox(width: 8),
              FilterChip(
                key: const ValueKey('graph-personal-layer'),
                label: const Text('Личный слой'),
                selected: _personalLayer,
                onSelected: (value) => setState(() {
                  _personalLayer = value;
                  _revision++;
                }),
              ),
              IconButton(
                tooltip: 'Сбросить карту',
                onPressed: () => setState(_rebuild),
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 360,
              child: ColoredBox(
                color: ResonanceColors.background,
                child: InteractiveViewer(
                  constrained: false,
                  minScale: .3,
                  maxScale: 3,
                  boundaryMargin: const EdgeInsets.all(400),
                  child: GestureDetector(
                    key: const ValueKey('graph-canvas'),
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) =>
                        unawaited(_onTap(details.localPosition)),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: _canvasSize,
                        painter: _GraphPainter(
                          viewport: _viewport,
                          selected: _selected,
                          personalLayer: _personalLayer,
                          revision: _revision,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final type in GraphLinkType.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 3,
                      color: graphLinkColor(type),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      type.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: ResonanceColors.muted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (selected != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  selected.kind == GraphNodeKind.track
                      ? Icons.music_note_rounded
                      : Icons.person_rounded,
                  color: ResonanceColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selected.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (selected.track != null)
                  IconButton(
                    tooltip: 'Слушать',
                    onPressed: () => unawaited(
                      playTrackOrOpenOfficial(ref, selected.track!),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                if (selected.kind == GraphNodeKind.artist)
                  TextButton(
                    onPressed: () => context.push(
                      '/artist/${Uri.encodeComponent(selected.label)}',
                    ),
                    child: const Text('Артист'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          const Text(
            'Нажмите на узел, чтобы раскрыть связи. Колесо/щипок — масштаб.',
            style: TextStyle(color: ResonanceColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.viewport,
    required this.selected,
    required this.personalLayer,
    required this.revision,
  });

  final GraphViewport viewport;
  final String? selected;
  final bool personalLayer;
  final int revision;

  /// Text layout is the expensive part: label only the most important nodes.
  static const _maxLabels = 24;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    final edgePaint = Paint()..strokeWidth = 1.2;
    for (final edge in viewport.visibleEdges()) {
      edgePaint.color = graphLinkColor(edge.type).withValues(alpha: .55);
      canvas.drawLine(
        viewport.positions[edge.from]!,
        viewport.positions[edge.to]!,
        edgePaint,
      );
    }
    final data = viewport.data;
    final labelled = viewport.visible.toList()
      ..sort((a, b) => data.degreeOf(b).compareTo(data.degreeOf(a)));
    final labels = {
      ...labelled.take(_maxLabels),
      ...viewport.expanded,
      ?selected,
    };
    final fill = Paint();
    for (final id in viewport.visible) {
      final node = data.nodes[id];
      if (node == null) continue;
      final position = viewport.positions[id]!;
      final dimmed = personalLayer && !node.personal;
      final radius = node.kind == GraphNodeKind.track
          ? 5.0
          : 8.0 + data.degreeOf(id).clamp(0, 12).toDouble();
      fill.color =
          (node.personal && personalLayer
                  ? ResonanceColors.primary
                  : node.kind == GraphNodeKind.track
                  ? ResonanceColors.secondary
                  : ResonanceColors.vk)
              .withValues(alpha: dimmed ? .35 : 1);
      canvas.drawCircle(position, radius, fill);
      if (id == selected) {
        canvas.drawCircle(
          position,
          radius + 4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = ResonanceColors.text,
        );
      }
      if (labels.contains(id)) {
        final painter = TextPainter(
          text: TextSpan(
            text: node.label,
            style: TextStyle(
              color: ResonanceColors.text.withValues(alpha: dimmed ? .5 : .9),
              fontSize: 11,
            ),
          ),
          maxLines: 1,
          ellipsis: '…',
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 140);
        painter.paint(canvas, position + Offset(radius + 3, -7));
      }
    }
  }

  @override
  bool shouldRepaint(_GraphPainter oldDelegate) =>
      oldDelegate.revision != revision ||
      oldDelegate.selected != selected ||
      oldDelegate.personalLayer != personalLayer;
}

class GraphPathRadioPanel extends ConsumerStatefulWidget {
  const GraphPathRadioPanel({super.key});

  @override
  ConsumerState<GraphPathRadioPanel> createState() =>
      _GraphPathRadioPanelState();
}

class _GraphPathRadioPanelState extends ConsumerState<GraphPathRadioPanel> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  bool _busy = false;
  List<String>? _via;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_from.text.trim().isEmpty || _to.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(graphApiProvider)
          .path(_from.text, _to.text);
      final count = await playTrackList(ref, result.tracks);
      if (!mounted) return;
      setState(() => _via = result.via);
      showFeatureSnack(
        context,
        !result.found
            ? 'Прямого пути нет — играем ближайшее'
            : count == 0
            ? 'По пути не нашлось доступных треков'
            : 'Радио по пути: $count треков',
      );
    } on Object catch (error) {
      if (mounted) showFeatureSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FeatureCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Радио по пути A → B',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Плавный маршрут от одного артиста к другому через связи графа.',
          style: TextStyle(color: ResonanceColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 200,
              child: TextField(
                controller: _from,
                decoration: const InputDecoration(labelText: 'От (A)'),
              ),
            ),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _to,
                decoration: const InputDecoration(labelText: 'К (B)'),
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : () => unawaited(_start()),
              icon: const Icon(Icons.route_rounded),
              label: const Text('Запустить'),
            ),
          ],
        ),
        if (_via != null && _via!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _via!.join(' → '),
            style: const TextStyle(color: ResonanceColors.muted),
          ),
        ],
      ],
    ),
  );
}

class BlindSpotsPanel extends ConsumerWidget {
  const BlindSpotsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spots = ref.watch(blindSpotsProvider).valueOrNull;
    if (spots == null || spots.isEmpty) return const SizedBox.shrink();
    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Белые пятна',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const Text(
            'Рядом с вашей музыкой, но ещё не в медиатеке.',
            style: TextStyle(color: ResonanceColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final spot in spots.take(8))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.explore_outlined),
              title: Text(spot.artist),
              subtitle: spot.from == null
                  ? null
                  : Text('Рядом с «${spot.from}»'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () =>
                  context.push('/artist/${Uri.encodeComponent(spot.artist)}'),
            ),
        ],
      ),
    );
  }
}
