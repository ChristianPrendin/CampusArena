import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/facility_model.dart';
import '../../../repositories/weather_repository.dart';
import '../cubit/weather_cubit.dart';
import '../cubit/weather_state.dart';
import 'weather_icon.dart';

/// Current-conditions row (temperature, precipitation, wind) for a facility
/// detail card, per the design's facility slide-up (`facility.png`).
///
/// Self-contained: give it the facility's [coordinates] and [isOutdoor] flag
/// and it manages its own [WeatherCubit]. When [isOutdoor] is false it renders
/// nothing — `isOutdoor` is the single source of truth for weather visibility
/// (never inferred from sport type). Pass [cubit] to share one cubit (and its
/// in-memory cache) across cards, e.g. hosted above the facility map.
class WeatherSnippet extends StatelessWidget {
  const WeatherSnippet({
    super.key,
    required this.coordinates,
    required this.isOutdoor,
    this.cubit,
  });

  final Coordinates coordinates;
  final bool isOutdoor;
  final WeatherCubit? cubit;

  @override
  Widget build(BuildContext context) {
    if (!isOutdoor) return const SizedBox.shrink();
    final body = _SnippetBody(coordinates: coordinates);
    final shared = cubit;
    if (shared != null) {
      return BlocProvider.value(value: shared, child: body);
    }
    return BlocProvider(create: (_) => WeatherCubit(), child: body);
  }
}

class _SnippetBody extends StatefulWidget {
  const _SnippetBody({required this.coordinates});

  final Coordinates coordinates;

  @override
  State<_SnippetBody> createState() => _SnippetBodyState();
}

class _SnippetBodyState extends State<_SnippetBody> {
  @override
  void initState() {
    super.initState();
    // Cache hits in the cubit resolve synchronously, so this is free when a
    // shared cubit already has fresh data for these coordinates.
    context.read<WeatherCubit>().loadCurrent(widget.coordinates);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: BlocBuilder<WeatherCubit, WeatherState>(
        builder: (context, state) {
          final snapshot = state.current;
          return Row(
            children: [
              Icon(
                snapshot == null
                    ? Icons.wb_sunny
                    : weatherIconFor(snapshot.weatherCode),
                size: 22,
                color: colors.tertiary,
              ),
              const SizedBox(width: 8),
              Text(
                state.currentStatus == WeatherStatus.error
                    ? l10n.weatherUnavailable
                    : l10n.weatherLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              ...switch (state.currentStatus) {
                WeatherStatus.ready when snapshot != null => _stats(
                  context,
                  snapshot,
                ),
                WeatherStatus.error => [_retry(context)],
                _ => const [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              },
            ],
          );
        },
      ),
    );
  }

  List<Widget> _stats(BuildContext context, WeatherSnapshot snapshot) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final whole = NumberFormat.decimalPattern(locale);
    // Up to one decimal so light drizzle doesn't display as "0 mm".
    final tenths = NumberFormat('0.#', locale);
    return [
      _Stat(
        icon: Icons.thermostat,
        value: l10n.weatherTemperature(
          whole.format(snapshot.temperatureC.round()),
        ),
      ),
      const SizedBox(width: 12),
      _Stat(
        icon: Icons.water_drop,
        value: l10n.weatherPrecipitation(
          tenths.format(snapshot.precipitationMm),
        ),
      ),
      const SizedBox(width: 12),
      _Stat(
        icon: Icons.air,
        value: l10n.weatherWind(whole.format(snapshot.windSpeedKmh.round())),
      ),
    ];
  }

  Widget _retry(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.read<WeatherCubit>().loadCurrent(widget.coordinates),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 3),
            Text(
              AppLocalizations.of(context).weatherRetry,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
