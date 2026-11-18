import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/facility_model.dart';
import '../../../repositories/weather_repository.dart';
import 'weather_state.dart';

/// Loads weather for one facility's coordinates and caches results in memory.
///
/// The cache is instance-level and TTL-bound: a cache hit re-emits `ready`
/// synchronously without touching the network, so hosting one cubit above a
/// screen (e.g. the facility map) makes reopening a detail card free. Errors
/// are never cached — calling a load method again after a failure retries.
class WeatherCubit extends Cubit<WeatherState> {
  WeatherCubit({
    WeatherRepository? repository,
    this.cacheTtl = const Duration(minutes: 15),
    DateTime Function()? clock,
  }) : _repository = repository ?? WeatherRepository(),
       _clock = clock ?? DateTime.now,
       super(const WeatherState());

  final WeatherRepository _repository;

  /// How long a fetched result stays served from cache.
  final Duration cacheTtl;

  final DateTime Function() _clock;

  final Map<String, _CacheEntry<WeatherSnapshot>> _currentCache = {};
  final Map<String, _CacheEntry<List<ForecastHour>>> _forecastCache = {};

  /// Loads current conditions at [coordinates]. No-op while a load for the
  /// same key is already in flight.
  Future<void> loadCurrent(Coordinates coordinates) async {
    final key = _coordKey(coordinates);
    final cached = _fresh(_currentCache[key]);
    if (cached != null) {
      emit(state.copyWith(currentStatus: WeatherStatus.ready, current: cached));
      return;
    }
    if (state.currentStatus == WeatherStatus.loading) return;
    emit(state.copyWith(currentStatus: WeatherStatus.loading));
    try {
      final snapshot = await _repository.getCurrentWeather(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );
      _currentCache[key] = _CacheEntry(snapshot, _clock());
      if (isClosed) return;
      emit(
        state.copyWith(currentStatus: WeatherStatus.ready, current: snapshot),
      );
    } on WeatherException {
      if (isClosed) return;
      emit(state.copyWith(currentStatus: WeatherStatus.error));
    }
  }

  /// Loads the hourly forecast at [coordinates] for the timeslot starting at
  /// [start] (a tournament's `scheduledAt`).
  Future<void> loadForecast(Coordinates coordinates, DateTime start) async {
    final key =
        '${_coordKey(coordinates)}@${start.year}-${start.month}-'
        '${start.day}T${start.hour}';
    final cached = _fresh(_forecastCache[key]);
    if (cached != null) {
      emit(
        state.copyWith(forecastStatus: WeatherStatus.ready, forecast: cached),
      );
      return;
    }
    if (state.forecastStatus == WeatherStatus.loading) return;
    emit(state.copyWith(forecastStatus: WeatherStatus.loading));
    try {
      final hours = await _repository.getHourlyForecast(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        start: start,
      );
      _forecastCache[key] = _CacheEntry(hours, _clock());
      if (isClosed) return;
      emit(
        state.copyWith(forecastStatus: WeatherStatus.ready, forecast: hours),
      );
    } on WeatherException {
      if (isClosed) return;
      emit(state.copyWith(forecastStatus: WeatherStatus.error));
    }
  }

  T? _fresh<T>(_CacheEntry<T>? entry) {
    if (entry == null) return null;
    if (_clock().difference(entry.fetchedAt) > cacheTtl) return null;
    return entry.value;
  }

  // ~110 m resolution: facilities sharing a spot share a cache entry, distinct
  // facilities never collide.
  static String _coordKey(Coordinates c) =>
      '${c.latitude.toStringAsFixed(3)},${c.longitude.toStringAsFixed(3)}';
}

class _CacheEntry<T> {
  const _CacheEntry(this.value, this.fetchedAt);

  final T value;
  final DateTime fetchedAt;
}
