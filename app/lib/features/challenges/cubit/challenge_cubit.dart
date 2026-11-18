import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants.dart';
import '../../../models/challenge_model.dart';
import '../../../models/match_model.dart';
import '../../../repositories/challenge_repository.dart';
import '../../../repositories/match_repository.dart';
import '../../../repositories/user_repository.dart';
import 'challenge_state.dart';

/// Drives the direct-challenges feature for the signed-in [uid]: streams the
/// incoming-pending inbox and the outgoing-recent outbox, resolves counterpart
/// display names (cached), and exposes `send` / `accept` / `decline`.
///
/// **Spark-tier note — no FCM.** On the Spark plan there is no server to send a
/// targeted push, so the "you were challenged" notification is *client-local*:
/// this cubit raises [ChallengeState.alertNonce] when a new incoming challenge
/// arrives after the first snapshot, and the Dashboard section turns that into
/// an in-app SnackBar + haptic while foregrounded. The `/challenge/:id` deep
/// link is kept working so a future Blaze-tier sender can target it directly.
///
/// Lazy expiry mirrors the match-timeout pattern: for any stale pending item it
/// streams, the cubit fires [ChallengeRepository.expireIfDue] (idempotent,
/// state-guarded) — there is no server sweep.
class ChallengeCubit extends Cubit<ChallengeState> {
  ChallengeCubit({
    required String uid,
    ChallengeRepository? challengeRepository,
    UserRepository? userRepository,
    MatchRepository? matchRepository,
  }) : this._(
         uid: uid,
         challengeRepository: challengeRepository,
         userRepository: userRepository,
         matchRepository: matchRepository,
         watch: true,
       );

  /// Send-only cubit for screens that just call [send] (e.g. the friends list):
  /// skips the incoming/outgoing stream subscriptions so it doesn't open two
  /// Firestore listeners it never reads — avoidable Spark reads.
  ChallengeCubit.sender({
    required String uid,
    ChallengeRepository? challengeRepository,
    UserRepository? userRepository,
  }) : this._(
         uid: uid,
         challengeRepository: challengeRepository,
         userRepository: userRepository,
         watch: false,
       );

  ChallengeCubit._({
    required this.uid,
    ChallengeRepository? challengeRepository,
    UserRepository? userRepository,
    MatchRepository? matchRepository,
    required bool watch,
  }) : _challengeRepository = challengeRepository ?? ChallengeRepository(),
       _userRepository = userRepository ?? UserRepository(),
       super(const ChallengeState()) {
    if (!watch) return;
    _incomingSub = _challengeRepository
        .watchIncomingPending(uid)
        .listen(_onIncoming, onError: _onStreamError);
    _outgoingSub = _challengeRepository
        .watchOutgoingRecent(uid)
        .listen(_onOutgoing, onError: _onStreamError);
    // The signed-in user's own recent matches, reused (via the existing
    // (playerUids, startedAt) index) to lazily complete a played challenge:
    // an accepted outgoing challenge whose opponent+sport turns up as a
    // confirmed match after it was accepted has "been played" and drops off
    // the outbox. Purely display-time — no write back to the challenge doc.
    // Constructed here (not in the sender path, which never reads it) so the
    // send-only cubit stays free of a Firestore-backed MatchRepository.
    _matchesSub = (matchRepository ?? MatchRepository())
        .watchUserMatches(uid, limit: _recentMatchLimit)
        .listen(_onMatches, onError: _onStreamError);
  }

  /// How many of the user's recent matches to keep in memory for the played-
  /// challenge check. The outbox itself is capped at a handful of recent
  /// challenges, so a played one's match is always well within this window.
  /// Deliberately equal to the dashboard's history fetch limit: an identical
  /// `watchUserMatches` query lets the Firestore SDK share one server-side
  /// listener between this cubit and the dashboard rather than paying for two.
  static const int _recentMatchLimit = 20;

  final String uid;
  final ChallengeRepository _challengeRepository;
  final UserRepository _userRepository;

  StreamSubscription<List<ChallengeModel>>? _incomingSub;
  StreamSubscription<List<ChallengeModel>>? _outgoingSub;
  StreamSubscription<List<MatchModel>>? _matchesSub;

  /// Raw outbox from Firestore, before the played-challenge filter. Held so a
  /// later match-stream emission can re-run the filter without re-reading.
  List<ChallengeModel> _rawOutgoing = const [];

  /// The user's recent confirmed-or-not matches, newest first. Only the
  /// confirmed ones gate the played-challenge filter.
  List<MatchModel> _recentMatches = const [];

  /// Cache of resolved counterpart names, so a re-emission only fetches newly
  /// seen uids.
  final Map<String, String> _nameCache = {};

  /// Challenge ids already streamed on the incoming side. Seeded on the first
  /// snapshot (which therefore never alerts); a later snapshot introducing an
  /// unseen id fires the client-local alert.
  Set<String> _seenIncomingIds = const {};
  bool _incomingInitialized = false;

  /// Ids we've already fired [expireIfDue] for, so a stale item isn't re-swept
  /// on every snapshot before Firestore acks the expiry.
  final Set<String> _expiryFired = {};

  void _onStreamError(Object _) {
    emit(state.copyWith(status: ChallengeStreamStatus.error));
  }

  Future<void> _onIncoming(List<ChallengeModel> incoming) async {
    await _resolveNames(incoming.map((c) => c.fromUserId));
    _sweepExpired(incoming);

    final currentIds = incoming.map((c) => c.challengeId).toSet();
    // Track arrival independently of the name: an unresolved name (the lookup
    // is decorative and degrades to a placeholder) must not swallow the alert.
    var hasNewArrival = false;
    String? alertName;
    if (_incomingInitialized) {
      // Newest-first: the first not-yet-seen challenge is the freshest arrival.
      for (final challenge in incoming) {
        if (!_seenIncomingIds.contains(challenge.challengeId)) {
          hasNewArrival = true;
          alertName = _nameCache[challenge.fromUserId];
          break;
        }
      }
    }
    _seenIncomingIds = currentIds;
    _incomingInitialized = true;

    emit(
      state.copyWith(
        status: ChallengeStreamStatus.ready,
        incoming: incoming,
        names: Map.of(_nameCache),
        // Only touch the alert on a genuine new arrival; `alertName` may be null
        // (unresolved) — the UI falls back — but must not carry a stale name.
        alertNonce: hasNewArrival ? state.alertNonce + 1 : null,
        alertName: hasNewArrival ? alertName : state.alertName,
      ),
    );
  }

  Future<void> _onOutgoing(List<ChallengeModel> outgoing) async {
    await _resolveNames(outgoing.map((c) => c.toUserId));
    _sweepExpired(outgoing);
    _rawOutgoing = outgoing;

    emit(
      state.copyWith(
        status: ChallengeStreamStatus.ready,
        outgoing: _visibleOutgoing(),
        names: Map.of(_nameCache),
      ),
    );
  }

  /// The user's recent matches changed — re-run the played-challenge filter so
  /// a just-confirmed match drops its accepted challenge off the outbox. No
  /// name resolution or expiry sweep here; those belong to the challenge stream.
  void _onMatches(List<MatchModel> matches) {
    _recentMatches = matches;
    if (_rawOutgoing.isEmpty) return;
    // Equatable dedups an unchanged outgoing list, so an irrelevant match
    // update (no accepted challenge resolved) emits nothing.
    emit(state.copyWith(outgoing: _visibleOutgoing()));
  }

  /// [_rawOutgoing] minus accepted challenges that have since been played: an
  /// `accepted` challenge is hidden once a *confirmed* match with the same
  /// opponent and sport, played after the challenge was accepted, appears on the
  /// user's own match stream. Pending / declined / expired rows are untouched.
  List<ChallengeModel> _visibleOutgoing() {
    return _rawOutgoing
        .where((c) => c.status != ChallengeStatus.accepted || !_wasPlayed(c))
        .toList(growable: false);
  }

  bool _wasPlayed(ChallengeModel challenge) {
    final since = challenge.respondedAt ?? challenge.createdAt;
    for (final match in _recentMatches) {
      if (match.state != MatchStates.confirmed) continue;
      if (match.sportId != challenge.sportId) continue;
      if (!match.playerUids.contains(challenge.toUserId)) continue;
      final playedAt = match.confirmedAt ?? match.startedAt;
      if (!playedAt.isBefore(since)) return true;
    }
    return false;
  }

  /// Fires lazy expiry for any stale `pending` items in [challenges]. Bounded
  /// and deduped via [_expiryFired]; failures are swallowed (the next snapshot
  /// retries).
  void _sweepExpired(List<ChallengeModel> challenges) {
    final now = DateTime.now();
    for (final challenge in challenges) {
      if (challenge.status != ChallengeStatus.pending) continue;
      if (now.difference(challenge.createdAt) <=
          ChallengeRepository.pendingTimeout) {
        continue;
      }
      if (!_expiryFired.add(challenge.challengeId)) continue;
      unawaited(
        _challengeRepository.expireIfDue(challenge, now: now).catchError((_) {
          // Retry on a later snapshot.
          _expiryFired.remove(challenge.challengeId);
        }),
      );
    }
  }

  Future<void> _resolveNames(Iterable<String> uids) async {
    final missing = uids.toSet()
      ..removeWhere((u) => u.isEmpty || _nameCache.containsKey(u));
    if (missing.isEmpty) return;
    try {
      for (final user in await _userRepository.getUsersByIds(
        missing.toList(),
      )) {
        _nameCache[user.uid] = user.name;
      }
    } catch (_) {
      // Names are decorative; unresolved counterparts fall back to a
      // placeholder in the UI. Never moves the streams to error.
    }
  }

  /// Sends a challenge to [toUserId] for [sportId] as the signed-in user.
  /// [toName] is the recipient's display name for the confirmation snackbar.
  /// Distinguishes the duplicate-pending guard so the sheet can explain it.
  Future<void> send({
    required String toUserId,
    required String sportId,
    String? toName,
  }) async {
    emit(
      state.copyWith(
        sendStatus: ChallengeSendStatus.sending,
        lastSentToName: toName,
      ),
    );
    try {
      await _challengeRepository.sendChallenge(
        fromUserId: uid,
        toUserId: toUserId,
        sportId: sportId,
      );
      emit(state.copyWith(sendStatus: ChallengeSendStatus.sent));
    } on ChallengeException catch (e) {
      emit(
        state.copyWith(
          sendStatus: switch (e.reason) {
            ChallengeError.duplicatePending => ChallengeSendStatus.duplicate,
            ChallengeError.notFriends => ChallengeSendStatus.notFriends,
            ChallengeError.self => ChallengeSendStatus.failed,
          },
        ),
      );
    } catch (_) {
      emit(state.copyWith(sendStatus: ChallengeSendStatus.failed));
    }
    // The outgoing stream re-emits the new row once Firestore acks.
  }

  /// Accepts [challengeId]; returns true only when the write actually committed,
  /// so the caller can route the recipient on to the accepted challenge's
  /// "scan to play" screen and stay put on any failure.
  Future<bool> accept(String challengeId) => _respond(challengeId, true);

  Future<bool> decline(String challengeId) => _respond(challengeId, false);

  Future<bool> _respond(String challengeId, bool accept) async {
    try {
      await _challengeRepository.respond(
        challengeId: challengeId,
        accept: accept,
      );
      // The incoming/outgoing streams re-emit the updated status.
      return true;
    } on ChallengeRespondException catch (e) {
      _emitActionError(e.reason);
      return false;
    } catch (_) {
      // An untyped failure is treated as retryable (offline/transient) rather
      // than misreported as an expiry.
      _emitActionError(ChallengeRespondError.unavailable);
      return false;
    }
  }

  void _emitActionError(ChallengeRespondError reason) {
    emit(
      state.copyWith(
        actionErrorNonce: state.actionErrorNonce + 1,
        actionError: reason,
      ),
    );
  }

  @override
  Future<void> close() {
    _incomingSub?.cancel();
    _outgoingSub?.cancel();
    _matchesSub?.cancel();
    return super.close();
  }
}
