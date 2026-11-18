import 'assistant_provider.dart';
import 'assistant_settings_model.dart';

/// Build-time configuration for the *shared* Arena Assistant.
///
/// CampusArena is a multi-user app whose users are athletes, not developers —
/// asking each of them to paste an LLM API key was never realistic. So the app
/// ships with one provider/key/model compiled in, and every user talks to the
/// same bot with zero setup.
///
/// Values are injected at build time and are **never committed**:
///
/// ```
/// flutter run --dart-define-from-file=dart_defines.json
/// ```
///
/// `dart_defines.json` is gitignored; `dart_defines.example.json` documents its
/// shape. With no file supplied, [apiKey] is empty and the assistant degrades
/// gracefully to rule-based "limited mode" — the app still builds and runs, so
/// CI and `flutter test` need no secrets.
///
/// ## Security
///
/// A `--dart-define` value is baked into the compiled binary. Anyone with the
/// APK can recover it with `strings` or `apktool`. This is not a secret store.
/// The only way to genuinely protect the key is to keep it off the device
/// behind a server-side proxy (e.g. a Cloud Function that holds the key and
/// forwards requests). That is the correct production design, and is out of
/// scope for this course project. Rotate the shared key after grading.
abstract final class AssistantDefaults {
  /// Provider id, matching [AssistantProviderX.id]. Defaults to Regolo.
  static const String _providerId = String.fromEnvironment(
    'ASSISTANT_PROVIDER',
    defaultValue: 'regolo',
  );

  /// The shared API key. Empty unless supplied at build time.
  static const String apiKey = String.fromEnvironment('ASSISTANT_API_KEY');

  /// Model id sent to the provider. Empty means "use the provider's default".
  static const String _model = String.fromEnvironment('ASSISTANT_MODEL');

  /// Whether the Assistant Settings entry points (gear icon, limited-mode
  /// "configure" button) are shown.
  ///
  /// Hidden in ALL builds — end users talk to the shared assistant and never
  /// meet an API-key form. The screen was a development/testing aid; bring it
  /// back for a dev session with `--dart-define=SHOW_ASSISTANT_SETTINGS=true`
  /// (works in both debug and release).
  ///
  /// The `/chatbot/settings` route itself is always registered — this only
  /// controls whether anything navigates to it.
  static const bool showSettings = bool.fromEnvironment(
    'SHOW_ASSISTANT_SETTINGS',
  );

  /// True when a shared key was baked in at build time.
  static bool get hasBundledKey => apiKey.trim().isNotEmpty;

  static AssistantProvider get provider =>
      AssistantProviderX.fromId(_providerId);

  /// The bundled configuration, falling back to the provider's default model
  /// when `ASSISTANT_MODEL` was not supplied.
  static AssistantSettingsModel get settings {
    final provider = AssistantDefaults.provider;
    return AssistantSettingsModel(
      provider: provider,
      apiKey: apiKey.trim(),
      model: _model.trim().isNotEmpty ? _model.trim() : provider.defaultModel,
    );
  }
}
