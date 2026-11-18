import 'package:campus_arena/features/chatbot/data/tool_results.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FacilityToolResult is value-equal by its fields', () {
    const a = FacilityToolResult(
      facilityId: 'f1',
      name: 'Table 1',
      sportId: 'ping_pong',
      status: 'free',
      queueLength: 0,
    );
    const b = FacilityToolResult(
      facilityId: 'f1',
      name: 'Table 1',
      sportId: 'ping_pong',
      status: 'free',
      queueLength: 0,
    );
    const c = FacilityToolResult(
      facilityId: 'f2',
      name: 'Table 2',
      sportId: 'foosball',
      status: 'busy',
      queueLength: 3,
    );

    expect(a, b);
    expect(a, isNot(c));
    expect(a.props, [a.facilityId, a.name, a.sportId, a.status, a.queueLength]);
  });

  test('TournamentToolResult is value-equal by its fields', () {
    final scheduledAt = DateTime(2026, 7, 10, 18);
    final a = TournamentToolResult(
      tournamentId: 't1',
      name: 'Spring Cup',
      sportId: 'ping_pong',
      status: 'open',
      scheduledAt: scheduledAt,
      participantCount: 4,
      maxParticipants: 8,
    );
    final b = TournamentToolResult(
      tournamentId: 't1',
      name: 'Spring Cup',
      sportId: 'ping_pong',
      status: 'open',
      scheduledAt: scheduledAt,
      participantCount: 4,
      maxParticipants: 8,
    );

    expect(a, b);
    expect(a.props, contains(scheduledAt));
    expect(a.props, contains('Spring Cup'));
  });

  test('QueuePositionToolResult is value-equal by its fields', () {
    const a = QueuePositionToolResult(
      facilityId: 'f1',
      facilityName: 'Table 2',
      position: 3,
    );
    const b = QueuePositionToolResult(
      facilityId: 'f1',
      facilityName: 'Table 2',
      position: 3,
    );
    expect(a, b);
    expect(a.props, ['f1', 'Table 2', 3]);
  });

  test('EloRankToolResult keeps a null rank distinct from a ranked one', () {
    const unranked = EloRankToolResult(
      sportId: 'ping_pong',
      elo: 1200,
      rank: null,
      matchesPlayed: 0,
    );
    const ranked = EloRankToolResult(
      sportId: 'ping_pong',
      elo: 1200,
      rank: 1,
      matchesPlayed: 0,
    );
    expect(unranked, isNot(ranked));
    expect(unranked.props, ['ping_pong', 1200, null, 0]);
  });
}
