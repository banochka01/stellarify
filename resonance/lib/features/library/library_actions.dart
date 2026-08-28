import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_controller.dart';

Future<void> showAddToPlaylistDialog(
  BuildContext context,
  WidgetRef ref,
  UnifiedTrack track,
) async {
  final library = await ref.read(libraryControllerProvider.future);
  if (!context.mounted) return;
  final selection = await showDialog<String>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('Добавить в плейлист'),
      children: [
        for (final playlist in library.playlists)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, playlist.id),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.playlist_play_rounded),
              title: Text(playlist.name),
              subtitle: Text('${playlist.trackCount} треков'),
            ),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, '__new__'),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.add_rounded),
            title: Text('Новый плейлист'),
          ),
        ),
      ],
    ),
  );
  if (selection == null || !context.mounted) return;
  var playlistId = selection;
  if (selection == '__new__') {
    final name = await showCreatePlaylistDialog(context);
    if (name == null || !context.mounted) return;
    playlistId = await ref
        .read(libraryControllerProvider.notifier)
        .createPlaylist(name);
  }
  await ref
      .read(libraryControllerProvider.notifier)
      .addToPlaylist(playlistId, track);
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Трек добавлен в плейлист')));
}

Future<String?> showCreatePlaylistDialog(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Новый плейлист'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 80,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'Например, Ночной вайб'),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.pop(dialogContext, value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isNotEmpty) Navigator.pop(dialogContext, value);
          },
          child: const Text('Создать'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}
