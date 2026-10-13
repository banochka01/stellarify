import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/features/platform/feature_flags.dart';
import 'package:resonance/features/rooms/room_controller.dart';
import 'package:resonance/features/rooms/room_dj_panel.dart';
import 'package:resonance/features/rooms/room_live_widgets.dart';
import 'package:resonance/features/rooms/room_queue_panel.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({this.initialLink, super.key});

  /// Код или ссылка-приглашение из маршрута `/rooms?code=…&invite=…`.
  final String? initialLink;

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  final _name = TextEditingController();
  late final _code = TextEditingController(text: widget.initialLink ?? '');
  bool _private = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomControllerProvider);
    final controller = ref.read(roomControllerProvider.notifier);
    final compact = MediaQuery.sizeOf(context).width < 650;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 34,
        compact ? 24 : 32,
        compact ? 18 : 34,
        130,
      ),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'СЛУШАТЬ ВМЕСТЕ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: ResonanceColors.primary,
                ),
              ),
            ),
            FeatureGate(
              flag: FeatureFlag.social,
              child: TextButton.icon(
                onPressed: () => context.push('/social'),
                icon: const Icon(Icons.people_alt_rounded, size: 18),
                label: const Text('Друзья'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Одна комната. Один ритм.',
          style: TextStyle(
            fontSize: compact ? 34 : 42,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          room.connected
              ? 'Сервер комнат подключён'
              : 'Подключаем сервер комнат…',
          style: TextStyle(
            color: room.connected
                ? const Color(0xFF7ACB93)
                : ResonanceColors.muted,
          ),
        ),
        const SizedBox(height: 28),
        ResonanceAnimatedSwap(
          child: KeyedSubtree(
            key: ValueKey(room.inRoom),
            child: room.inRoom
                ? _RoomLayout(
                    wide: !compact && MediaQuery.sizeOf(context).width >= 1100,
                    room: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ActiveRoom(
                          room: room,
                          isHost: controller.isHost,
                          onLeave: controller.leave,
                        ),
                        const SizedBox(height: 18),
                        const RoomReactionBar(),
                        const SizedBox(height: 18),
                        const RoomChatPanel(),
                        const SizedBox(height: 18),
                        const RoomPlayedPanel(),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _JoinPanel(
                        name: _name,
                        code: _code,
                        busy: room.busy,
                        private: _private,
                        onPrivateChanged: (value) =>
                            setState(() => _private = value),
                        onCreate: () =>
                            controller.create(_name.text, private: _private),
                        onJoin: () => controller.join(_code.text, _name.text),
                      ),
                      const SizedBox(height: 18),
                      const RoomHistoryPanel(),
                    ],
                  ),
          ),
        ),
        if (room.error != null) ...[
          const SizedBox(height: 16),
          Text(
            room.error!,
            style: const TextStyle(color: ResonanceColors.primary),
          ),
        ],
      ],
    );
  }
}

class _RoomLayout extends StatelessWidget {
  const _RoomLayout({required this.wide, required this.room});

  final bool wide;
  final Widget room;

  @override
  Widget build(BuildContext context) {
    const queue = SizedBox(height: 460, child: RoomQueuePanel());
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [room, const SizedBox(height: 18), queue],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(child: room),
        const SizedBox(width: 22),
        const SizedBox(width: 380, child: queue),
      ],
    );
  }
}

class _JoinPanel extends StatelessWidget {
  const _JoinPanel({
    required this.name,
    required this.code,
    required this.busy,
    required this.private,
    required this.onPrivateChanged,
    required this.onCreate,
    required this.onJoin,
  });
  final TextEditingController name;
  final TextEditingController code;
  final bool busy;
  final bool private;
  final ValueChanged<bool> onPrivateChanged;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 680),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: ResonanceColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ResonanceColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: name,
          maxLength: 32,
          decoration: const InputDecoration(
            labelText: 'Ваше имя',
            hintText: 'Например, monyx',
            counterText: '',
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: private,
          onChanged: onPrivateChanged,
          title: const Text('Приватная комната'),
          subtitle: const Text('Войти можно только по ссылке-приглашению'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: busy ? null : onCreate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Создать комнату'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 22),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'ИЛИ',
                  style: TextStyle(color: ResonanceColors.muted, fontSize: 10),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: code,
                maxLength: 256,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Код комнаты или ссылка-приглашение',
                  hintText: 'A1B2C3',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: busy ? null : onJoin,
              child: const Text('Войти'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ActiveRoom extends ConsumerWidget {
  const _ActiveRoom({
    required this.room,
    required this.isHost,
    required this.onLeave,
  });
  final ListeningRoomState room;
  final bool isHost;
  final VoidCallback onLeave;

  Future<void> _copyInvite(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final link = await ref.read(roomControllerProvider.notifier).inviteLink();
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    messenger?.showSnackBar(
      const SnackBar(content: Text('Ссылка-приглашение скопирована')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    constraints: const BoxConstraints(maxWidth: 680),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: ResonanceColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ResonanceColors.primary.withValues(alpha: .35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.graphic_eq_rounded,
              color: ResonanceColors.primary,
            ),
            const SizedBox(width: 10),
            Text(
              'КОМНАТА ${room.code}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            if (room.isPrivate) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.lock_rounded,
                size: 16,
                color: ResonanceColors.muted,
              ),
            ],
            const Spacer(),
            IconButton(
              tooltip: 'Скопировать код',
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: room.code!)),
              icon: const Icon(Icons.copy_rounded),
            ),
            if (room.canControl)
              IconButton(
                tooltip: 'Скопировать ссылку-приглашение',
                onPressed: () => unawaited(_copyInvite(context, ref)),
                icon: const Icon(Icons.link_rounded),
              ),
            TextButton(onPressed: onLeave, child: const Text('Выйти')),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isHost
              ? 'Вы ведущий — ваши трек, пауза и перемотка синхронизируются.'
              : room.selfRole == RoomRole.dj
              ? 'Вы диджей — можете включать следующий трек и чистить очередь.'
              : 'Управляет ведущий. Позиция автоматически выравнивается.',
          style: const TextStyle(color: ResonanceColors.muted),
        ),
        if (isHost)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: room.isPrivate,
            onChanged: (value) => unawaited(
              ref.read(roomControllerProvider.notifier).setPrivate(value),
            ),
            title: const Text('Только по приглашению'),
            subtitle: const Text('Новая ссылка отменяет старые'),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.push('/stage'),
          icon: const Icon(Icons.fullscreen_rounded),
          label: const Text('Открыть Stage с очередью зала'),
        ),
        RoomDjPanel(canControl: room.canControl),
        const SizedBox(height: 24),
        const Text(
          'УЧАСТНИКИ',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: ResonanceColors.muted,
          ),
        ),
        const SizedBox(height: 12),
        for (final participant in room.participants)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: ResonanceColors.surfaceHigh,
              child: Text(participant.name.characters.first.toUpperCase()),
            ),
            title: Text(participant.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (participant.role != RoomRole.listener)
                  Chip(label: Text(participant.role.label)),
                if (isHost && participant.role != RoomRole.host)
                  PopupMenuButton<RoomRole>(
                    tooltip: 'Роль участника',
                    onSelected: (role) => unawaited(
                      ref
                          .read(roomControllerProvider.notifier)
                          .setRole(participant.id, role),
                    ),
                    itemBuilder: (context) => [
                      for (final role in const [RoomRole.dj, RoomRole.listener])
                        CheckedPopupMenuItem(
                          value: role,
                          checked: participant.role == role,
                          child: Text(role.label),
                        ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}
