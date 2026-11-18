import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/features/chatbot/data/assistant_provider.dart';
import 'package:campus_arena/features/chatbot/settings/assistant_settings_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The screen builds its own [AssistantSettingsCubit], which reads/writes
/// SharedPreferences and — critically for tests — short-circuits Test
/// Connection to `missing_api_key` before any network call when no key is set.
Widget _screen() => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const AssistantSettingsScreen(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders the no-key banner, provider, fields and buttons', (
    tester,
  ) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    expect(find.text('Assistant Settings'), findsOneWidget);
    expect(find.textContaining('No API key configured'), findsOneWidget);
    expect(
      find.byType(DropdownButtonFormField<AssistantProvider>),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, ''), findsWidgets);
    expect(find.text('Test Connection'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('the key visibility toggle flips obscureText', (tester) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    // The API-key field starts obscured.
    final obscuredBefore = tester
        .widgetList<TextField>(find.byType(TextField))
        .any((f) => f.obscureText);
    expect(obscuredBefore, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    final anyObscuredAfter = tester
        .widgetList<TextField>(find.byType(TextField))
        .any((f) => f.obscureText);
    expect(anyObscuredAfter, isFalse);
  });

  testWidgets('entering a key and saving shows the saved snackbar', (
    tester,
  ) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'sk-my-key');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Assistant settings saved'), findsOneWidget);
    // The banner is gone once a key is present.
    expect(find.textContaining('No API key configured'), findsNothing);
  });

  testWidgets('Test Connection with no key surfaces the missing-key error', (
    tester,
  ) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Test Connection'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Connection failed:'), findsOneWidget);
    expect(find.textContaining('Add an API key first.'), findsOneWidget);
  });

  testWidgets('changing provider with a custom model prompts to reset it', (
    tester,
  ) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    // Make the model custom (differs from the current provider default).
    await tester.enterText(find.byType(TextField).last, 'my-custom-model');
    await tester.pump();

    // Open the provider dropdown and pick a different provider.
    await tester.tap(find.byType(DropdownButtonFormField<AssistantProvider>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenAI').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Reset the model field to this provider\'s default?'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Reset'));
    await tester.pumpAndSettle();

    // Model reset to OpenAI's default.
    final modelField = tester.widget<TextField>(find.byType(TextField).last);
    expect(modelField.controller?.text, AssistantProvider.openai.defaultModel);
  });
}
