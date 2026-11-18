import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/error_retry_view.dart';
import '../../l10n/app_localizations.dart';
import '../../models/match_model.dart';
import '../../repositories/challenge_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/rating_repository.dart';
import '../../repositories/user_repository.dart';
import '../../routing/route_constants.dart';
import '../auth/cubit/auth_cubit.dart';
import '../challenges/cubit/challenge_cubit.dart';
import '../challenges/widgets/challenge_section.dart';
import 'cubit/dashboard_cubit.dart';
import 'cubit/dashboard_state.dart';
import 'widgets/assistant_entry_card.dart';
import 'widgets/elo_hero_card.dart';
import 'widgets/recent_match_tile.dart';
import 'widgets/sport_selector.dart';

/// Below this shortest-side extent the dashboard is a single scrolling column;
/// at or above it the ELO summary and recent activity sit side by side (per the
/// design's tablet split). Gauged on the device's shortest side (not the content
/// width) so a phone in landscape — wide but short — keeps the single column
/// rather than a split that leaves dead space below the shorter column.
const double _tabletBreakpoint = 600;

/// How many recent matches the history list shows per sport.
const int _historyDisplayCount = 5;

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.ratingRepository,
    this.matchRepository,
    this.userRepository,
    this.challengeRepository,
  });

  final RatingRepository? ratingRepository;
  final MatchRepository? matchRepository;
  final UserRepository? userRepository;
  final ChallengeRepository? challengeRepository;

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthCubit>().state.uid!;
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => DashboardCubit(
            uid: uid,
            ratingRepository: ratingRepository,
            matchRepository: matchRepository,
            userRepository: userRepository,
          ),
        ),
        BlocProvider(
          create: (context) => ChallengeCubit(
            uid: uid,
            challengeRepository: challengeRepository,
            userRepository: userRepository,
            matchRepository: matchRepository,
          ),
        ),
      ],
      child: const HomeView(),
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTab),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events),
            tooltip: l10n.tournamentsTooltip,
            // The only tournaments entry in the app (team decision: no 5th nav
            // tab, no Home body card). Pushes on the root navigator so the
            // browser opens full-screen over the shell. No design counterpart —
            // precedent: the map recenter button.
            onPressed: () => context.push(RouteConstants.tournaments),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            switch (state.status) {
              case DashboardStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case DashboardStatus.error:
                return ErrorRetryView(
                  message: l10n.dashboardLoadError,
                  retryLabel: l10n.retryButtonLabel,
                  onRetry: () => context.read<DashboardCubit>().retry(),
                );
              case DashboardStatus.ready:
                final isTablet =
                    MediaQuery.sizeOf(context).shortestSide >=
                    _tabletBreakpoint;
                return isTablet
                    ? _TabletDashboard(state: state)
                    : _PhoneDashboard(state: state);
            }
          },
        ),
      ),
    );
  }
}

/// The last ELO change for [state]'s selected sport, from the most recent
/// confirmed match in the loaded window; null if there is none.
int? _lastDelta(DashboardState state, String uid) {
  for (final match in state.selectedRecentMatches) {
    if (match.state == MatchStates.confirmed) {
      final delta = match.eloDeltas?[uid];
      if (delta != null) return delta;
    }
  }
  return null;
}

class _PhoneDashboard extends StatelessWidget {
  const _PhoneDashboard({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    final matches = state.selectedRecentMatches
        .take(_historyDisplayCount)
        .toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SportSelector(
              selectedSportId: state.selectedSportId,
              onSelected: cubit.selectSport,
            ),
            const SizedBox(height: 14),
            EloHeroCard(
              rating: state.selectedRating,
              sportId: state.selectedSportId,
              lastDelta: _lastDelta(state, cubit.uid),
            ),
            const SizedBox(height: 14),
            _PlayButton(),
            const SizedBox(height: 14),
            // Renders nothing when there are no challenges (design's Home shows
            // no challenge empty-state), so the gap above collapses to one.
            const ChallengeSection(),
            AssistantEntryCard(onTap: () => _openAssistant(context)),
            const SizedBox(height: 20),
            _RecentHeader(),
            const SizedBox(height: 4),
            Card(
              clipBehavior: Clip.antiAlias,
              child: _RecentList(
                matches: matches,
                state: state,
                uid: cubit.uid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabletDashboard extends StatelessWidget {
  const _TabletDashboard({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    final matches = state.selectedRecentMatches
        .take(_historyDisplayCount)
        .toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: ELO summary. Scrolls so the challenge section (up to 5
              // incoming cards + outgoing rows) can't overflow the fixed-height
              // split on a short landscape tablet.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SportSelector(
                        selectedSportId: state.selectedSportId,
                        onSelected: cubit.selectSport,
                      ),
                      const SizedBox(height: 14),
                      EloHeroCard(
                        rating: state.selectedRating,
                        sportId: state.selectedSportId,
                        lastDelta: _lastDelta(state, cubit.uid),
                      ),
                      const SizedBox(height: 14),
                      _PlayButton(),
                      const SizedBox(height: 14),
                      const ChallengeSection(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Right: recent activity.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AssistantEntryCard(onTap: () => _openAssistant(context)),
                    const SizedBox(height: 16),
                    _RecentHeader(),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: _RecentList(
                          matches: matches,
                          state: state,
                          uid: cubit.uid,
                          scrollable: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _openAssistant(BuildContext context) {
  context.push(RouteConstants.chatbot);
}

class _PlayButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        textStyle: Theme.of(context).textTheme.titleMedium,
      ),
      icon: const Icon(Icons.qr_code_scanner),
      label: Text(l10n.playButtonLabel),
      // Phase 4B: open the QR check-in flow (blind scanner).
      onPressed: () => context.push(RouteConstants.qrScan),
    );
  }
}

class _RecentHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.recentMatchesTitle,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({
    required this.matches,
    required this.state,
    required this.uid,
    this.scrollable = false,
  });

  final List<MatchModel> matches;
  final DashboardState state;
  final String uid;

  /// When true (tablet card) the list scrolls on its own; on the phone it is
  /// non-scrolling because the whole page already scrolls.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (matches.isEmpty) {
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
                l10n.noRecentMatches,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: !scrollable,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      itemCount: matches.length,
      itemBuilder: (context, i) => RecentMatchTile(
        match: matches[i],
        currentUid: uid,
        opponentNames: state.opponentNames,
      ),
    );
  }
}
