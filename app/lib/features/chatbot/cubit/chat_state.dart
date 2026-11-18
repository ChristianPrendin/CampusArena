import 'package:equatable/equatable.dart';

import '../../../models/chat_message_model.dart';

/// Lifecycle of a single chat turn. `initial` is the fresh/empty state (shows
/// the suggested-question chips); `sending` covers both classifying intent
/// and running tools ("awaiting tools" in the plan is folded into `sending`
/// since, from the UI's point of view, both just show the typing indicator);
/// `answered` and `error` are terminal per-turn states.
enum ChatStatus { initial, sending, answered, error }

class ChatState extends Equatable {
  final ChatStatus status;
  final List<ChatMessageModel> messages;

  /// True when no API key is configured or the device is offline — drives
  /// the "limited mode" pill under the app bar.
  final bool limitedMode;

  /// True until the user has dismissed the first-open disclaimer banner (or
  /// sent a first message), per session — never persisted.
  final bool showIntroBanner;

  const ChatState({
    this.status = ChatStatus.initial,
    this.messages = const [],
    this.limitedMode = false,
    this.showIntroBanner = true,
  });

  ChatState copyWith({
    ChatStatus? status,
    List<ChatMessageModel>? messages,
    bool? limitedMode,
    bool? showIntroBanner,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      limitedMode: limitedMode ?? this.limitedMode,
      showIntroBanner: showIntroBanner ?? this.showIntroBanner,
    );
  }

  @override
  List<Object?> get props => [status, messages, limitedMode, showIntroBanner];
}
