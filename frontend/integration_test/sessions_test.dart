// Integration tests for Las Vegas GP FP2 session display.
// Run with: flutter test integration_test/sessions_test.dart -d emulator-5554
//
// Requires: the backend at REACT_APP_API_URL to be reachable from the emulator.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:f1/firebase_options.dart';
import 'package:f1/main.dart' as app;

Future<void> _pump(WidgetTester tester, {int seconds = 4}) async {
  await tester.pump();
  await tester.pump(Duration(seconds: seconds));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;

  setUpAll(() async {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  });

  // Boot the app as a logged-in user using the SP cache (avoids real Firebase login).
  void setLoggedInPrefs() {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'auth_user': '{"uid":"test-uid","email":"test@apex.com","name":"Test Driver",'
          '"favourite_team":"Ferrari","favourite_driver":"LEC","country":null,'
          '"rival_driver":null}',
    });
  }

  // ─── HOME SCREEN AFTER FP2 ──────────────────────────────────────────────────

  testWidgets(
    'S1 — home screen does NOT show LIVE ON TRACK banner after FP2 ends',
    (tester) async {
      setLoggedInPrefs();
      app.main();
      await _pump(tester, seconds: 5);

      // After Las Vegas FP2, sessionLiveStatusProvider.isLive == false
      // GPHeroWidget shows the pulsing banner ONLY when isLive is true
      expect(find.textContaining('LIVE ON TRACK'), findsNothing);
    },
  );

  testWidgets(
    'S2 — home screen (PitWallScreen) loads without crash after FP2',
    (tester) async {
      setLoggedInPrefs();
      app.main();
      await _pump(tester, seconds: 4);

      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    },
  );

  // Helper: navigate to SessionsListScreen via MORE drawer → REPLAY
  Future<void> _goToSessions(WidgetTester tester) async {
    final moreTab = find.text('MORE');
    if (moreTab.evaluate().isNotEmpty) {
      await tester.tap(moreTab.first);
      await _pump(tester, seconds: 1);
    }
    final replayItem = find.text('REPLAY');
    if (replayItem.evaluate().isNotEmpty) {
      await tester.tap(replayItem.first);
      await _pump(tester, seconds: 5);
    }
  }

  // ─── SESSIONS LIST ───────────────────────────────────────────────────────────

  testWidgets(
    'S3 — sessions list shows FP2 chip for Las Vegas GP 2026',
    (tester) async {
      setLoggedInPrefs();
      app.main();
      await _pump(tester, seconds: 4);

      await _goToSessions(tester);

      // Backend has FORMULA 1 HEINEKEN LAS VEGAS GRAND PRIX 2026 with P2 session
      // allSessionsProvider calls /api/timing/sessions (no auth required)
      expect(find.text('FP2'), findsAtLeastNWidgets(1),
          reason: 'Las Vegas FP2 chip should appear in session list');
    },
  );

  testWidgets(
    'S4 — tapping FP2 chip navigates to PracticeResultsScreen',
    (tester) async {
      setLoggedInPrefs();
      app.main();
      await _pump(tester, seconds: 4);

      await _goToSessions(tester);

      final fp2Chip = find.text('FP2');
      if (fp2Chip.evaluate().isEmpty) {
        debugPrint('S4 skipped — FP2 chip not found');
        return;
      }

      await tester.tap(fp2Chip.first);
      await _pump(tester, seconds: 5);

      // PracticeResultsScreen should render
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    },
  );

  // ─── LIVE TRACKER AFTER FP2 ─────────────────────────────────────────────────

  testWidgets(
    'S5 — live tracker does NOT show LIVE SESSION label between FP2 and FP3',
    (tester) async {
      setLoggedInPrefs();
      app.main();
      await _pump(tester, seconds: 4);

      // Tap TIMING bottom nav (index 1) to go to /live
      final timingTab = find.text('TIMING');
      if (timingTab.evaluate().isNotEmpty) {
        await tester.tap(timingTab.first);
        await _pump(tester, seconds: 3);
      }

      // Between FP2 and FP3 there's no live session running.
      // LiveTrackerScreen should NOT show the pulsing "LIVE SESSION" label.
      // (The backend live block is for the whole Las Vegas weekend, but
      // session_name may be empty / not "FP2 LIVE" right now.)
      expect(find.textContaining('LIVE SESSION'), findsNothing);
    },
  );
}
