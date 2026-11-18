import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/features/result/cubit/result_state.dart';
import 'package:campus_arena/features/result/widgets/result_summary_view.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/achievement_def_model.dart';
import 'package:campus_arena/routing/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

EloSummary _summary({
  bool isWin = true,
  int oldElo = 1400,
  int delta = 18,
  bool isSingles = true,
  int? rank,
}) => EloSummary(
  isWin: isWin,
  oldElo: oldElo,
  newElo: oldElo + delta,
  delta: delta,
  isSingles: isSingles,
  rank: rank,
);

AchievementDefModel _badge(String id) => AchievementDefModel(
  achievementId: id,
  nameKey: 'ach_$id',
  descriptionKey: 'ach_${id}_desc',
  iconAsset: 'assets/achievements/$id.png',
  condition: 'matches_won',
  threshold: 1,
);

Widget _wrap(ResultState state) {
  final router = GoRouter(
    initialLocation: '/summary',
    routes: [
      GoRoute(
        path: '/summary',
        builder: (_, _) => ResultSummaryView(state: state),
      ),
      GoRoute(
        path: RouteConstants.home,
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  return MaterialApp.router(
    theme: AppTheme.lightTheme,
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  testWidgets('a null summary shows a spinner', (tester) async {
    await tester.pumpWidget(
      _wrap(const ResultState(phase: ResultPhase.summary)),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a singles win shows Victory, the rank pill and Done -> home', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ResultState(
          phase: ResultPhase.summary,
          summary: _summary(isWin: true, rank: 3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Victory!'), findsOneWidget);
    expect(find.text('New campus rank'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('a loss shows Defeat and the down trend, no rank pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ResultState(
          phase: ResultPhase.summary,
          summary: _summary(isWin: false, delta: -14),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Defeat'), findsOneWidget);
    expect(find.byIcon(Icons.trending_down), findsOneWidget);
    expect(find.text('New campus rank'), findsNothing);
  });

  testWidgets('unlocked achievements reveal their badges', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ResultState(
          phase: ResultPhase.summary,
          summary: _summary(isWin: true),
          newBadges: [_badge('first_victory')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The badge asset is absent in tests, so the errorBuilder trophy shows.
    expect(find.byIcon(Icons.emoji_events), findsWidgets);
  });

  testWidgets('a doubles win omits the rank pill even when a rank is set', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ResultState(
          phase: ResultPhase.summary,
          summary: _summary(isWin: true, isSingles: false, rank: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New campus rank'), findsNothing);
  });
}
