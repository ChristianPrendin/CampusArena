import 'package:equatable/equatable.dart';

import '../../../core/constants.dart';
import '../../../models/tournament_model.dart';

enum TournamentBrowserStatus { loading, ready, error }

/// Enrichment resolved lazily for a browser card: the facility's outdoor flag
/// (the participant count rides the feed on `TournamentModel.participantCount`).
/// Decorative over the streamed feed — a failed lookup leaves the card at its
/// default (false) rather than erroring the screen.
class TournamentCardInfo extends Equatable {
  const TournamentCardInfo({this.outdoor = false});

  final bool outdoor;

  TournamentCardInfo copyWith({bool? outdoor}) {
    return TournamentCardInfo(outdoor: outdoor ?? this.outdoor);
  }

  @override
  List<Object?> get props => [outdoor];
}

class TournamentBrowserState extends Equatable {
  TournamentBrowserState({
    this.status = TournamentBrowserStatus.loading,
    String? selectedSportId,
    this.upcoming = const [],
    this.ongoing = const [],
    this.cardInfo = const {},
  }) : selectedSportId = selectedSportId ?? SportIds.supported.first;

  final TournamentBrowserStatus status;
  final String selectedSportId;

  /// `registering`/`seeded` tournaments, sorted by `scheduledAt` ascending.
  final List<TournamentModel> upcoming;

  /// `active` tournaments, sorted by `scheduledAt` ascending.
  final List<TournamentModel> ongoing;

  /// tournamentId → resolved card enrichment.
  final Map<String, TournamentCardInfo> cardInfo;

  TournamentCardInfo infoFor(String tournamentId) =>
      cardInfo[tournamentId] ?? const TournamentCardInfo();

  TournamentBrowserState copyWith({
    TournamentBrowserStatus? status,
    String? selectedSportId,
    List<TournamentModel>? upcoming,
    List<TournamentModel>? ongoing,
    Map<String, TournamentCardInfo>? cardInfo,
  }) {
    return TournamentBrowserState(
      status: status ?? this.status,
      selectedSportId: selectedSportId ?? this.selectedSportId,
      upcoming: upcoming ?? this.upcoming,
      ongoing: ongoing ?? this.ongoing,
      cardInfo: cardInfo ?? this.cardInfo,
    );
  }

  @override
  List<Object?> get props => [
    status,
    selectedSportId,
    upcoming,
    ongoing,
    cardInfo,
  ];
}
