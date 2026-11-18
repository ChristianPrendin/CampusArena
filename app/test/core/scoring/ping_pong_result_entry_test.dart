import 'package:campus_arena/core/scoring/ping_pong_scoring_strategy.dart';
import 'package:campus_arena/core/scoring/scoring_strategy.dart';
import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/models/match_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const strategy = PingPongScoringStrategy();

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

  testWidgets('renders header, first set row, and Add set', (tester) async {
    await pump(tester);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Opponent'), findsOneWidget);
    expect(find.text('Set 1'), findsOneWidget);
    expect(find.text('Add set'), findsOneWidget);
  });

  testWidgets('Add set appends a second set row', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Add set'));
    await tester.pump();
    expect(find.text('Set 2'), findsOneWidget);
  });

  testWidgets('emits null while the score is not a legal result', (
    tester,
  ) async {
    final emitted = await pump(tester);
    // Your increment is the first add button (opponent's is the second).
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    expect(emitted, isNotEmpty);
    expect(emitted.last, isNull); // 1-0 is not yet a decisive set
  });

  testWidgets('emits a validated, winner-first result once decisive', (
    tester,
  ) async {
    final emitted = await pump(tester);
    for (var i = 0; i < 11; i++) {
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();
    }
    final result = emitted.last;
    expect(result, isA<PingPongResult>());
    result as PingPongResult;
    expect(result.winnerIds, ['you1']);
    expect(result.sets, [11]);
    expect(result.opponentSets, [0]);
  });
}
