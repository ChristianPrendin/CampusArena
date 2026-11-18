import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/match_display.dart';
import '../../../core/widgets/identity_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/challenge_model.dart';
import '../../../repositories/challenge_repository.dart';
import '../../../routing/route_constants.dart';
import '../challenge_respond_copy.dart';
import '../cubit/challenge_cubit.dart';
import '../cubit/challenge_state.dart';

/// The Dashboard's direct-challenges block: incoming pending challenges as
/// accept/decline cards (design's "challenge banner"), followed by a compact
/// list of the user's recent outgoing challenges with status chips.
///
/// Consumes the [ChallengeCubit] provided by [HomeScreen]. Collapses to nothing
/// when both lists are empty — the design's Home shows no challenge empty-state.
/// A newly arrived incoming challenge raises an in-app SnackBar + heavy haptic
/// (the client-local alert; see [ChallengeCubit]).
class ChallengeSection extends StatelessWidget {
  const ChallengeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MultiBlocListener(
      listeners: [
        BlocListener<ChallengeCubit, ChallengeState>(
          listenWhen: (prev, curr) => curr.alertNonce > prev.alertNonce,
          listener: (context, state) {
            HapticFeedback.heavyImpact();
            final name = state.alertName ?? l10n.challengePlayerFallback;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(l10n.challengeReceivedSnack(name))),
              );
          },
        ),
        BlocListener<ChallengeCubit, ChallengeState>(
          listenWhen: (prev, curr) =>
              curr.actionErrorNonce > prev.actionErrorNonce,
          listener: (context, state) {
            final reason =
                state.actionError ?? ChallengeRespondError.unavailable;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(challengeRespondErrorMessage(l10n, reason)),
                ),
              );
          },
        ),
      ],
      child: BlocBuilder<ChallengeCubit, ChallengeState>(
        builder: (context, state) {
          if (state.isEmpty) return const SizedBox.shrink();
          final cubit = context.read<ChallengeCubit>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final challenge in state.incoming)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _IncomingCard(
                    challenge: challenge,
                    challengerName: state.nameOf(challenge.fromUserId),
                    // On a successful accept the pending card leaves the inbox;
                    // open the challenge's "scan to play" screen so the recipient
                    // has a clear next step instead of the card just vanishing.
                    onAccept: () async {
                      final accepted = await cubit.accept(
                        challenge.challengeId,
                      );
                      if (accepted && context.mounted) {
                        context.push(
                          RouteConstants.challenge(challenge.challengeId),
                        );
                      }
                    },
                    onDecline: () => cubit.decline(challenge.challengeId),
                  ),
                ),
              if (state.outgoing.isNotEmpty) ...[
                const SizedBox(height: 2),
                _OutgoingHeader(),
                const SizedBox(height: 4),
                for (final challenge in state.outgoing)
                  _OutgoingRow(
                    challenge: challenge,
                    counterpartName: state.nameOf(challenge.toUserId),
                  ),
              ],
              const SizedBox(height: 14),
            ],
          );
        },
      ),
    );
  }
}

/// Incoming pending challenge: secondary-container card with the challenger's
/// avatar, name over "challenged you to {sport}", and round accept/decline
/// buttons. Mirrors the design's Section B challenge banner.
class _IncomingCard extends StatelessWidget {
  const _IncomingCard({
    required this.challenge,
    required this.challengerName,
    required this.onAccept,
    required this.onDecline,
  });

  final ChallengeModel challenge;
  final String? challengerName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = challengerName ?? l10n.challengePlayerFallback;
    final sport = localizedSportName(l10n, challenge.sportId);

    return Container(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IdentityAvatar(
            seed: challenge.fromUserId,
            initials: initialsFromName(name),
            radius: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.challengeChallengedYou(sport),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSecondaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onAccept,
            icon: const Icon(Icons.check, size: 20),
            tooltip: l10n.challengeAcceptTooltip,
            style: IconButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
            ),
          ),
          const SizedBox(width: 6),
          IconButton.outlined(
            onPressed: onDecline,
            icon: const Icon(Icons.close, size: 20),
            tooltip: l10n.challengeDeclineTooltip,
            style: IconButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
              side: BorderSide(color: colors.outline),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutgoingHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Text(
      l10n.challengeOutgoingSectionTitle,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Compact outgoing-challenge row: counterpart + sport with a status chip. An
/// accepted row is tappable — the players coordinate offline, then start via
/// the standard QR check-in (no in-app scheduling, per the Decision Log).
class _OutgoingRow extends StatelessWidget {
  const _OutgoingRow({required this.challenge, required this.counterpartName});

  final ChallengeModel challenge;
  final String? counterpartName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = counterpartName ?? l10n.challengePlayerFallback;
    final accepted = challenge.status == ChallengeStatus.accepted;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Row(
        children: [
          Icon(
            sportIcon(challenge.sportId),
            size: 18,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.challengeOutgoingLabel(name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          _StatusChip(status: challenge.status),
          if (accepted) ...[
            const SizedBox(width: 4),
            Icon(Icons.qr_code_scanner, size: 18, color: colors.primary),
          ],
        ],
      ),
    );

    if (!accepted) return row;
    return InkWell(
      onTap: () => context.push(RouteConstants.qrScan),
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final (Color bg, Color fg, String label) = switch (status) {
      ChallengeStatus.accepted => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
        l10n.challengeStatusAccepted,
      ),
      ChallengeStatus.declined => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
        l10n.challengeStatusDeclined,
      ),
      ChallengeStatus.expired => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
        l10n.challengeStatusExpired,
      ),
      _ => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
        l10n.challengeStatusWaiting,
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
