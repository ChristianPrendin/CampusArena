import 'package:flutter/material.dart';

import 'package:campus_arena/l10n/app_localizations.dart';

/// Static, localized summary of what data the app stores. No third-party
/// sharing. Reached from the Settings "Privacy" row.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPrivacyTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(l10n.settingsPrivacyIntro, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            _PrivacyBullet(text: l10n.settingsPrivacyProfile),
            _PrivacyBullet(text: l10n.settingsPrivacyMatches),
            _PrivacyBullet(text: l10n.settingsPrivacyRatings),
            _PrivacyBullet(text: l10n.settingsPrivacyLocation),
            const SizedBox(height: 16),
            Text(
              l10n.settingsPrivacySharing,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyBullet extends StatelessWidget {
  const _PrivacyBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 12),
            child: Icon(
              Icons.check_circle_outline,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
