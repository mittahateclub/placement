import 'package:flutter/material.dart';

/// UniShip "Mono" design tokens — bold black & white minimalism.
///
/// Light: airy off-white canvas, white cards, ink-black CTAs and heroes.
/// Dark: true #000 background (as on OLED), charcoal surfaces, white CTAs.
/// Color appears only as small semantic pops (status, event types).
class AppColors {
  AppColors._();

  // ── Brand (monochrome) ──
  /// Neutral graphite — reads as a quiet tint on both themes.
  static const Color accent = Color(0xFF8E8E93);

  /// Ink black — the light-theme primary.
  static const Color accentDeep = Color(0xFF0A0A0C);

  /// Paper white — the dark-theme primary.
  static const Color accentBright = Color(0xFFF5F5F7);

  static const Color gradientStart = Color(0xFF48484E);
  static const Color gradientEnd = Color(0xFF101014);

  /// Graphite gradient — used for low-alpha tint chips and accents.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );

  /// Ink fill — flat, Apple-style black control fill for light mode.
  /// A whisper of a gradient keeps large fills from feeling dead-flat.
  static const LinearGradient glossyDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1B1B1F), Color(0xFF0E0E11)],
  );

  /// Porcelain fill — flat white control fill for dark mode.
  static const LinearGradient glossyLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFCFCFD), Color(0xFFF2F2F5)],
  );

  /// The control fill for the current theme (ink in light, porcelain in dark).
  static LinearGradient glossy(Brightness brightness) =>
      brightness == Brightness.dark ? glossyLight : glossyDark;

  /// Foreground that sits on top of [glossy].
  static Color onGlossy(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF0A0A0C) : Colors.white;

  // ── Semantic / categorical (small pops only) ──
  static const Color blue = Color(0xFF3B82F6);
  static const Color green = Color(0xFF10B981);
  static const Color success = Color(0xFF22C55E);
  static const Color amber = Color(0xFFF59E0B);
  static const Color pink = Color(0xFFEC4899);
  static const Color danger = Color(0xFFEF4444);

  // ── Dark theme — true black ──
  static const Color darkBg = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF0E0E10);
  static const Color darkElevated = Color(0xFF1A1A1E);
  static const Color darkBorder = Color(0xFF232327);
  static const Color darkBorderActive = Color(0xFF3A3A3F);
  static const Color darkText = Color(0xFFF5F5F7);

  // ── Light theme — paper & ink ──
  static const Color lightBg = Color(0xFFF5F5F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFEFEFF2);
  static const Color lightBorder = Color(0xFFE5E5EA);
  static const Color lightBorderActive = Color(0xFFD1D1D6);
  static const Color lightText = Color(0xFF0A0A0C);

  /// Event-type colors used across College Space / Calendar.
  static const Map<String, Color> eventTypeColors = {
    'event': Color(0xFF3B82F6),
    'internship': Color(0xFF10B981),
    'hackathon': Color(0xFF06B6D4),
    'research': Color(0xFFF59E0B),
    'workshop': Color(0xFFEC4899),
  };

  static Color eventTypeColor(String type) =>
      eventTypeColors[type] ?? eventTypeColors['event']!;

  static String eventTypeLabel(String type) {
    switch (type) {
      case 'internship':
        return 'Internship';
      case 'hackathon':
        return 'Hackathon';
      case 'research':
        return 'Research';
      case 'workshop':
        return 'Workshop';
      default:
        return 'Event';
    }
  }
}
