import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../models/facility_model.dart';

/// Status → colour mapping shared by markers, chips, badges and the legend.
///
/// Token mapping per the design system (`docs/design/CampusArena.dc.html`):
/// `--ca-free` is the brand green (the theme's primary seed), `--ca-occupied`
/// maps to the error role, `--ca-queued` to the tertiary role (the same slot
/// the weather widgets already use for the design's amber).
Color facilityStatusColor(ColorScheme colors, String status) {
  switch (status) {
    case FacilityStatus.occupied:
      return colors.error;
    case FacilityStatus.queued:
      return colors.tertiary;
    case FacilityStatus.free:
    default:
      return colors.primary;
  }
}

String facilityStatusLabel(AppLocalizations l10n, String status) {
  switch (status) {
    case FacilityStatus.occupied:
      return l10n.facilityStatusOccupied;
    case FacilityStatus.queued:
      return l10n.facilityStatusQueued;
    case FacilityStatus.free:
    default:
      return l10n.facilityStatusFree;
  }
}

/// Tinted status pill (colour dot + localized label) shared by the facility
/// detail sheet and the list rows. [dense] is the compact variant the list
/// uses; both draw from [facilityStatusColor]/[facilityStatusLabel] so the two
/// surfaces can't drift.
class FacilityStatusChip extends StatelessWidget {
  const FacilityStatusChip({
    super.key,
    required this.status,
    this.dense = false,
  });

  final String status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = facilityStatusColor(theme.colorScheme, status);
    final dotSize = dense ? 6.0 : 7.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 10,
        vertical: dense ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: dense ? 4 : 5),
          Text(
            facilityStatusLabel(l10n, status),
            style:
                (dense
                        ? theme.textTheme.labelSmall
                        : theme.textTheme.labelMedium)
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Facilities are seeded manually (script / one-off Firestore writes, per the
/// Decision Log) with no schema enforcement on the wire, so a malformed
/// coordinate — e.g. NaN from a seeding-script division bug — can reach the
/// client as valid-looking data. flutter_map's Mercator projection throws on
/// any non-finite `LatLng`, and `MarkerLayer` projects every marker in one
/// synchronous pass, so a single bad facility crashes the whole map. Filter
/// before handing facilities to `Marker`.
bool facilityHasValidCoordinates(FacilityModel facility) {
  final lat = facility.coordinates.latitude;
  final lng = facility.coordinates.longitude;
  return lat.isFinite && lng.isFinite && lat.abs() <= 90 && lng.abs() <= 180;
}

/// Great-circle distance in metres from [from] to [facility], or `null` when
/// there is no user location yet or the facility's coordinates are unusable
/// (reusing [facilityHasValidCoordinates] so a NaN never reaches the geodesy).
double? facilityDistanceMeters(FacilityModel facility, LatLng? from) {
  if (from == null || !facilityHasValidCoordinates(facility)) return null;
  return const Distance().as(
    LengthUnit.Meter,
    from,
    LatLng(facility.coordinates.latitude, facility.coordinates.longitude),
  );
}

/// Human-readable distance: whole metres under 1 km ("320 m"), otherwise
/// kilometres to one decimal ("1.2 km"). Units and decimal separator are
/// localised through the ARB placeholders.
String formatDistance(AppLocalizations l10n, double meters) {
  if (meters < 1000) return l10n.distanceMeters(meters.round());
  return l10n.distanceKilometers(meters / 1000);
}

/// Sport glyphs per the design (racket for ping pong, ball for foosball).
IconData facilitySportIcon(String sportId) {
  switch (sportId) {
    case SportIds.foosball:
      return Icons.sports_soccer;
    case SportIds.pingPong:
    default:
      return Icons.sports_tennis;
  }
}
