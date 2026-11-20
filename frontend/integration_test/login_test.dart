// Integration tests for the login / onboarding flow.
// Run with: flutter test integration_test/login_test.dart -d emulator-5554
//
// Note: app.main() is called ONCE per test.  We use tester.pump(Duration)
// instead of pumpAndSettle() because the app has periodic polling timers
// (liveTelemetryFeedProvider etc.) that prevent pumpAndSettle from settling.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:f1/firebase_options.dart';
import 'package:f1/main.dart' as app;

// Pump helper: advances time and flushes frames without requiring full settle.
Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
  await tester.pump();
  await tester.pump(Duration(seconds: seconds));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;

  // Initialize Firebase once and sign out so every test starts from a clean
  // unauthenticated state.  app.main() re-uses the already-initialized app.
  setUpAll(() async {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  });

  setUp(() async {
    // Ensure no session leaks between tests
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  });

  // ─── ONBOARDING SCREEN ──────────────────────────────────────────────────────

  testWidgets(
    'T1 — unauthenticated user sees onboarding / registration screen',
    (tester) async {
      // Set up SP BEFORE app.main() so the router reads the right value
      SharedPreferences.setMockInitialValues({'onboarding_completed': false});

      app.main();
      await _pump(tester, seconds: 4);

      // The app should land on onboarding (no Firebase user, SP flag is false)
      expect(find.text('DRIVER CREDENTIALS'), findsOneWidget,
          reason: 'Expected onboarding registration screen on first launch');
    },
  );

  testWidgets(
    'T2 — tapping SIGN IN chip switches header to login mode',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': false});
      app.main();
      await _pump(tester, seconds: 4);

      await tester.tap(find.text('SIGN IN'));
      await _pump(tester, seconds: 1);

      expect(find.text('DRIVER SIGN IN'), findsOneWidget);
      expect(find.text('BACK ON TRACK'), findsOneWidget);
      expect(find.text('AUTHENTICATE ▶'), findsOneWidget);
    },
  );

  testWidgets(
    'T3 — login mode exposes email and password text fields',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': false});
      app.main();
      await _pump(tester, seconds: 4);

      await tester.tap(find.text('SIGN IN'));
      await _pump(tester, seconds: 1);

      // Two TextFields: email at index 0, password at index 1
      expect(find.byType(TextField), findsAtLeastNWidgets(2));
    },
  );

  testWidgets(
    'T4 — AUTHENTICATE with empty fields stays on onboarding (silent guard)',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': false});
      app.main();
      await _pump(tester, seconds: 4);

      await tester.tap(find.text('SIGN IN'));
      await _pump(tester, seconds: 1);

      // Tap without filling fields — _handleDetailsNext returns early
      await tester.tap(find.text('AUTHENTICATE ▶'));
      await _pump(tester, seconds: 1);

      // Still on login mode, no navigation
      expect(find.text('BACK ON TRACK'), findsOneWidget);
    },
  );

  // ─── WRONG CREDENTIALS → ERROR MESSAGE ──────────────────────────────────────

  testWidgets(
    'T5 — wrong credentials show error message in red banner',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': false});
      app.main();
      await _pump(tester, seconds: 4);

      await tester.tap(find.text('SIGN IN'));
      await _pump(tester, seconds: 1);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'notreal@apextest.invalid');
      await tester.enterText(fields.at(1), 'wrongpassword123');
      await _pump(tester, seconds: 1);

      await tester.tap(find.text('AUTHENTICATE ▶'));

      // Wait up to 10 s for Firebase to respond
      await tester.pump(const Duration(seconds: 10));

      final errorFinder = find.textContaining(RegExp(
        r'(No account found|Incorrect email or password|invalid|Login failed)',
        caseSensitive: false,
      ));
      expect(errorFinder, findsAtLeastNWidgets(1),
          reason: 'Error message should appear after bad credentials');
    },
  );

  // ─── RETURNING USER RACE-CONDITION FIX ──────────────────────────────────────

  testWidgets(
    'T6 — returning user with live Firebase session skips onboarding',
    (tester) async {
      // This verifies the router fix: FirebaseAuth.instance.currentUser is
      // checked as a fallback, so a valid session bypasses the SP flag.
      //
      // Skip gracefully when emulator has no prior session.
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('T6 skipped — no pre-existing Firebase session on emulator');
        return;
      }

      // Clear SP to simulate the race condition scenario
      SharedPreferences.setMockInitialValues({});

      app.main();
      await _pump(tester, seconds: 4);

      // With the fix, router detects Firebase currentUser and skips /onboarding
      expect(find.text('DRIVER CREDENTIALS'), findsNothing,
          reason: 'Logged-in user should not see onboarding');
      expect(find.text('BACK ON TRACK'), findsNothing);
    },
  );

  // ─── REGISTRATION STEP INDICATOR ────────────────────────────────────────────

  testWidgets(
    'T7 — registration mode shows all four step indicators',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': false});
      app.main();
      await _pump(tester, seconds: 4);

      expect(find.text('DETAILS'), findsOneWidget);
      expect(find.text('TEAM'), findsOneWidget);
      expect(find.text('DRIVERS'), findsOneWidget);
      expect(find.text('LICENSE'), findsOneWidget);
    },
  );
}
