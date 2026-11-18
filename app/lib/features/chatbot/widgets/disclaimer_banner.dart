import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// First-open, dismissible info banner showing the full availability
/// disclaimer (`chatbotIntroDisclaimer`, exact copy from the plan). A tonal
/// [MaterialBanner]-style surface rather than the real [MaterialBanner]
/// widget, so it can live inline above the message list instead of docked to
/// the top of the [Scaffold].
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.chatbotIntroDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close),
            iconSize: 18,
            tooltip: l10n.chatbotDismissBanner,
            color: theme.colorScheme.onSecondaryContainer,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
