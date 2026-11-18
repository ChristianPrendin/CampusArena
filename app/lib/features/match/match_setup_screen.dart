import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart' as fs;
import '../../l10n/app_localizations.dart';
import '../../routing/route_constants.dart';
import 'cubit/match_cubit.dart';
import 'cubit/match_state.dart';

/// The match-setup surface: once a facility is resolved (a deep link, or a blind
/// scan of a far table) the creator picks singles/doubles and — for doubles —
/// their own side here, then checks in. Split out of the QR viewfinder so the
/// selection lives on a plain themed screen instead of being crammed over the
/// live camera feed.
///
/// A nearby blind scan never reaches this screen: it auto-confirms as singles
/// straight from [MatchFlowView], keeping the instant fast path intact.
class MatchSetupView extends StatefulWidget {
  const MatchSetupView({super.key, required this.isDeepLink});

  /// True when reached via `/play/facility/:id` — the back affordance leaves the
  /// flow entirely; a blind scan instead re-arms the scanner.
  final bool isDeepLink;

  @override
  State<MatchSetupView> createState() => _MatchSetupViewState();
}

class _MatchSetupViewState extends State<MatchSetupView> {
  String _mode = fs.MatchModes.singles;
  int _creatorTeam = 1;

  void _back() {
    final cubit = context.read<MatchCubit>();
    if (widget.isDeepLink) {
      // No scanner to fall back to on a deep link: exit the flow.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(RouteConstants.home);
      }
    } else {
      // Re-arm the viewfinder so a mis-scan can be retried.
      cubit.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<MatchCubit>().state;
    final facility = state.facility;
    final busy = state.status == MatchStatus.checkingIn;
    final isDoubles = _mode == fs.MatchModes.doubles;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.matchSetupTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: busy ? null : _back,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (facility != null) ...[
                      Text(
                        facility.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.matchSetupSubtitle(facility.name),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (state.gpsFar) ...[
                      _GpsWarningBanner(message: l10n.qrGpsWarning),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      l10n.matchModeLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: fs.MatchModes.singles,
                          label: Text(l10n.matchModeSingles),
                        ),
                        ButtonSegment(
                          value: fs.MatchModes.doubles,
                          label: Text(l10n.matchModeDoubles),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: busy
                          ? null
                          : (s) => setState(() => _mode = s.first),
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    if (isDoubles) ...[
                      const SizedBox(height: 20),
                      Text(
                        l10n.matchTeamLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(value: 1, label: Text(l10n.matchTeam1)),
                          ButtonSegment(value: 2, label: Text(l10n.matchTeam2)),
                        ],
                        selected: {_creatorTeam},
                        onSelectionChanged: busy
                            ? null
                            : (s) => setState(() => _creatorTeam = s.first),
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: (busy || facility == null)
                          ? null
                          : () => context.read<MatchCubit>().confirmCheckIn(
                              mode: _mode,
                              creatorTeam: _creatorTeam,
                            ),
                      child: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              facility == null
                                  ? l10n.matchSetupTitle
                                  : l10n.qrCheckInButton(facility.name),
                            ),
                    ),
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

/// The soft, non-blocking "you seem far" banner, themed for the plain surface
/// (the QR view's variant lives over the dark camera feed).
class _GpsWarningBanner extends StatelessWidget {
  const _GpsWarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.tertiary.withValues(alpha: 0.16),
        border: Border.all(color: colors.tertiary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_off, size: 18, color: colors.tertiary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.tertiary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
