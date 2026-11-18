import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/match_display.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/facility_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/queue_repository.dart';
import '../../repositories/rating_repository.dart';
import '../../repositories/tournament_repository.dart';
import '../../repositories/user_repository.dart';
import '../auth/cubit/auth_cubit.dart';
import '../map/user_location_service.dart';
import '../queue/widgets/priority_warning_dialog.dart';
import 'active_match_screen.dart';
import 'cubit/match_cubit.dart';
import 'cubit/match_state.dart';
import 'match_setup_screen.dart';
import 'qr_scan_screen.dart';

/// Entry point for the QR check-in / active-match flow. Provides the
/// [MatchCubit] and switches between the scan surface and the active-match
/// surface off the cubit's lifecycle. Two entry modes:
///
/// * blind scan (`/play/scan`, [facilityId] null) — the viewfinder is live and
///   a detected code drives check-in automatically;
/// * deep link (`/play/facility/:id`, [facilityId] set) — the facility is known,
///   so the flow attaches to its live match or shows an explicit "Check in".
class MatchFlowPage extends StatelessWidget {
  const MatchFlowPage({
    super.key,
    this.facilityId,
    this.tournamentId,
    this.tournamentRound,
    this.expectedSportId,
    this.enableCamera = true,
    this.matchRepository,
    this.facilityRepository,
    this.queueRepository,
    this.ratingRepository,
    this.userRepository,
    this.tournamentRepository,
    this.locationService,
  });

  final String? facilityId;

  /// Tournament context carried by a bracket-slot check-in deep link
  /// (`/play/facility/:id?tournamentId=…&round=…`); both null for a walk-up.
  final String? tournamentId;
  final String? tournamentRound;

  /// The sport an accepted challenge locks the scan to (`/play/scan?sport=…`);
  /// null for a walk-up scan. Forwarded to [MatchCubit] to reject a table of a
  /// different sport.
  final String? expectedSportId;

  /// Forwarded to [QrScanView]; tests disable the camera preview.
  final bool enableCamera;

  final MatchRepository? matchRepository;
  final FacilityRepository? facilityRepository;
  final QueueRepository? queueRepository;
  final RatingRepository? ratingRepository;
  final UserRepository? userRepository;
  final TournamentRepository? tournamentRepository;
  final UserLocationService? locationService;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = MatchCubit(
          uid: context.read<AuthCubit>().state.uid!,
          tournamentId: tournamentId,
          tournamentRound: tournamentRound,
          expectedSportId: expectedSportId,
          matchRepository: matchRepository,
          facilityRepository: facilityRepository,
          queueRepository: queueRepository,
          ratingRepository: ratingRepository,
          userRepository: userRepository,
          tournamentRepository: tournamentRepository,
          locationService: locationService,
        );
        // Deep-link entry (`/play/facility/:id`): the facility is already known,
        // so drive the open from here rather than the cubit constructor (which
        // must stay side-effect-free after its synchronous initial state).
        if (facilityId != null) cubit.openFacility(facilityId!);
        return cubit;
      },
      child: MatchFlowView(
        isDeepLink: facilityId != null,
        enableCamera: enableCamera,
      ),
    );
  }
}

class MatchFlowView extends StatelessWidget {
  const MatchFlowView({
    super.key,
    required this.isDeepLink,
    this.enableCamera = true,
  });

  final bool isDeepLink;
  final bool enableCamera;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MatchCubit, MatchState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) => _onStatus(context, state),
      builder: (context, state) {
        switch (state.status) {
          case MatchStatus.waitingOpponent:
          case MatchStatus.active:
          case MatchStatus.resultSubmitted:
          case MatchStatus.confirmed:
          case MatchStatus.disputed:
          case MatchStatus.ended:
            return const ActiveMatchView();
          case MatchStatus.readyToConfirm:
          case MatchStatus.checkingIn:
            // An explicit setup step (mode + side pick) is required for a deep
            // link, or a blind scan of a far table — both go to the dedicated
            // setup screen. A nearby blind scan auto-confirms as singles in
            // [_onStatus], so its transient readyToConfirm/checkingIn frame
            // stays on the viewfinder.
            if (isDeepLink || state.gpsFar) {
              return MatchSetupView(isDeepLink: isDeepLink);
            }
            return QrScanView(
              isDeepLink: isDeepLink,
              enableCamera: enableCamera,
            );
          case MatchStatus.idle:
          case MatchStatus.resolving:
          case MatchStatus.error:
            return QrScanView(
              isDeepLink: isDeepLink,
              enableCamera: enableCamera,
            );
        }
      },
    );
  }

  Future<void> _onStatus(BuildContext context, MatchState state) async {
    final cubit = context.read<MatchCubit>();
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (state.status == MatchStatus.error) {
      final message = switch (state.errorKind) {
        MatchErrorKind.invalidCode => l10n.qrInvalidCode,
        MatchErrorKind.load => l10n.matchLoadError,
        MatchErrorKind.tableBusy => l10n.qrTableBusy,
        MatchErrorKind.sportMismatch => l10n.qrSportMismatch(
          localizedSportName(l10n, cubit.expectedSportId ?? ''),
        ),
        _ => l10n.qrCheckInError,
      };
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      // Re-arm the scanner so the user can retry.
      cubit.reset();
      return;
    }

    if (state.status != MatchStatus.readyToConfirm) return;

    // Soft queue enforcement: a non-front queued user gets the Phase-3B nudge
    // before the table is claimed. It never blocks — "Wait my turn" simply lets
    // the polite user yield; "Claim anyway" proceeds.
    if (state.queuePriorityWarning) {
      final proceed = await PriorityWarningDialog.show(
        context: context,
        position: state.queuePosition!,
        frontPosition: state.queueFrontPosition!,
      );
      if (proceed) {
        await cubit.confirmCheckIn();
      } else {
        cubit.reset();
      }
      return;
    }

    // No queue conflict: a nearby blind scan checks in immediately. A deep-link
    // entry — or a blind scan of a far table — waits for the explicit "Check in"
    // button so the user reads the GPS warning before joining.
    if (!isDeepLink && !state.gpsFar) {
      await cubit.confirmCheckIn();
    }
  }
}
