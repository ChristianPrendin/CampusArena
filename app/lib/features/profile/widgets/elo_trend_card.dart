import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/match_display.dart';
import '../../../l10n/app_localizations.dart';
import '../profile_stats.dart';

/// Chart pane height inside the card (the in-card header sits above it).
const double _chartHeight = 120;

/// The profile's ELO trend card: title, the in-card Ping Pong / Foosball
/// segmented toggle, and an fl_chart line of the personal rating after each
/// rated match. With fewer than two points the pane shows an empty-state line
/// at the same height so toggling sports never shifts the layout.
class EloTrendCard extends StatelessWidget {
  const EloTrendCard({
    super.key,
    required this.selectedSportId,
    required this.points,
    required this.onSportSelected,
  });

  final String selectedSportId;
  final List<TrendPoint> points;
  final ValueChanged<String> onSportSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.profileEloTrendTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _SportToggle(
                  selectedSportId: selectedSportId,
                  onSelected: onSportSelected,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: _chartHeight,
              child: points.length < 2
                  ? Center(
                      child: Text(
                        l10n.profileTrendEmpty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : _TrendChart(points: points),
            ),
          ],
        ),
      ),
    );
  }
}

/// The in-card segmented pill that switches the trend (and the stat tiles /
/// fun-stat cards below) between sports — a compact variant of the
/// dashboard's SportSelector, per the design.
class _SportToggle extends StatelessWidget {
  const _SportToggle({required this.selectedSportId, required this.onSelected});

  final String selectedSportId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final sportId in SportIds.supported)
            _SportSegment(
              label: localizedSportName(l10n, sportId),
              selected: sportId == selectedSportId,
              onTap: () => onSelected(sportId),
            ),
        ],
      ),
    );
  }
}

class _SportSegment extends StatelessWidget {
  const _SportSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: selected ? colors.primary : Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: selected ? colors.onPrimary : colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);

    var minElo = points.first.elo;
    var maxElo = points.first.elo;
    for (final p in points) {
      if (p.elo < minElo) minElo = p.elo;
      if (p.elo > maxElo) maxElo = p.elo;
    }
    // Breathing room so the line never hugs the pane edges; a flat series
    // still gets a visible band.
    final pad = ((maxElo - minElo) * 0.15).clamp(8.0, double.infinity);

    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].elo.toDouble()),
    ];

    return LineChart(
      LineChartData(
        minY: minElo - pad,
        maxY: maxElo + pad,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.inverseSurface,
            getTooltipItems: (touched) => [
              for (final spot in touched)
                LineTooltipItem(
                  l10n.profileTrendTooltipPoint(
                    points[spot.spotIndex].elo,
                    materialL10n.formatShortDate(
                      points[spot.spotIndex].confirmedAt,
                    ),
                  ),
                  theme.textTheme.labelMedium!.copyWith(
                    color: colors.onInverseSurface,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: colors.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              // Only the latest point wears a dot, per the design.
              checkToShowDot: (spot, bar) => spot == bar.spots.last,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: colors.primary,
                strokeWidth: 2,
                strokeColor: colors.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.primary.withValues(alpha: 0.28),
                  colors.primary.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
