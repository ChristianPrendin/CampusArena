import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_arena/models/facility_model.dart';

void main() {
  group('Coordinates tests', () {
    test('equality and values check', () {
      const c1 = Coordinates(latitude: 45.4773, longitude: 9.2275);
      const c2 = Coordinates(latitude: 45.4773, longitude: 9.2275);
      const c3 = Coordinates(latitude: 45.0, longitude: 9.0);

      expect(c1, c2);
      expect(c1, isNot(c3));
    });
  });

  group('FacilityModel tests', () {
    final rawMap = {
      'name': 'Table 1 - Leonardo',
      'sportId': 'ping_pong',
      'coordinates': const GeoPoint(45.4773, 9.2275),
      'qrCode': 'qr_pingpong_1',
      'fallbackCode': 'PP1LEO',
      'isOutdoor': true,
      'status': 'occupied',
      'currentMatchId': 'match_abc',
      'kingOfTableUid': 'uid_king',
      'kingOfTableWins': 5,
      'queueTailPosition': 10,
    };

    test('should parse correctly fromMap', () {
      final facility = FacilityModel.fromMap(rawMap, 'fac_1');

      expect(facility.facilityId, 'fac_1');
      expect(facility.name, 'Table 1 - Leonardo');
      expect(facility.sportId, 'ping_pong');
      expect(facility.coordinates.latitude, 45.4773);
      expect(facility.coordinates.longitude, 9.2275);
      expect(facility.qrCode, 'qr_pingpong_1');
      expect(facility.fallbackCode, 'PP1LEO');
      expect(facility.isOutdoor, true);
      expect(facility.status, 'occupied');
      expect(facility.currentMatchId, 'match_abc');
      expect(facility.kingOfTableUid, 'uid_king');
      expect(facility.kingOfTableWins, 5);
      expect(facility.queueTailPosition, 10);
    });

    test('should fallback to defaults in fromMap', () {
      final facility = FacilityModel.fromMap(const {}, 'fac_1');

      expect(facility.facilityId, 'fac_1');
      expect(facility.name, '');
      expect(facility.coordinates.latitude, 0.0);
      expect(facility.coordinates.longitude, 0.0);
      expect(facility.status, 'free');
      expect(facility.kingOfTableWins, 0);
      expect(facility.queueTailPosition, 0);
    });

    test('should serialize correctly toMap', () {
      const facility = FacilityModel(
        facilityId: 'fac_1',
        name: 'Table 1 - Leonardo',
        sportId: 'ping_pong',
        coordinates: Coordinates(latitude: 45.4773, longitude: 9.2275),
        qrCode: 'qr_pingpong_1',
        fallbackCode: 'PP1LEO',
        isOutdoor: true,
        status: 'occupied',
        currentMatchId: 'match_abc',
        kingOfTableUid: 'uid_king',
        kingOfTableWins: 5,
        queueTailPosition: 10,
      );

      final map = facility.toMap();

      expect(map['name'], 'Table 1 - Leonardo');
      expect(map['coordinates'], isA<GeoPoint>());
      expect((map['coordinates'] as GeoPoint).latitude, 45.4773);
      expect((map['coordinates'] as GeoPoint).longitude, 9.2275);
      expect(map['status'], 'occupied');
      expect(map['queueTailPosition'], 10);
    });

    test('should support copyWith', () {
      const facility = FacilityModel(
        facilityId: 'fac_1',
        name: 'Table 1 - Leonardo',
        sportId: 'ping_pong',
        coordinates: Coordinates(latitude: 45.4773, longitude: 9.2275),
        qrCode: 'qr_pingpong_1',
        fallbackCode: 'PP1LEO',
        isOutdoor: true,
        status: 'free',
        kingOfTableWins: 0,
        queueTailPosition: 0,
      );

      final updated = facility.copyWith(
        status: 'occupied',
        kingOfTableWins: 2,
        queueTailPosition: 1,
      );
      expect(updated.status, 'occupied');
      expect(updated.kingOfTableWins, 2);
      expect(updated.queueTailPosition, 1);
      expect(updated.facilityId, 'fac_1');
    });
  });

  group('QueueEntryModel tests', () {
    final now = DateTime.now();
    final nowTimestamp = Timestamp.fromDate(now);

    final rawMap = {'position': 2, 'joinedAt': nowTimestamp};

    test('should parse correctly fromMap', () {
      final entry = QueueEntryModel.fromMap(rawMap, 'uid_player', 'fac_1');

      expect(entry.uid, 'uid_player');
      expect(entry.facilityId, 'fac_1');
      expect(entry.position, 2);
      expect(entry.joinedAt, now);
    });

    test('should serialize correctly toMap', () {
      final entry = QueueEntryModel(
        uid: 'uid_player',
        facilityId: 'fac_1',
        position: 2,
        joinedAt: now,
      );

      final map = entry.toMap();

      expect(map['userId'], 'uid_player');
      expect(map['position'], 2);
      expect(map['joinedAt'], isA<Timestamp>());
      expect((map['joinedAt'] as Timestamp).toDate(), now);
    });
  });
}
