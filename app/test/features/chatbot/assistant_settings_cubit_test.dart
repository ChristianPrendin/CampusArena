import 'package:campus_arena/features/chatbot/data/assistant_provider.dart';
import 'package:campus_arena/features/chatbot/data/assistant_settings_model.dart';
import 'package:campus_arena/features/chatbot/data/assistant_settings_repository.dart';
import 'package:campus_arena/features/chatbot/data/llm_client.dart';
import 'package:campus_arena/features/chatbot/settings/assistant_settings_cubit.dart';
import 'package:campus_arena/features/chatbot/settings/assistant_settings_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAssistantSettingsRepository extends Mock
    implements AssistantSettingsRepository {}

class MockLlmClient extends Mock implements LlmClient {}

class _FakeSettings extends Fake implements AssistantSettingsModel {}

void main() {
  late MockAssistantSettingsRepository repository;
  late MockLlmClient llmClient;

  const stored = AssistantSettingsModel(
    provider: AssistantProvider.openai,
    apiKey: 'sk-stored',
    model: 'gpt-4o-mini',
  );

  setUpAll(() => registerFallbackValue(_FakeSettings()));

  setUp(() {
    repository = MockAssistantSettingsRepository();
    llmClient = MockLlmClient();
    when(() => repository.getSettings()).thenAnswer((_) async => stored);
    when(() => repository.saveSettings(any())).thenAnswer((_) async {});
  });

  /// Builds the cubit and waits for its async constructor [_load] to settle,
  /// so tests act from the ready(stored) state rather than the initial one.
  Future<AssistantSettingsCubit> loadedCubit() async {
    final cubit = AssistantSettingsCubit(
      settingsRepository: repository,
      llmClient: llmClient,
    );
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);
    return cubit;
  }

  test('loads persisted settings and becomes ready on construction', () async {
    final cubit = await loadedCubit();
    expect(cubit.state.status, AssistantSettingsStatus.ready);
    expect(cubit.state.settings, stored);
  });

  test('changeProvider resets the model to the new provider default', () async {
    final cubit = await loadedCubit();
    cubit.changeProvider(AssistantProvider.gemini);
    expect(cubit.state.settings.provider, AssistantProvider.gemini);
    expect(cubit.state.settings.model, AssistantProvider.gemini.defaultModel);
  });

  test('changeProvider with keepModel preserves the current model', () async {
    final cubit = await loadedCubit();
    cubit.changeProvider(AssistantProvider.gemini, keepModel: true);
    expect(cubit.state.settings.provider, AssistantProvider.gemini);
    expect(cubit.state.settings.model, 'gpt-4o-mini');
  });

  test('changeApiKey and changeModel update the edited settings', () async {
    final cubit = await loadedCubit();
    cubit.changeApiKey('sk-new');
    cubit.changeModel('gpt-4o');
    expect(cubit.state.settings.apiKey, 'sk-new');
    expect(cubit.state.settings.model, 'gpt-4o');
  });

  test('an edit clears a prior test result', () async {
    when(
      () => llmClient.testConnection(any()),
    ).thenAnswer((_) async => const LlmConnectionTestResult.success());
    final cubit = await loadedCubit();
    await cubit.testConnection();
    expect(cubit.state.lastTestSuccess, isTrue);

    cubit.changeApiKey('sk-new');
    expect(cubit.state.lastTestSuccess, isNull);
  });

  test('testConnection records a success', () async {
    when(
      () => llmClient.testConnection(any()),
    ).thenAnswer((_) async => const LlmConnectionTestResult.success());
    final cubit = await loadedCubit();

    final statuses = <AssistantSettingsStatus>[];
    final sub = cubit.stream.listen((s) => statuses.add(s.status));

    await cubit.testConnection();

    expect(statuses, contains(AssistantSettingsStatus.testing));
    expect(cubit.state.status, AssistantSettingsStatus.ready);
    expect(cubit.state.lastTestSuccess, isTrue);
    expect(cubit.state.lastTestErrorReason, isNull);
    await sub.cancel();
  });

  test('testConnection surfaces the failure reason', () async {
    when(() => llmClient.testConnection(any())).thenAnswer(
      (_) async => const LlmConnectionTestResult.failure('invalid_api_key'),
    );
    final cubit = await loadedCubit();
    await cubit.testConnection();

    expect(cubit.state.lastTestSuccess, isFalse);
    expect(cubit.state.lastTestErrorReason, 'invalid_api_key');
  });

  test('save persists the settings and flips saved to true', () async {
    final cubit = await loadedCubit();

    final statuses = <AssistantSettingsStatus>[];
    final sub = cubit.stream.listen((s) => statuses.add(s.status));

    await cubit.save();

    expect(statuses, contains(AssistantSettingsStatus.saving));
    expect(cubit.state.status, AssistantSettingsStatus.ready);
    expect(cubit.state.saved, isTrue);
    verify(() => repository.saveSettings(stored)).called(1);
    await sub.cancel();
  });
}
