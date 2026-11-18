import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/achievements/achievement_evaluator.dart';
import '../core/constants.dart';
import '../models/tournament_model.dart';

/// Owns `tournaments/{tournamentId}` and its `participants` subcollection.
/// Bracket management is just `bracket` map writes plus per-participant
/// seed/elimination updates.
class TournamentRepository {
  TournamentRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestoreCollections.tournaments);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestoreCollections.users);

  CollectionReference<Map<String, dynamic>> _participants(String tournamentId) {
    return _col.doc(tournamentId).collection(FirestoreCollections.participants);
  }

  /// Creates the tournament. If [TournamentModel.tournamentId] is empty an ID
  /// is auto-generated. Returns the ID.
  Future<String> createTournament(TournamentModel tournament) async {
    final ref = tournament.tournamentId.isEmpty
        ? _col.doc()
        : _col.doc(tournament.tournamentId);
    await ref.set(tournament.toMap());
    return ref.id;
  }

  Future<TournamentModel?> getTournament(String tournamentId) async {
    final snap = await _col.doc(tournamentId).get();
    final data = snap.data();
    if (data == null) return null;
    return TournamentModel.fromMap(data, snap.id);
  }

  Stream<TournamentModel?> watchTournament(String tournamentId) {
    return _col.doc(tournamentId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return TournamentModel.fromMap(data, snap.id);
    });
  }

  /// Spark-tier default cap on the browser feed — every query is bounded.
  static const int defaultTournamentLimit = 25;

  /// Browser feed, optionally filtered by sport and/or status. [limit] bounds
  /// the read (Spark-tier rule); the results are ordered by `scheduledAt` so the
  /// cap keeps the *soonest* tournaments rather than an arbitrary doc-id slice
  /// (auto-ids are random w.r.t. schedule) — needs the
  /// `sportId + status + scheduledAt` composite index in `firestore.indexes.json`.
  Stream<List<TournamentModel>> watchTournaments({
    String? sportId,
    List<String>? statuses,
    int limit = defaultTournamentLimit,
  }) {
    Query<Map<String, dynamic>> query = _col;
    if (sportId != null) {
      query = query.where('sportId', isEqualTo: sportId);
    }
    if (statuses != null && statuses.isNotEmpty) {
      query = query.where('status', whereIn: statuses);
    }
    query = query.orderBy('scheduledAt').limit(limit);
    return query.snapshots().map(
      (q) =>
          q.docs.map((d) => TournamentModel.fromMap(d.data(), d.id)).toList(),
    );
  }

  /// One-shot (non-listening) read of tournaments whose `scheduledAt` falls
  /// within `[start, end)`, bounded by [limit]. Backs the chatbot's
  /// "tournaments today" tool — the caller passes the device-local day
  /// boundaries. A single range filter on `scheduledAt` needs no composite
  /// index beyond the existing single-field index Firestore creates
  /// automatically.
  Future<List<TournamentModel>> getTournamentsInWindow(
    DateTime start,
    DateTime end, {
    int limit = 25,
  }) async {
    final query = await _col
        .where(
          'scheduledAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
          isLessThan: Timestamp.fromDate(end),
        )
        .orderBy('scheduledAt')
        .limit(limit)
        .get();
    return query.docs
        .map((d) => TournamentModel.fromMap(d.data(), d.id))
        .toList();
  }

  /// One-shot (non-listening) count of `participants` for [tournamentId], via
  /// a bounded `count()` aggregation query. Used by the chatbot tool layer,
  /// which must never hold a snapshot listener open — [watchParticipants]
  /// stays for the live bracket/detail UI.
  Future<int> getParticipantCount(String tournamentId) async {
    final result = await _participants(tournamentId).count().get();
    return result.count ?? 0;
  }

  /// Upper bound on the pre-registration participant scan. Comfortably above any
  /// realistic campus bracket size (≤ 32), so the count is never truncated.
  static const int _participantScanCap = 64;

  /// Registers [uid] into [tournamentId]. Idempotent by construction — the
  /// participant doc id is the uid, so a re-register overwrites rather than
  /// duplicating and never bumps the count.
  ///
  /// The roster is pre-read only to detect an idempotent re-register (a query
  /// can't run inside a transaction). The transaction then re-reads the
  /// tournament and guards from its own denormalized `participantCount`: still
  /// `registering`, not full, and the registration deadline not passed — so the
  /// capacity guard and the new seed (`participantCount + 1`) are both atomic and
  /// two concurrent joins can neither overshoot capacity nor share a seed. Throws
  /// [StateError] when a guard fails. [now] is injectable.
  Future<void> registerParticipant(
    String tournamentId,
    String uid, {
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();

    // Pre-read the current roster ONLY to detect an idempotent re-register: a
    // query can't run inside a transaction, so the membership check must happen
    // here. The capacity guard and seed instead use the transaction's own
    // `participantCount` read so concurrent joins can't overshoot or collide.
    final rosterSnap = await _participants(
      tournamentId,
    ).limit(_participantScanCap).get();
    final alreadyRegistered = rosterSnap.docs.any((d) => d.id == uid);

    await _firestore.runTransaction((tx) async {
      final ref = _col.doc(tournamentId);
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) {
        throw StateError('Tournament not found.');
      }

      // An already-registered player is a no-op: never re-guard or re-seed them.
      if (alreadyRegistered) return;

      final status = data['status'] as String?;
      if (status != TournamentStatus.registering) {
        throw StateError('Registration is closed.');
      }

      // Transactionally-read count: guard and seed from it so two concurrent
      // registrations at max−1 can't both pass the guard or share a seed.
      final count = (data['participantCount'] as num?)?.toInt() ?? 0;
      final maxParticipants = (data['maxParticipants'] as num?)?.toInt() ?? 0;
      if (count >= maxParticipants) {
        throw StateError('Tournament is full.');
      }

      final deadline = (data['registrationDeadline'] as Timestamp?)?.toDate();
      if (deadline != null && !effectiveNow.isBefore(deadline)) {
        throw StateError('Registration deadline has passed.');
      }

      tx.set(_participants(tournamentId).doc(uid), {
        'seed': count + 1,
        'eliminated': false,
      });
      // Denormalized count for the browser feed — incremented atomically so
      // concurrent joins can't lose a tick. Reconciled to the true roster size
      // at seeding.
      tx.update(ref, {'participantCount': FieldValue.increment(1)});
    });
  }

  /// Records a played bracket [matchId] under [round] and, on the first recorded
  /// match, flips the tournament `seeded → active`. The only tournament write
  /// the match check-in path makes. Append is idempotent (no duplicate matchId);
  /// the status flip only fires while the tournament is still `seeded`.
  Future<void> recordBracketMatch(
    String tournamentId,
    String round,
    String matchId,
  ) {
    return _firestore.runTransaction((tx) async {
      final ref = _col.doc(tournamentId);
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) {
        throw StateError('Tournament not found.');
      }

      final rawBracket = data['bracket'] as Map? ?? const {};
      final bracket = <String, List<String>>{
        for (final entry in rawBracket.entries)
          entry.key as String: List<String>.from(
            entry.value as Iterable? ?? const [],
          ),
      };
      final roundMatches = bracket.putIfAbsent(round, () => <String>[]);
      if (!roundMatches.contains(matchId)) {
        roundMatches.add(matchId);
      }

      final update = <String, dynamic>{'bracket': bracket};
      if (data['status'] == TournamentStatus.seeded) {
        update['status'] = TournamentStatus.active;
      }
      tx.update(ref, update);
    });
  }

  Future<void> updateBracket(
    String tournamentId,
    Map<String, List<String>> bracket,
  ) {
    return _col.doc(tournamentId).update({'bracket': bracket});
  }

  /// Partial update (e.g. `status`, `winnerUid`).
  Future<void> updateTournament(
    String tournamentId,
    Map<String, dynamic> data,
  ) {
    return _col.doc(tournamentId).update(data);
  }

  Future<void> addParticipant(
    String tournamentId,
    TournamentParticipantModel participant,
  ) {
    return _participants(
      tournamentId,
    ).doc(participant.uid).set(participant.toMap());
  }

  Stream<List<TournamentParticipantModel>> watchParticipants(
    String tournamentId,
  ) {
    return _participants(tournamentId)
        .orderBy('seed')
        .snapshots()
        .map(
          (q) => q.docs
              .map((d) => TournamentParticipantModel.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  Future<void> updateParticipant(
    String tournamentId,
    String uid,
    Map<String, dynamic> data,
  ) {
    return _participants(tournamentId).doc(uid).update(data);
  }

  /// Lazy Spark-tier lifecycle transition out of `registering` — there is no
  /// server, so seeding happens the first time a client opens the bracket.
  ///
  /// Participants are pre-read (bounded by `maxParticipants`) because queries
  /// can't run inside a transaction; the transaction then re-reads only the
  /// tournament doc and, iff it is still `registering` AND due (`now` past the
  /// [TournamentModel.registrationDeadline] OR the bracket is full), rewrites
  /// seeds compacted to `1..N` ordered by `(seed, uid)` and flips the status to
  /// `seeded`. An under-filled bracket at the deadline simply proceeds smaller;
  /// fewer than two participants cancels the tournament instead. Idempotent and
  /// a no-op once past `registering`. [now] is injectable for tests.
  Future<void> seedIfDue(String tournamentId, {DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();

    final pre = await getTournament(tournamentId);
    if (pre == null || pre.status != TournamentStatus.registering) return;

    // Known limitation: participants are read here, outside the transaction
    // below (queries can't run inside one), so a registration landing in the
    // window between this read and the transaction's commit is neither
    // counted for `full` nor included in the seeding — yet the tournament
    // still flips to `seeded`. Unavoidable under Spark-tier (no server-side
    // trigger to close registration atomically); accepted as a rare-race
    // trade-off rather than a correctness guarantee.
    final participantsSnap = await _participants(
      tournamentId,
    ).orderBy('seed').limit(pre.maxParticipants).get();
    final participants = participantsSnap.docs
        .map((d) => TournamentParticipantModel.fromMap(d.data(), d.id))
        .toList();

    await _firestore.runTransaction((tx) async {
      final ref = _col.doc(tournamentId);
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return;
      final tournament = TournamentModel.fromMap(data, snap.id);
      if (tournament.status != TournamentStatus.registering) return;

      final deadlineReached = !effectiveNow.isBefore(
        tournament.registrationDeadline,
      );
      final full = participants.length >= tournament.maxParticipants;
      if (!deadlineReached && !full) return; // Not due yet.

      if (participants.length < 2) {
        tx.update(ref, {'status': TournamentStatus.cancelled});
        return;
      }

      final ordered = [...participants]
        ..sort((a, b) {
          final bySeed = a.seed.compareTo(b.seed);
          return bySeed != 0 ? bySeed : a.uid.compareTo(b.uid);
        });
      for (var i = 0; i < ordered.length; i++) {
        tx.update(_participants(tournamentId).doc(ordered[i].uid), {
          'seed': i + 1,
        });
      }
      // Reconcile the denormalized count to the actual seeded roster, healing
      // any drift and backfilling docs written before the field existed.
      tx.update(ref, {
        'status': TournamentStatus.seeded,
        'participantCount': ordered.length,
      });
    });
  }

  /// Lazy, idempotent `seeded → active` healing. The happy-path flip rides
  /// [recordBracketMatch] (best-effort, swallowed on failure), so a dropped
  /// write would otherwise strand an in-play tournament under UPCOMING forever.
  /// The bracket/detail cubits already stream the tournament's matches, so they
  /// call this whenever a match exists while the status is still `seeded` — a
  /// pure status heal, no extra read. Transaction-guarded to `seeded` so a raced
  /// or already-terminal tournament is untouched.
  Future<void> activateIfStarted(String tournamentId) {
    return _firestore.runTransaction((tx) async {
      final ref = _col.doc(tournamentId);
      final snap = await tx.get(ref);
      if (snap.data()?['status'] != TournamentStatus.seeded) return;
      tx.update(ref, {'status': TournamentStatus.active});
    });
  }

  /// Marks the tournament `completed` with [winnerUid] once the bracket engine
  /// has derived a champion. Transaction-guarded to `active` (normal path) or
  /// `seeded` (an all-bye/forfeit bracket decided before any match was played),
  /// so a raced or already-terminal tournament is left untouched. Called
  /// lazily from the cubit when it derives a champion. [winnerUid] is the
  /// engine's `championUid`.
  ///
  /// Awards the champion the `tournament_champion` badge in the SAME commit —
  /// write-once: the winner's `badges` map is read first and the merge write
  /// only fires when the id is absent, so an existing unlock timestamp is never
  /// overwritten (Spark-Tier client-side evaluation; no Cloud Function).
  Future<void> completeIfDecided(
    String tournamentId,
    String winnerUid, {
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    return _firestore.runTransaction((tx) async {
      final ref = _col.doc(tournamentId);
      final snap = await tx.get(ref);
      final status = snap.data()?['status'];
      if (status != TournamentStatus.active &&
          status != TournamentStatus.seeded) {
        return;
      }
      // Read the champion's badges before any write (Firestore reads-before-writes)
      // to honor the write-once rule.
      final userRef = _users.doc(winnerUid);
      final badges = (await tx.get(userRef)).data()?['badges'] as Map?;
      final alreadyChampion =
          badges?.containsKey(AchievementIds.tournamentChampion) ?? false;

      tx.update(ref, {
        'status': TournamentStatus.completed,
        'winnerUid': winnerUid,
      });
      if (!alreadyChampion) {
        tx.set(userRef, {
          'badges': {
            // Concrete Timestamp, not serverTimestamp(): the match-confirm path
            // does the same, and it keeps the optimistic (latency-compensated)
            // snapshot parseable. An unresolved serverTimestamp() surfaces as
            // null under ServerTimestampBehavior.none and would throw the
            // non-nullable Timestamp cast in UserModel.fromMap.
            AchievementIds.tournamentChampion: Timestamp.fromDate(effectiveNow),
          },
        }, SetOptions(merge: true));
      }
    });
  }
}
