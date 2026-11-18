import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../models/facility_model.dart';
import '../../repositories/facility_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/weather_repository.dart';
import '../queue/widgets/queue_section.dart';
import '../weather/cubit/weather_cubit.dart';
import 'cubit/facility_cubit.dart';
import 'cubit/facility_state.dart';
import 'facility_ui.dart';
import 'user_location_service.dart';
import 'widgets/facility_detail_card.dart';
import 'widgets/facility_list.dart';
import 'widgets/facility_marker.dart';

/// Live facility map (`map.png`): OpenStreetMap tiles centred on campus,
/// status-coloured markers, a legend, and a slide-up detail card per
/// `facility.png`. At ≥600dp the map is paired with the facility list in a
/// split view; below that the map is full-screen.
///
/// The repository parameters exist so tests can inject fakes; production
/// passes none and the screen defaults to the live implementations.
/// [tileProvider] is a test seam only — widget tests cannot fetch tiles.
/// Phone-only view switch: the map fills the screen, or the facility list does.
/// At ≥600dp both are shown side by side and this is irrelevant.
enum _MapViewMode { map, list }

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.facilityRepository,
    this.matchRepository,
    this.userRepository,
    this.weatherRepository,
    this.userLocationService,
    this.tileProvider,
  });

  final FacilityRepository? facilityRepository;
  final MatchRepository? matchRepository;
  final UserRepository? userRepository;
  final WeatherRepository? weatherRepository;
  final UserLocationService? userLocationService;
  final TileProvider? tileProvider;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final FacilityCubit _facilityCubit = FacilityCubit(
    repository: widget.facilityRepository,
  )..subscribe();

  // One shared cubit so every detail card hits the same in-memory cache.
  late final WeatherCubit _weatherCubit = WeatherCubit(
    repository: widget.weatherRepository,
  );

  // Lazy (`late final`): only constructed when a detail card first needs them.
  late final MatchRepository _matchRepository =
      widget.matchRepository ?? MatchRepository();
  late final UserRepository _userRepository =
      widget.userRepository ?? UserRepository();

  late final UserLocationService _locationService =
      widget.userLocationService ?? const UserLocationService();

  final MapController _mapController = MapController();

  StreamSubscription<LatLng>? _locationSub;

  // Held in a ValueNotifier, not screen state: a GPS fix arrives every ~10m of
  // movement, and only the location dot and the list's distances depend on it.
  // Rebuilding through the notifier keeps the FlutterMap, tiles and markers out
  // of that path instead of setState-ing the whole screen on every emission.
  final ValueNotifier<LatLng?> _userLocation = ValueNotifier<LatLng?>(null);
  _MapViewMode _mode = _MapViewMode.map;

  @override
  void initState() {
    super.initState();
    _subscribeLocation();
  }

  void _subscribeLocation() {
    _locationSub?.cancel();
    _locationSub = _locationService.watchPosition().listen(
      (position) => _userLocation.value = position,
    );
  }

  void _setMode(_MapViewMode mode) => setState(() => _mode = mode);

  Future<void> _recenter() async {
    final position = await _locationService.getCurrentPosition();
    if (!mounted) return;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).locationUnavailable),
        ),
      );
      return;
    }
    _userLocation.value = position;
    // Permission may have just been granted via the tap — restart the watch.
    _subscribeLocation();
    _mapController.move(position, MapDefaults.initialZoom);
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _userLocation.dispose();
    _mapController.dispose();
    _facilityCubit.close();
    _weatherCubit.close();
    super.dispose();
  }

  void _openDetail(FacilityModel facility) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        // Rebind to the cubit so the open card live-updates on status changes.
        return BlocProvider.value(
          value: _facilityCubit,
          child: BlocBuilder<FacilityCubit, FacilityState>(
            builder: (context, state) {
              final live = state.facilities.firstWhere(
                (f) => f.facilityId == facility.facilityId,
                orElse: () => facility,
              );
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(sheetContext).bottom,
                ),
                child: FacilityDetailCard(
                  facility: live,
                  matchRepository: _matchRepository,
                  userRepository: _userRepository,
                  weatherCubit: _weatherCubit,
                  queueSection: QueueSection(facilityId: live.facilityId),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _mapView({required FacilityState state, Widget? toggle}) {
    return _MapView(
      state: state,
      mapController: _mapController,
      userLocation: _userLocation,
      tileProvider: widget.tileProvider,
      onMarkerTap: _openDetail,
      onRetry: _facilityCubit.subscribe,
      onRecenter: _recenter,
      toggle: toggle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider.value(
      value: _facilityCubit,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.mapTab)),
        body: BlocBuilder<FacilityCubit, FacilityState>(
          builder: (context, state) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final isPhone = constraints.maxWidth < 600;

                // Built once and reused across layouts; only its distances
                // depend on the location, so it listens rather than the screen.
                final list = ValueListenableBuilder<LatLng?>(
                  valueListenable: _userLocation,
                  builder: (context, location, _) => FacilityList(
                    facilities: state.facilities,
                    onFacilityTap: _openDetail,
                    userLocation: location,
                  ),
                );

                if (isPhone) {
                  if (_mode == _MapViewMode.list) {
                    return Column(
                      children: [
                        const SizedBox(height: 12),
                        _MapViewToggle(mode: _mode, onChanged: _setMode),
                        const SizedBox(height: 4),
                        Expanded(child: list),
                      ],
                    );
                  }
                  // The toggle only makes sense on phone widths; the tablet
                  // split view shows both panes at once.
                  return _mapView(
                    state: state,
                    toggle: _MapViewToggle(mode: _mode, onChanged: _setMode),
                  );
                }

                return Row(
                  children: [
                    Expanded(child: _mapView(state: state)),
                    const VerticalDivider(thickness: 1, width: 1),
                    SizedBox(width: 360, child: list),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView({
    required this.state,
    required this.mapController,
    required this.userLocation,
    required this.tileProvider,
    required this.onMarkerTap,
    required this.onRetry,
    required this.onRecenter,
    this.toggle,
  });

  final FacilityState state;
  final MapController mapController;
  final ValueListenable<LatLng?> userLocation;
  final TileProvider? tileProvider;
  final ValueChanged<FacilityModel> onMarkerTap;
  final VoidCallback onRetry;
  final VoidCallback onRecenter;

  /// Map/list switch overlaid top-centre; null on the tablet split view.
  final Widget? toggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: MapDefaults.campusCenter,
            initialZoom: MapDefaults.initialZoom,
            minZoom: MapDefaults.minZoom,
            maxZoom: MapDefaults.maxZoom,
            backgroundColor: colors.surfaceContainerHighest,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'it.campusarena.campus_arena',
              tileProvider: tileProvider,
              // A fast pinch zoom-out crosses several zoom levels in a few
              // hundred ms; the default transformer fires a tile load on every
              // intermediate camera frame, flooding the cached provider's dio +
              // sqlite pipeline and stalling the UI on a real device. Debounce so
              // only the resting zoom fetches tiles — the flutter_map-recommended
              // pairing with a cancellable provider (CachedTileProvider is one),
              // which also cancels the in-flight intermediate requests.
              tileUpdateTransformer: TileUpdateTransformers.debounce(
                const Duration(milliseconds: 100),
              ),
            ),
            MarkerLayer(
              markers: [
                for (final facility in state.facilities.where(
                  facilityHasValidCoordinates,
                ))
                  Marker(
                    point: LatLng(
                      facility.coordinates.latitude,
                      facility.coordinates.longitude,
                    ),
                    width: facilityMarkerSize,
                    height: facilityMarkerSize,
                    // Widget above the point → the pin tip touches it.
                    alignment: Alignment.topCenter,
                    child: FacilityMarker(
                      key: ValueKey('facility_marker_${facility.facilityId}'),
                      facility: facility,
                      onTap: () => onMarkerTap(facility),
                    ),
                  ),
              ],
            ),
            ValueListenableBuilder<LatLng?>(
              valueListenable: userLocation,
              builder: (context, location, _) {
                if (location == null) return const SizedBox.shrink();
                return MarkerLayer(
                  markers: [
                    Marker(
                      point: location,
                      width: 30,
                      height: 30,
                      child: const _UserLocationDot(
                        key: ValueKey('user_location_dot'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        if (toggle != null)
          Positioned(top: 12, left: 0, right: 0, child: Center(child: toggle!)),
        const Positioned(
          left: 12,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_MapAttribution(), SizedBox(height: 8), _Legend()],
          ),
        ),
        Positioned(
          right: 12,
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: null,
            tooltip: l10n.mapRecenterTooltip,
            onPressed: onRecenter,
            child: const Icon(Icons.my_location),
          ),
        ),
        if (state.status == FacilityLoadStatus.initial ||
            state.status == FacilityLoadStatus.loading)
          const Center(child: CircularProgressIndicator()),
        if (state.status == FacilityLoadStatus.error)
          Center(
            child: _OverlayCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, color: colors.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text(l10n.facilityLoadError),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: onRetry,
                    child: Text(l10n.retryButtonLabel),
                  ),
                ],
              ),
            ),
          ),
        if (state.status == FacilityLoadStatus.loaded &&
            state.facilities.isEmpty)
          Center(child: _OverlayCard(child: Text(l10n.facilityListEmpty))),
      ],
    );
  }
}

/// Segmented Map/List pill (`map.png` toggle, dc.html lines 335–337): a
/// rounded-pill container with two segments; the active one fills with the
/// primary colour. Phone-only — the tablet split view shows both panes.
class _MapViewToggle extends StatelessWidget {
  const _MapViewToggle({required this.mode, required this.onChanged});

  final _MapViewMode mode;
  final ValueChanged<_MapViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Material(
      color: colors.surface,
      elevation: 2,
      shape: StadiumBorder(side: BorderSide(color: colors.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleSegment(
              key: const ValueKey('map_view_toggle_map'),
              icon: Icons.map_outlined,
              label: l10n.mapTab,
              selected: mode == _MapViewMode.map,
              onTap: () => onChanged(_MapViewMode.map),
            ),
            _ToggleSegment(
              key: const ValueKey('map_view_toggle_list'),
              icon: Icons.list,
              label: l10n.mapViewList,
              selected: mode == _MapViewMode.list,
              onTap: () => onChanged(_MapViewMode.list),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected ? colors.onPrimary : colors.onSurfaceVariant;

    return InkWell(
      onTap: selected ? null : onTap,
      customBorder: const StadiumBorder(),
      child: Ink(
        decoration: ShapeDecoration(
          color: selected ? colors.primary : Colors.transparent,
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// My-location dot (`map.png` / dc.html "my location"). Uses the theme's
/// [ColorScheme.secondary] — the accent role no facility-status colour claims
/// (free→primary, occupied→error, queued→tertiary) — so the dot stays visually
/// distinct from the markers, with [ColorScheme.onSecondary] as the contrast
/// ring. Both adapt to light/dark automatically.
class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: colors.secondary,
          shape: BoxShape.circle,
          border: Border.all(color: colors.onSecondary, width: 3),
          boxShadow: [
            BoxShadow(
              color: colors.secondary.withValues(alpha: 0.25),
              spreadRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayCard extends StatelessWidget {
  const _OverlayCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

/// OpenStreetMap credit pill, stacked above the legend bottom-left.
class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: EdgeInsets.zero,
      shape: const StadiumBorder(),
      child: InkWell(
        // OSM Attribution Guidelines: the credit must link to the licence page.
        onTap: () => launchUrl(
          Uri.parse('https://www.openstreetmap.org/copyright'),
          mode: LaunchMode.externalApplication,
        ),
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            l10n.mapAttribution,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    );
  }
}

/// Free / Occupied / Queued colour legend pill, bottom-left per `map.png`.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: EdgeInsets.zero,
      shape: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendEntry(
              color: facilityStatusColor(colors, FacilityStatus.free),
              label: l10n.facilityStatusFree,
            ),
            const SizedBox(width: 12),
            _LegendEntry(
              color: facilityStatusColor(colors, FacilityStatus.occupied),
              label: l10n.facilityStatusOccupied,
            ),
            const SizedBox(width: 12),
            _LegendEntry(
              color: facilityStatusColor(colors, FacilityStatus.queued),
              label: l10n.facilityStatusQueued,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
