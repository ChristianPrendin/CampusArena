import 'package:campus_arena/l10n/app_localizations.dart';

/// Form-field validators for the auth screens. Messages are localized, so each
/// takes the active [AppLocalizations].
class AuthValidators {
  AuthValidators._();

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// 3–20 chars, lowercase letters/digits/underscore only. Usernames are
  /// lowercase-only (case-insensitive identity); the register field also
  /// auto-lowercases input. Also keeps the handle safe as a Firestore document
  /// id (the `usernames/{handle}` reservation).
  static final RegExp _usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');

  /// Minimum password length Firebase Auth accepts.
  static const int minPasswordLength = 6;

  static String? required(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) return l10n.fieldRequired;
    return null;
  }

  static String? email(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) return l10n.fieldRequired;
    if (!_emailPattern.hasMatch(value.trim())) return l10n.invalidEmail;
    return null;
  }

  static String? username(AppLocalizations l10n, String? value) {
    final handle = value?.trim() ?? '';
    if (handle.isEmpty) return l10n.fieldRequired;
    if (!_usernamePattern.hasMatch(handle)) return l10n.invalidUsername;
    return null;
  }

  static String? password(AppLocalizations l10n, String? value) {
    if (value == null || value.isEmpty) return l10n.fieldRequired;
    if (value.length < minPasswordLength) return l10n.passwordTooShort;
    return null;
  }
}
