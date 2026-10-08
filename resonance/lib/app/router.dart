import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/features/artist/artist_screen.dart';
import 'package:resonance/features/auth/account_screen.dart';
import 'package:resonance/features/home/home_screen.dart';
import 'package:resonance/features/library/library_screen.dart';
import 'package:resonance/features/music_graph/music_graph_screen.dart';
import 'package:resonance/features/player/now_playing_screen.dart';
import 'package:resonance/features/player/visual_stage_screen.dart';
import 'package:resonance/features/recap/recap_screen.dart';
import 'package:resonance/features/rooms/rooms_screen.dart';
import 'package:resonance/features/search/search_screen.dart';
import 'package:resonance/features/settings/settings_screen.dart';
import 'package:resonance/shared/widgets/adaptive_app_shell.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';

final resonanceRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Каждая вкладка живёт в своей ветке: состояние и прокрутка сохраняются,
    // а переход — настоящий кроссфейд между двумя уже построенными экранами.
    StatefulShellRoute(
      builder: (context, state, navigationShell) => AdaptiveAppShell(
        selectedIndex: navigationShell.currentIndex,
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        child: navigationShell,
      ),
      navigatorContainerBuilder: (context, navigationShell, children) =>
          ResonanceBranchStack(
            index: navigationShell.currentIndex,
            children: children,
          ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/artist/:name',
              name: 'artist',
              builder: (context, state) => ArtistScreen(
                key: ValueKey(state.pathParameters['name']),
                artist: state.pathParameters['name'] ?? '',
              ),
            ),
            GoRoute(
              path: '/recap',
              name: 'recap',
              builder: (context, state) => const RecapScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              name: 'search',
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              name: 'library',
              builder: (context, state) => const LibraryScreen(),
            ),
            GoRoute(
              path: '/graph',
              name: 'music-graph',
              builder: (context, state) => const MusicGraphScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/rooms',
              name: 'rooms',
              builder: (context, state) => const RoomsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (context, state) => const SettingsScreen(),
            ),
            GoRoute(
              path: '/account',
              name: 'account',
              builder: (context, state) => const AccountScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/player',
      name: 'player',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        transitionDuration: ResonanceMotion.entrance,
        reverseTransitionDuration: ResonanceMotion.standard,
        child: const NowPlayingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
            return child;
          }
          final curved = CurvedAnimation(
            parent: animation,
            curve: ResonanceMotion.curve,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, .08),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    ),
    GoRoute(
      path: '/stage',
      name: 'visual-stage',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        transitionDuration: ResonanceMotion.gentle,
        reverseTransitionDuration: ResonanceMotion.standard,
        child: VisualStageScreen(
          initialMode: state.uri.queryParameters['mode'] == 'video'
              ? VisualStageMode.video
              : VisualStageMode.lyrics,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
            return child;
          }
          final curved = CurvedAnimation(
            parent: animation,
            curve: ResonanceMotion.curve,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 1.04, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    ),
  ],
);
