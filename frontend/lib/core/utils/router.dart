import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/home/presentation/screens/pitwall_screen.dart';
import '../../features/standings/presentation/screens/standings_screen.dart';
import '../../features/live/presentation/screens/live_tracker_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/predictor/presentation/screens/predictor_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../shared/widgets/dashboard_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) async {
    final prefs = await SharedPreferences.getInstance();
    final bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    
    final bool isOnboardingRoute = state.uri.toString() == '/onboarding';

    if (!onboardingCompleted) {
      return '/onboarding';
    }

    if (onboardingCompleted && isOnboardingRoute) {
      return '/';
    }

    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/onboarding',
      builder: (BuildContext context, GoRouterState state) {
        return const OnboardingScreen();
      },
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (BuildContext context, GoRouterState state, Widget child) {
        return DashboardShell(child: child);
      },
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) {
            return const PitWallScreen();
          },
        ),
        GoRoute(
          path: '/standings',
          builder: (BuildContext context, GoRouterState state) {
            return const StandingsScreen();
          },
        ),
        GoRoute(
          path: '/live',
          builder: (BuildContext context, GoRouterState state) {
            return const LiveTrackerScreen();
          },
        ),
        GoRoute(
          path: '/history',
          builder: (BuildContext context, GoRouterState state) {
            return const HistoryScreen();
          },
        ),
        GoRoute(
          path: '/predictor',
          builder: (BuildContext context, GoRouterState state) {
            return const PredictorScreen();
          },
        ),
        GoRoute(
          path: '/chat',
          builder: (BuildContext context, GoRouterState state) {
            return const ChatScreen();
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (BuildContext context, GoRouterState state) {
            return const SettingsScreen();
          },
        ),
      ],
    ),
  ],
);
