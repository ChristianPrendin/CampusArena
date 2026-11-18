import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/achievements/achievement_evaluator.dart';
import '../core/constants.dart';
import '../core/elo/elo_calculator.dart';
import '../models/achievement_def_model.dart';
import '../models/match_model.dart';
import '../models/rating_model.dart';
import 'achievement_repository.dart';
import 'rating_repository.dart';

/// Owns `matches/{matchId}` and the facility-status side effects of the match
/// lifecycle.
///
/// Every state-changing method runs inside [FirebaseFirestore.runTransaction].
/// Transactions are not offline-persisted, so they fail fast when there is no
/// connectivity — this is how ranked writes assert the network per the
/// "ranked matches require connectivity" rule, without a connectivity package.
///
/// The confirm path is the ELO **compute-and-supply layer** (task board Phase 4
/// Transaction Rule): it reads the rated entities, computes the update with the
/// pure [EloCalculator], and folds the ratings-doc writes into the *same*
/// match-confirmation transaction — never a separate `updateElo` afterwards, so
/// match history and ratings can never desync.
class MatchRepository {
  MatchRepository({
    FirebaseFirestore? firestore,
    RatingRepository? ratingRepository,
    EloCalculator? eloCalculator,
    AchievementRepository? achievementRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _ratingRepo =
           ratingRepository ??
           RatingRepository(firestore: firestore ?? FirebaseFirestore.instance),
       _elo = eloCalculator ?? const EloCalculator(),
       _achievementRepo =
           achievementRepository ??
           AchievementRepository(
             firestore: firestore ?? FirebaseFirestore.instance,
           );

  final FirebaseFirestore _firestore;
  final RatingRepository _ratingRepo;
  final EloCalculator _elo;
  final AchievementRepository _achievementRepo;
  static const AchievementEvaluator _achievements = AchievementEvaluator();

  /// Spark-tier bound on the per-player confirmed-history read that feeds
  /// achievement evaluation (win streak, monthly count, explorer).
  static const int badgeHistoryLimit = 50;

  /// Spark-tier bound on the campus-facility scan that gives the Explorer badge
  /// its target set.
  static const int badgeFacilityScanLimit = 50;

  CollectionReference<Map<String, dynamic>> get _matches =>
      _firestore.collection(FirestoreCollections.matches);

  CollectionReference<Map<String, dynamic>> get _facilities =>
      _firestore.collection(FirestoreCollections.facilities);

  CollectionReference<Map<String, dynamic>> get _ratings =>
      _firestore.collection(FirestoreCollections.ratings);

  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _firestore.collection(FirestoreCollections.tournaments);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestoreCollections.users);

  CollectionReference<Map<String, dynamic>> _queue(String facilityId) =>
      _facilities.doc(facilityId).collection(FirestoreCollections.queue);

  /// A table sitting `free` longer than this before a scan means the
  /// front-of-queue holders never showed — the claim purges them
  /// (`project_description.md` §3.4 step 2).
  static const Duration staleQueueThreshold = Duration(minutes: 5);

  /// Spark-tier bound on the eviction pre-read.
  static const int maxQueuePurge = 25;

  /// A match stuck `occupied` longer than this (no result ever submitted) is
  /// lazily transitioned to `abandoned` (schema Timeout note). No `submittedAt`
  /// timestamp exists, so both timeouts measure from `startedAt`.
  static const Duration occupiedTimeout = Duration(hours: 4);

  /// A match stuck `awaitingConfirmation` longer than this (opponent never
  /// responded) is lazily transitioned to `unconfirmed`.
  static const Duration awaitingConfirmationTimeout = Duration(hours: 24);

  /// Creates the match and atomically occupies its facility. If
  /// [MatchModel.matchId] is empty an ID is auto-generated. Returns the ID.
  ///
  /// Queue eviction: the scanning player(s) ([MatchModel.playerUids]) leave the
  /// line for the table, so their own queue tickets are always deleted in this
  /// transaction — otherwise a phantom ticket keeps the facility falsely
  /// `queued` after the match ends. Additionally, if the facility has been
  /// `free` for longer than [staleQueueThreshold], the scanner claims past any
  /// no-show front-runners *ahead* of them — only entries with a lower
  /// `position` than the scanner's are purged; anyone waiting behind keeps their
  /// ticket. A walk-up with no ticket treats the whole stale line as no-shows.
  /// [now] is injectable for tests.
  Future<String> createMatch(MatchModel match, {DateTime? now}) async {
    final ref = match.matchId.isEmpty
        ? _matches.doc()
        : _matches.doc(match.matchId);

    // Queries can't run inside a transaction (only doc reads), so the queue is
    // pre-read here; the deletes below still commit atomically with the occupy.
    final queueSnap = await _queue(
      match.facilityId,
    ).orderBy('position').limit(maxQueuePurge).get();

    await _firestore.runTransaction((tx) async {
      // Read the facility into the transaction (asserts connectivity).
      final facilitySnap = await tx.get(_facilities.doc(match.facilityId));
      final facilityData = facilitySnap.data();

      if (facilityData?['status'] != FacilityStatus.free) {
        throw StateError('Facility is currently occupied.');
      }

      final freedAt = (facilityData?['freedAt'] as Timestamp?)?.toDate();
      final purgeStale =
          freedAt != null &&
          (now ?? DateTime.now()).difference(freedAt) > staleQueueThreshold;

      int positionOf(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
          (d.data()['position'] as num?)?.toInt() ?? 0;

      final scanners = match.playerUids.toSet();
      // The scanner's own front-most ticket position, or null for a walk-up who
      // never queued. It is the cut-off: only tickets ahead of it are no-shows.
      int? scannerPosition;
      for (final d in queueSnap.docs) {
        if (!scanners.contains(d.id)) continue;
        final p = positionOf(d);
        if (scannerPosition == null || p < scannerPosition) scannerPosition = p;
      }

      // A no-show front-runner is a non-scanner ticket ahead of the scanner (or,
      // for a walk-up with no ticket, any non-scanner ticket).
      bool isNoShowAhead(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
          !scanners.contains(d.id) &&
          (scannerPosition == null || positionOf(d) < scannerPosition);

      for (final doc in queueSnap.docs) {
        // Always drop the scanning players' own tickets; only drop others when
        // the stale claim is purging no-show front-runners ahead of them.
        if (scanners.contains(doc.id) || (purgeStale && isNoShowAhead(doc))) {
          tx.delete(_queue(match.facilityId).doc(doc.id));
        }
      }

      // Anyone left waiting behind this check-in keeps the 'queued' marker so
      // the queue vertical knows the table has a line; an empty survivor set
      // reads plain 'occupied'.
      final hasQueue = queueSnap.docs.any(
        (d) => !scanners.contains(d.id) && !(purgeStale && isNoShowAhead(d)),
      );

      tx.set(ref, match.toMap());
      tx.update(_facilities.doc(match.facilityId), {
        'status': hasQueue ? FacilityStatus.queued : FacilityStatus.occupied,
        'currentMatchId': ref.id,
      });
    });
    return ref.id;
  }

  /// Joins an existing active match at [facilityId]. Used when an opponent scans
  /// the QR code of an already-occupied table. A table that is occupied *with a
  /// queue* reads `queued` (per the join-queue status marker), not `occupied`,
  /// so both count as joinable — otherwise no opponent could ever join a match
  /// at a table that has anyone waiting.
  ///
  /// Tournament context: a bracket player deep-linking into a slot carries
  /// [tournamentId] / [tournamentRound]. When the joined match was created
  /// context-free (the opponent scanned the plain facility QR first, so its
  /// `tournamentId` is null), these are patched onto the doc in the SAME
  /// transaction as the roster append — so the confirm applies the ×1.5
  /// multiplier and the slot resolves. Never overwrites an existing
  /// `tournamentId` (a real tournament match keeps its own context).
  /// [team] (1 or 2) is the side a joiner picked in a doubles match; it is
  /// appended to that side's `teamNPairId` (a sorted-uid `_`-join grown as
  /// players pick sides — a 1-member value is just the uid, the deterministic
  /// `pairIdFromUids` of a single member). Ignored for singles. A side already
  /// holding two members is full: joining it throws `StateError`.
  Future<String> joinMatch({
    required String facilityId,
    required String uid,
    int? team,
    String? tournamentId,
    String? tournamentRound,
  }) async {
    return _firestore.runTransaction((tx) async {
      final facilitySnap = await tx.get(_facilities.doc(facilityId));
      final facilityData = facilitySnap.data();

      final status = facilityData?['status'];
      if (status != FacilityStatus.occupied &&
          status != FacilityStatus.queued) {
        throw StateError('Facility is not occupied.');
      }

      final matchId = facilityData?['currentMatchId'] as String?;
      if (matchId == null) {
        throw StateError('No active match found for this facility.');
      }

      final matchRef = _matches.doc(matchId);
      final matchSnap = await tx.get(matchRef);
      final matchData = matchSnap.data();

      if (matchData == null || matchData['state'] != MatchStates.occupied) {
        throw StateError('Match is no longer joinable.');
      }

      final playerUids = List<String>.from(matchData['playerUids'] ?? []);
      final mode = matchData['mode'] as String? ?? MatchModes.singles;
      final maxPlayers = mode == MatchModes.doubles ? 4 : 2;

      final update = <String, dynamic>{};
      if (!playerUids.contains(uid) && playerUids.length < maxPlayers) {
        // Doubles: place the joiner on their chosen side, rejecting a side that
        // is already full so a race can't overfill a team. Grown as a sorted-uid
        // `_`-join; both teamNPairId fields hold the final pairId once full,
        // which the confirm path recomputes identically via pairIdFromUids.
        if (mode == MatchModes.doubles && team != null) {
          final field = team == 1 ? 'team1PairId' : 'team2PairId';
          final current = matchData[field] as String?;
          final members = current == null || current.isEmpty
              ? <String>[]
              : current.split('_');
          if (members.length >= 2) {
            throw StateError('That side is already full.');
          }
          members.add(uid);
          update[field] = pairIdFromUids(members);
        }
        playerUids.add(uid);
        update['playerUids'] = playerUids;
      }
      // Backfill tournament context onto a context-free match, only when it has
      // none yet — otherwise the opponent's ×1.0 walk-up would swallow a bracket
      // slot that this player deep-linked into.
      if (tournamentId != null &&
          tournamentRound != null &&
          matchData['tournamentId'] == null) {
        update['tournamentId'] = tournamentId;
        update['tournamentRound'] = tournamentRound;
      }
      if (update.isNotEmpty) tx.update(matchRef, update);

      return matchId;
    });
  }

  /// Cancels an in-progress check-in and frees its facility. Used when the
  /// player leaves before any result is submitted. Sets the match to
  /// `abandoned` only while it is still `occupied`, and frees the facility only
  /// while it still points at this match — so a match that raced to
  /// `awaitingConfirmation`, or a facility already reassigned, is left
  /// untouched. [now] is injectable for tests.
  Future<void> abandonMatch({
    required String matchId,
    required String facilityId,
    DateTime? now,
  }) {
    return _firestore.runTransaction((tx) async {
      final matchRef = _matches.doc(matchId);
      final facilityRef = _facilities.doc(facilityId);
      final matchSnap = await tx.get(matchRef);
      final facilitySnap = await tx.get(facilityRef);

      if (matchSnap.data()?['state'] != MatchStates.occupied) return;

      tx.update(matchRef, {'state': MatchStates.abandoned});

      if (facilitySnap.data()?['currentMatchId'] == matchId) {
        tx.update(facilityRef, {
          'status': FacilityStatus.free,
          'currentMatchId': null,
          'freedAt': Timestamp.fromDate(now ?? DateTime.now()),
        });
      }
    });
  }

  /// Cancels a check-in that never became a real match — the creator left while
  /// still alone at the table (no opponent had joined). Unlike [abandonMatch],
  /// this leaves no `abandoned` record in anyone's history: the match doc is
  /// deleted outright and its facility freed. Guarded like [abandonMatch] — the
  /// delete/free only run while the match is still `occupied` and the facility
  /// still points at it, so a raced check-in or reassignment is left untouched.
  Future<void> cancelMatch({
    required String matchId,
    required String facilityId,
    DateTime? now,
  }) {
    return _firestore.runTransaction((tx) async {
      final matchRef = _matches.doc(matchId);
      final facilityRef = _facilities.doc(facilityId);
      final matchSnap = await tx.get(matchRef);
      final facilitySnap = await tx.get(facilityRef);

      if (matchSnap.data()?['state'] != MatchStates.occupied) return;

      tx.delete(matchRef);

      if (facilitySnap.data()?['currentMatchId'] == matchId) {
        tx.update(facilityRef, {
          'status': FacilityStatus.free,
          'currentMatchId': null,
          'freedAt': Timestamp.fromDate(now ?? DateTime.now()),
        });
      }
    });
  }

  Stream<MatchModel?> watchMatch(String matchId) {
    return _matches.doc(matchId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return MatchModel.fromMap(data, snap.id);
    });
  }

  /// The live match at a facility, if any (`occupied` or `awaitingConfirmation`).
  ///
  /// Not used by the join-probe path (see [getActiveMatchForFacility]): this
  /// query picks the most recent match by `startedAt` among a whole collection
  /// scan, so a stale/leftover match doc at the same facility can outrank the
  /// real current one, and `.snapshots().first` can settle on a stale/empty
  /// cache read before the server round-trip lands.
  Stream<MatchModel?> watchActiveMatchForFacility(String facilityId) {
    return _matches
        .where('facilityId', isEqualTo: facilityId)
        .where(
          'state',
          whereIn: [MatchStates.occupied, MatchStates.awaitingConfirmation],
        )
        .orderBy('startedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((q) {
          if (q.docs.isEmpty) return null;
          final doc = q.docs.first;
          return MatchModel.fromMap(doc.data(), doc.id);
        });
  }

  /// The live match at [facilityId], resolved via the facility's own
  /// `currentMatchId` pointer rather than a query — the same authoritative
  /// source [createMatch] writes and [joinMatch] already trusts. Two
  /// server-fresh single-doc reads, so it can't return a stale/phantom match
  /// from elsewhere in the collection and doesn't depend on a composite index.
  ///
  /// Returns null when the facility has no live match: no `currentMatchId`, a
  /// dangling pointer to a deleted doc, or a match that has already resolved
  /// past `occupied`/`awaitingConfirmation`. A genuine read failure (offline,
  /// permission) propagates instead of being folded into that null, so the
  /// caller can tell "no live match" from "the probe itself broke".
  Future<MatchModel?> getActiveMatchForFacility(String facilityId) async {
    final facilitySnap = await _facilities.doc(facilityId).get();
    final matchId = facilitySnap.data()?['currentMatchId'] as String?;
    if (matchId == null) return null;

    final MatchModel match;
    try {
      match = await _readMatch(matchId);
    } on StateError {
      return null;
    }
    final isLive =
        match.state == MatchStates.occupied ||
        match.state == MatchStates.awaitingConfirmation;
    return isLive ? match : null;
  }

  /// History feed for a specific user (singles or doubles), newest first.
  /// [limit] caps the number of docs the query fetches; omit it for the full
  /// history. Served by the `(playerUids, startedAt)` composite index.
  Stream<List<MatchModel>> watchUserMatches(String uid, {int? limit}) {
    Query<Map<String, dynamic>> query = _matches
        .where('playerUids', arrayContains: uid)
        .orderBy('startedAt', descending: true);
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map(
      (q) => q.docs.map((d) => MatchModel.fromMap(d.data(), d.id)).toList(),
    );
  }

  /// History feed for one doubles pair, newest first. Reuses the
  /// `(playerUids, startedAt)` index by querying on one member's uid, then
  /// filtering client-side to the matches where this exact pair is a side
  /// (`team1PairId`/`team2PairId` == [pairId]) — so no new index is needed.
  /// [limit] caps the fetched docs (the pair is a subset of that member's
  /// history, so over-fetch slightly).
  Stream<List<MatchModel>> watchPairMatches(
    String pairId,
    String memberUid, {
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _matches
        .where('playerUids', arrayContains: memberUid)
        .orderBy('startedAt', descending: true);
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map(
      (q) => q.docs
          .map((d) => MatchModel.fromMap(d.data(), d.id))
          .where((m) => m.team1PairId == pairId || m.team2PairId == pairId)
          .toList(),
    );
  }

  /// One-shot bounded fetch of every match in a tournament's bracket, backing
  /// the live-bracket derivation. A single equality filter on `tournamentId`
  /// needs no composite index; [limit] is the Spark-tier bound (a full bracket
  /// is at most `bracketSize − 1` matches, well under the default).
  Future<List<MatchModel>> getTournamentMatches(
    String tournamentId, {
    int limit = 64,
  }) async {
    final snap = await _matches
        .where('tournamentId', isEqualTo: tournamentId)
        .limit(limit)
        .get();
    return snap.docs.map((d) => MatchModel.fromMap(d.data(), d.id)).toList();
  }

  /// Live, bounded view of every match in a tournament's bracket, backing the
  /// live-bracket derivation. Unlike [getTournamentMatches], this stays
  /// subscribed so a pending→confirmed transition on any bracket match
  /// re-derives the tree immediately, without depending on the tournament's
  /// `bracket` map changing.
  Stream<List<MatchModel>> watchTournamentMatches(
    String tournamentId, {
    int limit = 64,
  }) {
    return _matches
        .where('tournamentId', isEqualTo: tournamentId)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => MatchModel.fromMap(d.data(), d.id)).toList(),
        );
  }

  /// One player submits the result → `awaitingConfirmation`. Guarded: a stale or
  /// raced submit (the match is no longer `occupied` — already submitted,
  /// resolved, or timed out) throws [StateError], surfaced as a UI error.
  Future<void> submitResult({
    required String matchId,
    required MatchResult result,
    required String submittedByUid,
  }) {
    return _firestore.runTransaction((tx) async {
      final ref = _matches.doc(matchId);
      final snap = await tx.get(ref);
      if (snap.data()?['state'] != MatchStates.occupied) {
        throw StateError('Match is no longer accepting a result.');
      }
      tx.update(ref, {
        'state': MatchStates.awaitingConfirmation,
        'result': result.toMap(),
        'submittedByUid': submittedByUid,
      });
    });
  }

  /// Opponent confirms → `confirmed`. Reads the two rated entities, computes the
  /// ELO exchange, and folds every write — match doc, both rating docs, facility
  /// status, King of the Table, and any newly-earned achievement badges — into
  /// ONE atomic transaction (Phase 4 Transaction Rule). Throws [StateError] if
  /// the match is no longer `awaitingConfirmation`. [now] is injectable.
  ///
  /// Returns the badges unlocked by this confirmation, keyed by player uid
  /// (`uid → {achievementId}`) — write-once, so an already-owned badge is never
  /// in the map. The caller surfaces the confirming user's own set as the
  /// in-app unlock reveal.
  Future<Map<String, Set<String>>> confirmResult({
    required String matchId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();

    // Pre-read outside the transaction: the match doc drives who the sides are,
    // and the pair-rating resolution / King-of-Table counts / achievement
    // history all need queries, which can't run inside a transaction.
    final match = await _readMatch(matchId);
    if (match.state != MatchStates.awaitingConfirmation) {
      throw StateError('Match is not awaiting confirmation.');
    }
    final plan = await _prepareConfirmation(match, effectiveNow);

    return _firestore.runTransaction<Map<String, Set<String>>>((tx) async {
      final matchRef = _matches.doc(matchId);
      final snap = await tx.get(matchRef);
      // Re-assert the guard atomically — a concurrent dispute/confirm wins.
      if (snap.data()?['state'] != MatchStates.awaitingConfirmation) {
        throw StateError('Match is not awaiting confirmation.');
      }
      return _writeConfirmation(tx, plan, matchRef, effectiveNow);
    });
  }

  /// Opponent disputes → `disputed`. No ELO change; facility freed.
  ///
  /// Griefer mitigation (schema): the disputer's `disputeCount` increments; the
  /// 3rd dispute sets a 7-day `disputePenaltyUntil` and resets the count. A
  /// disputer already serving that penalty has their dispute intercepted and the
  /// match **force-confirmed with ELO processed normally** — the exact same
  /// in-transaction writes as [confirmResult] (via [_writeConfirmation]), so the
  /// two paths cannot drift. [now] is injectable for tests.
  Future<void> disputeResult({
    required String matchId,
    required String disputingUid,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final match = await _readMatch(matchId);

    // A force-confirm needs the confirmation plan (pair ratings + KotT counts),
    // whose queries must run before the transaction. Only prepare it when the
    // disputer is (pre-read) penalized — the common, un-penalized dispute pays
    // for none of that work, and the transaction re-checks the penalty
    // authoritatively before acting on it.
    final penalizedPreRead = await _isPenalized(disputingUid, effectiveNow);
    final plan = penalizedPreRead
        ? await _prepareConfirmation(match, effectiveNow)
        : null;

    await _firestore.runTransaction((tx) async {
      final matchRef = _matches.doc(matchId);
      final userRef = _users.doc(disputingUid);
      final matchSnap = await tx.get(matchRef);
      if (matchSnap.data()?['state'] != MatchStates.awaitingConfirmation) {
        throw StateError('Match is not awaiting confirmation.');
      }
      final userData = (await tx.get(userRef)).data();

      final penaltyUntil = userData?['disputePenaltyUntil'] as Timestamp?;
      final isPenalized =
          penaltyUntil != null && penaltyUntil.toDate().isAfter(effectiveNow);

      if (isPenalized && plan != null) {
        // Intercepted griefer: force confirm with real ELO, identical writes.
        await _writeConfirmation(tx, plan, matchRef, effectiveNow);
        return;
      }

      // Genuine dispute: bump the counter (7-day penalty on the 3rd), then mark
      // disputed and free the facility. No ELO change.
      final currentDisputes = (userData?['disputeCount'] as num?)?.toInt() ?? 0;
      final nextDisputes = currentDisputes + 1;
      final Map<String, dynamic> userUpdates = {'disputeCount': nextDisputes};
      if (nextDisputes >= 3) {
        userUpdates['disputePenaltyUntil'] = Timestamp.fromDate(
          effectiveNow.add(const Duration(days: 7)),
        );
        userUpdates['disputeCount'] = 0;
      }
      tx.set(userRef, userUpdates, SetOptions(merge: true));

      tx.update(matchRef, {'state': MatchStates.disputed});
      _freeFacility(tx, match.facilityId, effectiveNow);
    });
  }

  /// Lazily resolves a stale [match] (schema Timeout note): `occupied` past
  /// [occupiedTimeout] → `abandoned`; `awaitingConfirmation` past
  /// [awaitingConfirmationTimeout] → `unconfirmed`. No ELO change; the facility
  /// is freed. State-guarded inside the transaction so a concurrent real
  /// transition is never clobbered, and a no-op when the match is fresh or
  /// already terminal. [now] is injectable for tests.
  Future<void> resolveTimeout(MatchModel match, {DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final elapsed = effectiveNow.difference(match.startedAt);

    final String expectedState;
    final String targetState;
    if (match.state == MatchStates.occupied && elapsed > occupiedTimeout) {
      expectedState = MatchStates.occupied;
      targetState = MatchStates.abandoned;
    } else if (match.state == MatchStates.awaitingConfirmation &&
        elapsed > awaitingConfirmationTimeout) {
      expectedState = MatchStates.awaitingConfirmation;
      targetState = MatchStates.unconfirmed;
    } else {
      return; // Fresh or terminal.
    }

    await _firestore.runTransaction((tx) async {
      final matchRef = _matches.doc(match.matchId);
      final facilityRef = _facilities.doc(match.facilityId);
      final matchSnap = await tx.get(matchRef);
      final facilitySnap = await tx.get(facilityRef);

      if (matchSnap.data()?['state'] != expectedState) return;

      tx.update(matchRef, {'state': targetState});
      if (facilitySnap.data()?['currentMatchId'] == match.matchId) {
        _freeFacility(tx, match.facilityId, effectiveNow);
      }
    });
  }

  // --- confirm internals ---------------------------------------------------

  Future<MatchModel> _readMatch(String matchId) async {
    final snap = await _matches.doc(matchId).get();
    final data = snap.data();
    if (data == null) throw StateError('Match $matchId not found.');
    return MatchModel.fromMap(data, snap.id);
  }

  Future<bool> _isPenalized(String uid, DateTime now) async {
    try {
      final data = (await _users.doc(uid).get()).data();
      final until = data?['disputePenaltyUntil'] as Timestamp?;
      return until != null && until.toDate().isAfter(now);
    } catch (_) {
      return false;
    }
  }

  /// Resolves the confirmation inputs whose queries can't live inside the
  /// transaction: the winner/loser rating doc refs (creating pair ratings for
  /// doubles) and the King-of-Table win projection per winner uid. The winner
  /// is always side A with an [EloOutcome.win]; these sports admit no draw.
  Future<_ConfirmationPlan> _prepareConfirmation(
    MatchModel match,
    DateTime now,
  ) async {
    final result = match.result;
    final winnerIds = result?.winnerIds ?? const [];
    if (winnerIds.isEmpty) {
      throw StateError('Cannot confirm a match with no winner.');
    }

    final String winnerKey;
    final String loserKey;
    if (match.mode == 'doubles') {
      final winners = winnerIds;
      final losers = match.playerUids
          .where((u) => !winnerIds.contains(u))
          .toList();
      // Idempotent: resolves (and creates on first use) each pair's rating so
      // the transaction can read it fresh.
      await _ratingRepo.getOrCreatePairRating(
        sportId: match.sportId,
        memberUids: winners,
      );
      await _ratingRepo.getOrCreatePairRating(
        sportId: match.sportId,
        memberUids: losers,
      );
      winnerKey = pairIdFromUids(winners);
      loserKey = pairIdFromUids(losers);
    } else {
      winnerKey = winnerIds.first;
      loserKey = match.playerUids.firstWhere((u) => !winnerIds.contains(u));
    }

    // King of the Table is an individual tally: every winner uid (both, in
    // doubles) gains a win here. Pick the winner whose projected count is
    // highest; the transaction promotes them only if it beats the incumbent.
    String? kingUid;
    var kingWins = 0;
    for (final uid in winnerIds) {
      final wins = await _confirmedWinsAt(match.facilityId, uid) + 1;
      if (wins > kingWins) {
        kingWins = wins;
        kingUid = uid;
      }
    }

    final badges = await _prepareBadgeInputs(
      match,
      winnerIds: winnerIds,
      winnerKey: winnerKey,
      loserKey: loserKey,
    );

    return _ConfirmationPlan(
      facilityId: match.facilityId,
      sportId: match.sportId,
      winnerRef: _ratings.doc(
        RatingRepository.ratingId(match.sportId, winnerKey),
      ),
      loserRef: _ratings.doc(
        RatingRepository.ratingId(match.sportId, loserKey),
      ),
      winnerKey: winnerKey,
      loserKey: loserKey,
      tournamentId: match.tournamentId,
      kingUid: kingUid,
      kingWins: kingWins,
      badges: badges,
    );
  }

  /// Gathers the per-player achievement inputs whose reads can't live inside the
  /// transaction: each player's confirmed history (win streak / monthly / first
  /// victory), the campus-facility set (explorer target), and each player's
  /// current badge keys (write-once). Cosmetic per the Spark-Tier Trust Boundary,
  /// so any failure degrades to "no badges" and never fails the confirmation
  /// (the decorative-lookup rule).
  ///
  /// Note: this write-once read is non-transactional (unlike the tournament
  /// path, which reads `badges` via `tx.get`). Two concurrent confirmations for
  /// the same user could both pass the write-once check and re-stamp the unlock
  /// timestamp. Impact is cosmetic-only — the id is still present, only its
  /// timestamp moves — so it isn't worth the extra in-transaction round-trips.
  Future<_BadgeInputs> _prepareBadgeInputs(
    MatchModel match, {
    required List<String> winnerIds,
    required String winnerKey,
    required String loserKey,
  }) async {
    try {
      final defs = await _achievementRepo.getDefinitions();
      if (defs.isEmpty) return _BadgeInputs.empty;

      final facilitiesSnap = await _facilities
          .limit(badgeFacilityScanLimit)
          .get();
      final allFacilityIds = facilitiesSnap.docs.map((d) => d.id).toSet();

      final players = <_PlayerBadgeInputs>[];
      for (final uid in match.playerUids) {
        final won = winnerIds.contains(uid);
        final histSnap = await _matches
            .where('playerUids', arrayContains: uid)
            .orderBy('startedAt', descending: true)
            .limit(badgeHistoryLimit)
            .get();
        final prior = <ConfirmedMatchRecord>[];
        for (final d in histSnap.docs) {
          if (d.id == match.matchId) continue; // this match isn't prior history
          final m = MatchModel.fromMap(d.data(), d.id);
          if (m.state != MatchStates.confirmed) continue;
          prior.add(
            ConfirmedMatchRecord(
              won: m.result?.winnerIds.contains(uid) ?? false,
              sportId: m.sportId,
              facilityId: m.facilityId,
              playedAt: m.confirmedAt ?? m.startedAt,
            ),
          );
        }
        final userData = (await _users.doc(uid).get()).data();
        final currentBadges =
            (userData?['badges'] as Map?)?.keys
                .map((k) => k as String)
                .toSet() ??
            <String>{};
        players.add(
          _PlayerBadgeInputs(
            uid: uid,
            won: won,
            ownKey: won ? winnerKey : loserKey,
            opponentKey: won ? loserKey : winnerKey,
            priorConfirmedMatches: prior,
            currentBadges: currentBadges,
          ),
        );
      }

      return _BadgeInputs(
        players: players,
        allFacilityIds: allFacilityIds,
        defs: defs,
      );
    } catch (_) {
      return _BadgeInputs.empty;
    }
  }

  /// Confirmed wins for [uid] at [facilityId] — a bounded `count()` aggregation.
  /// King of the Table is decorative, so an unavailable count (missing index,
  /// offline) degrades to 0 rather than failing the confirmation.
  Future<int> _confirmedWinsAt(String facilityId, String uid) async {
    try {
      final snap = await _matches
          .where('facilityId', isEqualTo: facilityId)
          .where('state', isEqualTo: MatchStates.confirmed)
          .where('result.winnerIds', arrayContains: uid)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// The shared confirm-write core, run inside a transaction after all reads.
  /// Computes the ELO exchange from the freshly-read rating docs and writes the
  /// match doc, both rating docs, the facility status, King of the Table, and
  /// any newly-earned achievement badges. Returns the unlocked badges keyed by
  /// player uid.
  Future<Map<String, Set<String>>> _writeConfirmation(
    Transaction tx,
    _ConfirmationPlan plan,
    DocumentReference<Map<String, dynamic>> matchRef,
    DateTime now,
  ) async {
    final winnerSnap = await tx.get(plan.winnerRef);
    final loserSnap = await tx.get(plan.loserRef);
    final facilityRef = _facilities.doc(plan.facilityId);
    final facilitySnap = await tx.get(facilityRef);
    final tournamentSnap = plan.tournamentId == null
        ? null
        : await tx.get(_tournaments.doc(plan.tournamentId!));

    final winner = RatingModel.fromMap(winnerSnap.data()!, winnerSnap.id);
    final loser = RatingModel.fromMap(loserSnap.data()!, loserSnap.id);

    // Materialize inactivity decay at confirm time: the eloBefore snapshot is
    // the decayed base, and the update is computed from it.
    final winnerElo = _elo.decayedElo(
      elo: winner.elo,
      lastMatchAt: winner.lastMatchAt,
      now: now,
    );
    final loserElo = _elo.decayedElo(
      elo: loser.elo,
      lastMatchAt: loser.lastMatchAt,
      now: now,
    );

    final multiplier =
        (tournamentSnap?.data()?['eloMultiplier'] as num?)?.toDouble() ?? 1.0;

    final update = _elo.computeUpdate(
      eloA: winnerElo,
      matchesPlayedA: winner.matchesPlayed,
      eloB: loserElo,
      matchesPlayedB: loser.matchesPlayed,
      outcomeA: EloOutcome.win,
      multiplier: multiplier,
    );

    tx.update(matchRef, {
      'state': MatchStates.confirmed,
      'confirmedAt': Timestamp.fromDate(now),
      'eloBefore': {plan.winnerKey: winnerElo, plan.loserKey: loserElo},
      'eloDeltas': {
        plan.winnerKey: update.deltaA,
        plan.loserKey: update.deltaB,
      },
    });
    tx.update(plan.winnerRef, {
      'elo': update.newEloA,
      'matchesPlayed': winner.matchesPlayed + 1,
      'lastMatchAt': Timestamp.fromDate(now),
    });
    tx.update(plan.loserRef, {
      'elo': update.newEloB,
      'matchesPlayed': loser.matchesPlayed + 1,
      'lastMatchAt': Timestamp.fromDate(now),
    });

    final facilityUpdate = <String, dynamic>{
      'status': FacilityStatus.free,
      'currentMatchId': null,
      'freedAt': Timestamp.fromDate(now),
    };
    final currentKingWins =
        (facilitySnap.data()?['kingOfTableWins'] as num?)?.toInt() ?? 0;
    if (plan.kingUid != null && plan.kingWins > currentKingWins) {
      facilityUpdate['kingOfTableUid'] = plan.kingUid;
      facilityUpdate['kingOfTableWins'] = plan.kingWins;
    }
    tx.update(facilityRef, facilityUpdate);

    return _writeBadges(tx, plan, {
      plan.winnerKey: winnerElo,
      plan.loserKey: loserElo,
    }, now);
  }

  /// Pure client-side achievement evaluation, folded into the same atomic commit
  /// as the match/ELO/facility writes. Runs the [AchievementEvaluator] for every
  /// player using the pre-read history/facility/badge inputs and the just-computed
  /// [eloBefore] snapshot (giant slayer's input), then writes each newly-earned
  /// `badges.{id} = Timestamp` via `merge` — write-once: the evaluator never
  /// returns an already-owned id, so an existing unlock timestamp is untouched.
  Map<String, Set<String>> _writeBadges(
    Transaction tx,
    _ConfirmationPlan plan,
    Map<String, int> eloBefore,
    DateTime now,
  ) {
    final byUid = <String, Set<String>>{};
    for (final p in plan.badges.players) {
      final earned = _achievements.evaluate(
        AchievementContext(
          playerUid: p.uid,
          wonThisMatch: p.won,
          sportId: plan.sportId,
          facilityId: plan.facilityId,
          playedAt: now,
          ownEloBefore: eloBefore[p.ownKey] ?? 0,
          opponentEloBefore: eloBefore[p.opponentKey] ?? 0,
          priorConfirmedMatches: p.priorConfirmedMatches,
          allFacilityIds: plan.badges.allFacilityIds,
          currentBadges: p.currentBadges,
          defs: plan.badges.defs,
        ),
      );
      if (earned.isEmpty) continue;
      byUid[p.uid] = earned;
      tx.set(_users.doc(p.uid), {
        'badges': {for (final id in earned) id: Timestamp.fromDate(now)},
      }, SetOptions(merge: true));
    }
    return byUid;
  }

  void _freeFacility(Transaction tx, String facilityId, DateTime now) {
    tx.update(_facilities.doc(facilityId), {
      'status': FacilityStatus.free,
      'currentMatchId': null,
      'freedAt': Timestamp.fromDate(now),
    });
  }
}

/// Confirmation inputs resolved outside the transaction (rating doc refs, the
/// entity keys for `eloBefore`/`eloDeltas`, and the King-of-Table projection).
class _ConfirmationPlan {
  const _ConfirmationPlan({
    required this.facilityId,
    required this.sportId,
    required this.winnerRef,
    required this.loserRef,
    required this.winnerKey,
    required this.loserKey,
    required this.tournamentId,
    required this.kingUid,
    required this.kingWins,
    required this.badges,
  });

  final String facilityId;
  final String sportId;
  final DocumentReference<Map<String, dynamic>> winnerRef;
  final DocumentReference<Map<String, dynamic>> loserRef;

  /// uid (singles) or pairId (doubles) — the `eloBefore`/`eloDeltas` map keys.
  final String winnerKey;
  final String loserKey;
  final String? tournamentId;

  /// The winner uid with the highest projected wins at the facility, and that
  /// projected count. Null when no King-of-Table promotion is a candidate.
  final String? kingUid;
  final int kingWins;

  /// Pre-read achievement inputs for every player.
  final _BadgeInputs badges;
}

/// Achievement inputs read outside the transaction: the shared campus-facility
/// set and definition list, plus per-player history and current badge keys.
class _BadgeInputs {
  const _BadgeInputs({
    required this.players,
    required this.allFacilityIds,
    required this.defs,
  });

  static const _BadgeInputs empty = _BadgeInputs(
    players: [],
    allFacilityIds: {},
    defs: [],
  );

  final List<_PlayerBadgeInputs> players;
  final Set<String> allFacilityIds;
  final List<AchievementDefModel> defs;
}

/// One player's achievement inputs. [ownKey]/[opponentKey] index the confirm's
/// `eloBefore` map (uid in singles, pairId in doubles) for the giant-slayer gap.
class _PlayerBadgeInputs {
  const _PlayerBadgeInputs({
    required this.uid,
    required this.won,
    required this.ownKey,
    required this.opponentKey,
    required this.priorConfirmedMatches,
    required this.currentBadges,
  });

  final String uid;
  final bool won;
  final String ownKey;
  final String opponentKey;
  final List<ConfirmedMatchRecord> priorConfirmedMatches;
  final Set<String> currentBadges;
}
