import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:f1/main.dart';

void main() {
  // Setup SharedPreferences mock values before each test
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': false,
    });
  });

  testWidgets('App boots up and displays Onboarding screen', (WidgetTester tester) async {
    // Build our app under ProviderScope and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: F1ApexApp(),
      ),
    );

    // Wait for the async redirects of GoRouter and SharedPreferences to complete.
    await tester.pumpAndSettle();

    // Verify that onboarding screen shows the main header.
    expect(find.text('CHOOSE YOUR TEAM'), findsOneWidget);
  });
}
