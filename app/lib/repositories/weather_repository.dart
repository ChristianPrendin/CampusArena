import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;

/// Thrown when Open-Meteo is unreachable, returns a non-200 status, or the
/// body cannot be parsed. Callers surface this as the weather error state —
/// weather is decorative, so it never propagates further.
class WeatherException implements Exception {
  const WeatherException(this.message);

  final String message;

  @override
  String toString() => 'WeatherException: $message';
}

/// Current conditions at a facility's coordinates. Units are Open-Meteo
/// defaults: °C, mm, km/h. Not a Firestore model — weather is never persisted
/// (see the Phase 3 task board: pure external API integration).
class WeatherSnapshot extends Equatable {
  const WeatherSnapshot({
    required this.temperatureC,
    required this.precipitationMm,
    required this.windSpeedKmh,
    required this.weatherCode,
  });

  final double temperatureC;
  final double precipitationMm;
  final double windSpeedKmh;

  /// WMO weather interpretation code (0 = clear … 99 = thunderstorm w/ hail).
  final int weatherCode;

  @override
  List<Object?> get props => [
    temperatureC,
    precipitationMm,
    windSpeedKmh,
    weatherCode,
  ];
}

/// One hour of forecast for an outdoor tournament's scheduled timeslot.
class ForecastHour extends Equatable {
  const ForecastHour({
    required this.time,
    required this.temperatureC,
    required this.precipitationMm,
    required this.windSpeedKmh,
    required this.weatherCode,
  });

  /// Facility-local wall-clock time of the forecast hour.
  final DateTime time;
  final double temperatureC;
  final double precipitationMm;
  final double windSpeedKmh;
  final int weatherCode;

  @override
  List<Object?> get props => [
    time,
    temperatureC,
    precipitationMm,
    windSpeedKmh,
    weatherCode,
  ];
}

/// Fetches conditions from the Open-Meteo REST API (no key) by facility
/// coordinates. Read-only and Firestore-free; results are cached in memory by
/// [WeatherCubit], never persisted.
class WeatherRepository {
  WeatherRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _host = 'api.open-meteo.com';
  static const String _path = '/v1/forecast';
  static const String _variables =
      'temperature_2m,precipitation,wind_speed_10m,weather_code';

  /// Current conditions at ([latitude], [longitude]).
  Future<WeatherSnapshot> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    final body = await _get({
      'latitude': '$latitude',
      'longitude': '$longitude',
      'current': _variables,
    });
    final current = body['current'];
    if (current is! Map<String, dynamic>) {
      throw const WeatherException('missing "current" block in response');
    }
    return WeatherSnapshot(
      temperatureC: _asDouble(current, 'temperature_2m'),
      precipitationMm: _asDouble(current, 'precipitation'),
      windSpeedKmh: _asDouble(current, 'wind_speed_10m'),
      weatherCode: _asDouble(current, 'weather_code').toInt(),
    );
  }

  /// Hourly forecast covering [hours] hours from [start] (truncated to the
  /// hour), in facility-local time — used for a tournament's `scheduledAt`
  /// timeslot. The `start_hour`/`end_hour` window keeps the response bounded.
  Future<List<ForecastHour>> getHourlyForecast({
    required double latitude,
    required double longitude,
    required DateTime start,
    int hours = 4,
  }) async {
    assert(hours > 0);
    final startHour = DateTime(start.year, start.month, start.day, start.hour);
    final body = await _get({
      'latitude': '$latitude',
      'longitude': '$longitude',
      'hourly': _variables,
      'timezone': 'auto',
      'start_hour': _formatHour(startHour),
      'end_hour': _formatHour(startHour.add(Duration(hours: hours - 1))),
    });
    final hourly = body['hourly'];
    if (hourly is! Map<String, dynamic>) {
      throw const WeatherException('missing "hourly" block in response');
    }
    final times = _asList(hourly, 'time');
    final temps = _asList(hourly, 'temperature_2m');
    final precip = _asList(hourly, 'precipitation');
    final wind = _asList(hourly, 'wind_speed_10m');
    final codes = _asList(hourly, 'weather_code');
    final count = [
      times.length,
      temps.length,
      precip.length,
      wind.length,
      codes.length,
    ].reduce((a, b) => a < b ? a : b);
    return [
      for (var i = 0; i < count; i++)
        ForecastHour(
          time: DateTime.parse(times[i] as String),
          temperatureC: _toDouble(temps[i], 'temperature_2m'),
          precipitationMm: _toDouble(precip[i], 'precipitation'),
          windSpeedKmh: _toDouble(wind[i], 'wind_speed_10m'),
          weatherCode: _toDouble(codes[i], 'weather_code').toInt(),
        ),
    ];
  }

  Future<Map<String, dynamic>> _get(Map<String, String> query) async {
    final uri = Uri.https(_host, _path, query);
    final http.Response response;
    try {
      response = await _client.get(uri);
    } catch (e) {
      throw WeatherException('request failed: $e');
    }
    if (response.statusCode != 200) {
      throw WeatherException('HTTP ${response.statusCode}');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const WeatherException('response body is not valid JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const WeatherException('unexpected response shape');
    }
    return decoded;
  }

  static String _formatHour(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}T'
      '${t.hour.toString().padLeft(2, '0')}:00';

  static double _asDouble(Map<String, dynamic> map, String key) =>
      _toDouble(map[key], key);

  static double _toDouble(Object? value, String key) {
    if (value is num) return value.toDouble();
    throw WeatherException('missing or non-numeric "$key"');
  }

  static List<Object?> _asList(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is List) return value;
    throw WeatherException('missing "$key" array');
  }
}
