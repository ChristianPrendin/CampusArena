import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/identity_avatar.dart';
import '../../../models/rating_model.dart';

/// The top-three podium: the leader centred and raised, runner-up left, third
/// right, each on a podium-coloured pedestal. Renders whatever subset of the
/// three exists (a board with one or two players still shows).
class LeaderboardPodium extends StatelessWidget {
  const LeaderboardPodium({
    super.key,
    required this.top,
    required this.displayNames,
    this.labelFor,
    this.initialsFor,
    this.onTap,
  });

  /// Up to three ranked entries, ELO-descending.
  final List<RatingModel> top;
  final Map<String, String> displayNames;

  /// Resolves the label under a spot. Defaults to `displayNames[ownerId]` (with
  /// the ownerId as a fallback); doubles boards pass the joined pair names.
  final String Function(RatingModel)? labelFor;

  /// Resolves the avatar initials. Defaults to the label's initials; doubles
  /// boards pass both members' initials so a pair reads as e.g. "AB".
  final String Function(RatingModel)? initialsFor;

  final void Function(RatingModel)? onTap;

  @override
  Widget build(BuildContext context) {
    // Fall back when the app theme (and its extension) isn't in scope, so the
    // podium never hard-crashes under a bare theme.
    final podium =
        Theme.of(context).extension<PodiumColors>() ?? PodiumColors.light;
    RatingModel? at(int i) => i < top.length ? top[i] : null;

    Widget spot(int index, int rank, Color color, double pedestalHeight) =>
        Expanded(
          child: _Spot(
            rating: at(index),
            rank: rank,
            color: color,
            pedestalHeight: pedestalHeight,
            names: displayNames,
            labelFor: labelFor,
            initialsFor: initialsFor,
            onTap: onTap,
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          spot(1, 2, podium.silver, 64),
          const SizedBox(width: 8),
          spot(0, 1, podium.gold, 88),
          const SizedBox(width: 8),
          spot(2, 3, podium.bronze, 48),
        ],
      ),
    );
  }
}

class _Spot extends StatelessWidget {
  const _Spot({
    required this.rating,
    required this.rank,
    required this.color,
    required this.pedestalHeight,
    required this.names,
    required this.labelFor,
    required this.initialsFor,
    required this.onTap,
  });

  final RatingModel? rating;
  final int rank;
  final Color color;
  final double pedestalHeight;
  final Map<String, String> names;
  final String Function(RatingModel)? labelFor;
  final String Function(RatingModel)? initialsFor;
  final void Function(RatingModel)? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = rating;
    if (r == null) {
      // Keep the column's footprint so present spots stay aligned.
      return SizedBox(height: pedestalHeight + 96);
    }
    final name = labelFor?.call(r) ?? names[r.ownerId] ?? r.ownerId;
    final initials = initialsFor?.call(r) ?? initialsFromName(name);

    return InkWell(
      onTap: onTap == null ? null : () => onTap!(r),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 3),
                ),
                child: IdentityAvatar(
                  seed: r.ownerId,
                  initials: initials,
                  radius: rank == 1 ? 34 : 28,
                  fontSize: rank == 1 ? 26 : 22,
                ),
              ),
              Positioned(
                bottom: -6,
                child: CircleAvatar(
                  radius: 11,
                  backgroundColor: color,
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: theme.colorScheme.surface,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${r.elo}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: pedestalHeight,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '$rank',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
