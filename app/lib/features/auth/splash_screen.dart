import 'package:flutter/material.dart';

import 'package:campus_arena/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';

/// Shown while the auth state is still resolving (`AuthStatus.initial`). The
/// router redirect replaces it with the landing or home route once the first
/// `authStateChanges` event arrives.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  // The splash background is intentionally pinned to the brand primary color.
  // We hardcode the foreground to white to guarantee contrast against the
  // green background regardless of the current theme mode.

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const foreground = Colors.white;

    return Scaffold(
      backgroundColor: AppTheme.primarySeedColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Icon(
                        Icons.sports_tennis,
                        size: 56,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.appTitle,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: foreground,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.splashTagline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 56),
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(
                    foreground.withValues(alpha: 0.9),
                  ),
                  backgroundColor: foreground.withValues(alpha: 0.25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
