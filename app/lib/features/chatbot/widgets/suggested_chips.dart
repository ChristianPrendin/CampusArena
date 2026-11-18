import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Row of suggested-question chips shown while the chat is empty/fresh.
/// Tapping a chip sends its label as a user message via [onSelect].
class SuggestedChips extends StatelessWidget {
  const SuggestedChips({super.key, required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.chatbotChipEmptyTables,
      l10n.chatbotChipTournamentsToday,
      l10n.chatbotChipHowElo,
      l10n.chatbotChipQueuePosition,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: labels
            .map(
              (label) => ActionChip(
                label: Text(label),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onPressed: () => onSelect(label),
              ),
            )
            .toList(),
      ),
    );
  }
}
