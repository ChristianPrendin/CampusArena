import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants.dart';
import '../../../core/elo/elo_calculator.dart';
import '../../../core/match_display.dart';
import '../../../core/widgets/identity_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/rating_model.dart';
import '../../../models/user_model.dart';
import '../../../repositories/facility_repository.dart';
import '../../../repositories/match_repository.dart';
import '../../../repositories/rating_repository.dart';
import '../../../repositories/user_repository.dart';
import '../widgets/elo_trend_card.dart';
import '../widgets/profile_history_tile.dart';
import '../widgets/profile_stats_grid.dart';
import 'cubit/team_profile_cubit.dart';
import 'cubit/team_profile_state.dart';

/// The doubles team (pair) profile — a read-only drill-in from a doubles
/// leaderboard row. Mirrors [ProfileScreen] "as if the pair were a user":
/// two-member header, per-sport team ELO chips, the shared trend, the team's
/// win/loss grid, and the team's match history. No fun stats (a per-opponent
/// singles concept).
class TeamProfileScreen extends StatelessWidget {
  const TeamProfileScreen({
    super.key,
    required this.pairId,
    this.initialSportId,
    this.ratingRepository,
    this.matchRepository,
    this.userRepository,
    this.facilityRepository,
  });

  final String pairId;
  final String? initialSportId;

  final RatingRepository? ratingRepository;
  final MatchRepository? matchRepository;
  final UserRepository? userRepository;
  final FacilityRepository? facilityRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TeamProfileCubit(
        pairId: pairId,
        initialSportId: initialSportId,
        ratingRepository: ratingRepository,
        matchRepository: matchRepository,
        userRepository: userRepository,
        facilityRepository: facilityRepository,
      ),
      child: const TeamProfileView(),
    );
  }
}

class TeamProfileView extends StatelessWidget {
  const TeamProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.teamProfileTitle)),
      body: SafeArea(
        child: BlocBuilder<TeamProfileCubit, TeamProfileState>(
          builder: (context, state) {
            switch (state.status) {
              case TeamProfileStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case TeamProfileStatus.error:
                return _ErrorView(
                  message: l10n.teamProfileLoadError,
                  retryLabel: l10n.retryButtonLabel,
                  onRetry: () => context.read<TeamProfileCubit>().retry(),
                );
              case TeamProfileStatus.ready:
                return _TeamContent(state: state);
            }
          },
        ),
      ),
    );
  }
}

class _TeamContent extends StatelessWidget {
  const _TeamContent({required this.state});

  final TeamProfileState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TeamProfileCubit>();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TeamHeader(pairId: state.pairId, members: state.members),
            const SizedBox(height: 14),
            _TeamEloChipsRow(ratings: state.ratings),
            const SizedBox(height: 14),
            EloTrendCard(
              selectedSportId: state.selectedSportId,
              points: state.selectedTrend,
              onSportSelected: cubit.selectSport,
            ),
            const SizedBox(height: 14),
            ProfileStatsGrid(stats: state.selectedStats),
            const SizedBox(height: 20),
            _HistorySection(state: state),
          ],
        ),
      ),
    );
  }
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.pairId, required this.members});

  final String pairId;
  final List<UserModel> members;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Seed avatars from the pairId's uids so the header renders even before the
    // member docs resolve; names come from the resolved members.
    final uids = pairId.split('_');
    String nameFor(String uid) =>
        members.firstWhereOrNull((m) => m.uid == uid)?.name ?? '';
    final names = [for (final u in uids) nameFor(u)];

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < uids.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              IdentityAvatar(
                seed: uids[i],
                initials: initialsFromName(names[i]),
                radius: 34,
                fontSize: 24,
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          names.where((n) => n.isNotEmpty).join(' & '),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Per-sport team ELO chips (mirrors the profile's `_EloChipsRow`, one chip per
/// supported sport, showing the pair's read-time-decayed team ELO).
class _TeamEloChipsRow extends StatelessWidget {
  const _TeamEloChipsRow({required this.ratings});

  final List<RatingModel> ratings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final sportId in SportIds.supported) ...[
          if (sportId != SportIds.supported.first) const SizedBox(width: 8),
          Expanded(
            child: _TeamEloChip(
              sportId: sportId,
              rating: ratings.where((r) => r.sportId == sportId).firstOrNull,
            ),
          ),
        ],
      ],
    );
  }
}

class _TeamEloChip extends StatelessWidget {
  const _TeamEloChip({required this.sportId, required this.rating});

  final String sportId;
  final RatingModel? rating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final elo = rating == null
        ? null
        : const EloCalculator().decayedElo(
            elo: rating!.elo,
            lastMatchAt: rating!.lastMatchAt,
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(sportIcon(sportId), size: 16, color: colors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              localizedSportName(l10n, sportId),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            elo == null ? l10n.rankPlaceholder : '$elo',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.state});

  final TeamProfileState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // History is oriented from one member's perspective (opponentUids is
    // team-aware); the ELO delta reads the pairId key.
    final me = state.pairId.split('_').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.profileMatchHistoryTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: state.matches.isEmpty
              ? _HistoryEmpty(message: l10n.profileHistoryEmpty)
              : Column(
                  children: [
                    for (final match in state.matches)
                      ProfileHistoryTile(
                        match: match,
                        currentUid: me,
                        deltaKey: state.pairId,
                        opponentNames: state.opponentNames,
                        facilityNames: state.facilityNames,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Row(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 40, color: colors.error),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

extension _FirstWhereOrNull<E> on List<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
