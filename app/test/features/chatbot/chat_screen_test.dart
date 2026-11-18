import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/chatbot/chat_screen.dart';
import 'package:campus_arena/features/chatbot/cubit/chat_cubit.dart';
import 'package:campus_arena/features/chatbot/data/assistant_settings_model.dart';
import 'package:campus_arena/features/chatbot/data/assistant_settings_repository.dart';
import 'package:campus_arena/features/chatbot/data/chatbot_repository.dart';
import 'package:campus_arena/features/chatbot/data/tool_results.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockChatbotRepository extends Mock implements ChatbotRepository {}

class MockAssistantSettingsRepository extends Mock
    implements AssistantSettingsRepository {}

void main() {
  late MockChatbotRepository chatbotRepository;
  late MockAssistantSettingsRepository settingsRepository;

  setUpAll(() => registerFallbackValue(AppLocalizationsEn()));

  setUp(() {
    chatbotRepository = MockChatbotRepository();
    settingsRepository = MockAssistantSettingsRepository();
    when(
      () => settingsRepository.getSettings(),
    ).thenAnswer((_) async => AssistantSettingsModel.unconfigured());
  });

  Widget buildTestableWidget() {
    final router = GoRouter(
      initialLocation: '/chatbot',
      routes: [
        GoRoute(
          path: '/chatbot',
          builder: (context, state) => BlocProvider<ChatCubit>(
            create: (_) => ChatCubit(
              uid: 'u1',
              chatbotRepository: chatbotRepository,
              settingsRepository: settingsRepository,
            ),
            child: const ChatScreen(),
          ),
        ),
        GoRoute(
          path: '/chatbot/settings',
          builder: (context, state) => const Scaffold(body: Text('Settings')),
        ),
        GoRoute(
          path: '/map',
          builder: (context, state) => const Scaffold(body: Text('Map')),
        ),
      ],
    );

    return MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }

  testWidgets('shows suggested chips when the chat first opens', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    expect(find.text('What tables are empty?'), findsOneWidget);
    expect(find.text('Tournaments today'), findsOneWidget);
    expect(find.text('How does ELO work?'), findsOneWidget);
    expect(find.text('Where am I in the queue?'), findsOneWidget);
  });

  testWidgets('shows the intro disclaimer banner on first open', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Availability shows CampusArena activity only'),
      findsOneWidget,
    );
  });

  testWidgets('shows the limited-mode pill when no API key is configured', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    expect(find.textContaining('Limited mode'), findsOneWidget);
  });

  testWidgets('sending a message renders a user bubble', (tester) async {
    when(
      () => chatbotRepository.answer(
        message: any(named: 'message'),
        uid: any(named: 'uid'),
        languageCode: any(named: 'languageCode'),
        l10n: any(named: 'l10n'),
      ),
    ).thenAnswer(
      (_) async => const ChatAnswer(text: 'Hi there!', limitedMode: true),
    );

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hello assistant');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('Hello assistant'), findsOneWidget);
    expect(find.text('Hi there!'), findsOneWidget);
  });

  testWidgets('a facility card renders and the disclaimer shows exactly once', (
    tester,
  ) async {
    // The repository always appends the short disclaimer to the answer text
    // (its hard rule). The card must NOT repeat it, so the disclaimer should
    // appear exactly once in the bubble.
    when(
      () => chatbotRepository.answer(
        message: any(named: 'message'),
        uid: any(named: 'uid'),
        languageCode: any(named: 'languageCode'),
        l10n: any(named: 'l10n'),
      ),
    ).thenAnswer(
      (_) async => const ChatAnswer(
        text:
            'Free right now: Table 1.\n\nBased on app activity only — the '
            'table may be in use by non-app players. Not a reservation.',
        facilityResults: [
          FacilityToolResult(
            facilityId: 'f1',
            name: 'Table 1',
            sportId: SportIds.pingPong,
            status: FacilityStatus.free,
            queueLength: 0,
          ),
        ],
        limitedMode: true,
      ),
    );

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('What tables are empty?'));
    await tester.pumpAndSettle();

    expect(find.text('Table 1'), findsOneWidget);
    expect(find.textContaining('Based on app activity only'), findsOneWidget);
  });
}
