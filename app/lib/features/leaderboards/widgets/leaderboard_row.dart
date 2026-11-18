import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/degree_programs.dart';
import '../../../core/widgets/identity_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/rating_model.dart';

/// A single ranked list row: position, avatar, display name, degree program,
/// and ELO. Tapping opens the player's public profile — or, for a pair row, the
/// team profile. A pair row (`rating.ownerType == pair`) shows two avatars and
/// both member names joined with `&`, and no degree line.
class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({
    super.key,
    required this.rank,
    required this.rating,
    required this.name,
    this.memberNames = const [],
    this.onTap,
  });

  final int rank;
  final RatingModel rating;

  /// Resolved display name; falls back to the ownerId when still unresolved.
  /// For a pair this is the two names joined for the title.
  final String name;

  /// Per-member names for a pair row, index-aligned with `rating.memberUids`;
  /// empty for singles.
  final List<String> memberNames;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isPair = rating.ownerType == OwnerType.pair;
    final degree = rating.degreeProgram;

    return ListTile(
      onTap: onTap,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isPair)
            _PairAvatars(rating: rating, names: memberNames)
          else
            IdentityAvatar(
              seed: rating.ownerId,
              initials: initialsFromName(name),
            ),
        ],
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: (isPair || degree == null)
          ? null
          : Text(
              localizeDegreeProgram(l10n, degree),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Text(
        '${rating.elo}',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// The two overlapping member avatars for a pair row.
class _PairAvatars extends StatelessWidget {
  const _PairAvatars({required this.rating, required this.names});

  final RatingModel rating;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final uids = rating.memberUids ?? const <String>[];
    return SizedBox(
      width: 58,
      height: 40,
      child: Stack(
        children: [
          for (var i = 0; i < uids.length && i < 2; i++)
            Positioned(
              left: i * 22.0,
              child: IdentityAvatar(
                seed: uids[i],
                initials: initialsFromName(i < names.length ? names[i] : ''),
                radius: 18,
              ),
            ),
        ],
      ),
    );
  }
}
