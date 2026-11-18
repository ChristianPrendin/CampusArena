/// The set of questions the Arena Assistant can answer with a tool call.
/// [general] is the fallback when no keyword rule matches — it either goes
/// to the LLM (if configured) or a generic limited-mode message.
enum ChatIntent {
  emptyTables,
  tournamentsToday,
  eloExplainer,
  queuePosition,
  general,
}

/// Deterministic keyword → intent classifier. Used both as the fallback path
/// when no LLM is configured/reachable, and (before ever calling the LLM) to
/// decide which tool(s), if any, should ground the LLM's answer — the model
/// never invents which Firestore data to fetch.
///
/// English + Italian keywords are both matched, since the app is bilingual.
class RuleBasedIntentMatcher {
  const RuleBasedIntentMatcher();

  ChatIntent classify(String message) {
    final text = message.toLowerCase().trim();

    if (_matchesAny(text, _queueKeywords)) {
      return ChatIntent.queuePosition;
    }
    if (_matchesAny(text, _eloKeywords)) {
      return ChatIntent.eloExplainer;
    }
    if (_matchesAny(text, _tournamentKeywords)) {
      return ChatIntent.tournamentsToday;
    }
    if (_matchesAny(text, _emptyTableKeywords) || _asksForFreeTables(text)) {
      return ChatIntent.emptyTables;
    }
    return ChatIntent.general;
  }

  /// Word-order-independent fallback: any mention of tables together with a
  /// free/empty/available word counts, in either language ("quali tavoli sono
  /// liberi?", "is any table free?").
  bool _asksForFreeTables(String text) {
    final mentionsTables = text.contains('table') || text.contains('tavol');
    if (!mentionsTables) return false;
    const availabilityStems = [
      'free',
      'empty',
      'available',
      'liber',
      'vuot',
      'disponibil',
    ];
    return availabilityStems.any(text.contains);
  }

  bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  static const List<String> _emptyTableKeywords = [
    'empty table',
    'empty tables',
    'free table',
    'free tables',
    'which tables',
    'what tables',
    'available table',
    'available tables',
    'tavolo libero',
    'tavoli liberi',
    'tavoli vuoti',
  ];

  static const List<String> _tournamentKeywords = [
    'tournament',
    'tournaments',
    'torneo',
    'tornei',
  ];

  static const List<String> _eloKeywords = [
    'elo',
    'rank',
    'ranking',
    'rating',
    'classifica',
    'punteggio',
  ];

  static const List<String> _queueKeywords = [
    'queue',
    'my position',
    'in line',
    'in the line',
    'coda',
    'posizione in coda',
  ];
}
