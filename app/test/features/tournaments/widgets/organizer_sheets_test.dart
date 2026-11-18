import 'package:campus_arena/core/bracket/bracket_engine.dart';
import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/features/tournaments/cubit/tournament_detail_state.dart';
import 'package:campus_arena/features/tournaments/widgets/organizer_sheets.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a button that opens [onOpen]'s sheet, recording its resolved value.
Future<void> _pumpOpener(
  WidgetTester tester,
  Future<void> Function(BuildContext context) onOpen,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => onOpen(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('showForfeitSheet', () {
    testWidgets('lists alive participants and returns the tapped uid', (
      tester,
    ) async {
      String? result;
      await _pumpOpener(tester, (context) async {
        result = await showForfeitSheet(
          context: context,
          alive: const [
            StandingEntry(uid: 'u1', name: 'Alice', eliminated: false),
            StandingEntry(uid: 'u2', name: 'Bob', eliminated: false),
          ],
        );
      });

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);

      await tester.tap(find.text('Bob'));
      await tester.pumpAndSettle();
      expect(result, 'u2');
    });

    testWidgets('shows the empty notice when nobody is alive', (tester) async {
      await _pumpOpener(tester, (context) async {
        await showForfeitSheet(context: context, alive: const []);
      });
      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('showAdvanceSheet', () {
    BracketSlot slot() => BracketSlot(
      round: 'final',
      index: 0,
      a: BracketSide(uid: 'u1'),
      b: BracketSide(uid: 'u2'),
    );

    testWidgets('picking a slot then a winner returns the AdvanceChoice', (
      tester,
    ) async {
      AdvanceChoice? result;
      await _pumpOpener(tester, (context) async {
        result = await showAdvanceSheet(
          context: context,
          playableSlots: [slot()],
          names: const {'u1': 'Alice', 'u2': 'Bob'},
        );
      });

      // First frame lists the slot; tap it to expand to the two players.
      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pumpAndSettle();

      // Now both players are shown with a trophy affordance; pick the winner.
      expect(find.byIcon(Icons.emoji_events), findsNWidgets(2));
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.winnerUid, 'u1');
      expect(result!.slot.round, 'final');
    });

    testWidgets('shows the empty notice with no playable slots', (
      tester,
    ) async {
      await _pumpOpener(tester, (context) async {
        await showAdvanceSheet(
          context: context,
          playableSlots: const [],
          names: const {},
        );
      });
      expect(find.byType(ListTile), findsNothing);
    });
  });
}
