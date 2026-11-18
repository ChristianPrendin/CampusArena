import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/error_retry_view.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/facility_repository.dart';
import '../../repositories/tournament_repository.dart';
import '../../routing/route_constants.dart';
import 'cubit/tournament_browser_cubit.dart';
import 'cubit/tournament_browser_state.dart';
import 'widgets/tournament_card.dart';
import 'widgets/tournament_sport_filter.dart';

/// Content is centred and width-constrained on larger canvases (no bespoke
/// split-view — only Map and Dashboard get those).
const double _contentMaxWidth = 640;

class TournamentBrowserScreen extends StatelessWidget {
  const TournamentBrowserScreen({
    super.key,
    this.tournamentRepository,
    this.facilityRepository,
  });

  final TournamentRepository? tournamentRepository;
  final FacilityRepository? facilityRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TournamentBrowserCubit(
        tournamentRepository: tournamentRepository,
        facilityRepository: facilityRepository,
      )..init(),
      child: const TournamentBrowserView(),
    );
  }
}

class TournamentBrowserView extends StatelessWidget {
  const TournamentBrowserView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.tournamentsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle),
            color: Theme.of(context).colorScheme.primary,
            tooltip: l10n.tournamentsTitle,
            onPressed: () => context.push(RouteConstants.tournamentCreate),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<TournamentBrowserCubit, TournamentBrowserState>(
          builder: (context, state) {
            switch (state.status) {
              case TournamentBrowserStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case TournamentBrowserStatus.error:
                return ErrorRetryView(
                  message: l10n.tournamentsLoadError,
                  retryLabel: l10n.retryButtonLabel,
                  onRetry: () => context.read<TournamentBrowserCubit>().retry(),
                );
              case TournamentBrowserStatus.ready:
                return _ReadyBody(state: state);
            }
          },
        ),
      ),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.state});

  final TournamentBrowserState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TournamentBrowserCubit>();
    final isEmpty = state.upcoming.isEmpty && state.ongoing.isEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            TournamentSportFilter(
              selectedSportId: state.selectedSportId,
              onSelected: cubit.selectSport,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: isEmpty
                  ? _EmptyState(l10n: l10n)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        if (state.upcoming.isNotEmpty) ...[
                          _SectionHeader(label: l10n.tournamentsUpcoming),
                          for (final t in state.upcoming)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: UpcomingTournamentCard(
                                tournament: t,
                                info: state.infoFor(t.tournamentId),
                                onTap: () => context.push(
                                  RouteConstants.tournamentDetail(
                                    t.tournamentId,
                                  ),
                                ),
                              ),
                            ),
                        ],
                        if (state.ongoing.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _SectionHeader(label: l10n.tournamentsOngoing),
                          for (final t in state.ongoing)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: OngoingTournamentCard(
                                tournament: t,
                                onTap: () => context.push(
                                  RouteConstants.tournamentDetail(
                                    t.tournamentId,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              l10n.tournamentsEmptyTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.tournamentsEmptyBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
