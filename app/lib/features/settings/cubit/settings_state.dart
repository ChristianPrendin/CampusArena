import 'package:equatable/equatable.dart';

/// State of the Settings notification toggle.
///
/// The locked schema has no notification-preference field, so "on" means this
/// device's FCM token is a member of `users/{uid}.pushTokens`.
enum NotificationSetting {
  /// Resolving the FCM token / first user-doc read.
  loading,

  /// No FCM token on this device (iOS simulator, emulator without Play
  /// services). The row is shown disabled — never crashes.
  unavailable,

  /// This device's token is registered.
  enabled,

  /// This device's token is not registered.
  disabled,
}

class SettingsState extends Equatable {
  const SettingsState({
    this.notification = NotificationSetting.loading,
    this.notificationBusy = false,
    this.email,
  });

  final NotificationSetting notification;

  /// A push-token write is in flight; the toggle is momentarily non-interactive.
  final bool notificationBusy;

  /// The signed-in user's email, for the change-password reset flow. Null until
  /// the user document first loads.
  final String? email;

  bool get notificationsOn => notification == NotificationSetting.enabled;

  bool get notificationRowEnabled =>
      notification == NotificationSetting.enabled ||
      notification == NotificationSetting.disabled;

  SettingsState copyWith({
    NotificationSetting? notification,
    bool? notificationBusy,
    String? email,
  }) {
    return SettingsState(
      notification: notification ?? this.notification,
      notificationBusy: notificationBusy ?? this.notificationBusy,
      email: email ?? this.email,
    );
  }

  @override
  List<Object?> get props => [notification, notificationBusy, email];
}
