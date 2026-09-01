import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/desktop_window_bar.dart';
import 'package:resonance/shared/widgets/player_bar.dart';
import 'package:resonance/shared/widgets/provider_badges.dart';

class AdaptiveAppShell extends StatelessWidget {
  const AdaptiveAppShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  int get _selectedIndex => switch (location) {
    '/search' => 1,
    '/library' => 2,
    '/rooms' => 3,
    '/settings' => 4,
    '/account' => 4,
    '/subscription' => 4,
    _ => 0,
  };

  void _navigate(BuildContext context, int index) {
    context.go(switch (index) {
      1 => '/search',
      2 => '/library',
      3 => '/rooms',
      4 => '/settings',
      _ => '/',
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 900;
    if (!desktop) {
      return Scaffold(
        body: SafeArea(bottom: false, child: child),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PlayerBar(compact: true),
            NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => _navigate(context, index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Главная',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_rounded),
                  label: 'Поиск',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded),
                  label: 'Медиатека',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups_rounded),
                  label: 'Вместе',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_rounded),
                  label: 'Настройки',
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          const DesktopWindowBar(),
          Expanded(
            child: Row(
              children: [
                _DesktopSidebar(
                  selectedIndex: _selectedIndex,
                  onSelected: (index) => _navigate(context, index),
                ),
                Expanded(child: child),
              ],
            ),
          ),
          const PlayerBar(compact: false),
        ],
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 224,
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF080909),
        border: Border(right: BorderSide(color: ResonanceColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _BrandMark(),
          const SizedBox(height: 42),
          _SidebarItem(
            label: 'Главная',
            icon: Icons.home_rounded,
            selected: selectedIndex == 0,
            onTap: () => onSelected(0),
          ),
          _SidebarItem(
            label: 'Поиск',
            icon: Icons.search_rounded,
            selected: selectedIndex == 1,
            onTap: () => onSelected(1),
          ),
          _SidebarItem(
            label: 'Медиатека',
            icon: Icons.library_music_rounded,
            selected: selectedIndex == 2,
            onTap: () => onSelected(2),
          ),
          _SidebarItem(
            label: 'Слушать вместе',
            icon: Icons.groups_rounded,
            selected: selectedIndex == 3,
            onTap: () => onSelected(3),
          ),
          _SidebarItem(
            label: 'Настройки',
            icon: Icons.tune_rounded,
            selected: selectedIndex == 4,
            onTap: () => onSelected(4),
          ),
          const Spacer(),
          _SidebarItem(
            label: 'Подписка',
            icon: Icons.workspace_premium_outlined,
            selected: false,
            onTap: () => context.go('/subscription'),
          ),
          const SizedBox(height: 16),
          const _SourceList(),
        ],
      ),
    );
  }
}

class _SourceList extends StatelessWidget {
  const _SourceList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ИСТОЧНИКИ',
          style: TextStyle(
            color: ResonanceColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 14),
        _SourceItem(label: 'Яндекс', provider: MusicProvider.yandex),
        SizedBox(height: 12),
        _SourceItem(label: 'SoundCloud', provider: MusicProvider.soundcloud),
      ],
    );
  }
}

class _SourceItem extends StatelessWidget {
  const _SourceItem({required this.label, required this.provider});

  final String label;
  final MusicProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProviderBadge(provider: provider, compact: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB7B2AC),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.graphic_eq_rounded,
          size: 25,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'RESONANCE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Tooltip(
        message: label,
        child: Material(
          color: selected ? const Color(0xFF191715) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              height: 46,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 3,
                    height: selected ? 24 : 8,
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    icon,
                    size: 20,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : ResonanceColors.muted,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? ResonanceColors.text
                            : ResonanceColors.muted,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
