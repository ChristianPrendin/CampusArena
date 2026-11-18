import 'package:flutter/material.dart';

import '../../../core/elo/elo_calculator.dart';
import '../../../core/match_display.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/rating_model.dart';

/// The dashboard's headline: the selected sport's ELO on a gradient card, with
/// the last-match delta. Fills the height it is given (it is [Expanded] in the
/// tablet split), so a compact typography scale is used on short cards and a
/// larger one when there is room.
class EloHeroCard extends StatelessWidget {
  const EloHeroCard({
    super.key,
    required this.rating,
    required this.sportId,
    this.lastDelta,
  });

  /// The selected sport's rating, or null while ratings are still loading.
  final RatingModel? rating;

  final String sportId;

  /// ELO change from the most recent confirmed match in this sport, or null if
  /// there is none in the loaded window.
  final int? lastDelta;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Inactivity decay is computed lazily at read time, never persisted (the
    // stored ELO is the input; see `brain/firestore_schema.md`). Erodes only
    // idle gains above the baseline, so an active or sub-baseline rating shows
    // its stored value unchanged.
    final elo = rating == null
        ? null
        : const EloCalculator().decayedElo(
            elo: rating!.elo,
            lastMatchAt: rating!.lastMatchAt,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        // A tall card (tablet split) earns a bigger number.
        final tall =
            constraints.maxHeight.isFinite && constraints.maxHeight > 220;
        final eloStyle = (tall
            ? theme.textTheme.displayLarge
            : theme.textTheme.displayMedium);

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary,
                Color.lerp(colors.primary, colors.shadow, 0.14)!,
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned(
                  right: -14,
                  top: -10,
                  child: Icon(
                    sportIcon(sportId),
                    size: tall ? 170 : 120,
                    color: colors.onPrimary.withValues(alpha: 0.12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.eloRatingLabel.toUpperCase(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onPrimary.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        elo == null ? '—' : '$elo',
                        style: eloStyle?.copyWith(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                        ),
                      ),
                      if (lastDelta != null) ...[
                        const SizedBox(height: 10),
                        _DeltaPill(delta: lastDelta!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            delta >= 0 ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: colors.onPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            delta >= 0 ? '+$delta' : '$delta',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
