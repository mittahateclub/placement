import 'package:flutter/material.dart';

/// The app's own clean palette — soft neutrals with a modern blue accent
/// (intentionally distinct from the website's black/cyan theme).
class AppColors {
  AppColors._();

  // Accents (shared across themes)
  static const Color accent = Color(0xFF3B82F6);
  static const Color accentDeep = Color(0xFF2563EB);
  static const Color blue = Color(0xFF6366F1);
  static const Color green = Color(0xFF10B981);
  static const Color success = Color(0xFF22C55E);
  static const Color amber = Color(0xFFF59E0B);
  static const Color pink = Color(0xFFEC4899);
  static const Color danger = Color(0xFFEF4444);

  // Dark theme — soft slate, not pure black
  static const Color darkBg = Color(0xFF0E1116);
  static const Color darkSurface = Color(0xFF171B23);
  static const Color darkElevated = Color(0xFF1E2430);
  static const Color darkBorder = Color(0xFF262D3A);
  static const Color darkBorderActive = Color(0xFF39414F);
  static const Color darkText = Color(0xFFE9EBEF);

  // Light theme — airy off-white with white cards
  static const Color lightBg = Color(0xFFF6F7F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFF1F3F6);
  static const Color lightBorder = Color(0xFFE6E9EE);
  static const Color lightBorderActive = Color(0xFFD2D7DF);
  static const Color lightText = Color(0xFF171A20);

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
