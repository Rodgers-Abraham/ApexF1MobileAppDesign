import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:f1/main.dart';

import 'helpers/firebase_test_mock.dart';

void main() {
  setUpAll(setupFirebaseForTests);

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': false,
    });
  });

  testWidgets('App boots up and displays Onboarding screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: F1ApexApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CHOOSE YOUR TEAM'), findsOneWidget);
  });
}
