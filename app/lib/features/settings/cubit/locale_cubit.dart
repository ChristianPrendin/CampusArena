import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:campus_arena/l10n/app_localizations.dart';
import '../../../repositories/user_repository.dart';

/// The app's active locale override.
///
/// Emits `null` to follow the system locale; a non-null [Locale] pins the app
/// to that language. Provided above `MaterialApp.router` and bound to its
/// `locale:` via a `BlocBuilder`, so a change re-localises the whole app
/// immediately.
///
/// The initial state is synchronous (`null` → system) so there are no late
/// constructor emissions. The persisted choice is layered on afterwards:
/// [seed] once from `users/{uid}.language` when auth resolves, and
/// [setLanguage] from the Settings toggle (which also writes it back).
class LocaleCubit extends Cubit<Locale?> {
  LocaleCubit({UserRepository? userRepository})
    : _userRepository = userRepository ?? UserRepository(),
      super(null);

  final UserRepository _userRepository;

  /// The languages the app ships strings for, derived from the generated
  /// localizations; anything else falls back to the system locale rather than
  /// pinning to an untranslated language.
  static final Set<String> _supported = {
    for (final locale in AppLocalizations.supportedLocales) locale.languageCode,
  };

  /// Set once the user picks a language in-session. A late-resolving startup
  /// [seed] must never clobber that manual choice.
  bool _explicitlySet = false;

  /// Applies the stored language once, at startup, without persisting it back
  /// (it already came from Firestore). A blank or unsupported code leaves the
  /// app on the system locale. A no-op once the user has toggled the language
  /// manually, so a slow cold-start read can't revert their choice.
  void seed(String? languageCode) {
    if (_explicitlySet) return;
    final locale = _localeFor(languageCode);
    if (locale != null) emit(locale);
  }

  /// Switches the app to [languageCode] immediately and persists the choice to
  /// `users/{uid}.language` so it survives a restart. The UI updates from the
  /// emit even if the write is still in flight.
  Future<void> setLanguage(String uid, String languageCode) async {
    final locale = _localeFor(languageCode);
    if (locale == null) return;
    _explicitlySet = true;
    emit(locale);
    await _userRepository.updateUser(uid, {'language': languageCode});
  }

  Locale? _localeFor(String? code) {
    if (code == null) return null;
    final normalized = code.trim().toLowerCase();
    if (!_supported.contains(normalized)) return null;
    return Locale(normalized);
  }
}
