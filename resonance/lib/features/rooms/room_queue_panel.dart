import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/music_graph/music_graph.dart';
import 'package:resonance/features/rooms/room_controller.dart';
import 'package:resonance/shared/widgets/provider_badges.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

const _panelFill = Color(0xB3120E0C);
const _panelBorder = Color(0x1FFFFFFF);
const _warm = Color(0xFFFF8A5B);
const _cream = Color(0xFFF1ECE2);
const _soft = Color(0xFFA59D94);

String listenersLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  final word = mod10 == 1 && mod100 != 11
      ? 'слушатель'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
      ? 'слушателя'
      : 'слушателей';
  return '$count $word';
}

/// Плашка «● Комната · N слушателей» с аватарами участников.
class RoomChip extends ConsumerWidget {
  const RoomChip({this.compact = false, this.onTap, super.key});

  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomPresenceProvider);
    if (!room.inRoom) return const SizedBox.shrink();
    final count = room.participants.length;
    return Material(
      color: const Color(0x99100C0A),
      shape: const StadiumBorder(side: BorderSide(color: _panelBorder)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LiveDot(),
              const SizedBox(width: 8),
              Text(
                compact ? 'Комната · $count' : 'Комната ${room.code}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _cream,
                ),
              ),
              if (!compact) ...[
                Text(
                  ' · ${listenersLabel(count)}',
                  style: const TextStyle(fontSize: 12, color: _soft),
                ),
                const SizedBox(width: 10),
                ParticipantStack(participants: room.participants),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: const BoxDecoration(
      color: Color(0xFFFF5A36),
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: Color(0x99FF5A36), blurRadius: 8)],
    ),
  );
}

/// Перекрывающиеся кружки-аватары участников.
class ParticipantStack extends StatelessWidget {
  const ParticipantStack({
    required this.participants,
    this.size = 20,
    this.limit = 4,
    super.key,
  });

  final List<RoomParticipant> participants;
  final double size;
  final int limit;

  static const _tones = [
    Color(0xFFB8643F),
    Color(0xFF8C4A3A),
    Color(0xFF6F6A64),
    Color(0xFFC0473A),
    Color(0xFF4F6FA8),
    Color(0xFF3F8C68),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = participants.take(limit).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final extra = participants.length - shown.length;
    final step = size * .68;
    final slots = shown.length + (extra > 0 ? 1 : 0);
    return SizedBox(
      width: step * (slots - 1) + size,
      height: size,
      child: Stack(
        children: [
          for (var index = 0; index < shown.length; index++)
            Positioned(
              left: step * index,
              child: Tooltip(
                message: shown[index].name,
                child: _Avatar(
                  label: shown[index].name,
                  color:
                      _tones[shown[index].name.hashCode.abs() % _tones.length],
                  size: size,
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: step * shown.length,
              child: _Avatar(
                label: '+$extra',
                color: const Color(0xFF2B2522),
                size: size,
                raw: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.label,
    required this.color,
    required this.size,
    this.raw = false,
  });

  final String label;
  final Color color;
  final double size;
  final bool raw;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF120E0C), width: 1.5),
    ),
    child: Text(
      raw ? label : label.characters.first.toUpperCase(),
      style: TextStyle(
        fontSize: size * .42,
        fontWeight: FontWeight.w800,
        color: _cream,
        height: 1,
      ),
    ),
  );
}

/// «Очередь зала»: треки участников, отсортированные по голосам.
class RoomQueuePanel extends ConsumerWidget {
  const RoomQueuePanel({this.framed = true, super.key});

  /// `false` — без собственной подложки (внутри bottom sheet).
  final bool framed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomControllerProvider);
    final controller = ref.read(roomControllerProvider.notifier);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Очередь зала',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _cream,
                ),
              ),
            ),
            _PillButton(
              label: '+ Трек',
              tooltip: 'Предложить трек в очередь',
              onPressed: () => unawaited(showRoomTrackPicker(context)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: room.queue.isEmpty
              ? const _EmptyQueue()
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: room.queue.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final entry = room.queue[index];
                    return _QueueEntryTile(
                      key: ValueKey(entry.id),
                      entry: entry,
                      leading: index == 0,
                      voted: room.votedFor(entry),
                      ownEntry: entry.addedById == room.selfId,
                      removable: room.canRemove(entry),
                      onVote: () => unawaited(controller.vote(entry.id)),
                      onRemove: () =>
                          unawaited(controller.removeFromQueue(entry.id)),
                    );
                  },
                ),
        ),
        const Divider(height: 24, color: _panelBorder),
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: room.isHost
                      ? 'Вы ведущий. Следующий трек выберет '
                      : 'Следующий трек выберет ',
                  children: const [
                    TextSpan(
                      text: 'голос зала',
                      style: TextStyle(
                        color: _cream,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 12, color: _soft),
              ),
            ),
            if (room.isHost && room.queue.isNotEmpty)
              IconButton(
                tooltip: 'Включить лидера очереди сейчас',
                visualDensity: VisualDensity.compact,
                onPressed: () => unawaited(controller.playNextFromQueue()),
                icon: const Icon(Icons.skip_next_rounded, color: _warm),
              ),
          ],
        ),
      ],
    );
    if (!framed) return body;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
      decoration: BoxDecoration(
        color: _panelFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _panelBorder),
      ),
      child: body,
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        'Очередь пуста. Предложите трек — участники проголосуют, '
        'что прозвучит следующим.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _soft, fontSize: 12, height: 1.5),
      ),
    ),
  );
}

class _QueueEntryTile extends StatelessWidget {
  const _QueueEntryTile({
    required this.entry,
    required this.leading,
    required this.voted,
    required this.ownEntry,
    required this.removable,
    required this.onVote,
    required this.onRemove,
    super.key,
  });

  final RoomQueueEntry entry;
  final bool leading;
  final bool voted;
  final bool ownEntry;
  final bool removable;
  final VoidCallback onVote;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final track = entry.track;
    return AnimatedContainer(
      duration: ResonanceMotion.standard,
      curve: ResonanceMotion.curve,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: leading ? const Color(0x33B8432C) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: leading ? const Color(0x80C0503A) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          TrackArtwork(track: track, size: 44, borderRadius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _cream,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${track.artist} · ${ownEntry ? 'добавили вы' : 'добавил(а) ${entry.addedByName}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _soft),
                ),
              ],
            ),
          ),
          if (removable)
            IconButton(
              tooltip: 'Убрать из очереди',
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, color: _soft),
            ),
          _VoteButton(
            votes: entry.votes,
            voted: voted,
            locked: ownEntry,
            onPressed: onVote,
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.votes,
    required this.voted,
    required this.locked,
    required this.onPressed,
  });

  final int votes;
  final bool voted;
  final bool locked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: locked
        ? 'Ваш трек: голос учтён автоматически'
        : voted
        ? 'Снять голос'
        : 'Поднять в очереди',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '▲ $votes',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: voted ? _warm : _soft,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox.square(
          dimension: 28,
          child: Material(
            color: voted ? const Color(0x2EFF8A5B) : const Color(0x0FFFFFFF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: voted ? const Color(0x99FF8A5B) : _panelBorder,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: locked ? null : onPressed,
              child: Icon(
                Icons.arrow_drop_up_rounded,
                size: 22,
                color: voted ? _warm : _cream,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _cream,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        side: const BorderSide(color: Color(0x33FFFFFF)),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    ),
  );
}

/// Очередь зала во всплывающем листе — для телефонов.
Future<void> showRoomQueueSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141010),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .62,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: RoomQueuePanel(framed: false),
          ),
        ),
      ),
    );

/// Выбор трека для очереди: из текущей сессии, избранного или поиска.
Future<void> showRoomTrackPicker(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141010),
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: const _RoomTrackPicker(),
      ),
    );

class _RoomTrackPicker extends ConsumerStatefulWidget {
  const _RoomTrackPicker();

  @override
  ConsumerState<_RoomTrackPicker> createState() => _RoomTrackPickerState();
}

class _RoomTrackPickerState extends ConsumerState<_RoomTrackPicker> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<UnifiedTrack> _remote = const [];
  bool _searching = false;
  final Set<String> _added = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_search(value.trim())),
    );
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() {
        _remote = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final registry = ref.read(providerRegistryProvider);
    final batches = await Future.wait([
      for (final provider in const [
        MusicProvider.yandex,
        MusicProvider.soundcloud,
        MusicProvider.spotify,
        MusicProvider.vk,
      ])
        if (registry.catalogFor(provider) case final catalog?)
          catalog
              .searchTracks(query, limit: 10)
              .onError((_, _) => const <UnifiedTrack>[]),
    ]);
    if (!mounted || _query.text.trim() != query) return;
    setState(() {
      _remote = const MusicGraphBuilder().canonicalize(
        batches.expand((batch) => batch),
      );
      _searching = false;
    });
  }

  Future<void> _add(UnifiedTrack track) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final error = await ref
        .read(roomControllerProvider.notifier)
        .addToQueue(track);
    if (!mounted) return;
    if (error == null) {
      setState(() => _added.add(track.id));
    } else {
      messenger?.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackStateProvider).valueOrNull;
    final library = ref.watch(libraryControllerProvider).valueOrNull;
    final queued = {
      for (final entry in ref.watch(roomControllerProvider).queue)
        entry.track.id,
    };
    final query = _query.text.trim().toLowerCase();
    final local =
        <String, UnifiedTrack>{
          for (final track in [...?playback?.queue, ...?library?.favorites])
            track.id: track,
        }.values.where(
          (track) =>
              query.isEmpty ||
              track.title.toLowerCase().contains(query) ||
              track.artist.toLowerCase().contains(query),
        );
    final tracks = <String, UnifiedTrack>{
      for (final track in [...local.take(30), ..._remote]) track.id: track,
    }.values.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Предложить трек залу',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _cream,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _query,
                autofocus: false,
                onChanged: _onQuery,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Название или исполнитель',
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: tracks.isEmpty
              ? Center(
                  child: Text(
                    _searching
                        ? 'Ищем…'
                        : query.isEmpty
                        ? 'Начните вводить название трека.'
                        : 'Ничего не нашлось.',
                    style: const TextStyle(color: _soft),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final inQueue =
                        queued.contains(track.id) || _added.contains(track.id);
                    final provider =
                        track.preferredProvider ??
                        track.sources.firstOrNull?.provider;
                    return ListTile(
                      leading: TrackArtwork(
                        track: track,
                        size: 44,
                        borderRadius: 10,
                      ),
                      title: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _soft),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (provider != null)
                            ProviderBadge(provider: provider, compact: true),
                          const SizedBox(width: 6),
                          inQueue
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: _warm,
                                )
                              : IconButton(
                                  tooltip: 'В очередь зала',
                                  onPressed: () => unawaited(_add(track)),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                        ],
                      ),
                      onTap: inQueue ? null : () => unawaited(_add(track)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
