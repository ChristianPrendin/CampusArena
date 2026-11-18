import 'dart:async';

import 'package:campus_arena/core/constants.dart';
import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/features/auth/cubit/auth_cubit.dart';
import 'package:campus_arena/features/map/map_screen.dart';
import 'package:campus_arena/features/map/user_location_service.dart';
import 'package:campus_arena/features/map/widgets/facility_list.dart';
import 'package:campus_arena/features/map/widgets/facility_marker.dart';
import 'package:campus_arena/features/queue/widgets/queue_section.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/repositories/facility_repository.dart';
import 'package:campus_arena/repositories/match_repository.dart';
import 'package:campus_arena/repositories/user_repository.dart';
import 'package:campus_arena/repositories/weather_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/auth_test_helpers.dart';
import '../../helpers/fake_tile_provider.dart';

class MockFacilityRepository extends Mock implements FacilityRepository {}

class MockMatchRepository extends Mock implements MatchRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockWeatherRepository extends Mock implements WeatherRepository {}

class MockUserLocationService extends Mock implements UserLocationService {}

FacilityModel _facility(
  String id, {
  String status = FacilityStatus.free,
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
  status: status,
  kingOfTableWins: 0,
  queueTailPosition: 0,
);

/// One of each status, clustered around the campus centre so all markers are
/// inside the initial viewport.
final _facilities = [
  _facility('free1', latOffset: 0.0004),
  _facility('busy1', status: FacilityStatus.occupied, lngOffset: 0.0006),
  _facility('queued1', status: FacilityStatus.queued, latOffset: -0.0004),
];

/// Regression fixture: a malformed seeded facility (e.g. a NaN written by a
/// buggy seeding script) — flutter_map's Mercator projection throws on any
/// non-finite `LatLng`, so this must never reach a `Marker`.
final _facilityWithBadCoordinates = FacilityModel(
  facilityId: 'bad1',
  name: 'Table bad1',
  sportId: SportIds.pingPong,
  coordinates: const Coordinates(latitude: double.nan, longitude: double.nan),
  qrCode: 'qr-bad1',
  fallbackCode: 'fb-bad1',
  isOutdoor: false,
  status: FacilityStatus.free,
  kingOfTableWins: 0,
  queueTailPosition: 0,
);

void main() {
  late MockFacilityRepository facilityRepository;
  late MockMatchRepository matchRepository;
  late MockUserRepository userRepository;
  late MockWeatherRepository weatherRepository;
  late MockUserLocationService userLocationService;

  setUp(() {
    facilityRepository = MockFacilityRepository();
    matchRepository = MockMatchRepository();
    userRepository = MockUserRepository();
    weatherRepository = MockWeatherRepository();
    userLocationService = MockUserLocationService();
    // Location is unavailable by default; tests opt in to a position.
    when(
      () => userLocationService.watchPosition(),
    ).thenAnswer((_) => const Stream<LatLng>.empty());
    when(
      () => userLocationService.getCurrentPosition(),
    ).thenAnswer((_) async => null);
  });

  void stubFacilities(Stream<List<FacilityModel>> stream) {
    when(() => facilityRepository.watchFacilities()).thenAnswer((_) => stream);
  }

  // Unauthenticated on purpose: the detail sheet's QueueSection reads the uid
  // from this cubit, and a signed-in uid would make it construct a real
  // Firestore-backed QueueCubit. With no uid it renders nothing, keeping these
  // tests Firebase-free; the signed-in rendering is covered by
  // queue_section_test.dart against mocked repositories.
  Widget wrap({Locale? locale}) {
    final authCubit = unauthenticatedAuthCubit().cubit;
    addTearDown(authCubit.close);
    return BlocProvider<AuthCubit>.value(
      value: authCubit,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MapScreen(
          facilityRepository: facilityRepository,
          matchRepository: matchRepository,
          userRepository: userRepository,
          weatherRepository: weatherRepository,
          userLocationService: userLocationService,
          tileProvider: FakeTileProvider(),
        ),
      ),
    );
  }

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  void useTabletSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// The 40px inner pin of a marker (the outer 48px pin is the outline).
  Color? pinBodyColor(WidgetTester tester, String facilityId) {
    final icons = tester.widgetList<Icon>(
      find.descendant(
        of: find.byKey(ValueKey('facility_marker_$facilityId')),
        matching: find.byIcon(Icons.location_pin),
      ),
    );
    return icons.firstWhere((icon) => icon.size == 40).color;
  }

  testWidgets(
    'bounds zoom so a gesture-driven NaN/Infinite zoom clamps to a finite value',
    (tester) async {
      usePhoneSurface(tester);
      stubFacilities(Stream.value(_facilities));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final options = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options;
      expect(options.minZoom, MapDefaults.minZoom);
      expect(options.maxZoom, MapDefaults.maxZoom);
      expect(options.minZoom!.isFinite, isTrue);
      expect(options.maxZoom!.isFinite, isTrue);
    },
  );

  testWidgets('renders one status-coloured marker per facility', (
    tester,
  ) async {
    usePhoneSurface(tester);
    stubFacilities(Stream.value(_facilities));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byType(FacilityMarker), findsNWidgets(3));

    final colors = Theme.of(tester.element(find.byType(MapScreen))).colorScheme;
    expect(pinBodyColor(tester, 'free1'), colors.primary);
    expect(pinBodyColor(tester, 'busy1'), colors.error);
    expect(pinBodyColor(tester, 'queued1'), colors.tertiary);
  });

  testWidgets('shows the legend and the OSM attribution', (tester) async {
    usePhoneSurface(tester);
    stubFacilities(Stream.value(_facilities));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Occupied'), findsOneWidget);
    expect(find.text('Queued'), findsOneWidget);

    // Attribution is a persistent pill above the legend, bottom-left.
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
  });

  testWidgets('shows a progress indicator while the stream is pending', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final controller = StreamController<List<FacilityModel>>();
    addTearDown(controller.close);
    stubFacilities(controller.stream);

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    controller.add(_facilities);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(FacilityMarker), findsNWidgets(3));
  });

  testWidgets('shows the error state and recovers on retry', (tester) async {
    usePhoneSurface(tester);
    var calls = 0;
    when(() => facilityRepository.watchFacilities()).thenAnswer((_) {
      calls++;
      if (calls == 1) return Stream.error(Exception('firestore down'));
      return Stream.value(_facilities);
    });

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load facilities."), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load facilities."), findsNothing);
    expect(find.byType(FacilityMarker), findsNWidgets(3));
  });

  testWidgets(
    'skips a facility with non-finite coordinates instead of crashing the map',
    (tester) async {
      usePhoneSurface(tester);
      stubFacilities(
        Stream.value([..._facilities, _facilityWithBadCoordinates]),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FacilityMarker), findsNWidgets(3));
    },
  );

  testWidgets(
    'still lists a facility with invalid coordinates in the split view',
    (tester) async {
      useTabletSurface(tester);
      stubFacilities(
        Stream.value([..._facilities, _facilityWithBadCoordinates]),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FacilityMarker), findsNWidgets(3));
      expect(find.text('Table bad1'), findsOneWidget);
    },
  );

  testWidgets('shows the empty state when there are no facilities', (
    tester,
  ) async {
    usePhoneSurface(tester);
    stubFacilities(Stream.value(const []));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('No facilities on campus yet.'), findsOneWidget);
    expect(find.byType(FacilityMarker), findsNothing);
  });

  testWidgets('tapping a marker opens the detail sheet with the disclaimer', (
    tester,
  ) async {
    usePhoneSurface(tester);
    stubFacilities(Stream.value(_facilities));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('facility_marker_free1')));
    await tester.pumpAndSettle();

    expect(find.text('Table free1'), findsOneWidget);
    expect(
      find.text(
        'Based on app activity only — the table may be in use by non-app '
        'players. Not a reservation.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('detail sheet wires the queue section to the tapped facility', (
    tester,
  ) async {
    usePhoneSurface(tester);
    stubFacilities(Stream.value(_facilities));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('facility_marker_free1')));
    await tester.pumpAndSettle();

    final section = tester.widget<QueueSection>(find.byType(QueueSection));
    expect(section.facilityId, 'free1');
  });

  testWidgets('phone width shows the map without the side list', (
    tester,
  ) async {
    usePhoneSurface(tester);
    stubFacilities(Stream.value(_facilities));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(FacilityList), findsNothing);
  });

  testWidgets('phone toggle switches between the map and the list', (
    tester,
  ) async {
    usePhoneSurface(tester);
    stubFacilities(Stream.value(_facilities));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Defaults to the map.
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(FacilityList), findsNothing);

    // Switch to the list.
    await tester.tap(find.byKey(const ValueKey('map_view_toggle_list')));
    await tester.pumpAndSettle();
    expect(find.byType(FacilityList), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);

    // Switch back to the map.
    await tester.tap(find.byKey(const ValueKey('map_view_toggle_map')));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(FacilityList), findsNothing);
  });

  testWidgets('phone list-mode row taps open the detail sheet', (tester) async {
    usePhoneSurface(tester);
    stubFacilities(Stream.value(_facilities));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('map_view_toggle_list')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Table busy1'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Based on app activity only — the table may be in use by non-app '
        'players. Not a reservation.',
      ),
      findsWidgets,
    );
  });

  testWidgets('≥600dp shows the split view and list taps open the sheet', (
    tester,
  ) async {
    useTabletSurface(tester);
    stubFacilities(Stream.value(_facilities));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(FacilityList), findsOneWidget);
    expect(find.text('Table busy1'), findsOneWidget);

    await tester.tap(find.text('Table busy1'));
    await tester.pumpAndSettle();

    // Sheet copy of the name plus the list row behind it.
    expect(find.text('Table busy1'), findsNWidgets(2));
    expect(
      find.text(
        'Based on app activity only — the table may be in use by non-app '
        'players. Not a reservation.',
      ),
      findsWidgets,
    );
  });

  testWidgets('renders the Italian legend and status labels', (tester) async {
    useTabletSurface(tester);
    stubFacilities(Stream.value(_facilities));

    await tester.pumpWidget(wrap(locale: const Locale('it')));
    await tester.pumpAndSettle();

    expect(find.text('Libero'), findsNWidgets(2)); // legend + list chip
    expect(find.text('Occupato'), findsNWidgets(2));
    expect(find.text('In coda'), findsNWidgets(2));

    expect(find.text('© Contributori di OpenStreetMap'), findsOneWidget);
  });

  testWidgets('shows the user-location dot when a position arrives', (
    tester,
  ) async {
    usePhoneSurface(tester);
    stubFacilities(Stream.value(_facilities));
    when(() => userLocationService.watchPosition()).thenAnswer(
      (_) => Stream.value(
        LatLng(
          MapDefaults.campusCenter.latitude + 0.0002,
          MapDefaults.campusCenter.longitude,
        ),
      ),
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('user_location_dot')), findsOneWidget);
  });

  testWidgets('hides the user-location dot when location is unavailable', (
    tester,
  ) async {
    usePhoneSurface(tester);
    stubFacilities(Stream.value(_facilities));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('user_location_dot')), findsNothing);
  });

  testWidgets('recenter button fetches the position and shows the dot', (
    tester,
  ) async {
    usePhoneSurface(tester);
    stubFacilities(Stream.value(_facilities));
    when(
      () => userLocationService.getCurrentPosition(),
    ).thenAnswer((_) async => MapDefaults.campusCenter);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('user_location_dot')), findsNothing);

    await tester.tap(find.byIcon(Icons.my_location));
    await tester.pumpAndSettle();

    verify(() => userLocationService.getCurrentPosition()).called(1);
    expect(find.byKey(const ValueKey('user_location_dot')), findsOneWidget);
  });

  testWidgets('recenter shows a snackbar when location is unavailable', (
    tester,
  ) async {
    usePhoneSurface(tester);
    stubFacilities(Stream.value(_facilities));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.my_location));
    await tester.pumpAndSettle();

    expect(find.text('Location unavailable.'), findsOneWidget);
    expect(find.byKey(const ValueKey('user_location_dot')), findsNothing);
  });

  testWidgets('tiles use a debounced update transformer, not the default', (
    tester,
  ) async {
    // Guards the fast-zoom fix: the default (ignoreTapEvents) reloads tiles on
    // every intermediate zoom frame, flooding the cached provider and freezing
    // a real device on a fast pinch zoom-out.
    usePhoneSurface(tester);
    stubFacilities(Stream.value(_facilities));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(
      tileLayer.tileUpdateTransformer,
      isNot(same(TileUpdateTransformers.ignoreTapEvents)),
    );
  });
}
