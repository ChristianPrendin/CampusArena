import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/features/chatbot/data/tool_results.dart';
import 'package:campus_arena/features/chatbot/widgets/tournament_card.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TournamentToolResult _tournament({
  String id = 't1',
  String name = 'Spring Cup',
  String sportId = SportIds.pingPong,
  String status = 'open',
  int participants = 4,
  int max = 8,
}) => TournamentToolResult(
  tournamentId: id,
  name: name,
  sportId: sportId,
  status: status,
  scheduledAt: DateTime(2026, 7, 10, 18, 30),
  participantCount: participants,
  maxParticipants: max,
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('renders each tournament with its name and fill ratio', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TournamentCard(
          tournaments: [
            _tournament(),
            _tournament(id: 't2', name: 'Autumn Open', participants: 8, max: 8),
          ],
        ),
      ),
    );

    expect(find.text('Spring Cup'), findsOneWidget);
    expect(find.text('Autumn Open'), findsOneWidget);
    expect(find.textContaining('4/8'), findsOneWidget);
    expect(find.textContaining('8/8'), findsOneWidget);
  });

  testWidgets('uses the sport-specific icon', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TournamentCard(
          tournaments: [
            _tournament(sportId: SportIds.pingPong),
            _tournament(id: 't2', sportId: SportIds.foosball),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.sports_tennis), findsOneWidget);
    expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
  });

  testWidgets('shows no View button when onView is null', (tester) async {
    await tester.pumpWidget(
      _wrap(TournamentCard(tournaments: [_tournament()])),
    );
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('fires onView with the tournament id when tapped', (
    tester,
  ) async {
    String? viewed;
    await tester.pumpWidget(
      _wrap(
        TournamentCard(
          tournaments: [_tournament(id: 'abc')],
          onView: (id) => viewed = id,
        ),
      ),
    );

    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(viewed, 'abc');
  });
}
