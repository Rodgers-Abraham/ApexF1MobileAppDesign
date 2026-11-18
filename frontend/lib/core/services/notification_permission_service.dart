import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Permission states that map onto FirebaseMessaging's AuthorizationStatus but
/// keep us decoupled from it in tests.
enum NotifPermissionStatus {
  notDetermined, // never asked
  authorized, // granted
  denied, // asked and denied (may be re-requestable on Android)
  permanentlyDenied, // "don't ask again" — must route to system settings
}

/// Thin wrapper around FirebaseMessaging permission APIs.
///
/// Not a Riverpod provider — the Settings screen instantiates it directly so
/// it can call it synchronously in widget lifecycle callbacks. Tests can
/// replace it with [FakeNotificationPermissionService].
abstract class NotificationPermissionService {
  Future<NotifPermissionStatus> getStatus();

  /// Requests permission from the OS. Returns the new status.
  Future<NotifPermissionStatus> requestPermission();

  /// Retrieves the FCM registration token (null if not permitted or unavailable).
  Future<String?> getToken();

  /// Opens the app's system notification settings page.
  Future<void> openSettings();
}

class FirebaseNotificationPermissionService
    implements NotificationPermissionService {
  final FirebaseMessaging _messaging;

  FirebaseNotificationPermissionService(
      {FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  @override
  Future<NotifPermissionStatus> getStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return _mapStatus(settings.authorizationStatus);
  }

  @override
  Future<NotifPermissionStatus> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    return _mapStatus(settings.authorizationStatus);
  }

  @override
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> openSettings() async {
    // Deep-link to the app's notification settings on Android/iOS.
    const settingsUrl = 'app-settings:';
    if (await canLaunchUrl(Uri.parse(settingsUrl))) {
      await launchUrl(Uri.parse(settingsUrl));
    }
  }

  NotifPermissionStatus _mapStatus(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return NotifPermissionStatus.authorized;
      case AuthorizationStatus.denied:
        // Firebase doesn't distinguish between "denied" and "permanently denied"
        // at the OS level on Android; we treat both as denied and allow a
        // re-request (the system prompt won't appear if permanently denied,
        // so a subsequent getStatus() will still return denied — we detect
        // this case in the UI by checking if the prompt was shown at all).
        return NotifPermissionStatus.denied;
      case AuthorizationStatus.notDetermined:
        return NotifPermissionStatus.notDetermined;
    }
  }
}

/// Shows an in-app rationale dialog before triggering the system prompt.
///
/// Returns true if the user tapped "Allow" on the rationale; false means they
/// tapped "Not now" and we should NOT proceed to the system prompt.
Future<bool> showNotificationRationaleDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(children: [
        const Icon(Icons.notifications_outlined, color: Color(0xFF00E5FF), size: 22),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'RACE ALERTS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ]),
      content: const Text(
        'Get notified before race weekends, qualifying sessions, and when your predictions are about to lock.\n\nNo spam — only the alerts you turn on.',
        style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(
            'NOT NOW',
            style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 0.8),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            elevation: 0,
          ),
          child: const Text(
            'ALLOW',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
