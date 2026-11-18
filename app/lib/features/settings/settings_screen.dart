import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:campus_arena/l10n/app_localizations.dart';
import '../../core/services/push_token_service.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/user_repository.dart';
import '../auth/cubit/auth_cubit.dart';
import 'cubit/locale_cubit.dart';
import 'cubit/settings_cubit.dart';
import 'cubit/settings_state.dart';
import 'privacy_screen.dart';

/// App version shown in the footer. A single named constant so the string
/// stays in one place (the ARB template only carries the format).
const String kAppVersion = '1.0.0';

/// Settings screen — full-screen, outside the nav shell (back arrow, no bottom
/// nav), laid out per `docs/design/screenshots/settings.png`.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.userRepository,
    this.authRepository,
    this.pushTokenService,
  });

  /// All injectable for tests; production defaults to the live services.
  final UserRepository? userRepository;
  final AuthRepository? authRepository;
  final PushTokenService? pushTokenService;

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthCubit>().state.uid;
    return BlocProvider<SettingsCubit>(
      create: (_) => SettingsCubit(
        uid: uid ?? '',
        userRepository: userRepository,
        authRepository: authRepository,
        pushTokenService: pushTokenService,
      ),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  Future<void> _changePassword(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<SettingsCubit>();
    final email = cubit.state.email;
    final result = await cubit.sendPasswordReset();
    final String message;
    switch (result) {
      case PasswordResetResult.sent:
        message = l10n.settingsPasswordResetSent(email ?? '');
      case PasswordResetResult.failed:
        message = l10n.settingsPasswordResetError;
      case PasswordResetResult.noEmail:
        return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionHeader(label: l10n.settingsAccountSection),
                        Card(
                          margin: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _SettingsTile(
                                icon: Icons.lock_outline,
                                title: l10n.settingsChangePassword,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _changePassword(context),
                              ),
                              const Divider(height: 1, indent: 52),
                              _SettingsTile(
                                icon: Icons.shield_outlined,
                                title: l10n.settingsPrivacy,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const PrivacyScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _SectionHeader(label: l10n.settingsPreferencesSection),
                        Card(
                          margin: EdgeInsets.zero,
                          child: Column(
                            children: [
                              const _NotificationTile(),
                              const Divider(height: 1, indent: 52),
                              const _LanguageTile(),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => context.read<AuthCubit>().signOut(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            side: BorderSide(
                              color: theme.colorScheme.error,
                              width: 1.5,
                            ),
                          ),
                          icon: const Icon(Icons.logout),
                          label: Text(l10n.settingsLogout),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            l10n.settingsVersion(kAppVersion),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final rowEnabled = state.notificationRowEnabled;
        final unavailable =
            state.notification == NotificationSetting.unavailable;
        return _SettingsTile(
          icon: Icons.notifications_outlined,
          title: l10n.settingsNotifications,
          subtitle: unavailable ? l10n.settingsNotificationsUnavailable : null,
          trailing: Switch(
            value: state.notificationsOn,
            onChanged: rowEnabled && !state.notificationBusy
                ? (_) => context.read<SettingsCubit>().toggleNotifications()
                : null,
          ),
          onTap: rowEnabled && !state.notificationBusy
              ? () => context.read<SettingsCubit>().toggleNotifications()
              : null,
        );
      },
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Reflect the active locale: the explicit override if set, otherwise the
    // resolved system language.
    final override = context.watch<LocaleCubit>().state;
    final current =
        override?.languageCode ?? Localizations.localeOf(context).languageCode;
    final selected = current == 'it' ? 'it' : 'en';

    return _SettingsTile(
      icon: Icons.translate,
      title: l10n.settingsLanguage,
      trailing: SegmentedButton<String>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          textStyle: theme.textTheme.labelLarge,
        ),
        segments: [
          ButtonSegment<String>(
            value: 'en',
            label: Text(l10n.languageEnglishShort),
          ),
          ButtonSegment<String>(
            value: 'it',
            label: Text(l10n.languageItalianShort),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (selection) {
          final code = selection.first;
          if (code == selected) return;
          final uid = context.read<AuthCubit>().state.uid;
          context.read<LocaleCubit>().setLanguage(uid ?? '', code);
        },
      ),
    );
  }
}
