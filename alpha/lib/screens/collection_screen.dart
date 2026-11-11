import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/auth/account_controller.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';
import 'package:resonance_alpha/design/accent.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/design/widgets.dart';
import 'package:resonance_alpha/screens/account_sheet.dart';
import 'package:resonance_alpha/screens/tracklist_screen.dart';
import 'package:resonance_alpha/state.dart';

class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pad = wide ? 48.0 : 20.0;
    final library = ref.watch(libraryControllerProvider);
    final account = ref.watch(accountControllerProvider);
    final accent = ref.watch(currentAccentProvider);
    final favorites = library.valueOrNull?.favorites ?? const [];
    final playlists = library.valueOrNull?.playlists ?? const [];

    final likes = Press(
      scale: .98,
      onTap: () => Navigator.of(context).push(
        TracklistScreen.route(
          title: 'Мне нравится',
          load: () async =>
              (await ref.read(libraryControllerProvider.future)).favorites,
        ),
      ),
      child: Container(
        height: wide ? 300 : 220,
        padding: EdgeInsets.all(wide ? 32 : 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(accent, Pal.stage, .55)!,
              Color.lerp(accent, Pal.stage, .86)!,
            ],
          ),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              child: Row(
                children: [
                  for (final track in favorites.take(3))
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: TrackArtwork(
                        track: track,
                        size: wide ? 72 : 52,
                        borderRadius: 14,
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              right: 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${favorites.length}',
                          style: Txt.mono(14, color: Pal.paper),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Мне\nнравится',
                          style: Txt.display(wide ? 76 : 48, color: Pal.paper),
                        ),
                      ],
                    ),
                  ),
                  Knob(
                    icon: Icons.play_arrow_rounded,
                    size: wide ? 72 : 60,
                    filled: true,
                    color: accent,
                    iconColor: inkOn(accent),
                    onTap: favorites.isEmpty
                        ? null
                        : () => run(context, () => playList(ref, favorites)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, wide ? 48 : 20, pad, 160),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  Text('03 / КОЛЛЕКЦИЯ', style: Txt.mono(12)),
                  const Spacer(),
                  Press(
                    onTap: () => showAccountSheet(context),
                    child: Text(
                      account.valueOrNull?.email.toUpperCase() ?? 'ВОЙТИ →',
                      style: Txt.mono(12, color: Pal.paper),
                    ),
                  ),
                ],
              ),
              SizedBox(height: wide ? 40 : 24),
              likes,
              const SizedBox(height: 56),
              SectionHead(
                index: '01',
                title: 'Плейлисты',
                trailing: Pill(
                  label: 'Создать',
                  icon: Icons.add_rounded,
                  onTap: () => _create(context, ref),
                ),
              ),
              if (library.isLoading && playlists.isEmpty)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (playlists.isEmpty)
                const Hollow(
                  title: 'Плейлистов нет',
                  body: 'Добавляй треки через «…» → «В плейлист».',
                )
              else
                for (final (i, playlist) in playlists.indexed)
                  Press(
                    scale: .98,
                    onTap: () => Navigator.of(context).push(
                      TracklistScreen.route(
                        title: playlist.name,
                        load: () => ref
                            .read(libraryControllerProvider.notifier)
                            .loadPlaylistTracks(playlist.id),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Pal.line)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 44,
                            child: Text(
                              (i + 1).toString().padLeft(2, '0'),
                              style: Txt.mono(12),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              playlist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Txt.title(wide ? 30 : 22),
                            ),
                          ),
                          Text(
                            '${playlist.trackCount}',
                            style: Txt.mono(13, color: Pal.paper),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.arrow_outward_rounded,
                            color: Pal.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 56),
              const _AlphaNote(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      useRootNavigator: true,
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: Pal.raised,
        title: Text('Новый плейлист', style: Txt.title(20)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: Txt.body(16),
          onSubmitted: (value) => Navigator.of(dialog).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(controller.text),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !context.mounted) return;
    run(
      context,
      () =>
          ref.read(libraryControllerProvider.notifier).createPlaylist(trimmed),
    );
  }
}

class _AlphaNote extends StatelessWidget {
  const _AlphaNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        border: Border.all(color: Pal.line),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('α', style: Txt.display(40, color: Pal.acid)),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              'Это альфа нового интерфейса Resonance. Войди тем же аккаунтом — '
              'лайки и плейлисты синхронизируются с основным приложением. '
              'Подключение личных аккаунтов сервисов (Яндекс и др.) '
              'пока есть только в основном приложении.',
              style: Txt.body(14, color: Pal.muted),
            ),
          ),
        ],
      ),
    );
  }
}
