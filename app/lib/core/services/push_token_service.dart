import 'package:firebase_messaging/firebase_messaging.dart';

/// Thin wrapper over [FirebaseMessaging.getToken] for the Settings
/// notification toggle.
///
/// Returns `null` rather than throwing when a token can't be obtained — this
/// is expected on an iOS simulator / a free Apple developer account (no APNs)
/// or an Android emulator without Play services. Callers disable the toggle
/// row gracefully on `null`; they never crash.
class PushTokenService {
  PushTokenService({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  /// This device's current FCM registration token, or `null` when unavailable.
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }
}
