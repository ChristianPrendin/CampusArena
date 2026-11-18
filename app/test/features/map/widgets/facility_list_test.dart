import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/features/map/widgets/facility_list.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

FacilityModel _facility(
  String id, {
  double latOffset = 0,
  double lngOffset = 0,
}) => FacilityModel(
  facilityId: id,
  name: 'Table $id',
  sportId: SportIds.pingPong,
  coordinates: Coordinates(
    latitude: MapDefaults.campusCenter.latitude + latOffset,
    longitude: MapDefaults.campusCenter.longitude + lngOffset,
  ),
  qrCode: 'qr-$id',
  fallbackCode: 'fb-$id',
  isOutdoor: false,
  status: FacilityStatus.free,
  kingOfTableWins: 0,
  queueTailPosition: 0,
);

void main() {
  // Deliberately out of proximity order: far, near, mid.
  final facilities = [
    _facility('far', latOffset: 0.005),
    _facility('near', latOffset: 0.0005),
    _facility('mid', latOffset: 0.002),
  ];

  Widget wrap({LatLng? userLocation}) => MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: FacilityList(
        facilities: facilities,
        onFacilityTap: (_) {},
        userLocation: userLocation,
      ),
    ),
  );

  testWidgets('without a location: no header, no distances, incoming order', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Sorted by proximity'), findsNothing);
    // No distance readouts (the only digit-bearing text on a row).
    expect(find.textContaining(RegExp(r'\d')), findsNothing);

    // Incoming order preserved: far before near.
    final farTop = tester.getTopLeft(find.text('Table far')).dy;
    final nearTop = tester.getTopLeft(find.text('Table near')).dy;
    expect(farTop, lessThan(nearTop));

    // Disclaimer should be rendered at the bottom
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.textContaining('Based on app activity only'), findsOneWidget);
  });

  testWidgets('with a location: header shown and rows sorted nearest-first', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(userLocation: MapDefaults.campusCenter));
    await tester.pumpAndSettle();

    expect(find.text('Sorted by proximity'), findsOneWidget);

    final nearTop = tester.getTopLeft(find.text('Table near')).dy;
    final midTop = tester.getTopLeft(find.text('Table mid')).dy;
    final farTop = tester.getTopLeft(find.text('Table far')).dy;
    expect(nearTop, lessThan(midTop));
    expect(midTop, lessThan(farTop));

    // Each row carries a distance readout (digit-bearing text).
    expect(find.textContaining(RegExp(r'\d')), findsWidgets);
  });
}
