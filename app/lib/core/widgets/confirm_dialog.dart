import 'package:flutter/material.dart';

/// Shows a standard yes/no confirmation dialog and resolves to the user's
/// choice — `true` on confirm, `false` on cancel or dismiss.
///
/// One place for the `showDialog<bool>` + [AlertDialog] pattern that was being
/// re-copied per feature (friends removal, match forfeit, result review). Set
/// [isDestructive] to tint the confirm action with the error colour.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool isDestructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: theme.colorScheme.error)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
