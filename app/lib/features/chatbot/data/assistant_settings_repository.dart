import 'package:shared_preferences/shared_preferences.dart';

import 'assistant_defaults.dart';
// Looks unused, but brings the `AssistantProviderX` extension into scope for
// `settings.provider.id` in saveSettings(). Do not remove.
import 'assistant_provider.dart';
import 'assistant_settings_model.dart';

/// Resolves the Arena Assistant's provider/key/model configuration.
///
/// Precedence, highest first:
///
/// 1. A key the user saved on this device via the (debug-only) Assistant
///    Settings screen — an explicit override always wins.
/// 2. The shared key compiled in at build time ([AssistantDefaults]). This is
///    the path every ordinary user takes: they never see a key, never
///    configure anything, and the assistant just works.
/// 3. Nothing — [AssistantSettingsModel.unconfigured], which has no key, so
///    [ChatbotRepository] answers in rule-based "limited mode".
///
/// Persistence uses `shared_preferences` (the repo has no
/// `flutter_secure_storage` dependency and this is a course project, not a
/// production key vault). No Firestore involvement: this is local-only,
/// per-device configuration.
class AssistantSettingsRepository {
  const AssistantSettingsRepository();

  static const String _providerKey = 'assistant_provider';
  static const String _apiKeyKey = 'assistant_api_key';
  static const String _modelKey = 'assistant_model';

  Future<AssistantSettingsModel> getSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final provider = preferences.getString(_providerKey);
    final apiKey = preferences.getString(_apiKeyKey);
    final model = preferences.getString(_modelKey);

    // (1) A stored key is a deliberate override — honour it verbatim.
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      return AssistantSettingsModel.fromMap({
        'provider': provider,
        'apiKey': apiKey,
        'model': model,
      });
    }

    // (2) Otherwise fall back to the shared build-time key, if one was baked
    // in. Note this deliberately ignores any stored provider/model: without a
    // stored key those would only ever produce a broken half-configuration.
    if (AssistantDefaults.hasBundledKey) {
      return AssistantDefaults.settings;
    }

    // (3) No key anywhere → limited mode.
    if (provider == null && apiKey == null && model == null) {
      return AssistantSettingsModel.unconfigured();
    }

    return AssistantSettingsModel.fromMap({
      'provider': provider,
      'apiKey': apiKey,
      'model': model,
    });
  }

  Future<void> saveSettings(AssistantSettingsModel settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_providerKey, settings.provider.id);
    await preferences.setString(_apiKeyKey, settings.apiKey);
    await preferences.setString(_modelKey, settings.model);
  }

  /// Drops the user's override. The next [getSettings] therefore returns the
  /// shared build-time key (or limited mode, if none was baked in) — clearing
  /// resets to the default assistant rather than disabling it.
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_providerKey);
    await preferences.remove(_apiKeyKey);
    await preferences.remove(_modelKey);
  }
}
