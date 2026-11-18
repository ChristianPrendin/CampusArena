import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Placeholder for the Arena Assistant chat screen. The real chat UI (chips,
/// message bubbles, disclaimer banner, answer cards) lands in Phase 6 (C3);
/// this stub exists so the dashboard entry point and `/chatbot` route resolve.
class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatbotTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                l10n.chatbotComingSoon,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
