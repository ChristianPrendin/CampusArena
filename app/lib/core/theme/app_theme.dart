import 'package:flutter/material.dart';

/// Leaderboard podium (1st/2nd/3rd) accent colours. Gold/silver/bronze are
/// semantic to the podium, not roles in Material's [ColorScheme], so they live
/// in a [ThemeExtension] — widgets read them via `Theme.of(context)` and never
/// hardcode hex.
@immutable
class PodiumColors extends ThemeExtension<PodiumColors> {
  const PodiumColors({
    required this.gold,
    required this.silver,
    required this.bronze,
  });

  final Color gold;
  final Color silver;
  final Color bronze;

  /// Podium colour for a 1-based rank; null for anything below third.
  Color? forRank(int rank) => switch (rank) {
    1 => gold,
    2 => silver,
    3 => bronze,
    _ => null,
  };

  static const light = PodiumColors(
    gold: Color(0xFFE0A500),
    silver: Color(0xFF8D99A6),
    bronze: Color(0xFFB4713A),
  );

  static const dark = PodiumColors(
    gold: Color(0xFFE9B949),
    silver: Color(0xFFA7B0BA),
    bronze: Color(0xFFC98A55),
  );

  @override
  PodiumColors copyWith({Color? gold, Color? silver, Color? bronze}) =>
      PodiumColors(
        gold: gold ?? this.gold,
        silver: silver ?? this.silver,
        bronze: bronze ?? this.bronze,
      );

  @override
  PodiumColors lerp(ThemeExtension<PodiumColors>? other, double t) {
    if (other is! PodiumColors) return this;
    return PodiumColors(
      gold: Color.lerp(gold, other.gold, t)!,
      silver: Color.lerp(silver, other.silver, t)!,
      bronze: Color.lerp(bronze, other.bronze, t)!,
    );
  }
}

class AppTheme {
  // Purely static class.
  const AppTheme._();

  static const primarySeedColor = Color(0xFF00A86B); // Sleek Emerald Green

  static const _fieldRadius = 12.0;

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primarySeedColor,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(elevation: 2),
      elevatedButtonTheme: _elevatedButtonTheme,
      filledButtonTheme: _filledButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
      inputDecorationTheme: _inputDecorationTheme(colorScheme),
      extensions: const [PodiumColors.light],
    );
  }

  /// The dark [ColorScheme], exposed for surfaces that stay dark regardless of
  /// the active theme — e.g. the QR scanner chrome over a live camera feed —
  /// so they can source ColorScheme roles instead of raw color literals.
  static final ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: primarySeedColor,
    brightness: Brightness.dark,
    surface: const Color(0xFF1E1E1E),
  );

  static ThemeData get darkTheme {
    final colorScheme = darkColorScheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(elevation: 4, color: Color(0xFF1E1E1E)),
      elevatedButtonTheme: _elevatedButtonTheme,
      filledButtonTheme: _filledButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
      inputDecorationTheme: _inputDecorationTheme(colorScheme),
      extensions: const [PodiumColors.dark],
    );
  }

  static final _elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
      ),
    ),
  );

  // The app builds its primary/secondary actions with FilledButton and
  // OutlinedButton (never ElevatedButton), so those are the themes that must
  // carry the design's rounded-rectangle shape — Material 3's default for
  // both is a fully-rounded stadium border.
  static final _filledButtonTheme = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
      ),
    ),
  );

  static OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme colorScheme) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: colorScheme.primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
        ),
      ),
    );
  }

  // Filled, rounded-rectangle fields on a surface-container fill, per the
  // design system's `tf`/`tfSm` tokens — Material 3 otherwise defaults
  // TextFormField to an unfilled underline (Material 2) look.
  static InputDecorationTheme _inputDecorationTheme(ColorScheme colorScheme) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHigh,
      border: border(colorScheme.outline),
      enabledBorder: border(colorScheme.outline),
      focusedBorder: border(colorScheme.primary, 2),
      errorBorder: border(colorScheme.error),
      focusedErrorBorder: border(colorScheme.error, 2),
    );
  }
}
