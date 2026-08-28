import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/rooms/room_controller.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();

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
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const Text(
          'СЛУШАТЬ ВМЕСТЕ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: ResonanceColors.primary,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Одна комната. Один ритм.',
          style: TextStyle(
            fontSize: 38,
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
        if (!room.inRoom)
          _JoinPanel(
            name: _name,
            code: _code,
            busy: room.busy,
            onCreate: () => controller.create(_name.text),
            onJoin: () => controller.join(_code.text, _name.text),
          )
        else
          _ActiveRoom(
            room: room,
            isHost: controller.isHost,
            onLeave: controller.leave,
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

class _JoinPanel extends StatelessWidget {
  const _JoinPanel({
    required this.name,
    required this.code,
    required this.busy,
    required this.onCreate,
    required this.onJoin,
  });
  final TextEditingController name;
  final TextEditingController code;
  final bool busy;
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
        const SizedBox(height: 18),
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
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-fA-F0-9]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Код комнаты',
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

class _ActiveRoom extends StatelessWidget {
  const _ActiveRoom({
    required this.room,
    required this.isHost,
    required this.onLeave,
  });
  final ListeningRoomState room;
  final bool isHost;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) => Container(
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
            const Spacer(),
            IconButton(
              tooltip: 'Скопировать код',
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: room.code!)),
              icon: const Icon(Icons.copy_rounded),
            ),
            TextButton(onPressed: onLeave, child: const Text('Выйти')),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isHost
              ? 'Вы ведущий — ваши трек, пауза и перемотка синхронизируются.'
              : 'Управляет ведущий. Позиция автоматически выравнивается.',
          style: const TextStyle(color: ResonanceColors.muted),
        ),
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
            trailing: participant.id == room.hostId
                ? const Chip(label: Text('Ведущий'))
                : null,
          ),
      ],
    ),
  );
}
