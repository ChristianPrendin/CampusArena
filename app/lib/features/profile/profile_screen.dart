import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/degree_programs.dart';
import '../../core/elo/elo_calculator.dart';
import '../../core/match_display.dart';
import '../../core/widgets/identity_avatar.dart';
import '../../l10n/app_localizations.dart';
import '../../models/rating_model.dart';
import '../../repositories/achievement_repository.dart';
import '../../repositories/facility_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/rating_repository.dart';
import '../../repositories/user_repository.dart';
import '../../routing/route_constants.dart';
import '../auth/cubit/auth_cubit.dart';
import 'cubit/profile_cubit.dart';
import 'cubit/profile_state.dart';
import 'widgets/achievement_grid.dart';
import 'widgets/elo_trend_card.dart';
import 'widgets/fun_stat_card.dart';
import 'widgets/profile_history_tile.dart';
import 'widgets/profile_stats_grid.dart';

/// The profile tab. With no [uid] it shows the signed-in user's own profile
/// (with the settings entry point); Phase 5/A's public-profile reuse passes a
/// foreign uid, which hides the gear.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    this.uid,
    this.ratingRepository,
    this.matchRepository,
    this.userRepository,
    this.facilityRepository,
    this.achievementRepository,
  });

  /// Whose profile to show; defaults to the signed-in user.
  final String? uid;

  final RatingRepository? ratingRepository;
  final MatchRepository? matchRepository;
  final UserRepository? userRepository;
  final FacilityRepository? facilityRepository;
  final AchievementRepository? achievementRepository;

  @override
  Widget build(BuildContext context) {
    final authUid = context.read<AuthCubit>().state.uid;
    final profileUid = uid ?? authUid!;
    return BlocProvider(
      create: (context) => ProfileCubit(
        uid: profileUid,
        ratingRepository: ratingRepository,
        matchRepository: matchRepository,
        userRepository: userRepository,
        facilityRepository: facilityRepository,
        achievementRepository: achievementRepository,
      ),
      child: ProfileView(isOwnProfile: profileUid == authUid),
    );
  }
}

class ProfileView extends StatelessWidget {
  const ProfileView({super.key, required this.isOwnProfile});

  /// The settings gear only exists on the user's own profile.
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTab),
        actions: [
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.profileSettingsTooltip,
              onPressed: () => context.push(RouteConstants.settings),
            ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            switch (state.status) {
              case ProfileStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case ProfileStatus.error:
                return _ErrorView(
                  message: l10n.profileLoadError,
                  retryLabel: l10n.retryButtonLabel,
                  onRetry: () => context.read<ProfileCubit>().retry(),
                );
              case ProfileStatus.ready:
                return _ProfileContent(state: state);
            }
          },
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.state});

  final ProfileState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProfileCubit>();
    final funStats = state.selectedFunStats;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProfileHeader(state: state),
            const SizedBox(height: 14),
            _EloChipsRow(ratings: state.ratings),
            const SizedBox(height: 14),
            EloTrendCard(
              selectedSportId: state.selectedSportId,
              points: state.selectedTrend,
              onSportSelected: cubit.selectSport,
            ),
            const SizedBox(height: 14),
            ProfileStatsGrid(stats: state.selectedStats),
            if (funStats.blackBeast != null ||
                funStats.favoriteVictim != null) ...[
              const SizedBox(height: 14),
              _FunStatsRow(state: state),
            ],
            if (state.achievementDefs.isNotEmpty) ...[
              const SizedBox(height: 20),
              AchievementGrid(
                defs: state.achievementDefs,
                badges: state.badges,
              ),
            ],
            const SizedBox(height: 20),
            _HistorySection(state: state, uid: cubit.uid),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.state});

  final ProfileState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = state.user!;
    return Column(
      children: [
        IdentityAvatar(
          seed: user.uid,
          initials: initialsFromName(user.name),
          radius: 42,
          fontSize: 30,
        ),
        const SizedBox(height: 10),
        Text(
          user.name,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.profileIdentityLine(
            user.username,
            localizeDegreeProgram(l10n, user.degreeProgram),
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EloChipsRow extends StatelessWidget {
  const _EloChipsRow({required this.ratings});

  final List<RatingModel> ratings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final sportId in SportIds.supported) ...[
          if (sportId != SportIds.supported.first) const SizedBox(width: 8),
          Expanded(
            child: _EloChip(
              sportId: sportId,
              rating: ratings.where((r) => r.sportId == sportId).firstOrNull,
            ),
          ),
        ],
      ],
    );
  }
}

class _EloChip extends StatelessWidget {
  const _EloChip({required this.sportId, required this.rating});

  final String sportId;
  final RatingModel? rating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Displayed ELO is always decayed at read time, never persisted (see
    // `brain/firestore_schema.md`; mirrors the dashboard hero card).
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

class _FunStatsRow extends StatelessWidget {
  const _FunStatsRow({required this.state});

  final ProfileState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final beast = state.selectedFunStats.blackBeast;
    final victim = state.selectedFunStats.favoriteVictim;
    return Row(
      children: [
        if (beast != null)
          Expanded(
            child: FunStatCard(
              title: l10n.profileBlackBeastTitle,
              icon: Icons.mood_bad_outlined,
              accent: colors.error,
              tally: beast,
              opponentName: state.opponentNames[beast.opponentUid],
            ),
          ),
        if (beast != null && victim != null) const SizedBox(width: 10),
        if (victim != null)
          Expanded(
            child: FunStatCard(
              title: l10n.profileFavoriteVictimTitle,
              icon: Icons.favorite_outline,
              accent: colors.primary,
              tally: victim,
              opponentName: state.opponentNames[victim.opponentUid],
            ),
          ),
      ],
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.state, required this.uid});

  final ProfileState state;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
                        currentUid: uid,
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
