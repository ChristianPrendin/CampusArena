import 'package:campus_arena/features/profile/widgets/achievement_grid.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/achievement_def_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

const _firstVictory = AchievementDefModel(
  achievementId: 'first_victory',
  nameKey: 'achievement_first_victory_name',
  descriptionKey: 'achievement_first_victory_desc',
  iconAsset: 'assets/badges/first_victory.png',
  condition: 'first_victory',
);

const _streak5 = AchievementDefModel(
  achievementId: 'streak_5',
  nameKey: 'achievement_streak_5_name',
  descriptionKey: 'achievement_streak_5_desc',
  iconAsset: 'assets/badges/streak_5.png',
  condition: 'win_streak',
  threshold: 5,
);

void main() {
  Widget wrap({
    required List<AchievementDefModel> defs,
    required Map<String, DateTime> badges,
    Locale locale = const Locale('en'),
  }) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: AchievementGrid(defs: defs, badges: badges),
      ),
    ),
  );

  Future<AppLocalizations> l10nFor(Locale locale) =>
      AppLocalizations.delegate.load(locale);

  testWidgets('renders header + names, desaturating only locked badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        defs: const [_firstVictory, _streak5],
        badges: {'first_victory': DateTime(2026, 7, 9)},
      ),
    );
    await tester.pump();
    final l10n = await l10nFor(const Locale('en'));

    expect(find.text(l10n.profileAchievementsTitle), findsOneWidget);
    expect(find.text(l10n.achievement_first_victory_name), findsOneWidget);
    expect(find.text(l10n.achievement_streak_5_name), findsOneWidget);

    // No permanent on-grid caption — that detail only appears on tap.
    expect(find.textContaining('Unlocked'), findsNothing);

    // Desaturation path: exactly one badge (the locked streak_5) is greyscaled.
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  testWidgets('all-locked grid greyscales every badge', (tester) async {
    await tester.pumpWidget(
      wrap(defs: const [_firstVictory, _streak5], badges: const {}),
    );
    await tester.pump();

    expect(find.byType(ColorFiltered), findsNWidgets(2));
  });

  testWidgets(
    'tapping an earned badge reveals its unlock date as a system message',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          defs: const [_firstVictory, _streak5],
          badges: {'first_victory': DateTime(2026, 7, 9)},
        ),
      );
      await tester.pump();
      final l10n = await l10nFor(const Locale('en'));

      await tester.tap(find.text(l10n.achievement_first_victory_name));
      await tester.pump(); // SnackBar enter animation frame

      expect(
        find.text(
          l10n.achievementUnlockedOn(
            DateFormat.yMMMd('en').format(DateTime(2026, 7, 9)),
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tapping a locked badge reveals how to unlock it as a system message',
    (tester) async {
      await tester.pumpWidget(
        wrap(defs: const [_firstVictory, _streak5], badges: const {}),
      );
      await tester.pump();
      final l10n = await l10nFor(const Locale('en'));

      await tester.tap(find.text(l10n.achievement_streak_5_name));
      await tester.pump();

      expect(
        find.text(l10n.achievementUnlockHint(l10n.achievement_streak_5_desc)),
        findsOneWidget,
      );
    },
  );

  testWidgets('renders and reveals messages in Italian', (tester) async {
    await tester.pumpWidget(
      wrap(
        defs: const [_firstVictory, _streak5],
        badges: const {},
        locale: const Locale('it'),
      ),
    );
    await tester.pump();
    final l10n = await l10nFor(const Locale('it'));

    expect(find.text(l10n.profileAchievementsTitle), findsOneWidget);
    expect(find.text(l10n.achievement_first_victory_name), findsOneWidget);
    // Still desaturated in either locale.
    expect(find.byType(ColorFiltered), findsNWidgets(2));

    await tester.tap(find.text(l10n.achievement_streak_5_name));
    await tester.pump();

    expect(
      find.text(l10n.achievementUnlockHint(l10n.achievement_streak_5_desc)),
      findsOneWidget,
    );
  });
}
