import 'package:flutter/material.dart';

/// Maps a WMO weather interpretation code (Open-Meteo `weather_code`) to a
/// Material icon. Buckets follow the WMO code table: 0–2 clear/partly cloudy,
/// 3 overcast, 45–48 fog, 5x/6x/8x precipitation, 7x/85–86 snow, 9x thunder.
IconData weatherIconFor(int wmoCode) {
  if (wmoCode <= 1) return Icons.wb_sunny;
  if (wmoCode == 2) return Icons.wb_cloudy;
  if (wmoCode == 3) return Icons.cloud;
  if (wmoCode == 45 || wmoCode == 48) return Icons.foggy;
  if (wmoCode >= 95) return Icons.thunderstorm;
  if ((wmoCode >= 71 && wmoCode <= 77) || wmoCode == 85 || wmoCode == 86) {
    return Icons.ac_unit;
  }
  if (wmoCode >= 51) return Icons.water_drop;
  return Icons.cloud;
}
