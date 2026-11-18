import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Outcome of a permission request, normalized across geolocator and
/// permission_handler so the UI/Cubit never depends on a specific plugin enum.
enum AppPermissionStatus { granted, denied, permanentlyDenied }

/// Mockable boundary around the platform permission plugins, so callers like
/// [UserLocationService] stay unit-testable without touching real channels.
abstract class PermissionService {
  Future<AppPermissionStatus> requestLocation();

  /// Reports the current location permission without prompting — for passive
  /// callers (e.g. the map's location dot) that must not trigger a dialog.
  Future<AppPermissionStatus> checkLocation();

  Future<AppPermissionStatus> requestCamera();
}

class PlatformPermissionService implements PermissionService {
  const PlatformPermissionService();

  @override
  Future<AppPermissionStatus> requestLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return _mapLocation(permission);
  }

  @override
  Future<AppPermissionStatus> checkLocation() async {
    return _mapLocation(await Geolocator.checkPermission());
  }

  AppPermissionStatus _mapLocation(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return AppPermissionStatus.granted;
      case LocationPermission.deniedForever:
        return AppPermissionStatus.permanentlyDenied;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return AppPermissionStatus.denied;
    }
  }

  @override
  Future<AppPermissionStatus> requestCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) {
      return AppPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return AppPermissionStatus.permanentlyDenied;
    }
    return AppPermissionStatus.denied;
  }
}
