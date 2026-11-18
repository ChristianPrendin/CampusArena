import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/chatbot/data/chatbot_tools_service.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/models/rating_model.dart';
import 'package:campus_arena/models/tournament_model.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:campus_arena/repositories/queue_repository.dart';
import 'package:campus_arena/repositories/rating_repository.dart';
import 'package:campus_arena/repositories/tournament_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFacilityRepository extends Mock implements FacilityRepository {}

class MockTournamentRepository extends Mock implements TournamentRepository {}

class MockQueueRepository extends Mock implements QueueRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

FacilityModel _facility(String id, {String status = FacilityStatus.free}) =>
    FacilityModel(
      facilityId: id,
      name: 'Table $id',
      sportId: SportIds.pingPong,
      coordinates: const Coordinates(latitude: 45.47, longitude: 9.22),
      qrCode: 'qr_$id',
      fallbackCode: 'FB$id',
      isOutdoor: false,
      status: status,
      kingOfTableWins: 0,
      queueTailPosition: 0,
    );

TournamentModel _tournament(String id) => TournamentModel(
  tournamentId: id,
  name: 'Spring Cup',
  sportId: SportIds.pingPong,
  facilityId: 'f1',
  organizerId: 'org1',
  maxParticipants: 8,
  status: 'registering',
  bracket: const {},
  eloMultiplier: 1.5,
  registrationDeadline: DateTime(2026, 7, 5),
  scheduledAt: DateTime(2026, 7, 6, 18),
  createdAt: DateTime(2026, 6, 30),
);

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  late MockFacilityRepository facilityRepository;
  late MockTournamentRepository tournamentRepository;
  late MockQueueRepository queueRepository;
  late MockRatingRepository ratingRepository;
  late ChatbotToolsService service;

  setUp(() {
    facilityRepository = MockFacilityRepository();
    tournamentRepository = MockTournamentRepository();
    queueRepository = MockQueueRepository();
    ratingRepository = MockRatingRepository();
    service = ChatbotToolsService(
      facilityRepository: facilityRepository,
      tournamentRepository: tournamentRepository,
      queueRepository: queueRepository,
      ratingRepository: ratingRepository,
    );
  });

  group('getEmptyTables', () {
    test('returns only free facilities enriched with queue length', () async {
      when(
        () => facilityRepository.getFacilitiesByStatus(
          FacilityStatus.free,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [_facility('f1'), _facility('f2')]);
      when(
        () => queueRepository.getQueueLength('f1'),
      ).thenAnswer((_) async => 2);
      when(
        () => queueRepository.getQueueLength('f2'),
      ).thenAnswer((_) async => 0);

      final result = await service.getEmptyTables();

      expect(result, hasLength(2));
      expect(result.every((f) => f.status == FacilityStatus.free), isTrue);
      expect(result.firstWhere((f) => f.facilityId == 'f1').queueLength, 2);
    });

    test('is bounded by maxResults via the repository limit', () async {
      when(
        () => facilityRepository.getFacilitiesByStatus(
          FacilityStatus.free,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);

      await service.getEmptyTables();

      verify(
        () => facilityRepository.getFacilitiesByStatus(
          FacilityStatus.free,
          limit: ChatbotToolsService.maxResults,
        ),
      ).called(1);
    });
  });

  group('getTournamentsToday', () {
    test('enriches each tournament with its participant count', () async {
      when(
        () => tournamentRepository.getTournamentsInWindow(
          any(),
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [_tournament('t1')]);
      when(
        () => tournamentRepository.getParticipantCount('t1'),
      ).thenAnswer((_) async => 3);

      final result = await service.getTournamentsToday(
        now: DateTime(2026, 7, 6, 12),
      );

      expect(result, hasLength(1));
      expect(result.single.participantCount, 3);
      expect(result.single.maxParticipants, 8);
    });

    test('returns an empty list when no tournaments are scheduled', () async {
      when(
        () => tournamentRepository.getTournamentsInWindow(
          any(),
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);

      final result = await service.getTournamentsToday();

      expect(result, isEmpty);
    });
  });

  group('getUserQueuePosition', () {
    test('resolves facility name for the queued entry', () async {
      when(() => queueRepository.getUserQueueEntry('u1')).thenAnswer(
        (_) async => QueueEntryModel(
          uid: 'u1',
          facilityId: 'f1',
          position: 2,
          joinedAt: DateTime(2026, 7, 6),
        ),
      );
      when(
        () => facilityRepository.getFacility('f1'),
      ).thenAnswer((_) async => _facility('f1'));

      final result = await service.getUserQueuePosition('u1');

      expect(result, isNotNull);
      expect(result!.facilityName, 'Table f1');
      expect(result.position, 2);
    });

    test('returns null when the user is not queued anywhere', () async {
      when(
        () => queueRepository.getUserQueueEntry('u1'),
      ).thenAnswer((_) async => null);

      expect(await service.getUserQueuePosition('u1'), isNull);
    });
  });

  group('getUserEloAndRank', () {
    test('returns elo and rank when a rating exists', () async {
      when(
        () => ratingRepository.getUserRating('u1', SportIds.pingPong),
      ).thenAnswer(
        (_) async => RatingModel(
          ratingId: 'ping_pong_u1',
          ownerType: OwnerType.user,
          ownerId: 'u1',
          sportId: SportIds.pingPong,
          elo: 1350,
          matchesPlayed: 12,
          lastMatchAt: DateTime(2026, 7, 1),
        ),
      );
      when(
        () =>
            ratingRepository.getUserRank(sportId: SportIds.pingPong, elo: 1350),
      ).thenAnswer((_) async => 4);

      final result = await service.getUserEloAndRank(
        uid: 'u1',
        sportId: SportIds.pingPong,
      );

      expect(result, isNotNull);
      expect(result!.elo, 1350);
      expect(result.rank, 4);
      expect(result.matchesPlayed, 12);
    });

    test('returns null when the user has no rating for that sport', () async {
      when(
        () => ratingRepository.getUserRating('u1', SportIds.pingPong),
      ).thenAnswer((_) async => null);

      final result = await service.getUserEloAndRank(
        uid: 'u1',
        sportId: SportIds.pingPong,
      );

      expect(result, isNull);
    });
  });

  test('explainHowEloWorks returns fixed text with no repository call', () {
    final explainer = service.explainHowEloWorks();

    expect(explainer, contains('1200'));
    verifyZeroInteractions(facilityRepository);
    verifyZeroInteractions(tournamentRepository);
    verifyZeroInteractions(queueRepository);
    verifyZeroInteractions(ratingRepository);
  });
}
