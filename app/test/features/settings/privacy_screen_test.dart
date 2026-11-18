import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/features/settings/privacy_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the title, intro and four data bullets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PrivacyScreen(),
      ),
    );

    expect(find.text('Privacy'), findsOneWidget);
    expect(
      find.text("Here's what CampusArena stores about you."),
      findsOneWidget,
    );
    // One check-circle per stored-data bullet (profile, matches, ratings,
    // location).
    expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(4));
  });

  testWidgets('renders in Italian without missing strings', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PrivacyScreen(),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(4));
    expect(find.byType(AppBar), findsOneWidget);
  });
}
