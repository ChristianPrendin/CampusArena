import 'package:equatable/equatable.dart';

/// Lifecycle of the auth flow.
///
/// `initial` is the pre-resolution boot state (drives the splash). The stream
/// subscription moves the baseline between `authenticated` / `unauthenticated`;
/// `loading` / `error` are transient form-action states that never trigger
/// navigation away from an auth screen.
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState extends Equatable {
  final AuthStatus status;

  /// Set only when [status] is [AuthStatus.authenticated].
  final String? uid;

  /// Whether the signed-in user has finished onboarding. `null` while
  /// authenticated but the user document has not loaded yet (or is absent — see
  /// [profileMissing]) — the router holds on the splash rather than flashing the
  /// onboarding flow. Meaningless unless [status] is [AuthStatus.authenticated].
  final bool? onboardingComplete;

  /// True when the session is authenticated but its `users/{uid}` document is
  /// confirmed absent (the profile stream emitted `null`) — an Auth account with
  /// no profile, e.g. after a wiped/re-seeded database or a half-provisioned
  /// account. The router sends these sessions to registration to recreate the
  /// profile, since the onboarding tutorial would otherwise dead-end (its
  /// completion write targets a non-existent doc). Meaningless unless [status] is
  /// [AuthStatus.authenticated].
  final bool profileMissing;

  /// `FirebaseAuthException.code` when [status] is [AuthStatus.error].
  final String? errorCode;

  /// True while a profile is being provisioned — a fresh `register` or a
  /// `provisionProfile` recovery — from the auth account existing until its
  /// freshly-written `users/{uid}` doc first arrives on the profile stream. The
  /// router redirect honours it to keep `RegisterScreen` mounted (so its
  /// `BlocListener` can surface a failure instead of bouncing to splash), and to
  /// mask the transient document-absent snapshot that would otherwise be read as
  /// [profileMissing] and flash the empty recovery form.
  final bool registrationInProgress;

  const AuthState._({
    required this.status,
    this.uid,
    this.onboardingComplete,
    this.profileMissing = false,
    this.errorCode,
    this.registrationInProgress = false,
  });

  const AuthState.initial() : this._(status: AuthStatus.initial);

  const AuthState.loading() : this._(status: AuthStatus.loading);

  const AuthState.authenticated(
    String uid, {
    bool? onboardingComplete,
    bool profileMissing = false,
    bool registrationInProgress = false,
  }) : this._(
         status: AuthStatus.authenticated,
         uid: uid,
         onboardingComplete: onboardingComplete,
         profileMissing: profileMissing,
         registrationInProgress: registrationInProgress,
       );

  const AuthState.unauthenticated()
    : this._(status: AuthStatus.unauthenticated);

  const AuthState.error(String errorCode)
    : this._(status: AuthStatus.error, errorCode: errorCode);

  @override
  List<Object?> get props => [
    status,
    uid,
    onboardingComplete,
    profileMissing,
    errorCode,
    registrationInProgress,
  ];
}
