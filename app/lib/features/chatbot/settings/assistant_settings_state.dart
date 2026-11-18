import 'package:equatable/equatable.dart';

import '../data/assistant_settings_model.dart';

enum AssistantSettingsStatus { loading, ready, saving, testing }

class AssistantSettingsState extends Equatable {
  final AssistantSettingsStatus status;
  final AssistantSettingsModel settings;

  /// Null until Test Connection has been run at least once this session.
  final bool? lastTestSuccess;

  /// Localized-key error reason from the last failed test (e.g.
  /// `invalid_api_key`) — the screen maps this to a localized string.
  final String? lastTestErrorReason;

  final bool saved;

  const AssistantSettingsState({
    this.status = AssistantSettingsStatus.loading,
    required this.settings,
    this.lastTestSuccess,
    this.lastTestErrorReason,
    this.saved = false,
  });

  factory AssistantSettingsState.initial() =>
      AssistantSettingsState(settings: AssistantSettingsModel.unconfigured());

  AssistantSettingsState copyWith({
    AssistantSettingsStatus? status,
    AssistantSettingsModel? settings,
    bool? lastTestSuccess,
    String? lastTestErrorReason,
    bool? saved,
    bool clearLastTest = false,
  }) {
    return AssistantSettingsState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      lastTestSuccess: clearLastTest
          ? null
          : (lastTestSuccess ?? this.lastTestSuccess),
      lastTestErrorReason: clearLastTest
          ? null
          : (lastTestErrorReason ?? this.lastTestErrorReason),
      saved: saved ?? this.saved,
    );
  }

  @override
  List<Object?> get props => [
    status,
    settings,
    lastTestSuccess,
    lastTestErrorReason,
    saved,
  ];
}
