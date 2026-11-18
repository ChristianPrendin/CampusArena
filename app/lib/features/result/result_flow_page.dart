import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/rating_repository.dart';
import '../../repositories/user_repository.dart';
import '../../routing/route_constants.dart';
import '../auth/cubit/auth_cubit.dart';
import 'cubit/result_cubit.dart';
import 'cubit/result_state.dart';
import 'widgets/result_message_view.dart';
import 'widgets/result_summary_view.dart';
import 'widgets/review_view.dart';
import 'widgets/score_entry_view.dart';

/// Entry point for the result flow (`/match/:id/result`). One deep-linkable
/// route that streams the match doc and renders the phase-appropriate view —
/// score entry, review/confirmation, summary, or a terminal close/error — never
/// three orphan screens. Repository parameters exist so tests inject fakes;
/// production defaults to the live Firestore-backed repositories.
class ResultFlowPage extends StatelessWidget {
  const ResultFlowPage({
    super.key,
    required this.matchId,
    this.matchRepository,
    this.ratingRepository,
    this.userRepository,
  });

  final String matchId;
  final MatchRepository? matchRepository;
  final RatingRepository? ratingRepository;
  final UserRepository? userRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = ResultCubit(
          uid: context.read<AuthCubit>().state.uid!,
          matchId: matchId,
          matchRepository: matchRepository,
          ratingRepository: ratingRepository,
          userRepository: userRepository,
        );
        cubit.load();
        return cubit;
      },
      child: const ResultFlowView(),
    );
  }
}

class ResultFlowView extends StatelessWidget {
  const ResultFlowView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ResultCubit, ResultState>(
      builder: (context, state) {
        switch (state.phase) {
          case ResultPhase.loading:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case ResultPhase.scoreEntry:
          case ResultPhase.submitting:
            return ScoreEntryView(state: state);
          case ResultPhase.awaitingOpponent:
          case ResultPhase.review:
          case ResultPhase.confirming:
          case ResultPhase.disputing:
            return ReviewView(state: state);
          case ResultPhase.summary:
            return ResultSummaryView(state: state);
          case ResultPhase.closed:
            return _ClosedView(state: state);
          case ResultPhase.error:
            return _ErrorView(state: state);
        }
      },
    );
  }
}

class _ClosedView extends StatelessWidget {
  const _ClosedView({required this.state});

  final ResultState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (
      IconData icon,
      String title,
      String body,
    ) = switch (state.closedKind) {
      ResultClosedKind.unconfirmed => (
        Icons.timer_off_outlined,
        l10n.resultClosedUnconfirmedTitle,
        l10n.resultClosedUnconfirmedBody,
      ),
      ResultClosedKind.abandoned => (
        Icons.do_not_disturb_on_outlined,
        l10n.resultClosedAbandonedTitle,
        l10n.resultClosedAbandonedBody,
      ),
      ResultClosedKind.disputed || null => (
        Icons.gavel_outlined,
        l10n.resultClosedDisputedTitle,
        l10n.resultClosedDisputedBody,
      ),
    };
    return ResultMessageView(
      icon: icon,
      title: title,
      body: body,
      actionLabel: l10n.matchClose,
      onAction: () => context.go(RouteConstants.home),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.state});

  final ResultState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResultMessageView(
      icon: Icons.error_outline,
      iconColor: Theme.of(context).colorScheme.error,
      title: l10n.resultErrorTitle,
      body: l10n.resultErrorBody,
      actionLabel: l10n.resultRetry,
      onAction: () => context.read<ResultCubit>().retry(),
    );
  }
}
