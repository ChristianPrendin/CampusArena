import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../data/assistant_provider.dart';
import 'assistant_settings_cubit.dart';
import 'assistant_settings_state.dart';

/// Settings screen for the Arena Assistant's LLM configuration. Route
/// `/chatbot/settings`. Works fully without a saved key — the chat screen
/// just stays in rule-based "limited mode" until one is added here.
class AssistantSettingsScreen extends StatelessWidget {
  const AssistantSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AssistantSettingsCubit(),
      child: const _AssistantSettingsView(),
    );
  }
}

class _AssistantSettingsView extends StatefulWidget {
  const _AssistantSettingsView();

  @override
  State<_AssistantSettingsView> createState() => _AssistantSettingsViewState();
}

class _AssistantSettingsViewState extends State<_AssistantSettingsView> {
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  bool _obscureApiKey = true;
  bool _controllersSynced = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  String _localizeTestError(AppLocalizations l10n, String? reason) {
    switch (reason) {
      case 'invalid_api_key':
        return l10n.chatbotErrorInvalidApiKey;
      case 'rate_limited':
        return l10n.chatbotErrorRateLimited;
      case 'network_error':
        return l10n.chatbotErrorNetwork;
      case 'timeout':
        return l10n.chatbotErrorTimeout;
      case 'missing_api_key':
        return l10n.chatbotErrorMissingApiKey;
      default:
        return l10n.chatbotErrorGeneric;
    }
  }

  Future<void> _confirmProviderChange(
    BuildContext context,
    AssistantProvider provider,
  ) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<AssistantSettingsCubit>();
    final currentModel = cubit.state.settings.model;
    final currentProvider = cubit.state.settings.provider;
    final isCustomModel =
        currentModel.isNotEmpty && currentModel != currentProvider.defaultModel;

    if (!isCustomModel) {
      cubit.changeProvider(provider);
      return;
    }

    final resetToDefault = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.chatbotSettingsResetModelPrompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.chatbotSettingsResetModelNo),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.chatbotSettingsResetModelYes),
          ),
        ],
      ),
    );

    cubit.changeProvider(provider, keepModel: resetToDefault != true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatbotSettingsTitle)),
      body: BlocConsumer<AssistantSettingsCubit, AssistantSettingsState>(
        listenWhen: (previous, current) =>
            previous.saved != current.saved ||
            previous.lastTestSuccess != current.lastTestSuccess ||
            previous.lastTestErrorReason != current.lastTestErrorReason,
        listener: (context, state) {
          final messenger = ScaffoldMessenger.of(context);
          if (state.saved) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(l10n.chatbotSettingsSaved)),
              );
          } else if (state.lastTestSuccess == true) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(l10n.chatbotSettingsTestSuccess)),
              );
          } else if (state.lastTestSuccess == false) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    '${l10n.chatbotSettingsTestFailurePrefix} '
                    '${_localizeTestError(l10n, state.lastTestErrorReason)}',
                  ),
                ),
              );
          }
        },
        builder: (context, state) {
          if (!_controllersSynced &&
              state.status != AssistantSettingsStatus.loading) {
            _apiKeyController.text = state.settings.apiKey;
            _modelController.text = state.settings.model;
            _controllersSynced = true;
          }

          if (state.status == AssistantSettingsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final cubit = context.read<AssistantSettingsCubit>();
          final isBusy =
              state.status == AssistantSettingsStatus.saving ||
              state.status == AssistantSettingsStatus.testing;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!state.settings.hasApiKey)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.chatbotSettingsNoKeyBanner,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                Text(
                  l10n.chatbotSettingsProviderLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<AssistantProvider>(
                  key: ValueKey(state.settings.provider),
                  initialValue: state.settings.provider,
                  items: AssistantProvider.values
                      .map(
                        (provider) => DropdownMenuItem(
                          value: provider,
                          child: Text(provider.label),
                        ),
                      )
                      .toList(),
                  onChanged: (provider) {
                    if (provider == null) return;
                    _confirmProviderChange(context, provider).then((_) {
                      _modelController.text = cubit.state.settings.model;
                    });
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureApiKey,
                  onChanged: cubit.changeApiKey,
                  decoration: InputDecoration(
                    labelText: l10n.chatbotSettingsApiKeyLabel,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      tooltip: _obscureApiKey
                          ? l10n.chatbotSettingsShowKey
                          : l10n.chatbotSettingsHideKey,
                      onPressed: () =>
                          setState(() => _obscureApiKey = !_obscureApiKey),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _modelController,
                  onChanged: cubit.changeModel,
                  decoration: InputDecoration(
                    labelText: l10n.chatbotSettingsModelLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: isBusy ? null : cubit.testConnection,
                    child: state.status == AssistantSettingsStatus.testing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.chatbotSettingsTestConnection),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: isBusy ? null : cubit.save,
                    child: state.status == AssistantSettingsStatus.saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.chatbotSettingsSave),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
