import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/facility_model.dart';
import '../facility_ui.dart';

/// Scrollable facility list (`listview.png`): one card per facility with the
/// sport tile (status-dot badge), name and status chip. Tapping a card opens
/// the same detail sheet as its marker.
///
/// When [userLocation] is known the list is ordered nearest-first and each row
/// shows its distance under a "Sorted by proximity" header; without a location
/// it keeps the incoming order and omits distances.
class FacilityList extends StatelessWidget {
  const FacilityList({
    super.key,
    required this.facilities,
    required this.onFacilityTap,
    this.userLocation,
  });

  final List<FacilityModel> facilities;
  final ValueChanged<FacilityModel> onFacilityTap;
  final LatLng? userLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (facilities.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.facilityListEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final location = userLocation;
    // Compute each distance exactly once, then sort by the stored key — no
    // recomputing the haversine inside the comparator or again per row.
    final entries = [
      for (final facility in facilities)
        (
          facility: facility,
          distance: facilityDistanceMeters(facility, location),
        ),
    ];
    // Distances are only known (and the list only ordered) with a location;
    // without one, keep the incoming order and omit the header.
    final sorted = location != null;
    if (sorted) {
      entries.sort((a, b) {
        final da = a.distance;
        final db = b.distance;
        if (da == null) return db == null ? 0 : 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    }
    final headerCount = sorted ? 1 : 0;

    final itemCount = entries.length + headerCount + 1; // +1 for disclaimer

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: itemCount,
      separatorBuilder: (_, index) =>
          SizedBox(height: index < headerCount ? 8 : 10),
      itemBuilder: (context, index) {
        if (index < headerCount) return _ProximityHeader(l10n: l10n);
        if (index == itemCount - 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            child: Text(
              l10n.availabilityDisclaimerShort,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }
        final entry = entries[index - headerCount];
        return _FacilityListTile(
          facility: entry.facility,
          onTap: () => onFacilityTap(entry.facility),
          distanceMeters: entry.distance,
        );
      },
    );
  }
}

/// "Sorted by proximity" label (`listview.png`) shown atop the ordered list.
class _ProximityHeader extends StatelessWidget {
  const _ProximityHeader({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          Icon(
            Icons.near_me,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            l10n.facilityListSortedByProximity,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FacilityListTile extends StatelessWidget {
  const _FacilityListTile({
    required this.facility,
    required this.onTap,
    this.distanceMeters,
  });

  final FacilityModel facility;
  final VoidCallback onTap;
  final double? distanceMeters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final statusColor = facilityStatusColor(colors, facility.status);
    final distance = distanceMeters;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _SportBadge(facility: facility, statusColor: statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facility.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        FacilityStatusChip(
                          status: facility.status,
                          dense: true,
                        ),
                        if (facility.isOutdoor) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.wb_sunny_outlined,
                            size: 13,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            l10n.facilityOutdoorLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (distance != null) ...[
                const SizedBox(width: 12),
                Text(
                  formatDistance(l10n, distance),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded sport tile with a status dot pinned to its top-right corner.
class _SportBadge extends StatelessWidget {
  const _SportBadge({required this.facility, required this.statusColor});

  final FacilityModel facility;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              facilitySportIcon(facility.sportId),
              size: 24,
              color: colors.onSurfaceVariant,
            ),
          ),
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
