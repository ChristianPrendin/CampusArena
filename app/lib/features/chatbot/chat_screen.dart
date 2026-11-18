import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../routing/route_constants.dart';
import 'cubit/chat_cubit.dart';
import 'cubit/chat_state.dart';
import 'data/assistant_defaults.dart';
import 'widgets/disclaimer_banner.dart';
import 'widgets/message_bubble.dart';
import 'widgets/suggested_chips.dart';
import 'widgets/typing_indicator.dart';

/// Full-screen Arena Assistant chat route. Pushed on top of the app shell
/// (not a 5th tab) — see `app_router.dart`.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _send(String text) {
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    _inputController.clear();
    context.read<ChatCubit>().sendMessage(
      text: text,
      languageCode: languageCode,
      l10n: l10n,
    );
    _scrollToBottom();
  }

  void _retry() {
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    context.read<ChatCubit>().retryLast(languageCode: languageCode, l10n: l10n);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatbotTitle),
        actions: [
          // Hidden in release builds: the assistant ships with a shared key,
          // so end users have nothing to configure and should never be shown
          // an API-key form. See [AssistantDefaults.showSettings].
          if (AssistantDefaults.showSettings)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.chatbotSettingsTooltip,
              onPressed: () => context.push(RouteConstants.chatbotSettings),
            ),
          BlocBuilder<ChatCubit, ChatState>(
            builder: (context, state) {
              return PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'clear') {
                    context.read<ChatCubit>().clearChat();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'clear',
                    child: Text(l10n.chatbotClearChat),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<ChatCubit, ChatState>(
        listener: (context, state) => _scrollToBottom(),
        builder: (context, state) {
          return Column(
            children: [
              if (state.limitedMode)
                Container(
                  width: double.infinity,
                  color: theme.colorScheme.tertiaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wifi_off,
                        size: 16,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.chatbotLimitedModeBadge,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                      // Only actionable by someone who can actually supply a
                      // key; for everyone else the badge is informational.
                      if (AssistantDefaults.showSettings)
                        TextButton(
                          onPressed: () =>
                              context.push(RouteConstants.chatbotSettings),
                          child: Text(l10n.chatbotSettingsTooltip),
                        ),
                    ],
                  ),
                ),
              if (state.showIntroBanner)
                DisclaimerBanner(
                  onDismiss: () =>
                      context.read<ChatCubit>().dismissIntroBanner(),
                ),
              Expanded(
                child: state.messages.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              l10n.chatbotGreeting,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SuggestedChips(onSelect: _send),
                        ],
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount:
                            state.messages.length +
                            (state.status == ChatStatus.sending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= state.messages.length) {
                            return const Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ),
                                child: TypingIndicator(),
                              ),
                            );
                          }
                          final message = state.messages[index];
                          return MessageBubble(
                            message: message,
                            onRetry: message.isError ? _retry : null,
                            // The Map is a shell TAB, not a pushable page —
                            // pushing it would stack a second copy of the
                            // shell branch and trip the navigator's duplicate
                            // -key assertion. `go` switches to the tab instead
                            // (closing the chat, which is the expected UX for
                            // "take me to the map").
                            onOpenMap: () => context.go(RouteConstants.map),
                            onViewTournament: (id) => context.push(
                              RouteConstants.tournamentDetail(id),
                            ),
                          );
                        },
                      ),
              ),
              if (state.messages.isNotEmpty &&
                  state.status != ChatStatus.sending)
                SuggestedChips(onSelect: _send),
              _ChatInputBar(
                controller: _inputController,
                enabled: state.status != ChatStatus.sending,
                onSend: _send,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSend;

  void _submit() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: l10n.chatbotInputHint,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: FilledButton(
                onPressed: enabled ? _submit : null,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Icon(Icons.send, semanticLabel: l10n.chatbotSend),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
