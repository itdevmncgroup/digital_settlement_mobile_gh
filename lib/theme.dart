import 'package:flutter/material.dart';

const brandSeed = Color(0xFF6C8CFF);
const brandGradientStart = Color(0xFF1B2340);
const brandGradientEnd = Color(0xFF4A5CC7);

const _bgDeep = Color(0xFF0E1017);
const _surface = Color(0xFF171A24);
const _surfaceHigh = Color(0xFF1F2330);

/// Dark, fintech-style theme - the whole app runs in dark mode (forced via
/// MaterialApp.themeMode in main.dart), so this is the only palette in use.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandSeed,
    brightness: Brightness.dark,
  ).copyWith(
    surface: _surface,
    surfaceContainerHighest: _surfaceHigh,
    primaryContainer: const Color(0xFF2C3564),
    error: const Color(0xFFFF6B6B),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: _bgDeep,
    appBarTheme: AppBarTheme(
      backgroundColor: _bgDeep,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: _surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surfaceHigh,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.primary, width: 1.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      backgroundColor: _surfaceHigh,
      labelStyle: const TextStyle(color: Colors.white),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _surface,
      elevation: 3,
      indicatorColor: scheme.primary.withValues(alpha: 0.22),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11.5,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? scheme.primary : Colors.white.withValues(alpha: 0.55),
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? scheme.primary : Colors.white.withValues(alpha: 0.45)),
      ),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16), textColor: Colors.white),
    dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.08), space: 1),
    textTheme: ThemeData.dark().textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    snackBarTheme: SnackBarThemeData(backgroundColor: _surfaceHigh, contentTextStyle: const TextStyle(color: Colors.white)),
  );
}
