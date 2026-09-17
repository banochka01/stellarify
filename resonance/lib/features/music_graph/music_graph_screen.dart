import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/music_graph/music_graph.dart';
import 'package:resonance/features/player/track_action.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/provider_badges.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

class MusicGraphScreen extends ConsumerStatefulWidget {
  const MusicGraphScreen({super.key});

  @override
  ConsumerState<MusicGraphScreen> createState() => _MusicGraphScreenState();
}

class _MusicGraphScreenState extends ConsumerState<MusicGraphScreen> {
  String? _selectedId;
  bool _cleaning = false;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final library = ref.watch(libraryControllerProvider);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            compact ? 18 : 38,
            compact ? 24 : 34,
            compact ? 18 : 38,
            130,
          ),
          sliver: SliverList.list(
            children: [
              const Text(
                'MUSIC GRAPH',
                style: TextStyle(
                  color: ResonanceColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Музыка — это связи.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: compact ? 40 : 62,
                  height: .95,
                  letterSpacing: compact ? -2 : -3,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Resonance объединяет один трек из разных сервисов и показывает его окружение по артисту и альбому.',
                style: TextStyle(
                  color: ResonanceColors.muted,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              library.when(
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (error, _) => _GraphMessage(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось построить граф',
                  subtitle: error.toString(),
                ),
                data: (state) {
                  final graph = const MusicGraphBuilder().build(
                    state.graphTracks,
                  );
                  if (graph.nodes.isEmpty) {
                    return const _GraphMessage(
                      icon: Icons.hub_outlined,
                      title: 'Граф пока пуст',
                      subtitle:
                          'Добавьте треки в избранное или импортируйте плейлист — связи появятся автоматически.',
                    );
                  }
                  final selected = graph.nodes
                      .where((node) => node.track.id == _selectedId)
                      .firstOrNull;
                  final current = selected ?? _initialNode(graph.nodes);
                  return _GraphContent(
                    graph: graph,
                    selected: current,
                    compact: compact,
                    cleaning: _cleaning,
                    onSelected: (id) => setState(() => _selectedId = id),
                    onPlay: (track) =>
                        unawaited(playTrackOrOpenOfficial(ref, track)),
                    onCleanup: graph.duplicateCount == 0
                        ? null
                        : () => _cleanup(graph.duplicateCount),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  MusicGraphNode _initialNode(List<MusicGraphNode> nodes) {
    final ranked = [...nodes]
      ..sort((left, right) {
        final duplicates = right.duplicateCount.compareTo(left.duplicateCount);
        return duplicates != 0
            ? duplicates
            : right.sourceCount.compareTo(left.sourceCount);
      });
    return ranked.first;
  }

  Future<void> _cleanup(int duplicates) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Объединить совпадения?'),
        content: Text(
          'Music Graph объединит $duplicates дубликатов, сохранит все источники и обновит плейлисты. Разные версии с отличающимся названием или длительностью останутся отдельно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Объединить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cleaning = true);
    try {
      final result = await ref
          .read(libraryControllerProvider.notifier)
          .reconcileMusicGraph();
      if (!mounted) return;
      setState(() => _selectedId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Объединено записей: ${result.mergedTracks} · источников сохранено: ${result.sources}',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить граф: $error')),
      );
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }
}

class _GraphContent extends StatelessWidget {
  const _GraphContent({
    required this.graph,
    required this.selected,
    required this.compact,
    required this.cleaning,
    required this.onSelected,
    required this.onPlay,
    required this.onCleanup,
  });

  final MusicGraphSnapshot graph;
  final MusicGraphNode selected;
  final bool compact;
  final bool cleaning;
  final ValueChanged<String> onSelected;
  final ValueChanged<UnifiedTrack> onPlay;
  final VoidCallback? onCleanup;

  @override
  Widget build(BuildContext context) {
    final explorer = _GraphExplorer(
      graph: graph,
      selected: selected,
      onSelected: onSelected,
    );
    final detail = _NodeDetails(node: selected, onPlay: onPlay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Metric(value: '${graph.nodes.length}', label: 'композиций'),
            _Metric(value: '${graph.sourceCount}', label: 'источников'),
            _Metric(value: '${graph.artistCount}', label: 'артистов'),
            _Metric(
              value: '${graph.duplicateCount}',
              label: 'совпадений',
              accent: graph.duplicateCount > 0,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: cleaning ? null : onCleanup,
            icon: cleaning
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.merge_rounded),
            label: Text(
              graph.duplicateCount == 0
                  ? 'Медиатека уже чистая'
                  : 'Объединить совпадения · ${graph.duplicateCount}',
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (compact) ...[
          explorer,
          const SizedBox(height: 14),
          detail,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: explorer),
              const SizedBox(width: 14),
              Expanded(flex: 3, child: detail),
            ],
          ),
      ],
    );
  }
}

class _GraphExplorer extends StatelessWidget {
  const _GraphExplorer({
    required this.graph,
    required this.selected,
    required this.onSelected,
  });

  final MusicGraphSnapshot graph;
  final MusicGraphNode selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final relatedIds = graph
        .relationsFor(selected.track.id)
        .expand((edge) => [edge.fromId, edge.toId])
        .where((id) => id != selected.track.id)
        .toSet();
    final related = graph.nodes
        .where((node) => relatedIds.contains(node.track.id))
        .take(8)
        .toList();
    if (related.length < 5) {
      related.addAll(
        graph.nodes
            .where(
              (node) =>
                  node.track.id != selected.track.id &&
                  !related.any((item) => item.track.id == node.track.id),
            )
            .take(5 - related.length),
      );
    }
    return Container(
      height: 500,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ResonanceColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ResonanceColors.border),
        gradient: const RadialGradient(
          center: Alignment(.05, -.1),
          radius: 1.1,
          colors: [Color(0x223EFFA2), ResonanceColors.surface],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final center = Offset(
            constraints.maxWidth / 2,
            constraints.maxHeight / 2,
          );
          final radius = math.min(
            constraints.maxWidth * .34,
            constraints.maxHeight * .34,
          );
          final positions = <Offset>[
            for (var i = 0; i < related.length; i++)
              center +
                  Offset.fromDirection(
                    -math.pi / 2 + i * math.pi * 2 / related.length,
                    radius,
                  ),
          ];
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GraphLines(center: center, points: positions),
                ),
              ),
              _NodeBubble(
                node: selected,
                center: center,
                selected: true,
                onTap: () {},
              ),
              for (var index = 0; index < related.length; index++)
                _NodeBubble(
                  node: related[index],
                  center: positions[index],
                  selected: false,
                  onTap: () => onSelected(related[index].track.id),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GraphLines extends CustomPainter {
  const _GraphLines({required this.center, required this.points});

  final Offset center;
  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ResonanceColors.primary.withValues(alpha: .26)
      ..strokeWidth = 1.2;
    for (final point in points) {
      canvas.drawLine(center, point, paint);
      canvas.drawCircle(point, 3, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphLines oldDelegate) =>
      oldDelegate.center != center || oldDelegate.points != points;
}

class _NodeBubble extends StatelessWidget {
  const _NodeBubble({
    required this.node,
    required this.center,
    required this.selected,
    required this.onTap,
  });

  final MusicGraphNode node;
  final Offset center;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 132.0 : 92.0;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: Tooltip(
        message: '${node.track.title} — ${node.track.artist}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size),
          child: Container(
            padding: EdgeInsets.all(selected ? 10 : 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? ResonanceColors.primary.withValues(alpha: .18)
                  : ResonanceColors.surfaceHigh,
              border: Border.all(
                color: selected
                    ? ResonanceColors.primary
                    : ResonanceColors.border,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: ResonanceColors.primary.withValues(alpha: .18),
                        blurRadius: 28,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  node.sourceCount > 1
                      ? Icons.hub_rounded
                      : Icons.music_note_rounded,
                  color: selected
                      ? ResonanceColors.primary
                      : ResonanceColors.muted,
                  size: selected ? 30 : 22,
                ),
                const SizedBox(height: 7),
                Text(
                  node.track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: selected ? 12 : 10,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                if (node.sourceCount > 1)
                  Text(
                    '${node.sourceCount} источника',
                    style: const TextStyle(
                      color: ResonanceColors.muted,
                      fontSize: 8,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NodeDetails extends StatelessWidget {
  const _NodeDetails({required this.node, required this.onPlay});

  final MusicGraphNode node;
  final ValueChanged<UnifiedTrack> onPlay;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: ResonanceColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: ResonanceColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TrackArtwork(track: node.track, size: 96, borderRadius: 18),
        const SizedBox(height: 18),
        Text(
          node.track.title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          node.track.artist,
          style: const TextStyle(color: ResonanceColors.muted),
        ),
        if (node.track.album != null) ...[
          const SizedBox(height: 4),
          Text(
            node.track.album!,
            style: const TextStyle(color: ResonanceColors.muted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 22),
        const Text(
          'ИСТОЧНИКИ',
          style: TextStyle(
            color: ResonanceColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final source in node.track.sources)
              Chip(
                avatar: ProviderBadge(provider: source.provider, compact: true),
                label: Text(_providerName(source.provider)),
              ),
          ],
        ),
        if (node.duplicateCount > 0) ...[
          const SizedBox(height: 16),
          Text(
            '${node.duplicateCount + 1} записи распознаны как одна композиция.',
            style: const TextStyle(
              color: ResonanceColors.primary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => onPlay(node.track),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Воспроизвести'),
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    this.accent = false,
  });

  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) => Container(
    width: 142,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: accent
          ? ResonanceColors.primary.withValues(alpha: .1)
          : ResonanceColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: accent ? ResonanceColors.primary : ResonanceColors.border,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(color: ResonanceColors.muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _GraphMessage extends StatelessWidget {
  const _GraphMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 80),
    child: Center(
      child: Column(
        children: [
          Icon(icon, size: 52, color: ResonanceColors.muted),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ResonanceColors.muted),
            ),
          ),
        ],
      ),
    ),
  );
}

String _providerName(MusicProvider provider) => switch (provider) {
  MusicProvider.yandex => 'Яндекс',
  MusicProvider.spotify => 'Spotify',
  MusicProvider.vk => 'VK',
  MusicProvider.soundcloud => 'SoundCloud',
  MusicProvider.youtube => 'YouTube',
};
