// Shared UI atoms for the sport result-entry widgets. Kept sport-agnostic so
// both Ping Pong (per-set rows) and Foosball (single goal row) compose from the
// same stepper + header, matching `docs/design/screenshots/result.png`.

import 'package:flutter/material.dart';

import '../widgets/identity_avatar.dart';
import 'scoring_strategy.dart';

/// A `[−  value  +]` integer stepper. The decrement is disabled (and greys out)
/// at [minValue]; the increment is unbounded. Colours come from the theme —
/// the increment reads as the primary action, the decrement as a muted one.
class ScoreStepper extends StatelessWidget {
  const ScoreStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.minValue = 0,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int minValue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          color: colorScheme.onSurfaceVariant,
          onPressed: value > minValue ? () => onChanged(value - 1) : null,
          visualDensity: VisualDensity.compact,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          color: colorScheme.primary,
          onPressed: () => onChanged(value + 1),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

/// The two-avatar "You vs Opponent" header. The user's own side is tinted with
/// the primary colour, mirroring the design.
class ResultEntryHeader extends StatelessWidget {
  const ResultEntryHeader({
    super.key,
    required this.youSide,
    required this.opponentSide,
  });

  final ResultEntrySide youSide;
  final ResultEntrySide opponentSide;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SideColumn(side: youSide, highlight: true),
        _SideColumn(side: opponentSide, highlight: false),
      ],
    );
  }
}

class _SideColumn extends StatelessWidget {
  const _SideColumn({required this.side, required this.highlight});

  final ResultEntrySide side;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: highlight ? colorScheme.primary : colorScheme.onSurface,
    );

    // Doubles: two smaller avatars for the pair, with member names underneath.
    if (side.uids.length > 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < side.uids.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                IdentityAvatar(
                  seed: side.uids[i],
                  initials: initialsFromName(
                    i < side.memberNames.length ? side.memberNames[i] : null,
                  ),
                  radius: 20,
                  fontSize: 13,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(side.label, style: labelStyle),
          if (side.memberNames.isNotEmpty)
            Text(
              side.memberNames.where((n) => n.isNotEmpty).join(' & '),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      );
    }

    final seed = side.uids.isNotEmpty ? side.uids.join('_') : side.displayName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IdentityAvatar(
          seed: seed,
          initials: initialsFromName(side.displayName),
          radius: 28,
          fontSize: 16,
        ),
        const SizedBox(height: 8),
        Text(side.label, style: labelStyle),
      ],
    );
  }
}
