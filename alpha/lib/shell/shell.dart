import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_alpha/design/accent.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/design/widgets.dart';
import 'package:resonance_alpha/screens/collection_screen.dart';
import 'package:resonance_alpha/screens/flow_screen.dart';
import 'package:resonance_alpha/screens/search_screen.dart';
import 'package:resonance_alpha/screens/settings_screen.dart';
import 'package:resonance_alpha/shell/notices.dart';
import 'package:resonance_alpha/shell/player_dock.dart';
import 'package:resonance_alpha/state.dart';
import 'package:window_manager/window_manager.dart';

enum Section {
  flow('Поток', Icons.blur_on_rounded),
  search('Поиск', Icons.search_rounded),
  collection('Коллекция', Icons.grid_view_rounded);

  const Section(this.label, this.icon);
  final String label;
  final IconData icon;
}

final sectionProvider = StateProvider<Section>((ref) => Section.flow);

/// Root layout. Each section keeps its own navigator, so opening a mix in
/// Поток and switching to Поиск does not lose either place.
class AlphaShell extends ConsumerStatefulWidget {
  const AlphaShell({super.key});

  @override
  ConsumerState<AlphaShell> createState() => _AlphaShellState();
}

class _AlphaShellState extends ConsumerState<AlphaShell> {
  final _navigators = {
    for (final section in Section.values) section: GlobalKey<NavigatorState>(),
  };

  void _select(Section section) {
    final current = ref.read(sectionProvider);
    if (current == section) {
      // Second tap on the active tab returns to its root.
      _navigators[section]!.currentState?.popUntil((route) => route.isFirst);
    }
    ref.read(sectionProvider.notifier).state = section;
  }

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(sectionProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final hasTrack = ref.watch(currentTrackProvider) != null;

    final pages = IndexedStack(
      index: section.index,
      children: [
        for (final item in Section.values)
          HeroControllerScope.none(
            child: Navigator(
              key: _navigators[item],
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => switch (item) {
                  Section.flow => const FlowScreen(),
                  Section.search => const SearchScreen(),
                  Section.collection => const CollectionScreen(),
                },
              ),
            ),
          ),
      ],
    );

    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.space, control: true): () =>
          run(context, () => togglePlay(ref)),
      const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
          _select(Section.flow),
      const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
          _select(Section.search),
      const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
          _select(Section.collection),
      const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
          Navigator.of(context).push(SettingsScreen.route()),
      const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () =>
          run(context, () => togglePlay(ref)),
    };

    if (wide) {
      return CallbackShortcuts(
        bindings: shortcuts,
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Pal.stage,
            body: Column(
              children: [
                if (Platform.isWindows) const _WindowBar(),
                const UpdateBanner(),
                Expanded(
                  child: Row(
                    children: [
                      _Rail(selected: section, onSelect: _select),
                      const VerticalDivider(width: 1, color: Pal.line),
                      Expanded(child: pages),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(width: 560, child: PlaybackIssueBar()),
                  ),
                ),
                AnimatedSize(
                  duration: Motion.base,
                  curve: Motion.curve,
                  child: hasTrack
                      ? const PlayerDock(wide: true)
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Scaffold(
        backgroundColor: Pal.stage,
        body: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const UpdateBanner(),
                    Expanded(child: pages),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PlaybackIssueBar(),
                    const PlayerDock(wide: false),
                    if (hasTrack) const SizedBox(height: 8),
                    _TabBar(selected: section, onSelect: _select),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Desktop rail: huge vertical words instead of icons. The active one is
/// written in the colour of the current cover.
class _Rail extends ConsumerWidget {
  const _Rail({required this.selected, required this.onSelect});

  final Section selected;
  final ValueChanged<Section> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(currentAccentProvider);
    return SizedBox(
      width: 92,
      child: Column(
        children: [
          const SizedBox(height: 22),
          Text('α', style: Txt.display(46, color: accent)),
          const SizedBox(height: 28),
          for (final section in Section.values)
            Expanded(
              child: Press(
                onTap: () => onSelect(section),
                tooltip: '${section.label} · Ctrl+${section.index + 1}',
                child: Center(
                  // A short window must shrink the word, never break it.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: AnimatedDefaultTextStyle(
                        duration: Motion.base,
                        curve: Motion.curve,
                        style: Txt.display(
                          section == selected ? 30 : 22,
                          color: section == selected ? accent : Pal.faint,
                        ),
                        child: Text(
                          section.label.toUpperCase(),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Knob(
            icon: Icons.tune_rounded,
            size: 46,
            tooltip: 'Настройки · Ctrl+,',
            onTap: () => Navigator.of(context).push(SettingsScreen.route()),
          ),
          const SizedBox(height: 10),
          Text('ALPHA', style: Txt.mono(10, color: Pal.faint)),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _TabBar extends ConsumerWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final Section selected;
  final ValueChanged<Section> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(currentAccentProvider);
    return Container(
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xF0141414),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Pal.line),
      ),
      child: Row(
        children: [
          for (final section in Section.values)
            Expanded(
              child: Press(
                onTap: () => onSelect(section),
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.curve,
                  decoration: BoxDecoration(
                    color: section == selected ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      section.label,
                      style: Txt.body(
                        14,
                        weight: 750,
                        color: section == selected
                            ? onAccent(accent)
                            : Pal.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Press(
            tooltip: 'Настройки',
            onTap: () => Navigator.of(context).push(SettingsScreen.route()),
            child: const SizedBox(
              width: 52,
              child: Icon(Icons.tune_rounded, color: Pal.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frameless window chrome for Windows: drag anywhere, three square buttons.
class _WindowBar extends StatelessWidget {
  const _WindowBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'RESONANCE α — ALPHA',
                    style: Txt.mono(10, color: Pal.faint),
                  ),
                ),
              ),
            ),
          ),
          _WindowButton(
            icon: Icons.remove_rounded,
            onTap: windowManager.minimize,
          ),
          _WindowButton(
            icon: Icons.crop_square_rounded,
            onTap: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          _WindowButton(
            icon: Icons.close_rounded,
            danger: true,
            onTap: windowManager.close,
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final Future<void> Function() onTap;
  final bool danger;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 34,
          color: _hover
              ? (widget.danger ? const Color(0xFFE5302A) : Pal.line)
              : Colors.transparent,
          child: Icon(widget.icon, size: 16, color: Pal.paper),
        ),
      ),
    );
  }
}
