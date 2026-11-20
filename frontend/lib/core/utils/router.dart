import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/home/presentation/screens/pitwall_screen.dart';
import '../../features/standings/presentation/screens/standings_screen.dart';
import '../../features/live/presentation/screens/live_tracker_screen.dart';
import '../../features/live/presentation/screens/practice_replay_screen.dart';
import '../../features/live/presentation/screens/qualifying_replay_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/predictor/presentation/screens/predictor_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/sessions/presentation/screens/sessions_list_screen.dart';
import '../../features/sessions/presentation/screens/race_results_screen.dart';
import '../../features/sessions/presentation/screens/practice_results_screen.dart';
import '../../features/sessions/presentation/screens/qualifying_results_screen.dart';
import '../../shared/widgets/dashboard_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) async {
    final prefs = await SharedPreferences.getInstance();
    final bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    // Guard against the race condition where _tryAutoLogin() is still in-flight:
    // Firebase persists tokens locally, so currentUser is non-null synchronously
    // even before the async Firestore profile fetch completes.
    bool hasFirebaseUser = false;
    try {
      hasFirebaseUser = FirebaseAuth.instance.currentUser != null;
    } catch (_) {}

    final bool effectivelyCompleted = onboardingCompleted || hasFirebaseUser;
    final bool isOnboardingRoute = state.uri.toString() == '/onboarding';

    if (!effectivelyCompleted) return '/onboarding';
    if (effectivelyCompleted && isOnboardingRoute) return '/';
    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/onboarding',
      builder: (BuildContext context, GoRouterState state) {
        return const OnboardingScreen();
      }),
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
          }),
        GoRoute(
          path: '/standings',
          builder: (BuildContext context, GoRouterState state) {
            return const StandingsScreen();
          }),
        GoRoute(
          path: '/live',
          builder: (BuildContext context, GoRouterState state) {
            return const LiveTrackerScreen();
          }),
        GoRoute(
          path: '/history',
          builder: (BuildContext context, GoRouterState state) {
            return const HistoryScreen();
          }),
        GoRoute(
          path: '/predictor',
          builder: (BuildContext context, GoRouterState state) {
            return const PredictorScreen();
          }),
        GoRoute(
          path: '/chat',
          builder: (BuildContext context, GoRouterState state) {
            return const ChatScreen();
          }),
        GoRoute(
          path: '/settings',
          builder: (BuildContext context, GoRouterState state) {
            return const SettingsScreen();
          }),
        GoRoute(
          path: '/sessions',
          builder: (BuildContext context, GoRouterState state) {
            return const SessionsListScreen();
          }),
        GoRoute(
          path: '/replay/practice/:id',
          builder: (BuildContext context, GoRouterState state) {
            return PracticeReplayScreen(sessionId: state.pathParameters['id']!);
          }),
        GoRoute(
          path: '/replay/qualifying/:id',
          builder: (BuildContext context, GoRouterState state) {
            return QualifyingReplayScreen(sessionId: state.pathParameters['id']!);
          }),
        GoRoute(
          path: '/results/race/:id',
          builder: (BuildContext context, GoRouterState state) {
            return RaceResultsScreen(sessionId: state.pathParameters['id']!);
          }),
        GoRoute(
          path: '/results/practice/:id',
          builder: (BuildContext context, GoRouterState state) {
            return PracticeResultsScreen(sessionId: state.pathParameters['id']!);
          }),
        GoRoute(
          path: '/results/qualifying/:id',
          builder: (BuildContext context, GoRouterState state) {
            return QualifyingResultsScreen(sessionId: state.pathParameters['id']!);
          }),
      ]),
  ]);
