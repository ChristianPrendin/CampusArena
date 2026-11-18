import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../cubit/queue_cubit.dart';
import '../cubit/queue_state.dart';

/// Self-contained queue controls for the facility detail card.
///
/// The single-parameter constructor is the agreed seam with the map vertical
/// (Vertical A slots this into the detail card via `QueueSection(facilityId: …)`).
/// It reads the signed-in uid from the [AuthCubit] already in the widget tree
/// and provides its own [QueueCubit] — no auth re-plumbing, no `main.dart`
/// provider. Renders the "Join Queue" button, the live "You're #N of M" counter,
/// and the front-of-queue "table ready" banner.
class QueueSection extends StatelessWidget {
  const QueueSection({super.key, required this.facilityId});

  final String facilityId;

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthCubit>().state.uid;
    if (uid == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (_) => QueueCubit(facilityId: facilityId, uid: uid),
      child: const QueueSectionView(),
    );
  }
}

/// Presentational half of [QueueSection]: renders the queue state from the
/// [QueueCubit] provided above it. Split out so the exact rendered tree is
/// widget-testable against a mock-repository-driven cubit, without reaching for
/// Firebase (the container owns cubit creation).
class QueueSectionView extends StatelessWidget {
  const QueueSectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<QueueCubit, QueueState>(
      listenWhen: (prev, curr) => !prev.tableReady && curr.tableReady,
      listener: (context, state) => HapticFeedback.heavyImpact(),
      builder: (context, state) {
        // Smooth the height change as the banner / counter / error row slip in
        // and out (join, advance to front, leave) rather than snapping.
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.tableReady) ...[
                const _TableReadyBanner(),
                const SizedBox(height: 12),
              ],
              if (state.status == QueueStatus.inQueue ||
                  state.status == QueueStatus.leaving)
                _PositionCounter(state: state),
              if (state.status == QueueStatus.error) ...[
                const _QueueError(),
                const SizedBox(height: 10),
              ],
              _ActionButton(state: state),
            ],
          ),
        );
      },
    );
  }
}

/// Prominent "your table is ready" banner shown to the front-of-queue player.
class _TableReadyBanner extends StatelessWidget {
  const _TableReadyBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: colors.primary, size: 24),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.queueTableReadyTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.queueTableReadyBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                // Mandatory availability disclaimer (§3.10): this banner asserts
                // the table is free, so it carries the short copy.
                Text(
                  l10n.availabilityDisclaimerShort,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onPrimaryContainer.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: colors.onPrimaryContainer,
            tooltip: l10n.queueTableReadyDismiss,
            onPressed: () => context.read<QueueCubit>().dismissTableReady(),
          ),
        ],
      ),
    );
  }
}

/// Live "You're #N of M" counter, driven by the queue snapshot stream.
class _PositionCounter extends StatelessWidget {
  const _PositionCounter({required this.state});

  final QueueState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final position = state.position ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Icon(Icons.groups, size: 22, color: colors.onSecondaryContainer),
          const SizedBox(width: 11),
          Expanded(
            // Cross-fade the counter as the line advances, so a position change
            // reads as movement rather than a silent text swap.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                l10n.queuePositionCounter(position, state.queueLength),
                key: ValueKey('$position/${state.queueLength}'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (state.isFront)
            Text(
              l10n.queueYoureNext,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

/// Inline error with retry, shown after a failed join/leave.
class _QueueError extends StatelessWidget {
  const _QueueError();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Icon(Icons.error_outline, size: 18, color: colors.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.queueError,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
          ),
        ),
      ],
    );
  }
}

/// The primary affordance: Join Queue / Leave queue, with in-flight spinners.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.state});

  final QueueState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<QueueCubit>();

    switch (state.status) {
      case QueueStatus.inQueue:
        return OutlinedButton.icon(
          onPressed: cubit.leave,
          icon: const Icon(Icons.logout, size: 20),
          label: Text(l10n.queueLeave),
        );
      case QueueStatus.joining:
        return const FilledButton(onPressed: null, child: _ButtonSpinner());
      case QueueStatus.leaving:
        return const OutlinedButton(onPressed: null, child: _ButtonSpinner());
      case QueueStatus.error:
      case QueueStatus.idle:
        // A failed leave leaves me queued: Retry must re-issue the op that
        // failed, not blindly call join() (which would no-op and hang).
        final onPressed =
            state.status == QueueStatus.error &&
                state.lastAction == QueueAction.leave
            ? cubit.leave
            : cubit.join;
        return FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(
            state.status == QueueStatus.error ? Icons.refresh : Icons.login,
            size: 20,
          ),
          label: Text(
            state.status == QueueStatus.error
                ? l10n.queueRetry
                : l10n.queueJoin,
          ),
        );
    }
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
