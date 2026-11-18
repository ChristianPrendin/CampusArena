// Pure-Dart single-elimination bracket derivation — no Flutter, no Firestore.
// This is the ONE shared engine both tournament verticals derive their bracket
// from, so its public surface (roundKeysForSize, BracketSide, BracketSlot,
// BracketTree, build) is a frozen contract — see the elo_calculator precedent
// for a pure core module.
//
// Nothing extra is persisted: the schema's `bracket` map only ever holds the
// matchIds of matches actually played. Byes, forfeit advancement, and winner
// propagation are all recomputed deterministically here from participants +
// that map + the tournament's matches, on every read.

import '../../models/match_model.dart';
import '../../models/tournament_model.dart';
import '../constants.dart';

/// Canonical round keys for a [bracketSize]-slot single-elimination bracket,
/// ordered first round → final. These exact strings are BOTH the
/// `tournament.bracket` map keys AND the `matches.tournamentRound` values, e.g.
/// size 16 → `[round_of_16, quarterfinal, semifinal, final]`, size 4 →
/// `[semifinal, final]`, size 2 → `[final]`.
List<String> roundKeysForSize(int bracketSize) {
  final keys = <String>[];
  for (var players = bracketSize; players >= 2; players ~/= 2) {
    keys.add(switch (players) {
      2 => 'final',
      4 => 'semifinal',
      8 => 'quarterfinal',
      _ => 'round_of_$players',
    });
  }
  return keys;
}

/// One side of a [BracketSlot]. A real player has [uid] set; a [isBye] side is
/// an empty bracket position the opponent auto-advances past; `uid == null &&
/// !isBye` is a not-yet-decided (TBD) side awaiting an earlier round's winner.
class BracketSide {
  BracketSide({this.uid, this.isBye = false});

  String? uid;
  bool isBye;
}

/// One match position in the bracket: the two [a]/[b] sides, its [round] key
/// and 0-based [index] within that round, the [matchId] of the played match
/// backing it (if any), and its resolved [winnerUid] (once decided).
class BracketSlot {
  BracketSlot({
    required this.round,
    required this.index,
    required this.a,
    required this.b,
    this.matchId,
    this.winnerUid,
  });

  String round;
  int index;
  BracketSide a;
  BracketSide b;
  String? matchId;
  String? winnerUid;

  /// Both sides are known real players with no winner recorded yet — the only
  /// state in which a bracket match can actually be checked in and played.
  bool get isPlayable => winnerUid == null && a.uid != null && b.uid != null;
}

/// The fully derived bracket: ordered [rounds], the [slots] per round (ordered
/// by index), the [championUid] once the final resolves, and a flattened
/// [playableSlots] convenience view over every round.
class BracketTree {
  BracketTree({required this.rounds, required this.slots, this.championUid});

  List<String> rounds;
  Map<String, List<BracketSlot>> slots;
  String? championUid;

  List<BracketSlot> get playableSlots => [
    for (final round in rounds) ...?slots[round],
  ].where((slot) => slot.isPlayable).toList();
}

/// Derives the whole [BracketTree] deterministically from seed-compacted
/// [participants] (seeds `1..N`), the tournament's `bracket` map (round key →
/// played matchIds), and its [matches].
///
/// Rules: `bracketSize` is the next power of two ≥ N; round-1 slots are filled
/// via the standard tournament seed-distribution order (see [_seedOrder]) so
/// the top two seeds can only meet in the final, the top four no earlier than
/// the semifinal, and so on (a missing seed is a bye); the winner of slot `j`
/// feeds side a (even `j`) or b (odd `j`) of slot `j ~/ 2` in the next round.
/// Per-slot winner resolution, in priority order:
/// (1) a confirmed match for this round — sourced from `bracket[round]` or any
/// match whose own `tournamentRound` equals the round — whose players equal the
/// slot pair, (2) a bye, (3) an organizer forfeit (a real side flagged
/// `eliminated` with no confirmed defeat).
BracketTree build({
  required List<TournamentParticipantModel> participants,
  required Map<String, List<String>> bracket,
  required List<MatchModel> matches,
}) {
  final bracketSize = _nextPowerOfTwo(participants.length);
  final rounds = roundKeysForSize(bracketSize);

  final seedToUid = <int, String>{for (final p in participants) p.seed: p.uid};
  final eliminated = <String>{
    for (final p in participants)
      if (p.eliminated) p.uid,
  };
  final matchById = <String, MatchModel>{for (final m in matches) m.matchId: m};

  // Round key → played matchIds. The persisted `bracket` map is the fast path,
  // but every match doc also carries its own `tournamentRound`, so fold those
  // in: a match whose id never reached `bracket[round]` (e.g. a best-effort
  // `recordBracketMatch` write that failed on a transient error) still resolves
  // its slot from the doc alone. The map is thus a cache over the match docs,
  // never a source of truth that can silently desync.
  final roundMatchIds = <String, List<String>>{
    for (final e in bracket.entries) e.key: [...e.value],
  };
  for (final m in matches) {
    final round = m.tournamentRound;
    if (round == null) continue;
    final ids = roundMatchIds[round] ??= <String>[];
    if (!ids.contains(m.matchId)) ids.add(m.matchId);
  }

  // A participant has "lost a confirmed bracket match" when a confirmed match
  // lists them among the players but not the winners. This distinguishes an
  // organizer forfeit (eliminated, no such loss) from a real defeat (which a
  // confirmed match already resolves via priority 1).
  bool hasLostConfirmed(String uid) => matches.any(
    (m) =>
        m.state == MatchStates.confirmed &&
        m.playerUids.contains(uid) &&
        !(m.result?.winnerIds.contains(uid) ?? false),
  );

  // Empty scaffold: each round holds (playersInRound / 2) all-TBD slots.
  final slots = <String, List<BracketSlot>>{};
  for (var ri = 0; ri < rounds.length; ri++) {
    final slotCount = (bracketSize >> ri) ~/ 2;
    slots[rounds[ri]] = [
      for (var k = 0; k < slotCount; k++)
        BracketSlot(
          round: rounds[ri],
          index: k,
          a: BracketSide(),
          b: BracketSide(),
        ),
    ];
  }

  // Round 1: seeds placed via the standard seed-distribution order so the
  // strongest seeds are kept apart for as long as possible (seed 1 and seed 2
  // land in opposite halves and can only meet in the final). A seed beyond N
  // has no participant and resolves to a bye on whichever side it lands.
  if (rounds.isNotEmpty) {
    final order = _seedOrder(bracketSize);
    final first = slots[rounds.first]!;
    for (var k = 0; k < first.length; k++) {
      first[k].a = _sideForSeed(seedToUid[order[2 * k]]);
      first[k].b = _sideForSeed(seedToUid[order[2 * k + 1]]);
    }
  }

  // Resolve each round in order, feeding every resolved winner into the parent
  // slot of the next round (even index → side a, odd → side b).
  for (var ri = 0; ri < rounds.length; ri++) {
    for (final slot in slots[rounds[ri]]!) {
      _resolveSlot(
        slot,
        roundMatchIds[slot.round],
        matchById,
        eliminated,
        hasLostConfirmed,
      );
      if (ri + 1 < rounds.length && slot.winnerUid != null) {
        final parent = slots[rounds[ri + 1]]![slot.index ~/ 2];
        final winnerSide = BracketSide(uid: slot.winnerUid);
        if (slot.index.isEven) {
          parent.a = winnerSide;
        } else {
          parent.b = winnerSide;
        }
      }
    }
  }

  final championUid = rounds.isEmpty
      ? (participants.length == 1 ? participants.single.uid : null)
      : slots[rounds.last]!.single.winnerUid;

  return BracketTree(rounds: rounds, slots: slots, championUid: championUid);
}

BracketSide _sideForSeed(String? uid) =>
    uid != null ? BracketSide(uid: uid) : BracketSide(isBye: true);

/// Resolves [slot]'s [BracketSlot.matchId] and [BracketSlot.winnerUid] in the
/// documented priority order: a confirmed bracket match for the exact pair, a
/// bye, then an organizer forfeit.
void _resolveSlot(
  BracketSlot slot,
  List<String>? roundMatchIds,
  Map<String, MatchModel> matchById,
  Set<String> eliminated,
  bool Function(String) hasLostConfirmed,
) {
  final aUid = slot.a.uid;
  final bUid = slot.b.uid;
  final bothReal = aUid != null && bUid != null;

  // (1) A confirmed match whose players are exactly this slot's pair. A pending
  // (not-yet-confirmed) match for the pair still backs the slot's matchId.
  if (bothReal && roundMatchIds != null) {
    final pair = {aUid, bUid};
    for (final id in roundMatchIds) {
      final m = matchById[id];
      if (m == null) continue;
      final players = m.playerUids.toSet();
      if (players.length != pair.length || !players.containsAll(pair)) continue;
      slot.matchId = m.matchId;
      if (m.state == MatchStates.confirmed) {
        final winners = m.result?.winnerIds ?? const [];
        if (winners.isNotEmpty) {
          slot.winnerUid = winners.first;
          return;
        }
      }
    }
  }

  // (2) Bye: the real side advances unopposed.
  if (slot.b.isBye && aUid != null) {
    slot.winnerUid = aUid;
    return;
  }
  if (slot.a.isBye && bUid != null) {
    slot.winnerUid = bUid;
    return;
  }

  // (3) Forfeit: a real side flagged eliminated with no confirmed defeat has
  // been forfeited by the organizer, so the other side advances. Both
  // forfeited → side a advances (degenerate, tolerated).
  if (bothReal) {
    final aForfeit = eliminated.contains(aUid) && !hasLostConfirmed(aUid);
    final bForfeit = eliminated.contains(bUid) && !hasLostConfirmed(bUid);
    if (aForfeit && bForfeit) {
      slot.winnerUid = aUid;
    } else if (bForfeit) {
      slot.winnerUid = aUid;
    } else if (aForfeit) {
      slot.winnerUid = bUid;
    }
  }
}

/// The standard tournament seed-distribution order for a [size]-slot bracket:
/// position `2k`/`2k+1` (0-based) are the seeds for round-1 slot `k`. Built by
/// recursively doubling — each existing seed `s` is paired with its complement
/// `total + 1 − s`, alternating which one comes first so that every doubling
/// keeps the two strongest seeds seen so far apart in different halves. E.g.
/// size 8 → `[1, 8, 5, 4, 3, 6, 7, 2]`.
List<int> _seedOrder(int size) {
  var order = <int>[1];
  var current = 1;
  while (current < size) {
    final total = current * 2;
    final next = <int>[];
    for (var i = 0; i < order.length; i++) {
      final s = order[i];
      final complement = total + 1 - s;
      if (i.isEven) {
        next
          ..add(s)
          ..add(complement);
      } else {
        next
          ..add(complement)
          ..add(s);
      }
    }
    order = next;
    current = total;
  }
  return order;
}

/// Smallest power of two ≥ [n] (the bracket size); 1 for the degenerate empty
/// or single-participant bracket.
int _nextPowerOfTwo(int n) {
  if (n <= 1) return 1;
  var p = 1;
  while (p < n) {
    p <<= 1;
  }
  return p;
}
