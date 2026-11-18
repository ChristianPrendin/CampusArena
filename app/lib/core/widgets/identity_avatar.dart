import 'package:flutter/material.dart';

/// Up to two uppercase initials from a display name; '?' when the name is
/// unresolved or blank.
String initialsFromName(String? name) {
  if (name == null) return '?';
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '?';
  final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
  return letters.isEmpty ? '?' : letters;
}

/// Circle avatar whose background is a deterministic hue derived from [seed] —
/// the same seed always reads the same colour, without hardcoding a palette.
/// Shared by the dashboard's opponent avatars and the map's King of the Table.
class IdentityAvatar extends StatelessWidget {
  const IdentityAvatar({
    super.key,
    required this.seed,
    required this.initials,
    this.radius = 20,
    this.fontSize = 13,
  });

  final String seed;
  final String initials;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final hue = (seed.hashCode % 360).abs().toDouble();
    final color = HSVColor.fromAHSV(1, hue, 0.55, 0.82).toColor();
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
