import 'package:flutter/material.dart';

/// Brand palette mirrored from the UniShip web app (globals.css).
class AppColors {
  AppColors._();

  // Accents (shared across themes)
  static const Color accent = Color(0xFF00A8E1);
  static const Color accentDeep = Color(0xFF0088BD);
  static const Color blue = Color(0xFF4B8BBE);
  static const Color green = Color(0xFF00C16E);
  static const Color success = Color(0xFF4CAF50);
  static const Color amber = Color(0xFFF1A82C);
  static const Color pink = Color(0xFFE04DB0);
  static const Color danger = Color(0xFFDC2626);

  // Dark theme
  static const Color darkBg = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF151515);
  static const Color darkElevated = Color(0xFF0A0A0A);
  static const Color darkBorder = Color(0xFF2C2C2C);
  static const Color darkBorderActive = Color(0xFF4B4B4B);
  static const Color darkText = Color(0xFFEEEFE9);

  // Light theme
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF5F5F4);
  static const Color lightElevated = Color(0xFFFAFAF9);
  static const Color lightBorder = Color(0xFFE7E5E4);
  static const Color lightBorderActive = Color(0xFFD6D3D1);
  static const Color lightText = Color(0xFF1C1917);

  /// Event-type colors used across College Space / Calendar.
  static const Map<String, Color> eventTypeColors = {
    'event': blue,
    'internship': green,
    'hackathon': accent,
    'research': amber,
    'workshop': pink,
  };

  static Color eventTypeColor(String type) =>
      eventTypeColors[type] ?? blue;

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
