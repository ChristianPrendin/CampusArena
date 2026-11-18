import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/features/chatbot/cubit/chat_cubit.dart';
import 'package:campus_arena/features/chatbot/cubit/chat_state.dart';
import 'package:campus_arena/features/chatbot/data/assistant_settings_model.dart';
import 'package:campus_arena/features/chatbot/data/assistant_settings_repository.dart';
import 'package:campus_arena/features/chatbot/data/chatbot_repository.dart';
import 'package:campus_arena/l10n/app_localizations_en.dart';
import 'package:campus_arena/models/chat_message_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockChatbotRepository extends Mock implements ChatbotRepository {}

class MockAssistantSettingsRepository extends Mock
    implements AssistantSettingsRepository {}

void main() {
  late MockChatbotRepository chatbotRepository;
  late MockAssistantSettingsRepository settingsRepository;
  final l10n = AppLocalizationsEn();

  setUpAll(() => registerFallbackValue(AppLocalizationsEn()));

  setUp(() {
    chatbotRepository = MockChatbotRepository();
    settingsRepository = MockAssistantSettingsRepository();
  });

  ChatCubit buildCubit() => ChatCubit(
    uid: 'u1',
    chatbotRepository: chatbotRepository,
    settingsRepository: settingsRepository,
  );

  group('initial limited-mode detection', () {
    blocTest<ChatCubit, ChatState>(
      'flips limitedMode to true when no API key is configured',
      setUp: () {
        when(
          () => settingsRepository.getSettings(),
        ).thenAnswer((_) async => AssistantSettingsModel.unconfigured());
      },
      build: buildCubit,
      expect: () => [
        isA<ChatState>().having((s) => s.limitedMode, 'limitedMode', isTrue),
      ],
    );

    blocTest<ChatCubit, ChatState>(
      'stays false when a key is configured',
      setUp: () {
        when(() => settingsRepository.getSettings()).thenAnswer(
          (_) async =>
              AssistantSettingsModel.unconfigured().copyWith(apiKey: 'sk-test'),
        );
      },
      build: buildCubit,
      expect: () => [
        isA<ChatState>().having((s) => s.limitedMode, 'limitedMode', isFalse),
      ],
    );
  });

  group('sendMessage', () {
    setUp(() {
      when(
        () => settingsRepository.getSettings(),
      ).thenAnswer((_) async => AssistantSettingsModel.unconfigured());
    });

    blocTest<ChatCubit, ChatState>(
      'appends a user bubble immediately, then an assistant answer',
      build: buildCubit,
      act: (cubit) async {
        // Let the constructor's async limitedMode refresh emit first, so
        // `skip: 1` deterministically drops it and not the sending state.
        await Future<void>.delayed(Duration.zero);
        when(
          () => chatbotRepository.answer(
            message: any(named: 'message'),
            uid: any(named: 'uid'),
            languageCode: any(named: 'languageCode'),
            l10n: any(named: 'l10n'),
          ),
        ).thenAnswer(
          (_) async => const ChatAnswer(
            text: 'Free right now: Table 1.',
            limitedMode: true,
          ),
        );
        await cubit.sendMessage(
          text: 'What tables are empty?',
          languageCode: 'en',
          l10n: l10n,
        );
      },
      skip: 1, // the initial limitedMode refresh emission
      expect: () => [
        isA<ChatState>()
            .having((s) => s.status, 'status', ChatStatus.sending)
            .having((s) => s.messages.length, 'messages.length', 1)
            .having(
              (s) => s.messages.single.sender,
              'sender',
              ChatMessageSender.user,
            ),
        isA<ChatState>()
            .having((s) => s.status, 'status', ChatStatus.answered)
            .having((s) => s.messages.length, 'messages.length', 2)
            .having(
              (s) => s.messages.last.text,
              'answer text',
              'Free right now: Table 1.',
            ),
      ],
    );

    blocTest<ChatCubit, ChatState>(
      'ignores blank input',
      build: buildCubit,
      act: (cubit) =>
          cubit.sendMessage(text: '   ', languageCode: 'en', l10n: l10n),
      skip: 1,
      expect: () => <ChatState>[],
    );

    blocTest<ChatCubit, ChatState>(
      'emits an error bubble with retry when the repository throws',
      build: buildCubit,
      act: (cubit) async {
        // Let the constructor's async limitedMode refresh emit first, so
        // `skip: 1` deterministically drops it and not the sending state.
        await Future<void>.delayed(Duration.zero);
        when(
          () => chatbotRepository.answer(
            message: any(named: 'message'),
            uid: any(named: 'uid'),
            languageCode: any(named: 'languageCode'),
            l10n: any(named: 'l10n'),
          ),
        ).thenThrow(Exception('boom'));
        await cubit.sendMessage(
          text: 'What tables are empty?',
          languageCode: 'en',
          l10n: l10n,
        );
      },
      skip: 1,
      expect: () => [
        isA<ChatState>().having((s) => s.status, 'status', ChatStatus.sending),
        isA<ChatState>()
            .having((s) => s.status, 'status', ChatStatus.error)
            .having((s) => s.messages.last.isError, 'isError', isTrue),
      ],
    );
  });

  group('clearChat', () {
    blocTest<ChatCubit, ChatState>(
      'empties the message list and resets to initial',
      setUp: () {
        when(
          () => settingsRepository.getSettings(),
        ).thenAnswer((_) async => AssistantSettingsModel.unconfigured());
        when(
          () => chatbotRepository.answer(
            message: any(named: 'message'),
            uid: any(named: 'uid'),
            languageCode: any(named: 'languageCode'),
            l10n: any(named: 'l10n'),
          ),
        ).thenAnswer(
          (_) async => const ChatAnswer(text: 'hi', limitedMode: true),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.sendMessage(text: 'hello', languageCode: 'en', l10n: l10n);
        cubit.clearChat();
      },
      verify: (cubit) {
        expect(cubit.state.messages, isEmpty);
        expect(cubit.state.status, ChatStatus.initial);
      },
    );
  });

  group('dismissIntroBanner', () {
    blocTest<ChatCubit, ChatState>(
      'hides the intro banner',
      setUp: () {
        when(
          () => settingsRepository.getSettings(),
        ).thenAnswer((_) async => AssistantSettingsModel.unconfigured());
      },
      build: buildCubit,
      act: (cubit) => cubit.dismissIntroBanner(),
      skip: 1,
      expect: () => [
        isA<ChatState>().having(
          (s) => s.showIntroBanner,
          'showIntroBanner',
          isFalse,
        ),
      ],
    );
  });
}
