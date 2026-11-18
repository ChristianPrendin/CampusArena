import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/match_model.dart';
import 'constants.dart';

/// Material icon representing a sport, shared by the sport selectors, the
/// dashboard hero card, and the profile's ELO chips.
IconData sportIcon(String sportId) {
  switch (sportId) {
    case SportIds.foosball:
      return Icons.sports_soccer;
    case SportIds.pingPong:
    default:
      return Icons.sports_tennis;
  }
}

/// Localized display name for a sport, falling back to the raw id for sports
/// without a dedicated string (e.g. padel until it ships).
String localizedSportName(AppLocalizations l10n, String sportId) {
  switch (sportId) {
    case SportIds.pingPong:
      return l10n.sportPingPong;
    case SportIds.foosball:
      return l10n.sportFoosball;
    default:
      return sportId;
  }
}

/// A compact score for a terminal match, oriented from [uid]'s perspective
/// (the caller's tally first): a win reads `hi–lo`, a loss `lo–hi`. Ping pong
/// counts sets won pairwise; foosball uses the goal figures. Returns an empty
/// string when there is no scored result yet.
String matchScoreLabel(MatchModel match, String uid) {
  final result = match.result;
  int mine;
  int theirs;
  if (result is PingPongResult) {
    var won = 0;
    var lost = 0;
    final sets = result.sets;
    final opp = result.opponentSets;
    final n = sets.length < opp.length ? sets.length : opp.length;
    for (var i = 0; i < n; i++) {
      if (sets[i] > opp[i]) {
        won++;
      } else if (sets[i] < opp[i]) {
        lost++;
      }
    }
    mine = won;
    theirs = lost;
  } else if (result is FoosballResult) {
    mine = result.goals;
    theirs = result.opponentGoals;
  } else {
    return '';
  }
  final hi = mine >= theirs ? mine : theirs;
  final lo = mine >= theirs ? theirs : mine;
  final iWon = result!.winnerIds.contains(uid);
  return iWon ? '$hi–$lo' : '$lo–$hi';
}

/// The opponent UIDs in [match] from [uid]'s perspective.
///
/// For doubles, uses the team pair ids (sorted-uid joins) to exclude the
/// caller's own teammate; falls back to "everyone but me" when pair ids are
/// absent (singles, or legacy docs).
List<String> opponentUids(MatchModel match, String uid) {
  final t1 = match.team1PairId?.split('_');
  final t2 = match.team2PairId?.split('_');
  if (t1 != null && t2 != null) {
    if (t1.contains(uid)) return t2;
    if (t2.contains(uid)) return t1;
  }
  return match.playerUids.where((p) => p != uid).toList();
}
