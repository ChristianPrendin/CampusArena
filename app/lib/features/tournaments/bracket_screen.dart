import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/bracket/bracket_engine.dart';
import '../../core/constants.dart';
import '../../core/widgets/error_retry_view.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/facility_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/tournament_repository.dart';
import '../../repositories/user_repository.dart';
import '../../routing/route_constants.dart';
import '../auth/cubit/auth_cubit.dart';
import '../weather/widgets/forecast_strip.dart';
import 'cubit/tournament_cubit.dart';
import 'cubit/tournament_state.dart';
import 'tournament_ui.dart';

/// Live single-elimination bracket (design ref: `livebracket.png`): a back-arrow
/// app bar with the tournament name, an outdoor forecast strip, and
/// horizontally scrollable round columns of slot cards.
class BracketScreen extends StatelessWidget {
  const BracketScreen({
    super.key,
    required this.tournamentId,
    this.tournamentRepository,
    this.matchRepository,
    this.userRepository,
    this.facilityRepository,
  });

  final String tournamentId;
  final TournamentRepository? tournamentRepository;
  final MatchRepository? matchRepository;
  final UserRepository? userRepository;
  final FacilityRepository? facilityRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TournamentCubit(
        tournamentId: tournamentId,
        uid: context.read<AuthCubit>().state.uid!,
        tournamentRepository: tournamentRepository,
        matchRepository: matchRepository,
        userRepository: userRepository,
        facilityRepository: facilityRepository,
      )..load(),
      child: const BracketView(),
    );
  }
}

/// Bracket content, provided a [TournamentCubit] above it. Public so widget
/// tests can pump it with a driven cubit (see `LeaderboardView`).
class BracketView extends StatelessWidget {
  const BracketView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: BlocSelector<TournamentCubit, TournamentState, String>(
          selector: (state) => state.tournament?.name ?? '',
          builder: (_, name) => Text(name),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<TournamentCubit, TournamentState>(
          builder: (context, state) {
            switch (state.status) {
              case BracketStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case BracketStatus.error:
                return ErrorRetryView(
                  message: l10n.tournamentLoadError,
                  retryLabel: l10n.retryButtonLabel,
                  onRetry: () => context.read<TournamentCubit>().retry(),
                );
              case BracketStatus.ready:
                final tournament = state.tournament!;
                // Still open: the bracket is only seeded at the deadline (or
                // sooner if it fills), so show a placeholder until then.
                if (tournament.status == TournamentStatus.registering) {
                  return const _RegistrationOpen();
                }
                // Under-filled at the deadline: there is no bracket to show.
                if (tournament.status == TournamentStatus.cancelled) {
                  return const _Cancelled();
                }
                return _Bracket(state: state);
            }
          },
        ),
      ),
    );
  }
}

class _RegistrationOpen extends StatelessWidget {
  const _RegistrationOpen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.how_to_reg_outlined,
              size: 44,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              l10n.tournamentRegistrationOpenTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tournamentRegistrationOpenBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cancelled extends StatelessWidget {
  const _Cancelled();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 44,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              l10n.tournamentCancelledTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tournamentCancelledBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChampionBanner extends StatelessWidget {
  const _ChampionBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.emoji_events,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.tournamentCompletedBanner(name),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bracket extends StatelessWidget {
  const _Bracket({required this.state});

  final TournamentState state;

  /// Minimum vertical budget per first-round slot; the column grows past the
  /// viewport (and scrolls) only when a large bracket needs it.
  static const double _slotBudget = 72;

  @override
  Widget build(BuildContext context) {
    final tree = state.tree!;
    final tournament = state.tournament!;
    final facility = state.facility;
    final firstRoundSlots = tree.rounds.isEmpty
        ? 1
        : (tree.slots[tree.rounds.first]?.length ?? 1);
    final champion = tournament.status == TournamentStatus.completed
        ? tree.championUid
        : null;

    return Column(
      children: [
        if (champion != null)
          _ChampionBanner(name: state.names[champion] ?? _shortId(champion)),
        if (facility != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: ForecastStrip(
              coordinates: facility.coordinates,
              isOutdoor: facility.isOutdoor,
              scheduledAt: tournament.scheduledAt,
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = math.max(
                constraints.maxHeight,
                firstRoundSlots * _slotBudget,
              );
              return SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    height: height,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < tree.rounds.length; i++) ...[
                          if (i > 0) const SizedBox(width: 14),
                          _RoundColumn(
                            roundKey: tree.rounds[i],
                            isFinal: i == tree.rounds.length - 1,
                            slots: tree.slots[tree.rounds[i]] ?? const [],
                            state: state,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RoundColumn extends StatelessWidget {
  const _RoundColumn({
    required this.roundKey,
    required this.isFinal,
    required this.slots,
    required this.state,
  });

  final String roundKey;
  final bool isFinal;
  final List<BracketSlot> slots;
  final TournamentState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Text(
              tournamentRoundLabel(l10n, roundKey).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: isFinal ? colors.tertiary : colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final slot in slots)
                  _SlotCard(slot: slot, isFinal: isFinal, state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.isFinal,
    required this.state,
  });

  final BracketSlot slot;
  final bool isFinal;
  final TournamentState state;

  void _openMatch(BuildContext context) {
    final tournament = state.tournament;
    if (tournament == null) return;
    // The query params are consumed by 6-B's match flow; until that merges the
    // link degrades to a normal facility check-in.
    context.push(
      '${RouteConstants.facility(tournament.facilityId)}'
      '?tournamentId=${tournament.tournamentId}&round=${slot.round}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final uid = context.read<TournamentCubit>().uid;
    final mine = slot.isPlayable && (slot.a.uid == uid || slot.b.uid == uid);

    final decoration = BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isFinal ? colors.tertiary : colors.outlineVariant,
        width: isFinal ? 1.5 : 1,
      ),
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SideRow(
          side: slot.a,
          isWinner: slot.winnerUid != null && slot.winnerUid == slot.a.uid,
          names: state.names,
        ),
        Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
        _SideRow(
          side: slot.b,
          isWinner: slot.winnerUid != null && slot.winnerUid == slot.b.uid,
          names: state.names,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: mine
          ? InkWell(
              onTap: () => _openMatch(context),
              borderRadius: BorderRadius.circular(12),
              child: Ink(decoration: decoration, child: content),
            )
          : Container(decoration: decoration, child: content),
    );
  }
}

class _SideRow extends StatelessWidget {
  const _SideRow({
    required this.side,
    required this.isWinner,
    required this.names,
  });

  final BracketSide side;
  final bool isWinner;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    String text;
    TextStyle? style;
    if (side.isBye) {
      text = l10n.bracketBye;
      style = theme.textTheme.bodySmall?.copyWith(
        color: colors.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      );
    } else if (side.uid == null) {
      text = ' '; // TBD — a blank line keeps the card's two-row height.
      style = theme.textTheme.bodySmall;
    } else {
      text = names[side.uid!] ?? _shortId(side.uid!);
      style = isWinner
          ? theme.textTheme.bodySmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            )
          : theme.textTheme.bodySmall?.copyWith(color: colors.onSurface);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Short fallback for a not-yet-resolved display name.
String _shortId(String uid) =>
    uid.length <= 10 ? uid : '${uid.substring(0, 8)}…';
