// Shared, schema-level constants for the Firestore data layer.
//
// Centralised here so the seven repositories never drift on collection
// names, status strings, or sport identifiers. See `brain/firestore_schema.md`.

import 'package:latlong2/latlong.dart';

/// Top-level collection and subcollection names.
class FirestoreCollections {
  FirestoreCollections._();

  static const String users = 'users';

  /// Username-uniqueness reservation. Doc ID *is* the (lowercased) handle;
  /// the doc holds `{uid}`. A claim is created atomically with the `users` doc
  /// at registration and can never be overwritten — the only enforcement of
  /// username uniqueness on the Spark tier (no Cloud Functions).
  static const String usernames = 'usernames';
  static const String ratings = 'ratings';
  static const String facilities = 'facilities';
  static const String matches = 'matches';
  static const String tournaments = 'tournaments';
  static const String challenges = 'challenges';
  static const String achievementDefs = 'achievementDefs';

  /// Subcollection of `facilities/{facilityId}`.
  static const String queue = 'queue';

  /// Subcollection of `tournaments/{tournamentId}`.
  static const String participants = 'participants';
}

/// Supported sport identifiers. `padel` is defined but not enabled by default
/// (its scoring strategy is a Phase 6 stretch goal), so registration seeds
/// ratings only for [supported].
class SportIds {
  SportIds._();

  static const String pingPong = 'ping_pong';
  static const String foosball = 'foosball';
  static const String padel = 'padel';

  /// Sports a new user receives a rating for at registration.
  static const List<String> supported = <String>[pingPong, foosball];
}

/// `facilities/{facilityId}.status` values.
class FacilityStatus {
  FacilityStatus._();

  static const String free = 'free';
  static const String occupied = 'occupied';
  static const String queued = 'queued';
}

/// `matches/{matchId}.mode` values.
class MatchModes {
  MatchModes._();

  static const String singles = 'singles';
  static const String doubles = 'doubles';
}

/// `matches/{matchId}.state` values (see match state machine in the schema).
class MatchStates {
  MatchStates._();

  static const String occupied = 'occupied';
  static const String awaitingConfirmation = 'awaitingConfirmation';
  static const String confirmed = 'confirmed';
  static const String disputed = 'disputed';
  static const String unconfirmed = 'unconfirmed';
  static const String abandoned = 'abandoned';
}

/// `tournaments/{tournamentId}.status` values — the single-elimination
/// lifecycle: registration open → seeded bracket → first match played →
/// champion decided, plus the under-filled `cancelled` terminal.
class TournamentStatus {
  TournamentStatus._();

  static const String registering = 'registering';
  static const String seeded = 'seeded';
  static const String active = 'active';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
}

/// `challenges/{challengeId}.status` values.
class ChallengeStatus {
  ChallengeStatus._();

  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String declined = 'declined';
  static const String expired = 'expired';
}

/// `ratings/{ratingId}.ownerType` values.
class OwnerType {
  OwnerType._();

  static const String user = 'user';
  static const String pair = 'pair';
}

/// Every rating (user or pair) starts here.
const int kInitialElo = 1200;

/// Facility map defaults — PoliMi Leonardo campus (Piazza Leonardo da Vinci).
class MapDefaults {
  MapDefaults._();

  static const LatLng campusCenter = LatLng(45.4784, 9.2272);
  static const double initialZoom = 16.5;

  /// Bounds passed to `MapOptions.minZoom`/`maxZoom`.
  ///
  /// Sane zoom limits for a single-campus map (can't zoom out past the region
  /// or past OSM's max tile level). They double as cheap defence: `flutter_map`
  /// clamps every zoom against these *finite* bounds, and because Dart's
  /// `num.clamp` sorts NaN above any finite value, a transient NaN zoom from a
  /// fast pinch resolves to [maxZoom] rather than reaching the camera. (The
  /// 8.3.0 projection assertion that once turned such a NaN into a crash was
  /// removed in flutter_map 8.3.1; this now only prevents a degenerate view.)
  static const double minZoom = 10;
  static const double maxZoom = 19;
}
