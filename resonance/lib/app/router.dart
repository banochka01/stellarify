import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/features/auth/account_screen.dart';
import 'package:resonance/features/home/home_screen.dart';
import 'package:resonance/features/library/library_screen.dart';
import 'package:resonance/features/player/now_playing_screen.dart';
import 'package:resonance/features/rooms/rooms_screen.dart';
import 'package:resonance/features/search/search_screen.dart';
import 'package:resonance/features/settings/settings_screen.dart';
import 'package:resonance/features/subscription/subscription_screen.dart';
import 'package:resonance/shared/widgets/adaptive_app_shell.dart';

final resonanceRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AdaptiveAppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/subscription',
          name: 'subscription',
          builder: (context, state) => const SubscriptionScreen(),
        ),
        GoRoute(
          path: '/account',
          name: 'account',
          builder: (context, state) => const AccountScreen(),
        ),
        GoRoute(
          path: '/rooms',
          name: 'rooms',
          builder: (context, state) => const RoomsScreen(),
        ),
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/library',
          name: 'library',
          builder: (context, state) => const LibraryScreen(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/player',
      name: 'player',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const NowPlayingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
      ),
    ),
  ],
);
