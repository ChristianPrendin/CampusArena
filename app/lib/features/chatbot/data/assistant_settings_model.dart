import 'package:equatable/equatable.dart';

import 'assistant_provider.dart';

/// Persisted Arena Assistant configuration: which LLM provider to call, the
/// user's own API key for it, and which model id to send. `apiKey` is empty
/// when the assistant has not been configured yet, in which case
/// [ChatbotRepository] always falls back to rule-based "limited mode".
class AssistantSettingsModel extends Equatable {
  final AssistantProvider provider;
  final String apiKey;
  final String model;

  const AssistantSettingsModel({
    required this.provider,
    required this.apiKey,
    required this.model,
  });

  /// Unconfigured default: Gemini selected, no key, its default model.
  factory AssistantSettingsModel.unconfigured() => AssistantSettingsModel(
    provider: AssistantProvider.gemini,
    apiKey: '',
    model: AssistantProvider.gemini.defaultModel,
  );

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  AssistantSettingsModel copyWith({
    AssistantProvider? provider,
    String? apiKey,
    String? model,
  }) {
    return AssistantSettingsModel(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  Map<String, String> toMap() {
    return {'provider': provider.id, 'apiKey': apiKey, 'model': model};
  }

  factory AssistantSettingsModel.fromMap(Map<String, String?> map) {
    final provider = AssistantProviderX.fromId(map['provider'] ?? '');
    return AssistantSettingsModel(
      provider: provider,
      apiKey: map['apiKey'] ?? '',
      model: (map['model']?.isNotEmpty ?? false)
          ? map['model']!
          : provider.defaultModel,
    );
  }

  @override
  List<Object?> get props => [provider, apiKey, model];
}
