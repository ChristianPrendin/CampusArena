import 'package:campus_arena/core/scoring/foosball_scoring_strategy.dart';
import 'package:campus_arena/core/scoring/scoring_strategy.dart';
import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const strategy = FoosballScoringStrategy();

  final labels = ResultEntryLabels(
    setLabel: (n) => 'Set $n',
    addSetLabel: 'Add set',
    goalsLabel: 'Goals',
  );
  const youSide = ResultEntrySide(
    label: 'You',
    displayName: 'Mario Rossi',
    uids: ['you1'],
  );
  const opponentSide = ResultEntrySide(
    label: 'Opponent',
    displayName: 'Luigi Bianchi',
    uids: ['opp1'],
  );

  Future<List<MatchResult?>> pump(WidgetTester tester) async {
    final emitted = <MatchResult?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: strategy.getResultWidget(
            youSide: youSide,
            opponentSide: opponentSide,
            labels: labels,
            onResultChanged: emitted.add,
          ),
        ),
      ),
    );
    return emitted;
  }

  testWidgets('renders the header and a single goals row', (tester) async {
    await pump(tester);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Opponent'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    // Foosball is a single game — no per-set rows.
    expect(find.text('Set 1'), findsNothing);
    expect(find.text('Add set'), findsNothing);
  });

  testWidgets('emits null while the score is still a 0-0 tie', (tester) async {
    final emitted = await pump(tester);
    // Increment opponent goals, leaving your goals at 0 — a 0-1 is decisive,
    // so first drive it back to a tie to observe the null emission.
    await tester.tap(find.byIcon(Icons.add).first); // you: 1
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add).last); // opponent: 1 -> 1-1 tie
    await tester.pump();
    expect(emitted.last, isNull);
  });

  testWidgets('emits a validated, winner-first result once decisive', (
    tester,
  ) async {
    final emitted = await pump(tester);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byIcon(Icons.add).first); // you: 5
      await tester.pump();
    }
    await tester.tap(find.byIcon(Icons.add).last); // opponent: 1
    await tester.pump();

    final result = emitted.last;
    expect(result, isA<FoosballResult>());
    result as FoosballResult;
    expect(result.winnerIds, ['you1']);
    expect(result.goals, 5);
    expect(result.opponentGoals, 1);
    expect(strategy.validateResult(result).isValid, isTrue);
  });

  testWidgets('orients the winner to the opponent when they lead', (
    tester,
  ) async {
    final emitted = await pump(tester);
    await tester.tap(find.byIcon(Icons.add).first); // you: 1
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.add).last); // opponent: 3
      await tester.pump();
    }

    final result = emitted.last as FoosballResult;
    expect(result.winnerIds, ['opp1']);
    expect(result.goals, 3);
    expect(result.opponentGoals, 1);
  });

  testWidgets('the decrement is disabled at zero', (tester) async {
    await pump(tester);
    final removeButtons = tester
        .widgetList<IconButton>(find.widgetWithIcon(IconButton, Icons.remove))
        .toList();
    expect(removeButtons, hasLength(2));
    expect(removeButtons.every((b) => b.onPressed == null), isTrue);
  });
}
