import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/chatbot/data/assistant_provider.dart';
import 'package:campus_arena/features/chatbot/data/assistant_settings_model.dart';
import 'package:campus_arena/features/chatbot/data/assistant_settings_repository.dart';
import 'package:campus_arena/features/chatbot/data/chatbot_repository.dart';
import 'package:campus_arena/features/chatbot/data/chatbot_tools_service.dart';
import 'package:campus_arena/features/chatbot/data/intent_matcher.dart';
import 'package:campus_arena/features/chatbot/data/llm_client.dart';
import 'package:campus_arena/features/chatbot/data/tool_results.dart';
import 'package:campus_arena/l10n/app_localizations_en.dart';
import 'package:campus_arena/models/user_model.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockChatbotToolsService extends Mock implements ChatbotToolsService {}

class MockAssistantSettingsRepository extends Mock
    implements AssistantSettingsRepository {}

class MockLlmClient extends Mock implements LlmClient {}

class MockUserRepository extends Mock implements UserRepository {}

void main() {
  final l10n = AppLocalizationsEn();
  late MockChatbotToolsService tools;
  late MockAssistantSettingsRepository settingsRepository;
  late MockLlmClient llmClient;
  late ChatbotRepository repository;

  setUpAll(() {
    registerFallbackValue(
      const AssistantSettingsModel(
        provider: AssistantProvider.gemini,
        apiKey: '',
        model: 'gemini-1.5-flash',
      ),
    );
  });

  setUp(() {
    tools = MockChatbotToolsService();
    settingsRepository = MockAssistantSettingsRepository();
    llmClient = MockLlmClient();
    repository = ChatbotRepository(
      toolsService: tools,
      settingsRepository: settingsRepository,
      llmClient: llmClient,
      intentMatcher: const RuleBasedIntentMatcher(),
    );

    // Static explainer never touches Firestore; safe default for every test.
    when(() => tools.explainHowEloWorks()).thenReturn('ELO explainer text');
  });

  group('no API key configured -> rule-based limited mode', () {
    setUp(() {
      when(
        () => settingsRepository.getSettings(),
      ).thenAnswer((_) async => AssistantSettingsModel.unconfigured());
    });

    test('answers empty-tables questions from tool results only', () async {
      when(() => tools.getEmptyTables()).thenAnswer(
        (_) async => const [
          FacilityToolResult(
            facilityId: 'f1',
            name: 'Table 1',
            sportId: SportIds.pingPong,
            status: FacilityStatus.free,
            queueLength: 0,
          ),
        ],
      );

      final answer = await repository.answer(
        message: 'What tables are empty?',
        uid: 'u1',
        languageCode: 'en',
        l10n: l10n,
      );

      expect(answer.limitedMode, isTrue);
      expect(answer.text, contains('Table 1'));
      verifyNever(
        () => llmClient.sendMessage(
          settings: any(named: 'settings'),
          systemPrompt: any(named: 'systemPrompt'),
          history: any(named: 'history'),
        ),
      );
    });

    test('never calls the LLM client at all', () async {
      when(() => tools.getEmptyTables()).thenAnswer((_) async => const []);

      await repository.answer(
        message: 'What tables are empty?',
        uid: 'u1',
        languageCode: 'en',
        l10n: l10n,
      );

      verifyZeroInteractions(llmClient);
    });

    test('ELO answer includes the leaderboard rank when known', () async {
      when(
        () => tools.getUserEloAndRank(
          uid: any(named: 'uid'),
          sportId: any(named: 'sportId'),
        ),
      ).thenAnswer(
        (_) async => const EloRankToolResult(
          sportId: SportIds.pingPong,
          elo: 1350,
          rank: 4,
          matchesPlayed: 12,
        ),
      );

      final answer = await repository.answer(
        message: 'How does ELO work?',
        uid: 'u1',
        languageCode: 'en',
        l10n: l10n,
      );

      expect(answer.limitedMode, isTrue);
      expect(answer.text, contains('1350'));
      expect(answer.text, contains('#4'));
      expect(answer.text, contains('12'));
    });

    test('ELO answer omits the rank when it is unknown', () async {
      when(
        () => tools.getUserEloAndRank(
          uid: any(named: 'uid'),
          sportId: any(named: 'sportId'),
        ),
      ).thenAnswer(
        (_) async => const EloRankToolResult(
          sportId: SportIds.pingPong,
          elo: 1350,
          rank: null,
          matchesPlayed: 12,
        ),
      );

      final answer = await repository.answer(
        message: 'How does ELO work?',
        uid: 'u1',
        languageCode: 'en',
        l10n: l10n,
      );

      expect(answer.text, contains('1350'));
      expect(answer.text, isNot(contains('#')));
    });
  });

  group('LLM configured but the call fails -> falls back to limited mode', () {
    setUp(() {
      when(() => settingsRepository.getSettings()).thenAnswer(
        (_) async => const AssistantSettingsModel(
          provider: AssistantProvider.openai,
          apiKey: 'sk-test',
          model: 'gpt-4o-mini',
        ),
      );
      when(
        () => llmClient.sendMessage(
          settings: any(named: 'settings'),
          systemPrompt: any(named: 'systemPrompt'),
          history: any(named: 'history'),
        ),
      ).thenThrow(const LlmException('rate_limited'));
    });

    test('answers from tool results instead of surfacing the error', () async {
      when(() => tools.getEmptyTables()).thenAnswer(
        (_) async => const [
          FacilityToolResult(
            facilityId: 'f1',
            name: 'Table 1',
            sportId: SportIds.pingPong,
            status: FacilityStatus.free,
            queueLength: 0,
          ),
        ],
      );

      final answer = await repository.answer(
        message: 'What tables are empty?',
        uid: 'u1',
        languageCode: 'en',
        l10n: l10n,
      );

      expect(answer.limitedMode, isTrue);
      expect(answer.text, contains('Table 1'));
    });
  });

  group('LLM configured and succeeds -> uses the LLM answer', () {
    setUp(() {
      when(() => settingsRepository.getSettings()).thenAnswer(
        (_) async => const AssistantSettingsModel(
          provider: AssistantProvider.openai,
          apiKey: 'sk-test',
          model: 'gpt-4o-mini',
        ),
      );
      when(
        () => llmClient.sendMessage(
          settings: any(named: 'settings'),
          systemPrompt: any(named: 'systemPrompt'),
          history: any(named: 'history'),
        ),
      ).thenAnswer((_) async => 'Table 1 is free right now.');
    });

    test('returns the LLM text, not limited mode', () async {
      when(() => tools.getEmptyTables()).thenAnswer(
        (_) async => const [
          FacilityToolResult(
            facilityId: 'f1',
            name: 'Table 1',
            sportId: SportIds.pingPong,
            status: FacilityStatus.free,
            queueLength: 0,
          ),
        ],
      );

      final answer = await repository.answer(
        message: 'What tables are empty?',
        uid: 'u1',
        languageCode: 'en',
        l10n: l10n,
      );

      expect(answer.limitedMode, isFalse);
      expect(answer.text, contains('Table 1 is free right now.'));
    });
  });

  group('hard disclaimer rule', () {
    setUp(() {
      when(() => tools.getEmptyTables()).thenAnswer(
        (_) async => const [
          FacilityToolResult(
            facilityId: 'f1',
            name: 'Table 1',
            sportId: SportIds.pingPong,
            status: FacilityStatus.free,
            queueLength: 0,
          ),
        ],
      );
    });

    test('is appended on the rule-based (no-key) path', () async {
      when(
        () => settingsRepository.getSettings(),
      ).thenAnswer((_) async => AssistantSettingsModel.unconfigured());

      final answer = await repository.answer(
        message: 'What tables are empty?',
        uid: 'u1',
        languageCode: 'en',
        l10n: l10n,
      );

      expect(answer.text, contains(l10n.availabilityDisclaimerShort));
    });

    test(
      'is appended on the LLM path even though the LLM text omits it',
      () async {
        when(() => settingsRepository.getSettings()).thenAnswer(
          (_) async => const AssistantSettingsModel(
            provider: AssistantProvider.openai,
            apiKey: 'sk-test',
            model: 'gpt-4o-mini',
          ),
        );
        when(
          () => llmClient.sendMessage(
            settings: any(named: 'settings'),
            systemPrompt: any(named: 'systemPrompt'),
            history: any(named: 'history'),
          ),
          // The LLM's raw answer deliberately does NOT include the disclaimer
          // -- it must still show up in the final text, appended in code.
        ).thenAnswer((_) async => 'Table 1 is free right now.');

        final answer = await repository.answer(
          message: 'What tables are empty?',
          uid: 'u1',
          languageCode: 'en',
          l10n: l10n,
        );

        expect(answer.text, contains(l10n.availabilityDisclaimerShort));
        expect(answer.text, contains('Table 1 is free right now.'));
      },
    );

    test('is NOT appended when no availability tool fired', () async {
      when(
        () => settingsRepository.getSettings(),
      ).thenAnswer((_) async => AssistantSettingsModel.unconfigured());
      when(
        () => tools.getUserEloAndRank(
          uid: any(named: 'uid'),
          sportId: any(named: 'sportId'),
        ),
      ).thenAnswer((_) async => null);

      final answer = await repository.answer(
        message: 'How does ELO work?',
        uid: 'u1',
        languageCode: 'en',
        l10n: l10n,
      );

      expect(answer.text, isNot(contains(l10n.availabilityDisclaimerShort)));
    });
  });

  group('rule-based answers for the remaining intents (no key)', () {
    setUp(() {
      when(
        () => settingsRepository.getSettings(),
      ).thenAnswer((_) async => AssistantSettingsModel.unconfigured());
    });

    test('lists today\'s tournaments with their fill ratio', () async {
      when(() => tools.getTournamentsToday()).thenAnswer(
        (_) async => [
          TournamentToolResult(
            tournamentId: 't1',
            name: 'Spring Cup',
            sportId: SportIds.pingPong,
            status: 'open',
            scheduledAt: DateTime(2026, 7, 10, 18),
            participantCount: 4,
            maxParticipants: 8,
          ),
        ],
      );

      final answer = await repository.answer(
        message: 'any tournaments today?',
        uid: 'u1',
        languageCode: 'en',
        l10n: l10n,
      );

      expect(answer.limitedMode, isTrue);
      expect(answer.text, contains('Spring Cup'));
      expect(answer.text, contains('4/8'));
    });

    test('reports when there are no tournaments today', () async {
      when(() => tools.getTournamentsToday()).thenAnswer((_) async => const []);

      final answer = await repository.answer(
        message: 'any tournaments today?',
        uid: 'u1',
        languageCode: 'en',
        l10n: l10n,
      );

      expect(answer.text, l10n.chatbotAnswerNoTournaments);
    });

    test('reports the queue position when the user is queued', () async {
      when(() => tools.getUserQueuePosition('u1')).thenAnswer(
        (_) async => const QueuePositionToolResult(
          facilityId: 'f1',
          facilityName: 'Table 2',
          position: 3,
        ),
      );

      final answer = await repository.answer(
        message: 'what is my queue position?',
        uid: 'u1',
        languageCode: 'en',
        l10n: l10n,
      );

      expect(answer.text, contains('3'));
      expect(answer.text, contains('Table 2'));
    });

    test('reports when the user is not queued anywhere', () async {
      when(
        () => tools.getUserQueuePosition('u1'),
      ).thenAnswer((_) async => null);

      final answer = await repository.answer(
        message: 'what is my queue position?',
        uid: 'u1',
        languageCode: 'en',
        l10n: l10n,
      );

      expect(answer.text, l10n.chatbotAnswerQueueNone);
    });

    test(
      'falls back to the generic answer for an unmatched question',
      () async {
        final answer = await repository.answer(
          message: 'hello there, how are you?',
          uid: 'u1',
          languageCode: 'en',
          l10n: l10n,
        );

        expect(answer.limitedMode, isTrue);
        expect(answer.text, l10n.chatbotAnswerGeneral);
      },
    );
  });

  group('LLM grounding includes tool context and user personalization', () {
    late MockUserRepository userRepository;

    setUp(() {
      userRepository = MockUserRepository();
      repository = ChatbotRepository(
        toolsService: tools,
        settingsRepository: settingsRepository,
        llmClient: llmClient,
        intentMatcher: const RuleBasedIntentMatcher(),
        userRepository: userRepository,
      );
      when(() => settingsRepository.getSettings()).thenAnswer(
        (_) async => const AssistantSettingsModel(
          provider: AssistantProvider.openai,
          apiKey: 'sk-test',
          model: 'gpt-4o-mini',
        ),
      );
      when(
        () => llmClient.sendMessage(
          settings: any(named: 'settings'),
          systemPrompt: any(named: 'systemPrompt'),
          history: any(named: 'history'),
        ),
      ).thenAnswer((_) async => 'grounded answer');
    });

    String capturedPrompt() =>
        verify(
              () => llmClient.sendMessage(
                settings: any(named: 'settings'),
                systemPrompt: captureAny(named: 'systemPrompt'),
                history: any(named: 'history'),
              ),
            ).captured.single
            as String;

    test('grounds the model with the matched tournaments', () async {
      when(() => userRepository.getUser('u1')).thenAnswer((_) async => null);
      when(() => tools.getTournamentsToday()).thenAnswer(
        (_) async => [
          TournamentToolResult(
            tournamentId: 't1',
            name: 'Spring Cup',
            sportId: SportIds.pingPong,
            status: 'open',
            scheduledAt: DateTime(2026, 7, 10, 18),
            participantCount: 4,
            maxParticipants: 8,
          ),
        ],
      );

      final answer = await repository.answer(
        message: 'any tournaments today?',
        uid: 'u1',
        languageCode: 'en',
        l10n: l10n,
      );

      expect(answer.limitedMode, isFalse);
      expect(capturedPrompt(), contains('Spring Cup'));
    });

    test('injects the user profile and ELO into the system prompt', () async {
      when(() => userRepository.getUser('u1')).thenAnswer(
        (_) async => UserModel(
          uid: 'u1',
          name: 'Mario Rossi',
          username: 'mario',
          email: 'mario@polimi.it',
          degreeProgram: 'Computer Science',
          language: 'en',
          pushTokens: const [],
          friendUids: const [],
          badges: const {},
          onboardingComplete: true,
          createdAt: DateTime(2026),
        ),
      );
      when(
        () => tools.getUserEloAndRank(
          uid: 'u1',
          sportId: any(named: 'sportId'),
        ),
      ).thenAnswer(
        (_) async => const EloRankToolResult(
          sportId: SportIds.pingPong,
          elo: 1420,
          rank: 2,
          matchesPlayed: 9,
        ),
      );

      await repository.answer(
        message: 'hello',
        uid: 'u1',
        languageCode: 'en',
        l10n: l10n,
      );

      final prompt = capturedPrompt();
      expect(prompt, contains('Mario Rossi'));
      expect(prompt, contains('1420'));
    });
  });
}
