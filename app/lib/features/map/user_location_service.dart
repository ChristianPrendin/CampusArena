import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/permission_service.dart';

/// Mockable boundary around `geolocator` for the map's user-location dot and
/// recenter button. Delegates the permission ladder to [PermissionService] so
/// there is a single check→request→interpret implementation in the app.
///
/// Best-effort by design: the dot is decoration, so every failure mode —
/// location services off, permission denied, missing platform plugin —
/// resolves to "no location" instead of surfacing an error.
class UserLocationService {
  const UserLocationService([
    this._permissions = const PlatformPermissionService(),
  ]);

  final PermissionService _permissions;

  /// Continuous position updates. Emits nothing (and completes) when location
  /// is unavailable; never requests permission — onboarding already did, and
  /// the recenter button covers the explicit-intent case.
  Stream<LatLng> watchPosition() async* {
    if (!await _ready(requestPermission: false)) return;
    yield* Geolocator.getPositionStream(
          locationSettings: const LocationSettings(distanceFilter: 10),
        )
        .map((p) => LatLng(p.latitude, p.longitude))
        .where(_isFinite)
        .handleError((Object _) {});
  }

  /// One-shot position for the recenter button, requesting permission if
  /// needed (a tap is explicit user intent). Null when unavailable.
  Future<LatLng?> getCurrentPosition() async {
    try {
      if (!await _ready(requestPermission: true)) return null;
      final p = await Geolocator.getCurrentPosition();
      final position = LatLng(p.latitude, p.longitude);
      return _isFinite(position) ? position : null;
    } catch (_) {
      return null;
    }
  }

  // Some devices report a degenerate fix (NaN/infinite lat-lng) before a GPS
  // lock settles; flutter_map's projection throws on a non-finite LatLng.
  bool _isFinite(LatLng p) => p.latitude.isFinite && p.longitude.isFinite;

  Future<bool> _ready({required bool requestPermission}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      final status = requestPermission
          ? await _permissions.requestLocation()
          : await _permissions.checkLocation();
      return status == AppPermissionStatus.granted;
    } catch (_) {
      return false;
    }
  }
}
