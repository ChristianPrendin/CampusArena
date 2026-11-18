import 'package:campus_arena/features/onboarding/mini_tutorial_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(VoidCallback onFinish) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: MiniTutorialView(onFinish: onFinish)),
  );
}

void main() {
  testWidgets('paging to the last slide reveals Get Started, which finishes', (
    tester,
  ) async {
    var finished = 0;
    await tester.pumpWidget(_wrap(() => finished++));
    await tester.pumpAndSettle();

    // First slide shows Next, not the finish button.
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);

    // Advance through the three slides.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Get Started'), findsOneWidget);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(finished, 1);
  });

  testWidgets('Skip finishes immediately from the first slide', (tester) async {
    var finished = 0;
    await tester.pumpWidget(_wrap(() => finished++));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(finished, 1);
  });
}
