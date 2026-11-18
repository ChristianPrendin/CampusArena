import 'dart:async';

import 'package:campus_arena/features/weather/cubit/weather_cubit.dart';
import 'package:campus_arena/features/weather/widgets/weather_snippet.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/repositories/weather_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWeatherRepository extends Mock implements WeatherRepository {}

const _coords = Coordinates(latitude: 45.503, longitude: 9.156);

const _snapshot = WeatherSnapshot(
  temperatureC: 19.2,
  precipitationMm: 0.0,
  windSpeedKmh: 8.4,
  weatherCode: 2,
);

void main() {
  late MockWeatherRepository repository;
  late WeatherCubit cubit;

  setUp(() {
    repository = MockWeatherRepository();
    cubit = WeatherCubit(repository: repository);
  });

  tearDown(() => cubit.close());

  Widget wrap({bool isOutdoor = true}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: WeatherSnippet(
          coordinates: _coords,
          isOutdoor: isOutdoor,
          cubit: cubit,
        ),
      ),
    );
  }

  void stubCurrent() {
    when(
      () => repository.getCurrentWeather(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) async => _snapshot);
  }

  testWidgets('renders temperature, precipitation and wind when loaded', (
    tester,
  ) async {
    stubCurrent();

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Weather'), findsOneWidget);
    expect(find.text('19°'), findsOneWidget);
    expect(find.text('0 mm'), findsOneWidget);
    expect(find.text('8 km/h'), findsOneWidget);
  });

  testWidgets('renders nothing for an indoor facility', (tester) async {
    await tester.pumpWidget(wrap(isOutdoor: false));

    expect(find.text('Weather'), findsNothing);
    expect(find.byType(SizedBox), findsOneWidget);
    verifyNever(
      () => repository.getCurrentWeather(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    );
  });

  testWidgets('shows a progress indicator while loading', (tester) async {
    final gate = Completer<WeatherSnapshot>();
    when(
      () => repository.getCurrentWeather(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) => gate.future);

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete(_snapshot);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('19°'), findsOneWidget);
  });

  testWidgets('shows the error state and retries on tap', (tester) async {
    var calls = 0;
    when(
      () => repository.getCurrentWeather(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw const WeatherException('HTTP 500');
      return _snapshot;
    });

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Weather unavailable'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('19°'), findsOneWidget);
    expect(find.text('Weather unavailable'), findsNothing);
  });
}
