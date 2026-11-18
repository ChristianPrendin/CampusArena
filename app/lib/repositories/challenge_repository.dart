import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/challenge_model.dart';

/// Why a [sendChallenge] guard rejected.
enum ChallengeError {
  /// The recipient is not in the sender's `friendUids` (friends-only rule).
  notFriends,

  /// The sender addressed themselves.
  self,

  /// A `pending` challenge for the same (from, to, sport) already exists.
  duplicatePending,
}

/// Thrown by [ChallengeRepository.sendChallenge] when a guard rejects the send.
/// The cubit maps [reason] to distinct UI copy (the sheet explains the
/// duplicate-pending case specifically).
class ChallengeException implements Exception {
  const ChallengeException(this.reason);

  final ChallengeError reason;

  @override
  String toString() => 'ChallengeException(${reason.name})';
}

/// Why a [ChallengeRepository.respond] could not apply the accept/decline.
/// Distinct reasons so the UI stops collapsing every failure into one vague
/// "may have expired" message.
enum ChallengeRespondError {
  /// The challenge had lapsed past [ChallengeRepository.pendingTimeout]. The
  /// repository committed the lazy `expired` flip before rejecting, so the
  /// challenge leaves the pending inbox stream — the card is gone, not stuck.
  expired,

  /// The challenge is no longer `pending` for a non-expiry reason: already
  /// accepted/declined by another client, or the doc is gone (a race). Not
  /// retryable — the stream reflects its real state.
  noLongerPending,

  /// The write itself never committed — offline or a transient Firestore
  /// error. The challenge is untouched, so the action is retryable. This is the
  /// case the old blanket "expired" copy misrepresented most.
  unavailable,
}

/// Thrown by [ChallengeRepository.respond] when the accept/decline does not
/// apply. The cubit / deep-link screen map [reason] to distinct copy.
class ChallengeRespondException implements Exception {
  const ChallengeRespondException(this.reason);

  final ChallengeRespondError reason;

  @override
  String toString() => 'ChallengeRespondException(${reason.name})';
}

/// Owns `challenges/{challengeId}` — the direct-challenge data layer.
///
/// Friends-only is enforced in app logic here (the locked schema has no server
/// rule for it): [sendChallenge] reads the sender's `friendUids` and rejects a
/// recipient outside it. There is no server to expire stale challenges on the
/// Spark tier, so expiry is lazy and client-driven, mirroring the match-timeout
/// pattern: a `pending` challenge older than [pendingTimeout] is `expired` the
/// next time a client streams and acts on it ([respond]) or sweeps it
/// ([expireIfDue]). All state-changing writes are guarded transactions.
class ChallengeRepository {
  ChallengeRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// A `pending` challenge older than this is considered `expired`. The spec
  /// fixes no value; 48h is an engineering default long enough to survive an
  /// overnight/weekend gap before both players coordinate offline.
  static const Duration pendingTimeout = Duration(hours: 48);

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestoreCollections.challenges);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestoreCollections.users);

  /// Sends a `pending` challenge from [fromUserId] to [toUserId] for [sportId].
  ///
  /// Guards, in order: not self, recipient in the sender's `friendUids`
  /// (friends-only), and no existing `pending` challenge for the same
  /// (from, to, sport). Self is checked first — you can't be your own friend, so
  /// the friends guard would also reject it, but checking here yields the
  /// precise [ChallengeError.self]. The duplicate check is a bounded pre-read;
  /// the rare concurrent duplicate is acceptable at campus scale.
  Future<void> sendChallenge({
    required String fromUserId,
    required String toUserId,
    required String sportId,
  }) async {
    if (fromUserId == toUserId) {
      throw const ChallengeException(ChallengeError.self);
    }

    final senderSnap = await _users.doc(fromUserId).get();
    final friendUids = List<String>.from(
      senderSnap.data()?['friendUids'] as Iterable? ?? const [],
    );
    if (!friendUids.contains(toUserId)) {
      throw const ChallengeException(ChallengeError.notFriends);
    }

    final existing = await _col
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('sportId', isEqualTo: sportId)
        .where('status', isEqualTo: ChallengeStatus.pending)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw const ChallengeException(ChallengeError.duplicatePending);
    }

    await _col.add({
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'sportId': sportId,
      'status': ChallengeStatus.pending,
      'matchId': null,
      // Server-ordered so the incoming/outgoing `orderBy(createdAt)` queries are
      // consistent across clients regardless of local clock skew.
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': null,
    });
  }

  /// The recipient's live pending inbox: `toUserId == uid && status == pending`,
  /// newest first, bounded.
  Stream<List<ChallengeModel>> watchIncomingPending(
    String uid, {
    int limit = 5,
  }) {
    return _col
        .where('toUserId', isEqualTo: uid)
        .where('status', isEqualTo: ChallengeStatus.pending)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_toModels);
  }

  /// The sender's recent outbox: `fromUserId == uid`, newest first, bounded. No
  /// status filter — one query feeds the pending/accepted/declined/expired
  /// chips.
  Stream<List<ChallengeModel>> watchOutgoingRecent(
    String uid, {
    int limit = 5,
  }) {
    return _col
        .where('fromUserId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_toModels);
  }

  /// Streams a single challenge doc for the deep-link screen; emits null when it
  /// does not exist.
  Stream<ChallengeModel?> watchChallenge(String challengeId) {
    return _col.doc(challengeId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return ChallengeModel.fromMap(data, snap.id);
    });
  }

  /// Accepts or declines [challengeId] in a guarded transaction: re-reads the
  /// doc, requires it still `pending` and not lazily expired, then writes the
  /// terminal status + `respondedAt`.
  ///
  /// Throws a typed [ChallengeRespondException] on any non-success so the caller
  /// can tell the cases apart instead of showing one vague message:
  ///  - [ChallengeRespondError.expired] — past [pendingTimeout]; the lazy
  ///    `expired` flip is committed first (the transaction returns normally so
  ///    the write survives), then the reject is raised, so the card leaves the
  ///    pending stream.
  ///  - [ChallengeRespondError.noLongerPending] — already resolved by another
  ///    client, or the doc is gone.
  ///  - [ChallengeRespondError.unavailable] — the transaction itself failed to
  ///    commit (offline / transient); nothing was written, so it is retryable.
  ///
  /// [now] is injectable for tests.
  Future<void> respond({
    required String challengeId,
    required bool accept,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final ref = _col.doc(challengeId);

    final _RespondOutcome outcome;
    try {
      outcome = await _firestore.runTransaction<_RespondOutcome>((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data();
        if (data == null) return _RespondOutcome.notFound;

        final challenge = ChallengeModel.fromMap(data, snap.id);
        if (challenge.status != ChallengeStatus.pending) {
          return _RespondOutcome.notPending;
        }
        if (_isExpired(challenge, effectiveNow)) {
          // Commit the expiry (returns normally so the write is not rolled
          // back), then reject the response outside the transaction.
          tx.update(ref, {'status': ChallengeStatus.expired});
          return _RespondOutcome.expired;
        }

        tx.update(ref, {
          'status': accept
              ? ChallengeStatus.accepted
              : ChallengeStatus.declined,
          'respondedAt': Timestamp.fromDate(effectiveNow),
        });
        return _RespondOutcome.ok;
      });
    } catch (_) {
      // The transaction never committed — offline or a transient Firestore
      // error (including exhausted contention retries). The challenge is
      // untouched, so this is a retryable failure, NOT an expiry.
      throw const ChallengeRespondException(ChallengeRespondError.unavailable);
    }

    switch (outcome) {
      case _RespondOutcome.ok:
        return;
      case _RespondOutcome.expired:
        throw const ChallengeRespondException(ChallengeRespondError.expired);
      case _RespondOutcome.notFound:
      case _RespondOutcome.notPending:
        throw const ChallengeRespondException(
          ChallengeRespondError.noLongerPending,
        );
    }
  }

  /// Expires [challenge] if it is a `pending` doc older than [pendingTimeout];
  /// a no-op when it is fresh or already terminal. State-guarded inside the
  /// transaction so a concurrent accept/decline is never clobbered. The cubit
  /// fires this for stale pending items it streams. [now] is injectable.
  Future<void> expireIfDue(ChallengeModel challenge, {DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    if (!_isExpired(challenge, effectiveNow)) return; // Fresh or terminal.

    await _firestore.runTransaction((tx) async {
      final ref = _col.doc(challenge.challengeId);
      final snap = await tx.get(ref);
      if (snap.data()?['status'] != ChallengeStatus.pending) return;
      tx.update(ref, {'status': ChallengeStatus.expired});
    });
  }

  bool _isExpired(ChallengeModel challenge, DateTime now) {
    return challenge.status == ChallengeStatus.pending &&
        now.difference(challenge.createdAt) > pendingTimeout;
  }

  List<ChallengeModel> _toModels(QuerySnapshot<Map<String, dynamic>> snap) {
    return snap.docs
        .map((d) => ChallengeModel.fromMap(d.data(), d.id))
        .toList(growable: false);
  }
}

/// Terminal outcome of a [ChallengeRepository.respond] transaction, resolved
/// inside the transaction and thrown on outside it (so committed writes — the
/// lazy expiry — survive the rejection).
enum _RespondOutcome { ok, notFound, notPending, expired }
