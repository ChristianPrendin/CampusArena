import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:http_cache_drift_store/http_cache_drift_store.dart';
import 'package:path_provider/path_provider.dart';

/// Builds the production OpenStreetMap tile provider with an on-disk cache.
///
/// The OSM Tile Usage Policy *requires* clients to cache tiles locally
/// (per HTTP caching headers, or ≥7 days as a fallback). flutter_map's default
/// `NetworkTileProvider` only uses Flutter's in-memory `ImageCache`, which is
/// cleared on every restart — so it does not satisfy the policy on its own.
///
/// [CachedTileProvider] honours the server's `Cache-Control`/`Expires` headers
/// and falls back to [maxStale] when they are absent, backed by the drift/
/// sqlite-backed [DriftCacheStore]. Callers pass the resulting provider into
/// `MapScreen`; widget tests keep injecting their own fake provider instead.
///
/// Best-effort: returns `null` (→ `MapScreen` uses the default in-memory
/// `NetworkTileProvider`) if the platform can't hand back a cache directory or
/// the store won't open, so a cache failure never bricks app startup.
Future<TileProvider?> buildOsmTileProvider() async {
  try {
    final cacheDir = await getApplicationCacheDirectory();
    return CachedTileProvider(
      store: DriftCacheStore(databasePath: cacheDir.path),
      // Fallback retention when OSM's response carries no cache headers; well
      // above the policy's 7-day minimum.
      maxStale: const Duration(days: 30),
    );
  } catch (_) {
    return null;
  }
}
