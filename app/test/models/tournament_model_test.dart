import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_arena/models/tournament_model.dart';

void main() {
  group('TournamentModel tests', () {
    final now = DateTime.now();
    final nowTimestamp = Timestamp.fromDate(now);

    final rawMap = {
      'name': 'PoliPONG Summer Cup',
      'sportId': 'ping_pong',
      'facilityId': 'fac_1',
      'organizerId': 'uid_org',
      'maxParticipants': 16,
      'status': 'active',
      'bracket': {
        'round_1': ['match_1', 'match_2'],
        'round_2': ['match_3'],
      },
      'winnerUid': 'uid_winner',
      'eloMultiplier': 1.8,
      'registrationDeadline': nowTimestamp,
      'scheduledAt': nowTimestamp,
      'createdAt': nowTimestamp,
    };

    test('should parse correctly fromMap', () {
      final tournament = TournamentModel.fromMap(rawMap, 'tour_1');

      expect(tournament.tournamentId, 'tour_1');
      expect(tournament.name, 'PoliPONG Summer Cup');
      expect(tournament.sportId, 'ping_pong');
      expect(tournament.facilityId, 'fac_1');
      expect(tournament.organizerId, 'uid_org');
      expect(tournament.maxParticipants, 16);
      expect(tournament.status, 'active');
      expect(tournament.bracket, {
        'round_1': ['match_1', 'match_2'],
        'round_2': ['match_3'],
      });
      expect(tournament.winnerUid, 'uid_winner');
      expect(tournament.eloMultiplier, 1.8);
      expect(tournament.registrationDeadline, now);
      expect(tournament.scheduledAt, now);
      expect(tournament.createdAt, now);
    });

    test('should fallback to defaults in fromMap', () {
      final tournament = TournamentModel.fromMap(const {}, 'tour_1');

      expect(tournament.tournamentId, 'tour_1');
      expect(tournament.name, '');
      expect(tournament.bracket, isEmpty);
      expect(tournament.maxParticipants, 8);
      expect(tournament.status, 'registering');
      expect(tournament.eloMultiplier, 1.5);
    });

    test('should serialize correctly toMap', () {
      final tournament = TournamentModel(
        tournamentId: 'tour_1',
        name: 'PoliPONG Summer Cup',
        sportId: 'ping_pong',
        facilityId: 'fac_1',
        organizerId: 'uid_org',
        maxParticipants: 16,
        status: 'active',
        bracket: const {
          'round_1': ['match_1', 'match_2'],
        },
        winnerUid: 'uid_winner',
        eloMultiplier: 1.8,
        registrationDeadline: now,
        scheduledAt: now,
        createdAt: now,
      );

      final map = tournament.toMap();

      expect(map['name'], 'PoliPONG Summer Cup');
      expect(map['bracket'], {
        'round_1': ['match_1', 'match_2'],
      });
      expect(map['registrationDeadline'], isA<Timestamp>());
      expect((map['registrationDeadline'] as Timestamp).toDate(), now);
      expect(map['scheduledAt'], isA<Timestamp>());
      expect((map['scheduledAt'] as Timestamp).toDate(), now);
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), now);
    });

    test('should support copyWith', () {
      final tournament = TournamentModel(
        tournamentId: 'tour_1',
        name: 'PoliPONG Summer Cup',
        sportId: 'ping_pong',
        facilityId: 'fac_1',
        organizerId: 'uid_org',
        maxParticipants: 16,
        status: 'registering',
        bracket: const {},
        eloMultiplier: 1.5,
        registrationDeadline: now,
        scheduledAt: now,
        createdAt: now,
      );

      final updated = tournament.copyWith(
        status: 'seeded',
        winnerUid: 'winner',
      );
      expect(updated.status, 'seeded');
      expect(updated.winnerUid, 'winner');
      expect(updated.tournamentId, 'tour_1');
    });
  });

  group('TournamentParticipantModel tests', () {
    final rawMap = {'seed': 4, 'eliminated': true};

    test('should parse correctly fromMap', () {
      final participant = TournamentParticipantModel.fromMap(
        rawMap,
        'uid_player',
      );

      expect(participant.uid, 'uid_player');
      expect(participant.seed, 4);
      expect(participant.eliminated, true);
    });

    test('should serialize correctly toMap', () {
      const participant = TournamentParticipantModel(
        uid: 'uid_player',
        seed: 4,
        eliminated: true,
      );

      final map = participant.toMap();

      expect(map['seed'], 4);
      expect(map['eliminated'], true);
    });
  });
}
