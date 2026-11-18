import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/facility_model.dart';
import '../../../repositories/weather_repository.dart';
import '../cubit/weather_cubit.dart';
import '../cubit/weather_state.dart';
import 'weather_icon.dart';

/// Hourly forecast strip for outdoor tournament views, per the design's
/// bracket screen: an uppercase header and one column per hour (time, icon,
/// temperature) covering the tournament's scheduled timeslot.
///
/// Self-contained like [WeatherSnippet]: takes the facility's [coordinates]
/// and [isOutdoor] flag plus the tournament's [scheduledAt], renders nothing
/// when the facility is indoors ([isOutdoor] is the single source of truth),
/// and manages its own [WeatherCubit] unless [cubit] is provided.
class ForecastStrip extends StatelessWidget {
  const ForecastStrip({
    super.key,
    required this.coordinates,
    required this.isOutdoor,
    required this.scheduledAt,
    this.cubit,
  });

  final Coordinates coordinates;
  final bool isOutdoor;

  /// Start of the timeslot to forecast (the tournament's `scheduledAt`).
  final DateTime scheduledAt;

  final WeatherCubit? cubit;

  @override
  Widget build(BuildContext context) {
    if (!isOutdoor) return const SizedBox.shrink();
    final body = _StripBody(coordinates: coordinates, scheduledAt: scheduledAt);
    final shared = cubit;
    if (shared != null) {
      return BlocProvider.value(value: shared, child: body);
    }
    return BlocProvider(create: (_) => WeatherCubit(), child: body);
  }
}

class _StripBody extends StatefulWidget {
  const _StripBody({required this.coordinates, required this.scheduledAt});

  final Coordinates coordinates;
  final DateTime scheduledAt;

  @override
  State<_StripBody> createState() => _StripBodyState();
}

class _StripBodyState extends State<_StripBody> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    context.read<WeatherCubit>().loadForecast(
      widget.coordinates,
      widget.scheduledAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.wb_sunny,
                size: 14,
                color: colors.onSecondaryContainer,
              ),
              const SizedBox(width: 5),
              Text(
                l10n.forecastLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          BlocBuilder<WeatherCubit, WeatherState>(
            builder: (context, state) => switch (state.forecastStatus) {
              WeatherStatus.ready => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final hour in state.forecast) _HourColumn(hour: hour),
                ],
              ),
              WeatherStatus.error => _error(context),
              _ => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _error(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.weatherUnavailable,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSecondaryContainer,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _load,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              l10n.weatherRetry,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HourColumn extends StatelessWidget {
  const _HourColumn({required this.hour});

  final ForecastHour hour;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();

    return Column(
      children: [
        Text(
          DateFormat.Hm(locale).format(hour.time),
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSecondaryContainer.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 3),
        Icon(
          weatherIconFor(hour.weatherCode),
          size: 19,
          color: colors.tertiary,
        ),
        const SizedBox(height: 3),
        Text(
          l10n.weatherTemperature(
            NumberFormat.decimalPattern(
              locale,
            ).format(hour.temperatureC.round()),
          ),
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
