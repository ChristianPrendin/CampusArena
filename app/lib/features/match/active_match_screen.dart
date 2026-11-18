import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart' show MatchModes, MatchStates, SportIds;
import '../../core/widgets/identity_avatar.dart';
import '../../l10n/app_localizations.dart';
import '../../routing/route_constants.dart';
import 'cubit/match_cubit.dart';
import 'cubit/match_state.dart';

/// The live game (and its terminal states), rendered from the streamed match
/// doc via [MatchCubit]. Matches `docs/design/screenshots/activegame.png`:
/// centred title, a pulsing "Live" badge, the sport label, a big monotonic
/// timer, the two player cards around a "VS", and the "Record result" CTA.
class ActiveMatchView extends StatelessWidget {
  const ActiveMatchView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<MatchCubit>().state;
    final match = state.match;
    final facility = state.facility;

    // Leaving must free the table (see [_leaveAndPop]), so intercept every pop
    // — the AppBar back button and the Android system back gesture alike.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveAndPop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(facility?.name ?? ''),
          // Explicit exit: on deep-link entry there is no back stack, so the
          // AppBar's implicit back button never appears and iOS has no system
          // back — without this the user is stranded on the match screen.
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => _leaveAndPop(context),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _StatusBadge(status: state.status),
                    const Spacer(),
                    Text(
                      _sportLabel(l10n, match?.sportId),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // The clock only makes sense once the match is live; while
                    // waiting for an opponent we show guidance instead.
                    if (state.status == MatchStatus.waitingOpponent)
                      _WaitingCaption(
                        isDoubles: match?.mode == MatchModes.doubles,
                      )
                    else
                      _MatchTimer(
                        startedAt: match?.startedAt,
                        running: state.status == MatchStatus.active,
                      ),
                    const Spacer(),
                    _PlayersRow(state: state),
                    const SizedBox(height: 20),
                    _BottomAction(state: state),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Leaves the match flow, first asking the cubit to free the table when this
/// device owns an in-progress check-in (a no-op otherwise). Shared by the back
/// button/gesture (via `PopScope`) and the terminal-state "Close" button.
///
/// When the leave would actually abandon a live match this device is part of,
/// it first confirms — a back swipe abandons the match for *both* players and
/// frees the table, so it shouldn't be silent. Leaving *before* an opponent has
/// joined only cancels this device's own solo check-in (a silent delete, no
/// abandon-for-both), so it skips the dialog; likewise spectating or a terminal
/// match (where [MatchCubit.leave] is a no-op) leaves immediately.
Future<void> _leaveAndPop(BuildContext context) async {
  final cubit = context.read<MatchCubit>();
  final match = cubit.state.match;
  final requiredPlayers = match?.mode == 'doubles' ? 4 : 2;
  final willAbandon =
      match != null &&
      match.state == MatchStates.occupied &&
      match.playerUids.contains(cubit.uid) &&
      match.playerUids.length >= requiredPlayers;

  if (willAbandon) {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.leaveMatchTitle),
        content: Text(l10n.leaveMatchMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.leaveMatchCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.leaveMatchConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
  }

  await cubit.leave();
  if (!context.mounted) return;
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(RouteConstants.home);
  }
}

/// The sport caption above the timer, reusing the dashboard's sport strings.
String _sportLabel(AppLocalizations l10n, String? sportId) {
  switch (sportId) {
    case SportIds.foosball:
      return l10n.sportFoosball;
    case SportIds.pingPong:
    default:
      return l10n.sportPingPong;
  }
}

/// A colour-coded status pill. Live states use the occupied/error role with a
/// pulsing dot; terminal states use a neutral/confirm colour without the pulse.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final MatchStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    final (Color color, String label, bool pulse) = switch (status) {
      MatchStatus.confirmed => (
        colors.primary,
        l10n.matchConfirmedStatus,
        false,
      ),
      MatchStatus.disputed => (colors.error, l10n.matchDisputedStatus, false),
      MatchStatus.ended => (
        colors.onSurfaceVariant,
        l10n.matchEndedStatus,
        false,
      ),
      MatchStatus.resultSubmitted => (
        colors.tertiary,
        l10n.matchResultSubmittedStatus,
        true,
      ),
      _ => (colors.error, l10n.matchLiveBadge, true),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse)
            _PulsingDot(color: color)
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.25).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// The elapsed-time readout off `match.startedAt`. Ticks once a second only
/// while [running] (the match is `active`); in every other state it shows a
/// frozen value — so the clock doesn't run while waiting for an opponent or
/// after a result is in.
class _MatchTimer extends StatefulWidget {
  const _MatchTimer({required this.startedAt, required this.running});

  final DateTime? startedAt;
  final bool running;

  @override
  State<_MatchTimer> createState() => _MatchTimerState();
}

class _MatchTimerState extends State<_MatchTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(_MatchTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resync on startedAt too, not just the running toggle: a deep-link/rejoin
    // mounts this already-running with startedAt still null (the cubit
    // pre-emits `active` before the match doc streams in), so the ticker must
    // start when startedAt finally arrives even though `running` never changed.
    if (widget.running != oldWidget.running ||
        widget.startedAt != oldWidget.startedAt) {
      _syncTicker();
    }
  }

  void _syncTicker() {
    _timer?.cancel();
    _timer = null;
    if (widget.running && widget.startedAt != null) {
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final started = widget.startedAt;
    final elapsed = started == null
        ? Duration.zero
        : DateTime.now().difference(started);
    return Text(
      _format(elapsed),
      style: Theme.of(context).textTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: 1,
      ),
    );
  }
}

/// Shown in the timer's place while waiting for an opponent: no running clock,
/// just guidance to have the opponent scan the same table.
class _WaitingCaption extends StatelessWidget {
  const _WaitingCaption({this.isDoubles = false});

  final bool isDoubles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Text(
        isDoubles
            ? l10n.matchWaitingPlayersBody
            : l10n.matchWaitingOpponentBody,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The two player cards separated by "VS". The opponent slot shows a
/// "waiting for opponent" placeholder until a second player has checked in.
class _PlayersRow extends StatelessWidget {
  const _PlayersRow({required this.state});

  final MatchState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = context.read<MatchCubit>().uid;
    final match = state.match;
    final players = match?.playerUids ?? const [];

    if (match?.mode == MatchModes.doubles) {
      return _DoublesPlayersRow(state: state, me: me);
    }

    // Always render the current user on the left; the first other player (if
    // any) on the right, otherwise a waiting placeholder.
    final others = players.where((p) => p != me).toList();
    final opponentUid = others.isEmpty ? null : others.first;

    // IntrinsicHeight bounds the Row's cross-axis extent so the two cards can
    // stretch to equal heights without demanding infinite height from the
    // surrounding (Spacer-driven) Column.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _PlayerCard(display: state.players[me], uid: me),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              l10n.matchVs,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: opponentUid == null
                ? const _WaitingOpponentCard()
                : _PlayerCard(
                    display: state.players[opponentUid],
                    uid: opponentUid,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.uid, this.display});

  final String uid;
  final PlayerDisplay? display;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = display?.name;
    final elo = display?.elo;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IdentityAvatar(
              seed: uid,
              initials: initialsFromName(name),
              radius: 26,
              fontSize: 18,
            ),
            const SizedBox(height: 8),
            Text(
              name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              elo == null ? '' : l10n.matchEloValue(elo),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingOpponentCard extends StatelessWidget {
  const _WaitingOpponentCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.hourglass_empty,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.matchWaitingOpponentTitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Doubles roster: Team 1 vs Team 2, up to two members a side. Empty slots are
/// tappable "Join" buttons while the current user is not yet on the roster (each
/// calls [MatchCubit.joinSide]); once rostered they become waiting placeholders.
class _DoublesPlayersRow extends StatelessWidget {
  const _DoublesPlayersRow({required this.state, required this.me});

  final MatchState state;
  final String me;

  static List<String> _members(String? pairId) =>
      (pairId == null || pairId.isEmpty) ? const [] : pairId.split('_');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final match = state.match;
    final team1 = _members(match?.team1PairId);
    final team2 = _members(match?.team2PairId);
    final amRostered = (match?.playerUids ?? const []).contains(me);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TeamColumn(
              label: l10n.matchTeam1,
              members: team1,
              me: me,
              players: state.players,
              canJoin: !amRostered && team1.length < 2,
              team: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              l10n.matchVs,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: _TeamColumn(
              label: l10n.matchTeam2,
              members: team2,
              me: me,
              players: state.players,
              canJoin: !amRostered && team2.length < 2,
              team: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({
    required this.label,
    required this.members,
    required this.me,
    required this.players,
    required this.canJoin,
    required this.team,
  });

  final String label;
  final List<String> members;
  final String me;
  final Map<String, PlayerDisplay> players;
  final bool canJoin;
  final int team;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          if (i < members.length)
            _TeamMemberTile(
              uid: members[i],
              display: players[members[i]],
              isMe: members[i] == me,
            )
          else if (canJoin)
            _JoinSlot(team: team)
          else
            const _WaitingSlot(),
        ],
      ],
    );
  }
}

class _TeamMemberTile extends StatelessWidget {
  const _TeamMemberTile({required this.uid, required this.isMe, this.display});

  final String uid;
  final bool isMe;
  final PlayerDisplay? display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = display?.name;
    return Card(
      shape: isMe
          ? RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            IdentityAvatar(
              seed: uid,
              initials: initialsFromName(name),
              radius: 16,
              fontSize: 12,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinSlot extends StatelessWidget {
  const _JoinSlot({required this.team});

  final int team;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      icon: const Icon(Icons.add, size: 18),
      label: Text(l10n.matchPickSideTitle),
      onPressed: () => context.read<MatchCubit>().joinSide(team),
    );
  }
}

class _WaitingSlot extends StatelessWidget {
  const _WaitingSlot();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.hourglass_empty,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context).matchWaitingOpponentTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bottom CTA: "Record result" while the game is live, a "Close" affordance
/// once the streamed match reaches a terminal state.
class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.state});

  final MatchState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final matchId = state.match?.matchId;

    void openResult() => context.push(
      RouteConstants.matchResultPath.replaceFirst(':id', matchId!),
    );

    switch (state.status) {
      case MatchStatus.active:
      case MatchStatus.waitingOpponent:
        final canRecord = state.status == MatchStatus.active && matchId != null;
        return FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: Theme.of(context).textTheme.titleMedium,
          ),
          icon: const Icon(Icons.scoreboard_outlined),
          label: Text(l10n.matchRecordResult),
          onPressed: canRecord ? openResult : null,
        );
      case MatchStatus.resultSubmitted:
        // A result is in; the flow route shows either the review (opponent's
        // turn) or the "waiting for confirmation" status (submitter's turn).
        final iSubmitted =
            state.match?.submittedByUid == context.read<MatchCubit>().uid;
        return FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: Theme.of(context).textTheme.titleMedium,
          ),
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(
            iSubmitted ? l10n.matchViewStatus : l10n.matchReviewResult,
          ),
          onPressed: matchId != null ? openResult : null,
        );
      case MatchStatus.confirmed:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: Theme.of(context).textTheme.titleMedium,
          ),
          icon: const Icon(Icons.emoji_events_outlined),
          label: Text(l10n.matchViewSummary),
          onPressed: matchId != null ? openResult : null,
        );
      case MatchStatus.disputed:
      case MatchStatus.ended:
      default:
        return OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: () => _leaveAndPop(context),
          child: Text(l10n.matchClose),
        );
    }
  }
}
