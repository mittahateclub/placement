import 'package:flutter/material.dart';

/// Monochrome base — true black in dark mode, pure white in light mode —
/// with a violet accent that reads well on both.
class AppColors {
  AppColors._();

  // Accents (shared across themes)
  static const Color accent = Color(0xFF8B5CF6);
  static const Color accentDeep = Color(0xFF7C3AED);
  static const Color blue = Color(0xFF6366F1);
  static const Color green = Color(0xFF10B981);
  static const Color success = Color(0xFF22C55E);
  static const Color amber = Color(0xFFF59E0B);
  static const Color pink = Color(0xFFEC4899);
  static const Color danger = Color(0xFFEF4444);

  // Dark theme — true black with neutral gray surfaces
  static const Color darkBg = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF101010);
  static const Color darkElevated = Color(0xFF1A1A1A);
  static const Color darkBorder = Color(0xFF262626);
  static const Color darkBorderActive = Color(0xFF3F3F3F);
  static const Color darkText = Color(0xFFF4F4F5);

  // Light theme — pure white with neutral gray hairlines
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFF4F4F5);
  static const Color lightBorder = Color(0xFFE4E4E7);
  static const Color lightBorderActive = Color(0xFFD4D4D8);
  static const Color lightText = Color(0xFF09090B);

  /// Event-type colors used across College Space / Calendar.
  static const Map<String, Color> eventTypeColors = {
    'event': Color(0xFF6366F1),
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
