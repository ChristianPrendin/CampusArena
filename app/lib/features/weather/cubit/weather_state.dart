import 'package:equatable/equatable.dart';

import '../../../repositories/weather_repository.dart';

enum WeatherStatus { initial, loading, ready, error }

/// Weather for one facility: current conditions (detail-card snippet) and,
/// when requested, the hourly forecast for a tournament's scheduled timeslot.
/// The two halves load independently — each has its own status so a widget
/// only ever depends on the half it renders.
class WeatherState extends Equatable {
  const WeatherState({
    this.currentStatus = WeatherStatus.initial,
    this.current,
    this.forecastStatus = WeatherStatus.initial,
    this.forecast = const [],
  });

  final WeatherStatus currentStatus;

  /// Current conditions, or null until the first successful load.
  final WeatherSnapshot? current;

  final WeatherStatus forecastStatus;

  /// Hourly forecast entries, oldest first; empty until loaded.
  final List<ForecastHour> forecast;

  WeatherState copyWith({
    WeatherStatus? currentStatus,
    WeatherSnapshot? current,
    WeatherStatus? forecastStatus,
    List<ForecastHour>? forecast,
  }) {
    return WeatherState(
      currentStatus: currentStatus ?? this.currentStatus,
      current: current ?? this.current,
      forecastStatus: forecastStatus ?? this.forecastStatus,
      forecast: forecast ?? this.forecast,
    );
  }

  @override
  List<Object?> get props => [currentStatus, current, forecastStatus, forecast];
}
