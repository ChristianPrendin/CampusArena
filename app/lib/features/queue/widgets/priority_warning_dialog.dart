import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Soft-enforcement priority warning shown when a non-front queued user attempts
/// to claim a table (Phase 4B QR check-in will be the trigger).
///
/// Standalone and reusable — its only inputs are my ticket [position] and the
/// [frontPosition] ahead of me. It NEVER blocks: it returns `true` if the user
/// chose to proceed anyway, `false` if they backed out, and the caller is free
/// to honour "proceed" unconditionally (the design is a nudge, not a gate).
class PriorityWarningDialog {
  const PriorityWarningDialog._();

  static Future<bool> show({
    required BuildContext context,
    required int position,
    required int frontPosition,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.tertiary,
          ),
          title: Text(l10n.queuePriorityTitle),
          content: Text(l10n.queuePriorityBody(position, frontPosition)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.queuePriorityCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.queuePriorityProceed),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
