import 'package:campus_arena/features/chatbot/data/assistant_defaults.dart';
import 'package:campus_arena/features/chatbot/data/assistant_provider.dart';
import 'package:campus_arena/features/chatbot/data/assistant_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `flutter test` runs without `--dart-define`, so [AssistantDefaults] never
/// has a bundled key here. That pins the "no key anywhere" branch; the
/// bundled-key branch is asserted indirectly via [AssistantDefaults.settings].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const repository = AssistantSettingsRepository();

  group('AssistantSettingsRepository.getSettings precedence', () {
    test(
      'a stored key overrides everything and is returned verbatim',
      () async {
        SharedPreferences.setMockInitialValues({
          'assistant_provider': 'openai',
          'assistant_api_key': 'sk-user-supplied',
          'assistant_model': 'gpt-4o-mini',
        });

        final settings = await repository.getSettings();

        expect(settings.provider, AssistantProvider.openai);
        expect(settings.apiKey, 'sk-user-supplied');
        expect(settings.model, 'gpt-4o-mini');
        expect(settings.hasApiKey, isTrue);
      },
    );

    test('empty prefs with no bundled key yields limited mode', () async {
      SharedPreferences.setMockInitialValues({});

      final settings = await repository.getSettings();

      expect(settings.hasApiKey, isFalse);
    });

    test('a stored provider without a key still yields limited mode', () async {
      SharedPreferences.setMockInitialValues({
        'assistant_provider': 'anthropic',
        'assistant_api_key': '',
        'assistant_model': 'claude-3-5-haiku-latest',
      });

      final settings = await repository.getSettings();

      expect(settings.hasApiKey, isFalse);
    });

    test('a whitespace-only stored key is not treated as a key', () async {
      SharedPreferences.setMockInitialValues({
        'assistant_provider': 'openai',
        'assistant_api_key': '   ',
        'assistant_model': 'gpt-4o-mini',
      });

      final settings = await repository.getSettings();

      expect(settings.hasApiKey, isFalse);
    });

    test('clear() drops the user override', () async {
      SharedPreferences.setMockInitialValues({
        'assistant_provider': 'openai',
        'assistant_api_key': 'sk-user-supplied',
        'assistant_model': 'gpt-4o-mini',
      });

      await repository.clear();
      final settings = await repository.getSettings();

      // No bundled key in the test environment, so this falls all the way
      // through to limited mode rather than to the shared assistant.
      expect(settings.hasApiKey, isFalse);
    });
  });

  group('AssistantDefaults', () {
    test('no key is baked in during tests', () {
      expect(AssistantDefaults.hasBundledKey, isFalse);
      expect(AssistantDefaults.apiKey, isEmpty);
    });

    test('defaults to the Regolo provider and its model', () {
      expect(AssistantDefaults.provider, AssistantProvider.regolo);
      expect(AssistantDefaults.settings.model, 'qwen3.5-122b');
    });

    test('settings entry points are hidden unless explicitly forced', () {
      // Tests run without --dart-define=SHOW_ASSISTANT_SETTINGS=true, so the
      // gear icon / "configure" button must be hidden — end users never see
      // the API-key form in any build.
      expect(AssistantDefaults.showSettings, isFalse);
    });
  });

  group('AssistantProvider.regolo', () {
    test('round-trips through its persisted id', () {
      expect(AssistantProvider.regolo.id, 'regolo');
      expect(AssistantProviderX.fromId('regolo'), AssistantProvider.regolo);
    });

    test('exposes a label and a default model', () {
      expect(AssistantProvider.regolo.label, isNotEmpty);
      expect(AssistantProvider.regolo.defaultModel, 'qwen3.5-122b');
    });
  });
}
