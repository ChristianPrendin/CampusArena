import 'package:campus_arena/l10n/app_localizations.dart';

/// Maps a `FirebaseAuthException.code` (carried in `AuthState.errorCode`) to a
/// localized, user-facing message. Unknown codes fall back to a generic one.
String localizeAuthError(AppLocalizations l10n, String? code) {
  switch (code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
    case 'user-disabled':
      return l10n.authErrorInvalidCredentials;
    case 'email-already-in-use':
      return l10n.authErrorEmailInUse;
    case 'invalid-email':
      return l10n.authErrorInvalidEmail;
    case 'weak-password':
      return l10n.authErrorWeakPassword;
    case 'network-request-failed':
      return l10n.authErrorNetwork;
    case 'username-taken':
      return l10n.authErrorUsernameTaken;
    default:
      return l10n.authErrorGeneric;
  }
}
