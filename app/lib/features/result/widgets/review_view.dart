import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/match_model.dart';
import '../../../routing/route_constants.dart';
import '../cubit/result_cubit.dart';
import '../cubit/result_state.dart';
import 'result_score_card.dart';

/// The single review screen (`docs/design/screenshots/opponentconfirmation.png`)
/// in its two variants: the submitter sees the score card with a "waiting"
/// footer and no actions; the opponent sees Dispute / Confirm.
class ReviewView extends StatelessWidget {
  const ReviewView({super.key, required this.state});

  final ResultState state;

  bool get _isSubmitter => state.phase == ResultPhase.awaitingOpponent;

  /// The current user's side first, the opponents second. Doubles reads the
  /// stored pair ids (UIDs never contain `_`, so the split is safe); singles is
  /// simply the user vs the other player.
  (List<String>, List<String>) _sides(MatchModel match, String uid) {
    if (match.mode == 'doubles') {
      final t1 = match.team1PairId?.split('_') ?? const <String>[];
      final t2 = match.team2PairId?.split('_') ?? const <String>[];
      if (t1.contains(uid)) return (t1, t2);
      if (t2.contains(uid)) return (t2, t1);
    }
    return (
      [uid],
      [match.playerUids.firstWhere((u) => u != uid, orElse: () => '')],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ResultCubit>();
    final match = state.match!;
    final result = match.result;

    final uid = cubit.uid;
    final youWon = result?.winnerIds.contains(uid) ?? false;
    final (youUids, opponentUids) = _sides(match, uid);
    String nameOf(String u) => state.players[u] ?? '';
    final submittedBy = match.submittedByUid == uid
        ? l10n.resultSideYou
        : (state.players[match.submittedByUid] ?? '');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resultConfirmTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _leave(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SubmittedBanner(name: submittedBy),
                  const SizedBox(height: 16),
                  if (result != null)
                    ResultScoreCard(
                      result: result,
                      youWon: youWon,
                      youUids: youUids,
                      opponentUids: opponentUids,
                      youNames: [for (final u in youUids) nameOf(u)],
                      opponentNames: [for (final u in opponentUids) nameOf(u)],
                      youLabel: l10n.resultSideYou,
                      opponentLabel: opponentUids.length > 1
                          ? l10n.resultSideOpponents
                          : (opponentUids.isEmpty
                                ? l10n.resultSideOpponent
                                : nameOf(opponentUids.first)),
                      footer: _isSubmitter
                          ? Text(
                              l10n.resultWaitingConfirm,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _isSubmitter
          ? null
          : _ConfirmDisputeBar(state: state),
    );
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteConstants.home);
    }
  }
}

class _SubmittedBanner extends StatelessWidget {
  const _SubmittedBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.how_to_reg_outlined,
            size: 20,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.resultSubmittedBy(name),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmDisputeBar extends StatelessWidget {
  const _ConfirmDisputeBar({required this.state});

  final ResultState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ResultCubit>();
    final confirming = state.phase == ResultPhase.confirming;
    final disputing = state.phase == ResultPhase.disputing;
    final busy = confirming || disputing;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
              onPressed: busy ? null : () => _confirmDispute(context, cubit),
              child: disputing
                  ? const _ButtonSpinner()
                  : Text(l10n.resultDispute),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: busy ? null : cubit.confirm,
              child: confirming
                  ? const _ButtonSpinner()
                  : Text(l10n.resultConfirm),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDispute(BuildContext context, ResultCubit cubit) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.resultDisputeDialogTitle),
        content: Text(l10n.resultDisputeDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.resultDisputeDialogCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.resultDispute),
          ),
        ],
      ),
    );
    if (confirmed == true) cubit.dispute();
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
