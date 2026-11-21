import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:f1/core/utils/api_config.dart';
import 'package:f1/firebase_options.dart';
import 'package:f1/main.dart' as app;

const _email1 = String.fromEnvironment('APEX_LOGIN_EMAIL_1');
const _password1 = String.fromEnvironment('APEX_LOGIN_PASSWORD_1');
const _email2 = String.fromEnvironment('APEX_LOGIN_EMAIL_2');
const _password2 = String.fromEnvironment('APEX_LOGIN_PASSWORD_2');

Future<void> _launchUnauthenticated(PatrolIntegrationTester $) async {
  await FirebaseAuth.instance.signOut();
  SharedPreferences.setMockInitialValues({'onboarding_completed': false});
  app.main();
  await $.tester.pump();
  await $.tester.pump(const Duration(seconds: 4));
  expect(find.text('DRIVER CREDENTIALS'), findsOneWidget);
  await $.tester.tap(find.text('SIGN IN'));
  await $.tester.pump(const Duration(seconds: 1));
  expect(find.text('DRIVER SIGN IN'), findsOneWidget);
}

Future<void> _checkLogin(
  PatrolIntegrationTester $,
  String email,
  String password,
  String accountLabel,
) async {
  await _launchUnauthenticated($);

  final fields = find.byType(TextField);
  expect(fields, findsNWidgets(2));
  $.tester.widget<TextField>(fields.at(0)).controller!.text = email;
  $.tester.widget<TextField>(fields.at(1)).controller!.text = password;
  FocusManager.instance.primaryFocus?.unfocus();
  await $.tester.pump();

  final authenticate = find.text('AUTHENTICATE ▶');
  await $.tester.ensureVisible(authenticate);
  await $.tester.tap(authenticate);

  for (var second = 0;
      second < 60 && find.text('DRIVER SIGN IN').evaluate().isNotEmpty;
      second++) {
    await $.tester.pump(const Duration(seconds: 1));
  }

  final signInStillVisible = find.text('DRIVER SIGN IN').evaluate().isNotEmpty;
  final visibleMessages = find
      .byType(Text)
      .evaluate()
      .map((element) => (element.widget as Text).data)
      .whereType<String>()
      .where(
        (text) => RegExp(
          r'(login failed|incorrect|no account|network|permission|failed)',
          caseSensitive: false,
        ).hasMatch(text),
      );
  debugPrint(
    '$accountLabel: currentUser=${FirebaseAuth.instance.currentUser?.email}, '
    'signInStillVisible=$signInStillVisible, '
    'messages=${visibleMessages.join(' / ')}',
  );
  expect(
    FirebaseAuth.instance.currentUser?.email,
    email,
    reason: '$accountLabel should have an authenticated Firebase user.',
  );
  if (signInStillVisible) {
    final visibleErrors = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .whereType<String>()
        .where(
          (text) => RegExp(
            r'(login failed|account|credential|network|permission)',
            caseSensitive: false,
          ).hasMatch(text),
        );
    debugPrint(
      '$accountLabel: Firebase user is present but app did not finish login. '
      'Visible auth messages: ${visibleErrors.join(' / ')}',
    );
  }
  expect(
    find.text('DRIVER SIGN IN'),
    findsNothing,
    reason:
        '$accountLabel authenticated with Firebase but remained on sign-in; '
        'the profile/persistence step likely failed.',
  );
  debugPrint('$accountLabel login completed and app navigated from sign-in.');
}

void main() {
  setUpAll(() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  });

  patrolTest('login with first supplied account', ($) async {
    expect(_email1, isNotEmpty, reason: 'Provide APEX_LOGIN_EMAIL_1.');
    expect(_password1, isNotEmpty, reason: 'Provide APEX_LOGIN_PASSWORD_1.');
    await _checkLogin($, _email1, _password1, 'Account 1');
  });

  patrolTest('login with second supplied account', ($) async {
    expect(_email2, isNotEmpty, reason: 'Provide APEX_LOGIN_EMAIL_2.');
    expect(_password2, isNotEmpty, reason: 'Provide APEX_LOGIN_PASSWORD_2.');
    await _checkLogin($, _email2, _password2, 'Account 2');
  });

  patrolTest('report current live-session status from the app API', ($) async {
    await dotenv.load();
    final client = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
    final response =
        await client.get<Map<String, dynamic>>('/api/f1/session-status');
    final telemetryResponse =
        await client.get<List<dynamic>>('/api/f1/telemetry/live');
    final status = response.data;
    final telemetry = telemetryResponse.data;

    expect(status, isNotNull);
    expect(status!['is_live'], isA<bool>());
    expect(telemetry, isA<List<dynamic>>());
    debugPrint(
      'Live-status API: is_live=${status['is_live']}, '
      'is_race_weekend=${status['is_race_weekend']}, '
      'session=${status['session_name']}, '
      'meeting=${status['meeting_name']}, '
      'session_type=${status['session_type']}, '
      'live_telemetry_rows=${telemetry?.length}',
    );
  });
}
