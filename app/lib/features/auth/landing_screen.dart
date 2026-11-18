import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:campus_arena/l10n/app_localizations.dart';
import '../../routing/route_constants.dart';

/// Unauthenticated entry point: choose Log In or Register.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.sports_tennis,
                            size: 46,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          l10n.appTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            l10n.landingTagline,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    // `go`, not `push`: the auth flow is governed entirely by the
                    // router redirect. An imperatively pushed /register lingers as a
                    // second match while the redirect holds on /register during
                    // `registrationInProgress`, stacking a fresh, empty RegisterScreen
                    // over the filled one. A declarative navigation keeps a single
                    // /register the redirect owns.
                    onPressed: () => context.go(RouteConstants.register),
                    child: Text(l10n.register),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go(RouteConstants.login),
                    child: Text(l10n.logIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
