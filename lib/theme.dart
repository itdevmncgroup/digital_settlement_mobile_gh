import 'package:flutter/material.dart';

const brandSeed = Color(0xFF4A5CC7);
const brandGradientStart = Color(0xFF1B2340);
const brandGradientEnd = Color(0xFF4A5CC7);

const _bgLight = Color(0xFFF4F5FA);
const _surface = Colors.white;
const _surfaceHigh = Color(0xFFF0F1F7);
const _textPrimary = Color(0xFF1B2340);
const _textMuted = Color(0xFF6B7280);

/// Light, fintech-style theme (FinFlow look) - the whole app runs in light
/// mode (forced via MaterialApp.themeMode in main.dart), so this is the only
/// palette in use.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandSeed,
    brightness: Brightness.light,
  ).copyWith(
    surface: _surface,
    surfaceContainerHighest: _surfaceHigh,
    primaryContainer: const Color(0xFFE1E6FA),
    error: const Color(0xFFE5484D),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: _bgLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: _surface,
      foregroundColor: _textPrimary,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: TextStyle(color: _textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
      iconTheme: IconThemeData(color: _textPrimary),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: _surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surfaceHigh,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: const TextStyle(color: _textMuted),
      hintStyle: TextStyle(color: _textMuted.withValues(alpha: 0.8)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
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
        side: BorderSide(color: Colors.black.withValues(alpha: 0.16)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      backgroundColor: _surfaceHigh,
      labelStyle: const TextStyle(color: _textPrimary),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _surface,
      elevation: 3,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11.5,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? scheme.primary : _textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? scheme.primary : _textMuted),
      ),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16), textColor: _textPrimary),
    dividerTheme: DividerThemeData(color: Colors.black.withValues(alpha: 0.08), space: 1),
    textTheme: ThemeData.light().textTheme.apply(bodyColor: _textPrimary, displayColor: _textPrimary),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    snackBarTheme: const SnackBarThemeData(backgroundColor: _textPrimary, contentTextStyle: TextStyle(color: Colors.white)),
  );
}
