import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/features/map/facility_ui.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

FacilityModel _facility({
  required double latitude,
  required double longitude,
}) => FacilityModel(
  facilityId: 'f',
  name: 'Table f',
  sportId: SportIds.pingPong,
  coordinates: Coordinates(latitude: latitude, longitude: longitude),
  qrCode: 'qr',
  fallbackCode: 'fb',
  isOutdoor: false,
  status: FacilityStatus.free,
  kingOfTableWins: 0,
  queueTailPosition: 0,
);

Future<AppLocalizations> _l10n(Locale locale) =>
    AppLocalizations.delegate.load(locale);

void main() {
  final center = MapDefaults.campusCenter;

  group('facilityDistanceMeters', () {
    test('is null when there is no user location', () {
      final facility = _facility(
        latitude: center.latitude,
        longitude: center.longitude,
      );
      expect(facilityDistanceMeters(facility, null), isNull);
    });

    test('is null when the facility coordinates are non-finite', () {
      final facility = _facility(latitude: double.nan, longitude: double.nan);
      expect(facilityDistanceMeters(facility, center), isNull);
    });

    test('measures the great-circle distance for valid inputs', () {
      final facility = _facility(
        latitude: center.latitude,
        longitude: center.longitude,
      );
      // Same point → zero.
      expect(facilityDistanceMeters(facility, center), closeTo(0, 0.5));

      // ~0.001° of latitude ≈ 111 m.
      final north = _facility(
        latitude: center.latitude + 0.001,
        longitude: center.longitude,
      );
      expect(facilityDistanceMeters(north, center), closeTo(111, 5));
    });

    test('orders nearer facilities below farther ones', () {
      final near = _facility(
        latitude: center.latitude + 0.0005,
        longitude: center.longitude,
      );
      final far = _facility(
        latitude: center.latitude + 0.005,
        longitude: center.longitude,
      );
      expect(
        facilityDistanceMeters(near, center),
        lessThan(facilityDistanceMeters(far, center)!),
      );
    });
  });

  group('formatDistance', () {
    testWidgets('renders metres under 1 km and kilometres above (en)', (
      tester,
    ) async {
      final l10n = await _l10n(const Locale('en'));
      expect(formatDistance(l10n, 40), '40 m');
      expect(formatDistance(l10n, 999), '999 m');
      expect(formatDistance(l10n, 1000), '1.0 km');
      expect(formatDistance(l10n, 1240), '1.2 km');
    });

    testWidgets('localises the decimal separator (it)', (tester) async {
      final l10n = await _l10n(const Locale('it'));
      expect(formatDistance(l10n, 40), '40 m');
      expect(formatDistance(l10n, 1240), '1,2 km');
    });
  });
}
