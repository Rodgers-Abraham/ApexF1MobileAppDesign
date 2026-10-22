import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl {
    if (dotenv.isInitialized && dotenv.env['API_URL'] != null && dotenv.env['API_URL']!.isNotEmpty) {
      final url = dotenv.env['API_URL']!;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && (url.contains('localhost') || url.contains('127.0.0.1'))) {
        return 'http://192.168.100.86:8000';
      }
      return url;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'https://f1-backend-41t9.onrender.com';
    }
    return 'https://f1-backend-41t9.onrender.com';
  }

  Future<void> initialize() async {
    try {
      await dotenv.load();
    } catch (e) {
      debugPrint('Warning: .env file not found, using default configuration');
    }
  }
}
