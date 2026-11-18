import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/match_display.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/error_retry_view.dart';
import '../../core/widgets/identity_avatar.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/rating_repository.dart';
import '../../repositories/tournament_repository.dart';
import '../../repositories/user_repository.dart';
import '../../routing/route_constants.dart';
import '../auth/cubit/auth_cubit.dart';
import 'cubit/tournament_detail_cubit.dart';
import 'cubit/tournament_detail_state.dart';
import 'tournament_ui.dart';
import 'widgets/organizer_sheets.dart';

const double _contentMaxWidth = 640;

class TournamentDetailScreen extends StatelessWidget {
  const TournamentDetailScreen({
    super.key,
    required this.tournamentId,
    this.tournamentRepository,
    this.matchRepository,
    this.userRepository,
    this.ratingRepository,
  });

  final String tournamentId;
  final TournamentRepository? tournamentRepository;
  final MatchRepository? matchRepository;
  final UserRepository? userRepository;
  final RatingRepository? ratingRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TournamentDetailCubit(
        tournamentId: tournamentId,
        uid: context.read<AuthCubit>().state.uid!,
        tournamentRepository: tournamentRepository,
        matchRepository: matchRepository,
        userRepository: userRepository,
        ratingRepository: ratingRepository,
      )..init(),
      child: const TournamentDetailView(),
    );
  }
}

class TournamentDetailView extends StatelessWidget {
  const TournamentDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<TournamentDetailCubit, TournamentDetailState>(
      builder: (context, state) {
        final title = state.tournament?.name ?? l10n.tournamentsTitle;
        final canCancel =
            state.isOrganizer &&
            state.tournament?.status == TournamentStatus.registering;

        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: Text(title),
            actions: [
              if (canCancel)
                PopupMenuButton<void>(
                  itemBuilder: (menuContext) => [
                    PopupMenuItem<void>(
                      onTap: () => _confirmCancel(context),
                      child: Text(l10n.tournamentCancelAction),
                    ),
                  ],
                ),
            ],
          ),
          body: SafeArea(
            child: switch (state.status) {
              TournamentDetailStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              TournamentDetailStatus.error => ErrorRetryView(
                message: l10n.tournamentDetailError,
                retryLabel: l10n.retryButtonLabel,
                onRetry: () => context.read<TournamentDetailCubit>().retry(),
              ),
              TournamentDetailStatus.ready => _ReadyBody(state: state),
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final cubit = context.read<TournamentDetailCubit>();
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.tournamentCancelTitle,
      message: l10n.tournamentCancelBody,
      confirmLabel: l10n.tournamentCancelConfirm,
      cancelLabel: l10n.tournamentCancelDismiss,
      isDestructive: true,
    );
    if (confirmed) await cubit.cancel();
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.state});

  final TournamentDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tournament = state.tournament!;
    final isRegistering = tournament.status == TournamentStatus.registering;
    final showOrganizerControls =
        state.isOrganizer &&
        (tournament.status == TournamentStatus.seeded ||
            tournament.status == TournamentStatus.active);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _MetaRow(state: state),
            const SizedBox(height: 14),
            Text(
              l10n.tournamentStandings,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _StandingsCard(standings: state.standings),
            const SizedBox(height: 16),
            if (isRegistering) ...[
              _RegisterBar(state: state),
              const SizedBox(height: 12),
            ] else if (showOrganizerControls) ...[
              Text(
                l10n.tournamentOrganizerControls,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _OrganizerControls(state: state),
              const SizedBox(height: 12),
            ],
            _BracketButton(tournamentId: tournament.tournamentId),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.state});

  final TournamentDetailState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tournament = state.tournament!;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Row(
      children: [
        TournamentStatusPill(status: tournament.status),
        const SizedBox(width: 12),
        Icon(
          sportIcon(tournament.sportId),
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(localizedSportName(l10n, tournament.sportId), style: muted),
        const SizedBox(width: 14),
        Icon(Icons.group, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          '${state.participants.length}/${tournament.maxParticipants}',
          style: muted,
        ),
      ],
    );
  }
}

class _StandingsCard extends StatelessWidget {
  const _StandingsCard({required this.standings});

  final List<StandingEntry> standings;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < standings.length; i++)
              _StandingRow(rank: i + 1, entry: standings[i]),
          ],
        ),
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.rank, required this.entry});

  final int rank;
  final StandingEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 30,
            height: 30,
            child: entry.name == null
                ? null
                : IdentityAvatar(
                    seed: entry.uid,
                    initials: initialsFromName(entry.name),
                    radius: 15,
                    fontSize: 11,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.name ?? entry.uid,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (entry.elo != null)
            Text(
              '${entry.elo}',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
    // Eliminated players are dimmed and sorted last.
    return Opacity(opacity: entry.eliminated ? 0.45 : 1, child: row);
  }
}

class _OrganizerControls extends StatelessWidget {
  const _OrganizerControls({required this.state});

  final TournamentDetailState state;

  Map<String, String?> _names() => {
    for (final s in state.standings) s.uid: s.name,
  };

  Future<void> _advance(BuildContext context) async {
    final cubit = context.read<TournamentDetailCubit>();
    final choice = await showAdvanceSheet(
      context: context,
      playableSlots: state.playableSlots,
      names: _names(),
    );
    if (choice != null) await cubit.advanceSlot(choice.slot, choice.winnerUid);
  }

  Future<void> _forfeit(BuildContext context) async {
    final cubit = context.read<TournamentDetailCubit>();
    final uid = await showForfeitSheet(
      context: context,
      alive: state.aliveStandings,
    );
    if (uid != null) await cubit.markForfeit(uid);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _advance(context),
            icon: Icon(Icons.skip_next, color: theme.colorScheme.primary),
            label: Text(l10n.tournamentAdvanceSlot),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _forfeit(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
            icon: const Icon(Icons.flag),
            label: Text(l10n.tournamentMarkForfeit),
          ),
        ),
      ],
    );
  }
}

class _RegisterBar extends StatelessWidget {
  const _RegisterBar({required this.state});

  final TournamentDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TournamentDetailCubit>();
    final tournament = state.tournament!;
    final registered = state.participants.any((p) => p.uid == cubit.uid);
    final full = state.participants.length >= tournament.maxParticipants;

    final (String label, VoidCallback? onPressed) = switch ((
      registered,
      full,
    )) {
      (true, _) => (l10n.tournamentRegistered, null),
      (false, true) => (l10n.tournamentFull, null),
      (false, false) => (
        l10n.tournamentRegister,
        () => _register(context, cubit),
      ),
    };

    return SizedBox(
      width: double.infinity,
      child: FilledButton(onPressed: onPressed, child: Text(label)),
    );
  }

  Future<void> _register(
    BuildContext context,
    TournamentDetailCubit cubit,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await cubit.register();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok ? l10n.tournamentRegisteredSnack : l10n.tournamentRegisterError,
          ),
        ),
      );
  }
}

class _BracketButton extends StatelessWidget {
  const _BracketButton({required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: () =>
            context.push(RouteConstants.tournamentBracket(tournamentId)),
        icon: const Icon(Icons.account_tree),
        label: Text(l10n.tournamentBracket),
      ),
    );
  }
}
