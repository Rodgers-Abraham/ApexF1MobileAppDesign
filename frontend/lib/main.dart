import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/utils/router.dart';
import 'shared/theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load();
  } catch (e) {
    debugPrint('Failed to load .env file: $e');
  }

  runApp(
    const ProviderScope(
      child: F1ApexApp(),
    ),
  );
}

class F1ApexApp extends ConsumerWidget {
  const F1ApexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return MaterialApp.router(
      title: 'F1 Apex',
      debugShowCheckedModeBanner: false,
      theme: themeNotifier.getThemeData(),
      themeMode: themeState.themeMode,
      routerConfig: appRouter,
    );
  }
}
