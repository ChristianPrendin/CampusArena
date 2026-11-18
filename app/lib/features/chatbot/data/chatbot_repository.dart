import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../repositories/user_repository.dart';
import 'assistant_settings_repository.dart';
import 'chatbot_system_prompt.dart';
import 'chatbot_tools_service.dart';
import 'intent_matcher.dart';
import 'llm_client.dart';
import 'tool_results.dart';

/// Result of answering one user turn: the text to show, any structured card
/// data to render, whether the answer came from the LLM or the rule-based
/// fallback, and whether an availability tool fired (so the caller — here,
/// this repository itself — knows to append the disclaimer).
class ChatAnswer {
  final String text;
  final List<FacilityToolResult>? facilityResults;
  final List<TournamentToolResult>? tournamentResults;
  final bool limitedMode;

  const ChatAnswer({
    required this.text,
    this.facilityResults,
    this.tournamentResults,
    required this.limitedMode,
  });
}

/// Orchestrates one chat turn: classify intent, run the matching read-only
/// tool(s), then either ground an LLM answer in the tool results or fall back
/// to a deterministic templated answer — and, as a hard rule enforced here
/// in code (never delegated to the LLM), append the short availability
/// disclaimer whenever a facility-availability tool fired.
class ChatbotRepository {
  ChatbotRepository({
    ChatbotToolsService? toolsService,
    AssistantSettingsRepository? settingsRepository,
    LlmClient? llmClient,
    RuleBasedIntentMatcher? intentMatcher,
    UserRepository? userRepository,
  }) : _tools = toolsService ?? ChatbotToolsService(),
       _settingsRepository =
           settingsRepository ?? const AssistantSettingsRepository(),
       _llmClient = llmClient ?? LlmClient(),
       _intentMatcher = intentMatcher ?? const RuleBasedIntentMatcher(),
       _userRepositoryOverride = userRepository;

  final ChatbotToolsService _tools;
  final AssistantSettingsRepository _settingsRepository;
  final LlmClient _llmClient;
  final RuleBasedIntentMatcher _intentMatcher;

  /// Injected in tests; otherwise constructed lazily inside [_userContext] so
  /// that merely creating this repository never touches
  /// `FirebaseFirestore.instance` (unit tests run without Firebase).
  final UserRepository? _userRepositoryOverride;

  /// Per-uid personalization block for the system prompt, fetched once per
  /// repository lifetime (name/degree don't change mid-session; ELO snapshots
  /// may age a little, which is fine — live ELO questions go through the
  /// eloExplainer tool). Kept best-effort: any failure (offline, missing doc,
  /// uninitialized Firebase in unit tests) just means no personalization.
  final Map<String, String?> _userContextCache = {};

  Future<String?> _userContext(String uid) async {
    if (uid.isEmpty) return null;
    if (_userContextCache.containsKey(uid)) return _userContextCache[uid];

    String? context;
    try {
      final userRepository = _userRepositoryOverride ?? UserRepository();
      final user = await userRepository.getUser(uid);
      if (user != null) {
        final lines = <String>[
          '- Name: ${user.name} (username: ${user.username})',
          '- Degree program: ${user.degreeProgram}',
        ];
        for (final sportId in [SportIds.pingPong, SportIds.foosball]) {
          final eloRank = await _tools.getUserEloAndRank(
            uid: uid,
            sportId: sportId,
          );
          if (eloRank != null) {
            lines.add(
              '- $sportId: ELO ${eloRank.elo}'
              '${eloRank.rank != null ? ' (rank #${eloRank.rank})' : ''}'
              ', ${eloRank.matchesPlayed} matches played',
            );
          }
        }
        context = lines.join('\n');
      }
    } catch (e) {
      debugPrint('[ArenaAssistant] user context unavailable: $e');
      context = null;
    }
    _userContextCache[uid] = context;
    return context;
  }

  /// [l10n] carries every user-facing string this turn may need: the short
  /// availability disclaimer (appended verbatim and unconditionally whenever
  /// an availability tool fired — see the class doc) and the localized
  /// rule-based / limited-mode answer templates. The English `toolContext`
  /// built below is *only* LLM grounding, never shown to the user directly.
  Future<ChatAnswer> answer({
    required String message,
    required String uid,
    required String languageCode,
    required AppLocalizations l10n,
    List<LlmMessage> history = const [],
  }) async {
    final intent = _intentMatcher.classify(message);

    List<FacilityToolResult>? facilityResults;
    List<TournamentToolResult>? tournamentResults;
    QueuePositionToolResult? queueResult;
    EloRankToolResult? eloResult;
    String toolContext = 'No tool was invoked for this question.';
    bool availabilityToolFired = false;

    switch (intent) {
      case ChatIntent.emptyTables:
        facilityResults = await _tools.getEmptyTables();
        availabilityToolFired = true;
        toolContext = _describeFacilities(facilityResults);
        break;
      case ChatIntent.tournamentsToday:
        tournamentResults = await _tools.getTournamentsToday();
        toolContext = _describeTournaments(tournamentResults);
        break;
      case ChatIntent.queuePosition:
        queueResult = await _tools.getUserQueuePosition(uid);
        toolContext = queueResult == null
            ? 'The user is not currently queued at any facility.'
            : 'The user is at position ${queueResult.position} in the '
                  'queue for "${queueResult.facilityName}".';
        break;
      case ChatIntent.eloExplainer:
        final explainer = _tools.explainHowEloWorks();
        eloResult = await _tools.getUserEloAndRank(
          uid: uid,
          sportId: SportIds.pingPong,
        );
        toolContext = eloResult == null
            ? explainer
            : '$explainer\n\nThe user\'s current Ping Pong ELO is '
                  '${eloResult.elo}'
                  '${eloResult.rank != null ? ", ranked #${eloResult.rank}" : ""} '
                  'after ${eloResult.matchesPlayed} matches.';
        break;
      case ChatIntent.general:
        toolContext = 'No tool was invoked for this question.';
        break;
    }

    final settings = await _settingsRepository.getSettings();
    String text;
    bool limitedMode;

    if (settings.hasApiKey) {
      try {
        final systemPrompt = ChatbotSystemPrompt.build(
          languageCode: languageCode,
          toolContext: toolContext,
          userContext: await _userContext(uid),
        );
        text = await _llmClient.sendMessage(
          settings: settings,
          systemPrompt: systemPrompt,
          history: [
            ...history,
            LlmMessage(role: 'user', content: message),
          ],
        );
        limitedMode = false;
      } on LlmException {
        text = _ruleBasedAnswer(
          l10n: l10n,
          intent: intent,
          facilityResults: facilityResults,
          tournamentResults: tournamentResults,
          queueResult: queueResult,
          eloResult: eloResult,
        );
        limitedMode = true;
      }
    } else {
      text = _ruleBasedAnswer(
        l10n: l10n,
        intent: intent,
        facilityResults: facilityResults,
        tournamentResults: tournamentResults,
        queueResult: queueResult,
        eloResult: eloResult,
      );
      limitedMode = true;
    }

    // HARD RULE: never trust the LLM (or the rule-based templates) to have
    // included the disclaimer. Append it here, unconditionally, in code,
    // whenever an availability tool fired as part of answering this turn.
    if (availabilityToolFired) {
      text = '$text\n\n${l10n.availabilityDisclaimerShort}';
    }

    return ChatAnswer(
      text: text,
      facilityResults: facilityResults,
      tournamentResults: tournamentResults,
      limitedMode: limitedMode,
    );
  }

  String _describeFacilities(List<FacilityToolResult> facilities) {
    if (facilities.isEmpty) {
      return 'No facilities are currently free according to app activity.';
    }
    final rows = facilities.map(
      (f) =>
          '- ${f.name} (sport: ${f.sportId}, status: ${f.status}, queue: '
          '${f.queueLength})',
    );
    return jsonEncode({'emptyTables': rows.toList()});
  }

  String _describeTournaments(List<TournamentToolResult> tournaments) {
    if (tournaments.isEmpty) {
      return 'No tournaments are scheduled for today.';
    }
    final rows = tournaments.map(
      (t) =>
          '- ${t.name} (sport: ${t.sportId}, status: ${t.status}, at '
          '${t.scheduledAt.toIso8601String()}, participants: '
          '${t.participantCount}/${t.maxParticipants})',
    );
    return jsonEncode({'tournamentsToday': rows.toList()});
  }

  /// Deterministic, non-LLM answer built directly from the tool results and
  /// localized via [l10n] — used whenever no API key is configured, the device
  /// is offline, or the LLM call errors. Never invents data beyond what the
  /// tool returned.
  String _ruleBasedAnswer({
    required AppLocalizations l10n,
    required ChatIntent intent,
    List<FacilityToolResult>? facilityResults,
    List<TournamentToolResult>? tournamentResults,
    QueuePositionToolResult? queueResult,
    EloRankToolResult? eloResult,
  }) {
    switch (intent) {
      case ChatIntent.emptyTables:
        if (facilityResults == null || facilityResults.isEmpty) {
          return l10n.chatbotAnswerNoFreeTables;
        }
        final names = facilityResults.map((f) => f.name).join(', ');
        return l10n.chatbotAnswerFreeTables(names);
      case ChatIntent.tournamentsToday:
        if (tournamentResults == null || tournamentResults.isEmpty) {
          return l10n.chatbotAnswerNoTournaments;
        }
        final names = tournamentResults
            .map(
              (t) => '${t.name} (${t.participantCount}/${t.maxParticipants})',
            )
            .join(', ');
        return l10n.chatbotAnswerTournamentsToday(names);
      case ChatIntent.queuePosition:
        return queueResult == null
            ? l10n.chatbotAnswerQueueNone
            : l10n.chatbotAnswerQueuePosition(
                queueResult.position,
                queueResult.facilityName,
              );
      case ChatIntent.eloExplainer:
        final explainer = l10n.chatbotAnswerEloExplainer;
        if (eloResult == null) return explainer;
        final eloLine = eloResult.rank != null
            ? l10n.chatbotAnswerYourEloRanked(
                eloResult.elo,
                eloResult.rank!,
                eloResult.matchesPlayed,
              )
            : l10n.chatbotAnswerYourElo(eloResult.elo, eloResult.matchesPlayed);
        return '$explainer\n\n$eloLine';
      case ChatIntent.general:
        return l10n.chatbotAnswerGeneral;
    }
  }
}
