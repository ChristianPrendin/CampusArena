import 'package:equatable/equatable.dart';

import '../../../models/challenge_model.dart';
import '../../../repositories/challenge_repository.dart';

/// Lifecycle of the challenge streams (incoming pending + outgoing recent).
enum ChallengeStreamStatus { loading, ready, error }

/// Outcome of the most recent [send] attempt. Every attempt passes through
/// [sending] before landing on a terminal value, so the UI can gate its
/// snackbar on `previous == sending` and still fire on two identical results.
enum ChallengeSendStatus {
  idle,
  sending,
  sent,

  /// A `pending` challenge for the same friend + sport already exists — the one
  /// failure the sheet explains distinctly.
  duplicate,

  /// The recipient is no longer a friend (e.g. removed between list and send).
  notFriends,

  /// Any other send failure (offline, permission, self).
  failed,
}

class ChallengeState extends Equatable {
  const ChallengeState({
    this.status = ChallengeStreamStatus.loading,
    this.incoming = const [],
    this.outgoing = const [],
    this.names = const {},
    this.sendStatus = ChallengeSendStatus.idle,
    this.lastSentToName,
    this.alertNonce = 0,
    this.alertName,
    this.actionErrorNonce = 0,
    this.actionError,
  });

  /// Loading / ready / error for the two challenge streams.
  final ChallengeStreamStatus status;

  /// Incoming pending challenges (recipient inbox), newest first, capped by the
  /// repository's `limit`.
  final List<ChallengeModel> incoming;

  /// Recent outgoing challenges (sender outbox) across all statuses.
  final List<ChallengeModel> outgoing;

  /// Resolved `uid → display name` for every counterpart in [incoming] and
  /// [outgoing]. A counterpart that fails to resolve is simply absent.
  final Map<String, String> names;

  /// Result of the last [send] attempt (transient; drives the sheet snackbar).
  final ChallengeSendStatus sendStatus;

  /// Display name the last challenge was sent to, for the success snackbar copy.
  final String? lastSentToName;

  /// Bumped when a *new* incoming challenge arrives after the first snapshot —
  /// the client-local "you were challenged" alert signal. Zero until then, so
  /// the first snapshot never fires it.
  final int alertNonce;

  /// Challenger display name carried by the latest alert.
  final String? alertName;

  /// Bumped when an accept/decline fails, so the UI can surface a one-shot
  /// error snackbar. Paired with [actionError] for the specific copy.
  final int actionErrorNonce;

  /// Why the last accept/decline failed — drives distinct snackbar copy
  /// (expired vs offline/transient vs no-longer-pending). Null until the first
  /// failure; only meaningful for the emission that bumped [actionErrorNonce].
  final ChallengeRespondError? actionError;

  bool get isEmpty => incoming.isEmpty && outgoing.isEmpty;

  /// Display name for [uid], or null when unresolved (UI supplies a fallback).
  String? nameOf(String uid) => names[uid];

  ChallengeState copyWith({
    ChallengeStreamStatus? status,
    List<ChallengeModel>? incoming,
    List<ChallengeModel>? outgoing,
    Map<String, String>? names,
    ChallengeSendStatus? sendStatus,
    String? lastSentToName,
    int? alertNonce,
    // Sentinel default so a caller can explicitly clear the alert name: a new
    // arrival whose display name failed to resolve must reset it to null (UI
    // falls back), not silently carry the previous challenger's name.
    Object? alertName = _unset,
    int? actionErrorNonce,
    ChallengeRespondError? actionError,
  }) {
    return ChallengeState(
      status: status ?? this.status,
      incoming: incoming ?? this.incoming,
      outgoing: outgoing ?? this.outgoing,
      names: names ?? this.names,
      sendStatus: sendStatus ?? this.sendStatus,
      lastSentToName: lastSentToName ?? this.lastSentToName,
      alertNonce: alertNonce ?? this.alertNonce,
      alertName: identical(alertName, _unset)
          ? this.alertName
          : alertName as String?,
      actionErrorNonce: actionErrorNonce ?? this.actionErrorNonce,
      actionError: actionError ?? this.actionError,
    );
  }

  /// Sentinel distinguishing "argument omitted" from "explicitly set to null"
  /// for [copyWith]'s nullable [alertName].
  static const Object _unset = Object();

  @override
  List<Object?> get props => [
    status,
    incoming,
    outgoing,
    names,
    sendStatus,
    lastSentToName,
    alertNonce,
    alertName,
    actionErrorNonce,
    actionError,
  ];
}
