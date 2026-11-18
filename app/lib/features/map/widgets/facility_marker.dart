import 'package:flutter/material.dart';

import '../../../models/facility_model.dart';
import '../facility_ui.dart';

/// Marker size passed to `flutter_map`'s [Marker]; the pin is bottom-anchored
/// so its tip sits on the facility's coordinates.
const double facilityMarkerSize = 48;

/// Status-coloured map pin with the facility's sport glyph, per `map.png`:
/// a teardrop pin outlined in the surface colour so it reads on the tiles.
class FacilityMarker extends StatelessWidget {
  const FacilityMarker({super.key, required this.facility, this.onTap});

  final FacilityModel facility;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = facilityStatusColor(colors, facility.status);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Icon(
            Icons.location_pin,
            size: facilityMarkerSize,
            color: colors.surface,
          ),
          Positioned(
            bottom: 4,
            child: Icon(Icons.location_pin, size: 40, color: statusColor),
          ),
          Positioned(
            top: 10,
            child: Icon(
              facilitySportIcon(facility.sportId),
              size: 15,
              color: colors.surface,
            ),
          ),
        ],
      ),
    );
  }
}
