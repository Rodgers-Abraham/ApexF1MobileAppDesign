import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Initialises Firebase with a stub implementation so unit and widget
/// tests run without a real Firebase project.
///
/// Call [setupFirebaseForTests] in [setUpAll] in any test file that
/// exercises code backed by Firebase (Auth, Firestore, Messaging, etc.).
/// This same helper is intended for Patrol integration tests — import it
/// from your test entry point before calling [patrolTest].
Future<void> setupFirebaseForTests() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  await Firebase.initializeApp();
}
