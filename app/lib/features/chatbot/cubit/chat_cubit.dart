import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/chat_message_model.dart';
import '../data/assistant_settings_repository.dart';
import '../data/chatbot_repository.dart';
import 'chat_state.dart';

/// Drives the Arena Assistant chat screen. Holds the full (in-memory only,
/// never persisted) conversation for this session and delegates the actual
/// answer-building to [ChatbotRepository].
class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required this.uid,
    ChatbotRepository? chatbotRepository,
    AssistantSettingsRepository? settingsRepository,
  }) : _chatbotRepository = chatbotRepository ?? ChatbotRepository(),
       _settingsRepository =
           settingsRepository ?? const AssistantSettingsRepository(),
       super(const ChatState()) {
    _refreshLimitedMode();
  }

  final String uid;
  final ChatbotRepository _chatbotRepository;
  final AssistantSettingsRepository _settingsRepository;

  int _messageCounter = 0;

  String _nextId() => 'msg_${_messageCounter++}';

  /// Re-checks whether an API key is configured, so the "limited mode" pill
  /// reflects the current Assistant Settings as soon as the chat opens (e.g.
  /// after the user saves a key and comes back).
  Future<void> _refreshLimitedMode() async {
    final settings = await _settingsRepository.getSettings();
    emit(state.copyWith(limitedMode: !settings.hasApiKey));
  }

  void dismissIntroBanner() {
    emit(state.copyWith(showIntroBanner: false));
  }

  void clearChat() {
    emit(state.copyWith(messages: const [], status: ChatStatus.initial));
  }

  /// Sends [text] as a user message and asks [ChatbotRepository] for the
  /// answer. [languageCode] is the current locale's language code (`en`/`it`)
  /// so the LLM path answers in the right language.
  Future<void> sendMessage({
    required String text,
    required String languageCode,
    required AppLocalizations l10n,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMessage = ChatMessageModel(
      id: _nextId(),
      sender: ChatMessageSender.user,
      text: trimmed,
      sentAt: DateTime.now(),
    );

    emit(
      state.copyWith(
        status: ChatStatus.sending,
        messages: [...state.messages, userMessage],
        showIntroBanner: false,
      ),
    );

    await _answer(userText: trimmed, languageCode: languageCode, l10n: l10n);
  }

  /// Re-runs the last user message after an error bubble's retry action.
  Future<void> retryLast({
    required String languageCode,
    required AppLocalizations l10n,
  }) async {
    final lastUserMessage = state.messages.reversed.firstWhere(
      (m) => m.sender == ChatMessageSender.user,
      orElse: () => ChatMessageModel(
        id: _nextId(),
        sender: ChatMessageSender.user,
        text: '',
        sentAt: DateTime.now(),
      ),
    );
    if (lastUserMessage.text.isEmpty) return;

    // Drop the trailing error bubble before retrying, so we don't stack
    // multiple error bubbles for the same failed turn.
    final messages = [...state.messages];
    if (messages.isNotEmpty && messages.last.isError) {
      messages.removeLast();
    }
    emit(state.copyWith(status: ChatStatus.sending, messages: messages));

    await _answer(
      userText: lastUserMessage.text,
      languageCode: languageCode,
      l10n: l10n,
    );
  }

  Future<void> _answer({
    required String userText,
    required String languageCode,
    required AppLocalizations l10n,
  }) async {
    try {
      final answer = await _chatbotRepository.answer(
        message: userText,
        uid: uid,
        languageCode: languageCode,
        l10n: l10n,
      );

      final assistantMessage = ChatMessageModel(
        id: _nextId(),
        sender: ChatMessageSender.assistant,
        text: answer.text,
        sentAt: DateTime.now(),
        facilityResults: answer.facilityResults,
        tournamentResults: answer.tournamentResults,
        limitedMode: answer.limitedMode,
      );

      emit(
        state.copyWith(
          status: ChatStatus.answered,
          messages: [...state.messages, assistantMessage],
          limitedMode: answer.limitedMode,
        ),
      );
    } catch (e, stackTrace) {
      // A bare `catch (_)` here hid the real cause of every failed turn: any
      // exception escaping ChatbotRepository.answer() (a missing Firestore
      // composite index, a permission denial, a null cast) surfaced
      // identically to an LLM outage. Log it — the user still sees the same
      // friendly bubble.
      debugPrint('[ArenaAssistant] answer() threw: $e');
      debugPrintStack(stackTrace: stackTrace, label: 'ArenaAssistant');

      final errorMessage = ChatMessageModel(
        id: _nextId(),
        sender: ChatMessageSender.assistant,
        text: l10n.chatbotErrorMessage,
        sentAt: DateTime.now(),
        isError: true,
      );
      emit(
        state.copyWith(
          status: ChatStatus.error,
          messages: [...state.messages, errorMessage],
          limitedMode: true,
        ),
      );
    }
  }
}
