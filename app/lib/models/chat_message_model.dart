import 'package:equatable/equatable.dart';

import '../features/chatbot/data/tool_results.dart';

/// Who authored a [ChatMessageModel].
enum ChatMessageSender { user, assistant }

/// A single message in the (session-only, in-memory) Arena Assistant
/// conversation. Never persisted — [ChatCubit] holds the full list in state
/// and it is discarded when the chat screen closes, per the plan's
/// no-chat-persistence rule.
class ChatMessageModel extends Equatable {
  final String id;
  final ChatMessageSender sender;
  final String text;
  final DateTime sentAt;

  /// Set when this assistant message carries live facility data — rendered
  /// as a [FacilityStatusCard] list beneath the text.
  final List<FacilityToolResult>? facilityResults;

  /// Set when this assistant message carries tournament data — rendered as
  /// [TournamentCard]s beneath the text.
  final List<TournamentToolResult>? tournamentResults;

  /// True when this assistant message was answered without an LLM (no API
  /// key configured, offline, or the LLM call failed) — used only for
  /// per-message bookkeeping; the "limited mode" pill itself is driven by
  /// [ChatState.limitedMode].
  final bool limitedMode;

  /// True when this message represents a failed send that offers retry.
  final bool isError;

  const ChatMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    required this.sentAt,
    this.facilityResults,
    this.tournamentResults,
    this.limitedMode = false,
    this.isError = false,
  });

  ChatMessageModel copyWith({
    String? id,
    ChatMessageSender? sender,
    String? text,
    DateTime? sentAt,
    List<FacilityToolResult>? facilityResults,
    List<TournamentToolResult>? tournamentResults,
    bool? limitedMode,
    bool? isError,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
      facilityResults: facilityResults ?? this.facilityResults,
      tournamentResults: tournamentResults ?? this.tournamentResults,
      limitedMode: limitedMode ?? this.limitedMode,
      isError: isError ?? this.isError,
    );
  }

  @override
  List<Object?> get props => [
    id,
    sender,
    text,
    sentAt,
    facilityResults,
    tournamentResults,
    limitedMode,
    isError,
  ];
}
