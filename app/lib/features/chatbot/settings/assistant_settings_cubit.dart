import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/assistant_provider.dart';
import '../data/assistant_settings_repository.dart';
import '../data/llm_client.dart';
import 'assistant_settings_state.dart';

/// Drives the Assistant Settings screen: loads the persisted configuration,
/// tracks in-progress edits, runs [LlmClient.testConnection], and persists on
/// save.
class AssistantSettingsCubit extends Cubit<AssistantSettingsState> {
  AssistantSettingsCubit({
    AssistantSettingsRepository? settingsRepository,
    LlmClient? llmClient,
  }) : _settingsRepository =
           settingsRepository ?? const AssistantSettingsRepository(),
       _llmClient = llmClient ?? LlmClient(),
       super(AssistantSettingsState.initial()) {
    _load();
  }

  final AssistantSettingsRepository _settingsRepository;
  final LlmClient _llmClient;

  Future<void> _load() async {
    final settings = await _settingsRepository.getSettings();
    emit(
      state.copyWith(status: AssistantSettingsStatus.ready, settings: settings),
    );
  }

  /// Updates the provider, and — unless [keepModel] is true — resets the
  /// model field to that provider's default. The settings screen asks the
  /// user before dropping a custom model value.
  void changeProvider(AssistantProvider provider, {bool keepModel = false}) {
    emit(
      state.copyWith(
        settings: state.settings.copyWith(
          provider: provider,
          model: keepModel ? state.settings.model : provider.defaultModel,
        ),
        clearLastTest: true,
      ),
    );
  }

  void changeApiKey(String apiKey) {
    emit(
      state.copyWith(
        settings: state.settings.copyWith(apiKey: apiKey),
        clearLastTest: true,
      ),
    );
  }

  void changeModel(String model) {
    emit(
      state.copyWith(
        settings: state.settings.copyWith(model: model),
        clearLastTest: true,
      ),
    );
  }

  Future<void> testConnection() async {
    emit(state.copyWith(status: AssistantSettingsStatus.testing));
    final result = await _llmClient.testConnection(state.settings);
    emit(
      state.copyWith(
        status: AssistantSettingsStatus.ready,
        lastTestSuccess: result.success,
        lastTestErrorReason: result.errorMessage,
      ),
    );
  }

  Future<void> save() async {
    emit(state.copyWith(status: AssistantSettingsStatus.saving, saved: false));
    await _settingsRepository.saveSettings(state.settings);
    emit(state.copyWith(status: AssistantSettingsStatus.ready, saved: true));
  }
}
