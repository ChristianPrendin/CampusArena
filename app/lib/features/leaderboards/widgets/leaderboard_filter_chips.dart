import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/match_display.dart';
import '../../../l10n/app_localizations.dart';
import '../cubit/leaderboard_state.dart';

/// The leaderboard filters, as three vertically-stacked controls for three
/// distinct choices: a chip row with one single-select chip per supported sport
/// (same language as the Dashboard's sport selector) leads, then a full-width
/// singles/doubles mode toggle, then a three-segment scope selector (Global |
/// Friends | My course) where exactly one scope is always visibly active — no
/// invisible "nothing selected = global" state. Sport comes first as the primary
/// axis; the two like-styled segmented selectors group together below it, each
/// on its own row so a long chip list can never collide with them.
class LeaderboardFilterChips extends StatelessWidget {
  const LeaderboardFilterChips({
    super.key,
    required this.selectedSportId,
    required this.scope,
    required this.mode,
    required this.onSport,
    required this.onScope,
    required this.onMode,
  });

  final String selectedSportId;
  final LeaderboardScope scope;
  final LeaderboardMode mode;
  final ValueChanged<String> onSport;
  final ValueChanged<LeaderboardScope> onScope;
  final ValueChanged<LeaderboardMode> onMode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // Sport is the primary axis — it leads. Its chips get their own
        // scrolling row, free to grow without bumping into any trailing control.
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final sportId in SportIds.supported) ...[
                  _Chip(
                    icon: sportIcon(sportId),
                    label: localizedSportName(l10n, sportId),
                    selected: sportId == selectedSportId,
                    onTap: () => onSport(sportId),
                  ),
                  if (sportId != SportIds.supported.last)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // The two full-width segmented selectors sit together below the chips so
        // the like-styled controls read as one group: mode first, then scope.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<LeaderboardMode>(
            segments: [
              ButtonSegment(
                value: LeaderboardMode.singles,
                label: Text(l10n.matchModeSingles),
              ),
              ButtonSegment(
                value: LeaderboardMode.doubles,
                label: Text(l10n.matchModeDoubles),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) => onMode(s.single),
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
          ),
        ),
        // Scope only applies to the singles boards — doubles is global-only, so
        // the scope selector vanishes entirely in doubles mode.
        if (mode == LeaderboardMode.singles) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<LeaderboardScope>(
              segments: [
                ButtonSegment(
                  value: LeaderboardScope.global,
                  label: Text(l10n.leaderboardScopeGlobal),
                ),
                ButtonSegment(
                  value: LeaderboardScope.friends,
                  label: Text(l10n.leaderboardScopeFriends),
                ),
                ButtonSegment(
                  value: LeaderboardScope.myCourse,
                  label: Text(l10n.leaderboardScopeMyCourse),
                ),
              ],
              selected: {scope},
              onSelectionChanged: (selection) => onScope(selection.single),
              showSelectedIcon: false,
              // Stretch to the search bar's width above it.
              expandedInsets: EdgeInsets.zero,
            ),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? scheme.onPrimary : scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: scheme.primary,
      showCheckmark: false,
    );
  }
}
