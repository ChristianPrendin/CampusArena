import 'dart:convert';
import 'dart:io';

import 'package:campus_arena/repositories/weather_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

const _lat = 45.503;
const _lon = 9.156;

String _currentBody({
  double temp = 19.2,
  double precip = 0.0,
  double wind = 8.4,
  int code = 2,
}) => jsonEncode({
  'current': {
    'time': '2026-07-03T10:00',
    'temperature_2m': temp,
    'precipitation': precip,
    'wind_speed_10m': wind,
    'weather_code': code,
  },
});

String _hourlyBody({int hours = 4}) => jsonEncode({
  'hourly': {
    'time': [for (var i = 0; i < hours; i++) '2026-07-04T${15 + i}:00'],
    'temperature_2m': [for (var i = 0; i < hours; i++) 20.0 + i],
    'precipitation': [for (var i = 0; i < hours; i++) 0.1 * i],
    'wind_speed_10m': [for (var i = 0; i < hours; i++) 10.0 + i],
    'weather_code': [for (var i = 0; i < hours; i++) i],
  },
});

void main() {
  late MockHttpClient client;
  late WeatherRepository repository;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    client = MockHttpClient();
    repository = WeatherRepository(client: client);
  });

  void stubGet(String body, {int statusCode = 200}) {
    when(
      () => client.get(any()),
    ).thenAnswer((_) async => http.Response(body, statusCode));
  }

  Uri requestedUri() =>
      verify(() => client.get(captureAny())).captured.single as Uri;

  group('getCurrentWeather', () {
    test('parses current conditions from the Open-Meteo response', () async {
      stubGet(_currentBody());

      final snapshot = await repository.getCurrentWeather(
        latitude: _lat,
        longitude: _lon,
      );

      expect(
        snapshot,
        const WeatherSnapshot(
          temperatureC: 19.2,
          precipitationMm: 0.0,
          windSpeedKmh: 8.4,
          weatherCode: 2,
        ),
      );
    });

    test(
      'requests the forecast endpoint with the facility coordinates',
      () async {
        stubGet(_currentBody());

        await repository.getCurrentWeather(latitude: _lat, longitude: _lon);

        final uri = requestedUri();
        expect(uri.host, 'api.open-meteo.com');
        expect(uri.path, '/v1/forecast');
        expect(uri.queryParameters['latitude'], '$_lat');
        expect(uri.queryParameters['longitude'], '$_lon');
        expect(
          uri.queryParameters['current'],
          'temperature_2m,precipitation,wind_speed_10m,weather_code',
        );
      },
    );

    test('handles integer numerics in the response', () async {
      stubGet(
        jsonEncode({
          'current': {
            'temperature_2m': 19,
            'precipitation': 0,
            'wind_speed_10m': 8,
            'weather_code': 0,
          },
        }),
      );

      final snapshot = await repository.getCurrentWeather(
        latitude: _lat,
        longitude: _lon,
      );

      expect(snapshot.temperatureC, 19.0);
      expect(snapshot.weatherCode, 0);
    });

    test('throws WeatherException on a non-200 status', () {
      stubGet('server error', statusCode: 500);

      expect(
        () => repository.getCurrentWeather(latitude: _lat, longitude: _lon),
        throwsA(isA<WeatherException>()),
      );
    });

    test('throws WeatherException when the body is not JSON', () {
      stubGet('<html>gateway</html>');

      expect(
        () => repository.getCurrentWeather(latitude: _lat, longitude: _lon),
        throwsA(isA<WeatherException>()),
      );
    });

    test('throws WeatherException when the current block is missing', () {
      stubGet(jsonEncode({'hourly': <String, Object>{}}));

      expect(
        () => repository.getCurrentWeather(latitude: _lat, longitude: _lon),
        throwsA(isA<WeatherException>()),
      );
    });

    test('wraps network failures in WeatherException', () {
      when(
        () => client.get(any()),
      ).thenThrow(const SocketException('no route to host'));

      expect(
        () => repository.getCurrentWeather(latitude: _lat, longitude: _lon),
        throwsA(isA<WeatherException>()),
      );
    });
  });

  group('getHourlyForecast', () {
    final scheduledAt = DateTime(2026, 7, 4, 15, 47);

    test('parses one ForecastHour per returned hour', () async {
      stubGet(_hourlyBody());

      final hours = await repository.getHourlyForecast(
        latitude: _lat,
        longitude: _lon,
        start: scheduledAt,
      );

      expect(hours, hasLength(4));
      expect(
        hours.first,
        ForecastHour(
          time: DateTime(2026, 7, 4, 15),
          temperatureC: 20.0,
          precipitationMm: 0.0,
          windSpeedKmh: 10.0,
          weatherCode: 0,
        ),
      );
      expect(hours.last.temperatureC, 23.0);
    });

    test(
      'requests an hour-bounded window from the scheduled timeslot',
      () async {
        stubGet(_hourlyBody());

        await repository.getHourlyForecast(
          latitude: _lat,
          longitude: _lon,
          start: scheduledAt,
        );

        final uri = requestedUri();
        expect(uri.queryParameters['start_hour'], '2026-07-04T15:00');
        expect(uri.queryParameters['end_hour'], '2026-07-04T18:00');
        expect(uri.queryParameters['timezone'], 'auto');
        expect(
          uri.queryParameters['hourly'],
          'temperature_2m,precipitation,wind_speed_10m,weather_code',
        );
      },
    );

    test('truncates to the shortest hourly array', () async {
      final body = jsonDecode(_hourlyBody()) as Map<String, dynamic>;
      final hourly = body['hourly'] as Map<String, dynamic>;
      hourly['weather_code'] = (hourly['weather_code'] as List).sublist(0, 2);
      stubGet(jsonEncode(body));

      final hours = await repository.getHourlyForecast(
        latitude: _lat,
        longitude: _lon,
        start: scheduledAt,
      );

      expect(hours, hasLength(2));
    });

    test('throws WeatherException when the hourly block is missing', () {
      stubGet(jsonEncode(<String, Object>{}));

      expect(
        () => repository.getHourlyForecast(
          latitude: _lat,
          longitude: _lon,
          start: scheduledAt,
        ),
        throwsA(isA<WeatherException>()),
      );
    });
  });
}
