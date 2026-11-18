import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/push_token_service.dart';
import '../../../models/user_model.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/user_repository.dart';
import 'settings_state.dart';

/// Outcome of a password-reset request, so the UI can tell "sent" apart from
/// "no address yet" and an actual send failure (offline / rate-limited).
enum PasswordResetResult { sent, noEmail, failed }

/// Backs the Settings screen's stateful bits: the notification toggle and the
/// change-password action. The language toggle is owned by `LocaleCubit`; the
/// logout button by `AuthCubit`.
///
/// The notification toggle's semantics are FCM-token registration (the locked
/// schema has no preference field): "on" means this device's token is a member
/// of `users/{uid}.pushTokens`. The token is resolved once; membership is read
/// live off the streamed user document, so a write reflects back through the
/// same stream.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required this.uid,
    UserRepository? userRepository,
    AuthRepository? authRepository,
    PushTokenService? pushTokenService,
  }) : _userRepository = userRepository ?? UserRepository(),
       _authRepository = authRepository ?? AuthRepository(),
       _pushTokenService = pushTokenService ?? PushTokenService(),
       super(const SettingsState()) {
    _subscription = _userRepository.watchUser(uid).listen(_onUserChanged);
    _resolveToken();
  }

  final String uid;
  final UserRepository _userRepository;
  final AuthRepository _authRepository;
  final PushTokenService _pushTokenService;
  late final StreamSubscription<UserModel?> _subscription;

  /// This device's FCM token, or null when unavailable. Resolved once.
  String? _token;
  bool _tokenResolved = false;
  bool _userLoaded = false;
  List<String> _pushTokens = const [];

  Future<void> _resolveToken() async {
    _token = await _pushTokenService.getToken();
    _tokenResolved = true;
    _recompute();
  }

  void _onUserChanged(UserModel? user) {
    _userLoaded = true;
    _pushTokens = user?.pushTokens ?? const [];
    emit(state.copyWith(email: user?.email));
    _recompute();
  }

  void _recompute() {
    // Hold `loading` until BOTH the token and the first user snapshot are in:
    // computing against a still-default (empty) `_pushTokens` would flash a
    // spurious `disabled` for an already-registered device, and a toggle tap in
    // that window would call `addPushToken` (no-op) instead of removing it.
    if (!_tokenResolved || !_userLoaded) return;
    if (_token == null) {
      emit(state.copyWith(notification: NotificationSetting.unavailable));
      return;
    }
    emit(
      state.copyWith(
        notification: _pushTokens.contains(_token)
            ? NotificationSetting.enabled
            : NotificationSetting.disabled,
      ),
    );
  }

  /// Registers / deregisters this device's token in `pushTokens`. A no-op when
  /// the token is unavailable or a write is already in flight. Membership
  /// updates arrive back through the user-document stream.
  Future<void> toggleNotifications() async {
    final token = _token;
    if (token == null || state.notificationBusy) return;
    if (!state.notificationRowEnabled) return;

    final wasOn = state.notificationsOn;
    emit(state.copyWith(notificationBusy: true));
    try {
      if (wasOn) {
        await _userRepository.removePushToken(uid, token);
      } else {
        await _userRepository.addPushToken(uid, token);
      }
    } finally {
      emit(state.copyWith(notificationBusy: false));
    }
  }

  /// Sends a password-reset email to the signed-in address. The whole feature
  /// is the email flow — there is no in-app re-auth / new-password form.
  /// Returns [PasswordResetResult.sent] on success, [noEmail] when the address
  /// isn't known yet, and [failed] when the send itself throws (offline,
  /// rate-limited) so the caller can surface feedback instead of swallowing it.
  Future<PasswordResetResult> sendPasswordReset() async {
    final email = state.email;
    if (email == null || email.isEmpty) return PasswordResetResult.noEmail;
    try {
      await _authRepository.resetPassword(email: email);
      return PasswordResetResult.sent;
    } catch (_) {
      return PasswordResetResult.failed;
    }
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
