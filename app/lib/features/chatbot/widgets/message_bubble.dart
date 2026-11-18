import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/chat_message_model.dart';
import 'facility_status_card.dart';
import 'tournament_card.dart';

/// A single chat bubble. User messages are right-aligned in
/// `primaryContainer`; assistant messages are left-aligned in
/// `surfaceContainer`. Error bubbles (assistant, [ChatMessageModel.isError])
/// show a retry action. Rich cards ([FacilityStatusCard] / [TournamentCard])
/// are rendered beneath the text when the message carries tool data.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onOpenMap,
    this.onViewTournament,
  });

  final ChatMessageModel message;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenMap;
  final ValueChanged<String>? onViewTournament;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isUser = message.sender == ChatMessageSender.user;

    final bubbleColor = message.isError
        ? theme.colorScheme.errorContainer
        : isUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainer;
    final textColor = message.isError
        ? theme.colorScheme.onErrorContainer
        : isUser
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.text, style: TextStyle(color: textColor)),
              if (message.facilityResults != null &&
                  message.facilityResults!.isNotEmpty)
                FacilityStatusCard(
                  facilities: message.facilityResults!,
                  onOpenMap: onOpenMap,
                ),
              if (message.tournamentResults != null &&
                  message.tournamentResults!.isNotEmpty)
                TournamentCard(
                  tournaments: message.tournamentResults!,
                  onView: onViewTournament,
                ),
              if (message.isError && onRetry != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onRetry,
                    child: Text(l10n.chatbotRetry),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
