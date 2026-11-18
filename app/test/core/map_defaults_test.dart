import 'package:campus_arena/core/constants.dart';
import 'package:flutter_test/flutter_test.dart';

/// The map's crash-avoidance contract is that its camera bounds are *finite*
/// (flutter_map clamps every zoom against them, so a transient NaN/Infinity
/// from a fast pinch resolves to a bound instead of reaching the projection),
/// and that the campus center is a valid coordinate. Assert those invariants
/// on [MapDefaults] directly rather than re-simulating the library's internals.
void main() {
  test('zoom bounds are finite and ordered around the initial zoom', () {
    expect(MapDefaults.minZoom.isFinite, isTrue);
    expect(MapDefaults.maxZoom.isFinite, isTrue);
    expect(MapDefaults.minZoom, lessThan(MapDefaults.maxZoom));
    expect(MapDefaults.initialZoom, greaterThanOrEqualTo(MapDefaults.minZoom));
    expect(MapDefaults.initialZoom, lessThanOrEqualTo(MapDefaults.maxZoom));
  });

  test('campus center is a finite, in-range coordinate', () {
    expect(MapDefaults.campusCenter.latitude.isFinite, isTrue);
    expect(MapDefaults.campusCenter.longitude.isFinite, isTrue);
    expect(MapDefaults.campusCenter.latitude.abs(), lessThanOrEqualTo(90));
    expect(MapDefaults.campusCenter.longitude.abs(), lessThanOrEqualTo(180));
  });
}
