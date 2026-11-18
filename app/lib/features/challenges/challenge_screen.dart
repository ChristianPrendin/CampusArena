import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/match_display.dart';
import '../../core/widgets/error_retry_view.dart';
import '../../core/widgets/identity_avatar.dart';
import '../../l10n/app_localizations.dart';
import '../../models/challenge_model.dart';
import '../../repositories/challenge_repository.dart';
import '../../repositories/user_repository.dart';
import '../../routing/route_constants.dart';
import '../auth/cubit/auth_cubit.dart';
import 'challenge_respond_copy.dart';

/// The `/challenge/:id` deep-link screen (root navigator, outside the shell —
/// kept working so a future Blaze-tier push can target it directly).
///
/// State is ephemeral to this single view (one streamed doc + one name lookup),
/// so it is managed by a [StatefulWidget] rather than the feature's uid-scoped
/// [ChallengeCubit]. The recipient (`toUserId`) sees the accept/decline prompt;
/// the sender a waiting state; terminal statuses render their status. Per the
/// Decision Log there is no in-app scheduling: on accept the screen surfaces a
/// "Scan to play" CTA into the standard QR check-in.
class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({
    super.key,
    required this.challengeId,
    this.challengeRepository,
    this.userRepository,
  });

  final String challengeId;
  final ChallengeRepository? challengeRepository;
  final UserRepository? userRepository;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  late final ChallengeRepository _challengeRepository =
      widget.challengeRepository ?? ChallengeRepository();
  late final UserRepository _userRepository =
      widget.userRepository ?? UserRepository();

  StreamSubscription<ChallengeModel?>? _subscription;

  ChallengeModel? _challenge;
  bool _loading = true;
  bool _error = false;

  /// Resolved counterpart display name (the other party from the viewer).
  String? _counterpartName;
  String? _resolvedCounterpartUid;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    setState(() {
      _loading = true;
      _error = false;
    });
    _subscription?.cancel();
    _subscription = _challengeRepository
        .watchChallenge(widget.challengeId)
        .listen(
          _onChallenge,
          onError: (_) => setState(() {
            _loading = false;
            _error = true;
          }),
        );
  }

  String get _uid => context.read<AuthCubit>().state.uid ?? '';

  void _onChallenge(ChallengeModel? challenge) {
    if (!mounted) return;
    setState(() {
      _challenge = challenge;
      _loading = false;
      _error = false;
    });
    if (challenge != null) _resolveCounterpart(challenge);
  }

  Future<void> _resolveCounterpart(ChallengeModel challenge) async {
    final counterpartUid = challenge.toUserId == _uid
        ? challenge.fromUserId
        : challenge.toUserId;
    if (counterpartUid.isEmpty || counterpartUid == _resolvedCounterpartUid) {
      return;
    }
    _resolvedCounterpartUid = counterpartUid;
    try {
      final users = await _userRepository.getUsersByIds([counterpartUid]);
      if (!mounted || users.isEmpty) return;
      setState(() => _counterpartName = users.first.name);
    } catch (_) {
      // Name is decorative; the fallback copy stands in.
    }
  }

  Future<void> _respond({required bool accept}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _challengeRepository.respond(
        challengeId: widget.challengeId,
        accept: accept,
      );
      // The stream re-emits the new status; no local mutation needed.
    } on ChallengeRespondException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(challengeRespondErrorMessage(l10n, e.reason))),
        );
    } catch (_) {
      // Untyped failure: treat as retryable rather than a misleading expiry.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.challengeActionUnavailable)),
        );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.challengeScreenTitle)),
      body: SafeArea(child: Center(child: _buildBody(context, l10n))),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_loading) return const CircularProgressIndicator();
    if (_error) {
      return ErrorRetryView(
        message: l10n.challengeLoadError,
        retryLabel: l10n.retryButtonLabel,
        onRetry: _subscribe,
      );
    }
    final challenge = _challenge;
    if (challenge == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(l10n.challengeNotFound, textAlign: TextAlign.center),
      );
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = _counterpartName ?? l10n.challengePlayerFallback;
    final sport = localizedSportName(l10n, challenge.sportId);
    final isRecipient = challenge.toUserId == _uid;
    final isPending = challenge.status == ChallengeStatus.pending;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  IdentityAvatar(
                    seed: isRecipient
                        ? challenge.fromUserId
                        : challenge.toUserId,
                    initials: initialsFromName(name),
                    radius: 30,
                    fontSize: 18,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isRecipient
                        ? l10n.challengeChallengedYou(sport)
                        : l10n.challengeOutgoingLabel(name),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSecondaryContainer.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ..._buildActions(context, l10n, challenge, isRecipient, isPending),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    AppLocalizations l10n,
    ChallengeModel challenge,
    bool isRecipient,
    bool isPending,
  ) {
    // Guard: only the recipient ever gets the accept/decline actions.
    if (isPending && isRecipient) {
      return [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _respond(accept: false),
                icon: const Icon(Icons.close, size: 20),
                label: Text(l10n.challengeDecline),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _respond(accept: true),
                icon: const Icon(Icons.check, size: 20),
                label: Text(l10n.challengeAccept),
              ),
            ),
          ],
        ),
      ];
    }

    if (isPending) {
      // Sender's waiting state.
      final name = _counterpartName ?? l10n.challengePlayerFallback;
      return [
        _StatusBanner(
          icon: Icons.hourglass_top,
          title: l10n.challengeWaitingTitle(name),
          body: l10n.challengeWaitingBody,
        ),
      ];
    }

    if (challenge.status == ChallengeStatus.accepted) {
      return [
        _StatusBanner(
          icon: Icons.check_circle,
          title: l10n.challengeStatusAccepted,
          body: l10n.challengeAcceptedCta,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () =>
              context.push(RouteConstants.qrScanForSport(challenge.sportId)),
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(l10n.challengeScanToPlay),
        ),
      ];
    }

    // Declined / expired terminal states.
    final label = challenge.status == ChallengeStatus.declined
        ? l10n.challengeStatusDeclined
        : l10n.challengeStatusExpired;
    return [_StatusBanner(icon: Icons.info_outline, title: label, body: null)];
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.title, this.body});

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    body!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
