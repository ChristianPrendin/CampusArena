import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/match_display.dart';
import '../../../l10n/app_localizations.dart';

/// Single-select sport filter row on the tournament browser (one chip per
/// supported sport). Mirrors the leaderboard's chip styling so the two filter
/// surfaces read the same.
class TournamentSportFilter extends StatelessWidget {
  const TournamentSportFilter({
    super.key,
    required this.selectedSportId,
    required this.onSelected,
  });

  final String selectedSportId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final sportId in SportIds.supported) ...[
            ChoiceChip(
              selected: sportId == selectedSportId,
              onSelected: (_) => onSelected(sportId),
              avatar: Icon(
                sportIcon(sportId),
                size: 18,
                color: sportId == selectedSportId
                    ? scheme.onPrimary
                    : scheme.onSurfaceVariant,
              ),
              label: Text(localizedSportName(l10n, sportId)),
              labelStyle: TextStyle(
                color: sportId == selectedSportId
                    ? scheme.onPrimary
                    : scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              selectedColor: scheme.primary,
              showCheckmark: false,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
