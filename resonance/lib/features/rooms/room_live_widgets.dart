import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/rooms/room_controller.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

/// Эмодзи-реакции комнаты, всплывающие поверх Visual Stage, и вертикальная
/// панель, чтобы отправить свою.
class RoomReactionsOverlay extends ConsumerWidget {
  const RoomReactionsOverlay({this.showBar = true, super.key});

  final bool showBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactions = ref.watch(
      roomPresenceProvider.select((room) => room.reactions),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (final reaction in reactions)
                _FloatingReaction(key: ValueKey(reaction.id), reaction: reaction),
            ],
          ),
        ),
        if (showBar)
          const Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: 14),
              child: RoomReactionBar(vertical: true),
            ),
          ),
      ],
    );
  }
}

class _FloatingReaction extends StatefulWidget {
  const _FloatingReaction({required this.reaction, super.key});

  final RoomReaction reaction;

  @override
  State<_FloatingReaction> createState() => _FloatingReactionState();
}

class _FloatingReactionState extends State<_FloatingReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();

  // Горизонталь зависит от id, чтобы реакции не складывались в столбик.
  late final double _x = (widget.reaction.id.hashCode % 1000) / 1000 * .5 + .4;
  late final double _drift = ((widget.reaction.id.hashCode >> 4) % 100 - 50) / 900;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        final opacity = _controller.value < .12
            ? _controller.value / .12
            : (1 - (_controller.value - .12) / .88).clamp(0.0, 1.0);
        return Align(
          alignment: Alignment(
            (_x + _drift * t) * 2 - 1,
            reduced ? .6 : .85 - t * 1.1,
          ),
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: Semantics(
        label: '${widget.reaction.fromName}: ${widget.reaction.emoji}',
        child: Text(
          widget.reaction.emoji,
          style: const TextStyle(
            fontSize: 38,
            shadows: [Shadow(color: Color(0x88000000), blurRadius: 14)],
          ),
        ),
      ),
    );
  }
}

/// Кнопки реакций; доступны всем участникам комнаты.
class RoomReactionBar extends ConsumerWidget {
  const RoomReactionBar({this.vertical = false, super.key});

  final bool vertical;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inRoom = ref.watch(roomPresenceProvider.select((r) => r.inRoom));
    if (!inRoom) return const SizedBox.shrink();
    final buttons = [
      for (final emoji in roomReactionEmojis)
        IconButton(
          tooltip: 'Реакция $emoji',
          visualDensity: VisualDensity.compact,
          onPressed: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(ref.read(roomControllerProvider.notifier).react(emoji));
          },
          icon: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x990D0A10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: vertical
            ? Column(mainAxisSize: MainAxisSize.min, children: buttons)
            : Wrap(children: buttons),
      ),
    );
  }
}

/// Короткий текстовый чат комнаты: без медиа, до 280 символов.
class RoomChatPanel extends ConsumerStatefulWidget {
  const RoomChatPanel({super.key});

  @override
  ConsumerState<RoomChatPanel> createState() => _RoomChatPanelState();
}

class _RoomChatPanelState extends ConsumerState<RoomChatPanel> {
  final _input = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _input.text.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await ref
        .read(roomControllerProvider.notifier)
        .sendChat(_input.text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = error;
      if (error == null) _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomControllerProvider);
    final messages = room.chat.reversed.toList(growable: false);
    return _Section(
      title: 'ЧАТ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 200,
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'Пока тихо. Напишите первым.',
                      style: TextStyle(color: ResonanceColors.muted),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final mine = message.fromId == room.selfId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${message.fromName}  ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: mine
                                      ? ResonanceColors.live
                                      : ResonanceColors.primary,
                                ),
                              ),
                              TextSpan(text: message.text),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _input,
            maxLength: roomChatMaxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => unawaited(_send()),
            decoration: InputDecoration(
              hintText: 'Сообщение комнате',
              errorText: _error,
              suffixIcon: IconButton(
                tooltip: 'Отправить',
                onPressed: _sending ? null : () => unawaited(_send()),
                icon: const Icon(Icons.send_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Плейлист сессии: всё, что прозвучало, сохраняется одним тапом.
class RoomPlayedPanel extends ConsumerStatefulWidget {
  const RoomPlayedPanel({super.key});

  @override
  ConsumerState<RoomPlayedPanel> createState() => _RoomPlayedPanelState();
}

class _RoomPlayedPanelState extends ConsumerState<RoomPlayedPanel> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final count = await ref
          .read(roomControllerProvider.notifier)
          .savePlayedToLibrary();
      messenger?.showSnackBar(
        SnackBar(content: Text('Плейлист комнаты сохранён: $count треков')),
      );
    } on Object {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить плейлист')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final played = ref.watch(roomControllerProvider.select((r) => r.played));
    return _Section(
      title: 'ПРОЗВУЧАЛО В КОМНАТЕ',
      trailing: FilledButton.tonalIcon(
        onPressed: played.isEmpty || _saving ? null : () => unawaited(_save()),
        icon: const Icon(Icons.library_add_rounded, size: 18),
        label: const Text('Сохранить себе'),
      ),
      child: played.isEmpty
          ? const Text(
              'Треки появятся, когда ведущий начнёт играть.',
              style: TextStyle(color: ResonanceColors.muted),
            )
          : Column(
              children: [
                for (final track in played.reversed.take(8))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (played.length > 8)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'и ещё ${played.length - 8}',
                      style: const TextStyle(color: ResonanceColors.muted),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// История прошлых сессий с кнопкой «Переслушать».
class RoomHistoryPanel extends ConsumerStatefulWidget {
  const RoomHistoryPanel({super.key});

  @override
  ConsumerState<RoomHistoryPanel> createState() => _RoomHistoryPanelState();
}

class _RoomHistoryPanelState extends ConsumerState<RoomHistoryPanel> {
  Future<List<RoomSessionSummary>>? _sessions;

  void _load() {
    setState(() {
      _sessions = ref.read(roomControllerProvider.notifier).history();
    });
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(
      roomControllerProvider.select((r) => r.connected),
    );
    if (connected && _sessions == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sessions == null) _load();
      });
    }
    return _Section(
      title: 'ИСТОРИЯ СЕССИЙ',
      trailing: IconButton(
        tooltip: 'Обновить',
        onPressed: connected ? _load : null,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: FutureBuilder<List<RoomSessionSummary>>(
        future: _sessions,
        builder: (context, snapshot) {
          final sessions = snapshot.data ?? const <RoomSessionSummary>[];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator();
          }
          if (sessions.isEmpty) {
            return const Text(
              'Здесь появятся комнаты, где вы слушали музыку вместе.',
              style: TextStyle(color: ResonanceColors.muted),
            );
          }
          return Column(
            children: [
              for (final session in sessions.take(10))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded),
                  title: Text('Комната ${session.code}'),
                  subtitle: Text(
                    '${_formatDate(session.startedAt)} · '
                    '${session.tracks.length} тр.',
                  ),
                  trailing: TextButton(
                    onPressed: () => unawaited(
                      ref.read(roomControllerProvider.notifier).replay(session),
                    ),
                    child: const Text('Переслушать'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

String _formatDate(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)} '
      '${two(value.hour)}:${two(value.minute)}';
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 680),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: ResonanceColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ResonanceColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: ResonanceColors.muted,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}
