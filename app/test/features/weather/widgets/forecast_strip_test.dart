import 'package:campus_arena/features/weather/cubit/weather_cubit.dart';
import 'package:campus_arena/features/weather/widgets/forecast_strip.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/repositories/weather_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWeatherRepository extends Mock implements WeatherRepository {}

const _coords = Coordinates(latitude: 45.503, longitude: 9.156);

final _scheduledAt = DateTime(2026, 7, 4, 15);

final _forecast = [
  for (var i = 0; i < 4; i++)
    ForecastHour(
      time: DateTime(2026, 7, 4, 15 + i),
      temperatureC: 20.0 + i,
      precipitationMm: 0.0,
      windSpeedKmh: 10.0,
      weatherCode: 1,
    ),
];

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
        body: ForecastStrip(
          coordinates: _coords,
          isOutdoor: isOutdoor,
          scheduledAt: _scheduledAt,
          cubit: cubit,
        ),
      ),
    );
  }

  testWidgets('renders one column per forecast hour for the timeslot', (
    tester,
  ) async {
    when(
      () => repository.getHourlyForecast(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        start: any(named: 'start'),
      ),
    ).thenAnswer((_) async => _forecast);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('FORECAST'), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
    expect(find.text('18:00'), findsOneWidget);
    expect(find.text('20°'), findsOneWidget);
    expect(find.text('23°'), findsOneWidget);
    verify(
      () => repository.getHourlyForecast(
        latitude: _coords.latitude,
        longitude: _coords.longitude,
        start: _scheduledAt,
      ),
    ).called(1);
  });

  testWidgets('renders nothing for an indoor facility', (tester) async {
    await tester.pumpWidget(wrap(isOutdoor: false));

    expect(find.text('FORECAST'), findsNothing);
    verifyNever(
      () => repository.getHourlyForecast(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        start: any(named: 'start'),
      ),
    );
  });

  testWidgets('shows the error state when the forecast fails', (tester) async {
    when(
      () => repository.getHourlyForecast(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        start: any(named: 'start'),
      ),
    ).thenThrow(const WeatherException('HTTP 500'));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Weather unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
