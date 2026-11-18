import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants.dart';
import '../../../models/facility_model.dart';
import '../../../repositories/facility_repository.dart';
import '../../../repositories/queue_repository.dart';
import 'queue_state.dart';

/// Drives one user's place in one facility's queue.
///
/// Two live listeners feed the state while I am queued: [QueueRepository.watchQueue]
/// (already `orderBy('position')`) is the single source of truth for my rank, the
/// total length, and whether I'm at the front; [FacilityRepository.watchFacility]
/// is a READ-ONLY listener used solely to detect the table freeing while I wait.
///
/// Both streams are Spark-tier billable on every write, so they are attached only
/// while I am actually in the queue: construction resolves my initial membership
/// with a one-shot [QueueRepository.getPosition], and the listeners attach on join
/// (or on that initial resolve) and detach on leave. Joining writes only the queue
/// subcollection (via the repository transaction); this cubit never writes
/// `facility.status` — that is the match flow's field.
///
/// Repositories are instantiated with their default constructors (mirroring how
/// `WeatherCubit` owns its `WeatherRepository`), so hosting this cubit needs no
/// provider in `main.dart`; tests inject mocks through the optional parameters.
class QueueCubit extends Cubit<QueueState> {
  QueueCubit({
    required this.facilityId,
    required this.uid,
    QueueRepository? queueRepository,
    FacilityRepository? facilityRepository,
  }) : _queueRepository = queueRepository ?? QueueRepository(),
       _facilityRepository = facilityRepository ?? FacilityRepository(),
       super(const QueueState()) {
    unawaited(_resolveInitialMembership());
  }

  final String facilityId;
  final String uid;
  final QueueRepository _queueRepository;
  final FacilityRepository _facilityRepository;

  StreamSubscription<List<QueueEntryModel>>? _queueSub;
  StreamSubscription<FacilityModel?>? _facilitySub;

  // Freed-detection bookkeeping. We baseline the first facility snapshot rather
  // than alerting on it, so only a genuine free-transition while I wait fires.
  bool _facilitySeen = false;
  DateTime? _lastFreedAt;
  bool _freedPending = false;

  /// One-shot membership check on open: attach the live listeners only if I am
  /// already queued, so a user who merely browses the detail card pays for no
  /// streams.
  Future<void> _resolveInitialMembership() async {
    try {
      final position = await _queueRepository.getPosition(
        facilityId: facilityId,
        uid: uid,
      );
      if (isClosed) return;
      if (position != null) _attach();
    } catch (_) {
      // A failed membership probe just leaves us idle; the user can still join.
    }
  }

  /// Appends me to the queue. Idempotent (the repository transaction returns my
  /// existing position on re-join). On success the queue listener is attached and
  /// emits `inQueue` once it observes me, so this only brackets the write with
  /// `joining`/`error`.
  Future<void> join() async {
    if (state.status == QueueStatus.joining ||
        state.status == QueueStatus.inQueue) {
      return;
    }
    emit(state.copyWith(status: QueueStatus.joining));
    try {
      await _queueRepository.joinQueue(facilityId: facilityId, uid: uid);
      if (isClosed) return;
      _attach();
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(status: QueueStatus.error, lastAction: QueueAction.join),
      );
    }
  }

  /// Removes me from the queue, detaches the live listeners, and returns to idle.
  Future<void> leave() async {
    if (state.status != QueueStatus.inQueue &&
        state.status != QueueStatus.error) {
      return;
    }
    emit(state.copyWith(status: QueueStatus.leaving));
    try {
      await _queueRepository.leaveQueue(facilityId: facilityId, uid: uid);
      if (isClosed) return;
      _detach();
      emit(const QueueState());
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: QueueStatus.error,
          lastAction: QueueAction.leave,
        ),
      );
    }
  }

  /// Acknowledges the table-ready banner.
  void dismissTableReady() {
    if (state.tableReady) emit(state.copyWith(tableReady: false));
  }

  /// Subscribes both live listeners. Idempotent, and resets the freed-detection
  /// bookkeeping so a fresh wait baselines from the next facility snapshot.
  void _attach() {
    if (_queueSub != null) return;
    _facilitySeen = false;
    _lastFreedAt = null;
    _freedPending = false;
    _queueSub = _queueRepository.watchQueue(facilityId).listen(_onQueue);
    _facilitySub = _facilityRepository
        .watchFacility(facilityId)
        .listen(_onFacility);
  }

  void _detach() {
    _queueSub?.cancel();
    _facilitySub?.cancel();
    _queueSub = null;
    _facilitySub = null;
  }

  void _onQueue(List<QueueEntryModel> entries) {
    if (isClosed) return;
    final total = entries.length;
    final mineIndex = entries.indexWhere((e) => e.uid == uid);
    if (mineIndex < 0) {
      // Not queued: back to idle. A pending freed alert is meaningless once I'm
      // out of line, so it is dropped by constructing a fresh state.
      emit(const QueueState());
      return;
    }
    emit(
      QueueState(
        status: QueueStatus.inQueue,
        position: mineIndex + 1,
        queueLength: total,
        isFront: mineIndex == 0,
        tableReady: state.tableReady,
      ),
    );
    _maybeEmitReady();
  }

  void _onFacility(FacilityModel? facility) {
    if (isClosed || facility == null) return;
    final freedAt = facility.freedAt;
    final isFree = facility.status == FacilityStatus.free;
    final isFreedTransition =
        _facilitySeen && isFree && freedAt != null && freedAt != _lastFreedAt;
    _facilitySeen = true;
    _lastFreedAt = freedAt;
    // Once the table is re-taken, any un-fired freed alert is stale — drop it so
    // a later promotion-to-front doesn't surface a bogus "table ready".
    if (!isFree) _freedPending = false;
    if (isFreedTransition) {
      // Spark constraint: client-local alert, fires only while this client's
      // listener is alive; true background push needs a server.
      _freedPending = true;
      _maybeEmitReady();
    }
  }

  // Fires the alert only when a freed-transition and front-of-queue both hold,
  // regardless of which listener observed its half last.
  void _maybeEmitReady() {
    if (_freedPending &&
        state.status == QueueStatus.inQueue &&
        state.isFront &&
        !state.tableReady) {
      _freedPending = false;
      emit(state.copyWith(tableReady: true));
    }
  }

  @override
  Future<void> close() {
    _queueSub?.cancel();
    _facilitySub?.cancel();
    return super.close();
  }
}
