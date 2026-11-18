import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/features/weather/cubit/weather_cubit.dart';
import 'package:campus_arena/features/weather/cubit/weather_state.dart';
import 'package:campus_arena/models/facility_model.dart';
import 'package:campus_arena/repositories/weather_repository.dart';
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

  setUp(() {
    repository = MockWeatherRepository();
  });

  void stubCurrent() {
    when(
      () => repository.getCurrentWeather(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) async => _snapshot);
  }

  void stubForecast() {
    when(
      () => repository.getHourlyForecast(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        start: any(named: 'start'),
      ),
    ).thenAnswer((_) async => _forecast);
  }

  group('loadCurrent', () {
    blocTest<WeatherCubit, WeatherState>(
      'emits loading then ready with the fetched snapshot',
      build: () {
        stubCurrent();
        return WeatherCubit(repository: repository);
      },
      act: (cubit) => cubit.loadCurrent(_coords),
      expect: () => const [
        WeatherState(currentStatus: WeatherStatus.loading),
        WeatherState(currentStatus: WeatherStatus.ready, current: _snapshot),
      ],
    );

    blocTest<WeatherCubit, WeatherState>(
      'serves a fresh cache entry without refetching',
      build: () {
        stubCurrent();
        return WeatherCubit(repository: repository);
      },
      act: (cubit) async {
        await cubit.loadCurrent(_coords);
        await cubit.loadCurrent(_coords);
      },
      expect: () => const [
        WeatherState(currentStatus: WeatherStatus.loading),
        WeatherState(currentStatus: WeatherStatus.ready, current: _snapshot),
      ],
      verify: (_) {
        verify(
          () => repository.getCurrentWeather(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          ),
        ).called(1);
      },
    );

    blocTest<WeatherCubit, WeatherState>(
      'refetches once the cache TTL has expired',
      build: () {
        stubCurrent();
        var calls = 0;
        // First load stamps t0; the second load's freshness check sees t0+16m.
        return WeatherCubit(
          repository: repository,
          cacheTtl: const Duration(minutes: 15),
          clock: () => DateTime(2026, 7, 3, 10, 16 * calls++),
        );
      },
      act: (cubit) async {
        await cubit.loadCurrent(_coords);
        await cubit.loadCurrent(_coords);
      },
      expect: () => const [
        WeatherState(currentStatus: WeatherStatus.loading),
        WeatherState(currentStatus: WeatherStatus.ready, current: _snapshot),
        WeatherState(currentStatus: WeatherStatus.loading, current: _snapshot),
        WeatherState(currentStatus: WeatherStatus.ready, current: _snapshot),
      ],
      verify: (_) {
        verify(
          () => repository.getCurrentWeather(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          ),
        ).called(2);
      },
    );

    blocTest<WeatherCubit, WeatherState>(
      'emits error on WeatherException and retries on the next load',
      build: () {
        var failed = false;
        when(
          () => repository.getCurrentWeather(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          ),
        ).thenAnswer((_) async {
          if (!failed) {
            failed = true;
            throw const WeatherException('HTTP 500');
          }
          return _snapshot;
        });
        return WeatherCubit(repository: repository);
      },
      act: (cubit) async {
        await cubit.loadCurrent(_coords);
        await cubit.loadCurrent(_coords);
      },
      expect: () => const [
        WeatherState(currentStatus: WeatherStatus.loading),
        WeatherState(currentStatus: WeatherStatus.error),
        WeatherState(currentStatus: WeatherStatus.loading),
        WeatherState(currentStatus: WeatherStatus.ready, current: _snapshot),
      ],
    );

    blocTest<WeatherCubit, WeatherState>(
      'caches per coordinate key — nearby-but-distinct facilities refetch',
      build: () {
        stubCurrent();
        return WeatherCubit(repository: repository);
      },
      act: (cubit) async {
        await cubit.loadCurrent(_coords);
        await cubit.loadCurrent(
          const Coordinates(latitude: 45.510, longitude: 9.156),
        );
      },
      verify: (_) {
        verify(
          () => repository.getCurrentWeather(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          ),
        ).called(2);
      },
    );
  });

  group('loadForecast', () {
    blocTest<WeatherCubit, WeatherState>(
      'emits loading then ready with the hourly forecast',
      build: () {
        stubForecast();
        return WeatherCubit(repository: repository);
      },
      act: (cubit) => cubit.loadForecast(_coords, _scheduledAt),
      expect: () => [
        const WeatherState(forecastStatus: WeatherStatus.loading),
        WeatherState(forecastStatus: WeatherStatus.ready, forecast: _forecast),
      ],
      verify: (_) {
        verify(
          () => repository.getHourlyForecast(
            latitude: _coords.latitude,
            longitude: _coords.longitude,
            start: _scheduledAt,
          ),
        ).called(1);
      },
    );

    blocTest<WeatherCubit, WeatherState>(
      'serves a fresh forecast cache entry without refetching',
      build: () {
        stubForecast();
        return WeatherCubit(repository: repository);
      },
      act: (cubit) async {
        await cubit.loadForecast(_coords, _scheduledAt);
        await cubit.loadForecast(_coords, _scheduledAt);
      },
      verify: (_) {
        verify(
          () => repository.getHourlyForecast(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            start: any(named: 'start'),
          ),
        ).called(1);
      },
    );

    blocTest<WeatherCubit, WeatherState>(
      'emits error when the forecast fetch fails',
      build: () {
        when(
          () => repository.getHourlyForecast(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            start: any(named: 'start'),
          ),
        ).thenThrow(const WeatherException('HTTP 500'));
        return WeatherCubit(repository: repository);
      },
      act: (cubit) => cubit.loadForecast(_coords, _scheduledAt),
      expect: () => const [
        WeatherState(forecastStatus: WeatherStatus.loading),
        WeatherState(forecastStatus: WeatherStatus.error),
      ],
    );
  });
}
