import 'package:equatable/equatable.dart';

/// Lifecycle of one user's relationship to one facility's queue.
///
/// `idle` = not queued (the "Join Queue" affordance). `joining` / `leaving`
/// are transient action states bracketing a transactional repository write.
/// `inQueue` carries the live position/length/front data the counter renders.
/// `error` is a failed join/leave that the UI lets the user retry.
enum QueueStatus { idle, joining, inQueue, leaving, error }

/// Which mutation last ran, so an `error` state can route Retry to the failed op
/// (a failed leave leaves me queued — retrying `join()` would hit the idempotent
/// no-write branch and hang on the spinner).
enum QueueAction { join, leave }

class QueueState extends Equatable {
  const QueueState({
    this.status = QueueStatus.idle,
    this.position,
    this.queueLength = 0,
    this.isFront = false,
    this.tableReady = false,
    this.lastAction = QueueAction.join,
  });

  final QueueStatus status;

  /// My dense 1..N rank in the queue (1 = front). Non-null only while [status]
  /// is [QueueStatus.inQueue]. This is a display rank, not the Firestore ticket
  /// number — the Phase-4B check-in contract reads that from the repository.
  final int? position;

  /// Total people currently queued at this facility (the "of M" in the counter).
  final int queueLength;

  /// Whether I hold the front of the queue (lowest ticket number).
  final bool isFront;

  /// One-shot "your table is ready" flag: set when I'm front-of-queue and the
  /// facility flips to free. Surfaced as an in-app banner + haptic, then
  /// dismissible. Spark constraint — see [QueueCubit].
  final bool tableReady;

  /// The mutation whose outcome the current state reflects. Read by the UI in
  /// [QueueStatus.error] to send Retry to the right method.
  final QueueAction lastAction;

  QueueState copyWith({
    QueueStatus? status,
    int? position,
    int? queueLength,
    bool? isFront,
    bool? tableReady,
    QueueAction? lastAction,
  }) {
    return QueueState(
      status: status ?? this.status,
      position: position ?? this.position,
      queueLength: queueLength ?? this.queueLength,
      isFront: isFront ?? this.isFront,
      tableReady: tableReady ?? this.tableReady,
      lastAction: lastAction ?? this.lastAction,
    );
  }

  @override
  List<Object?> get props => [
    status,
    position,
    queueLength,
    isFront,
    tableReady,
    lastAction,
  ];
}
