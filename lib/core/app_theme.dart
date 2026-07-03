import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// UniShip "Mono" theme — a single Inter system with a strong weight
/// hierarchy (tight-tracked heavy headings, regular body), black & white
/// primaries, true-black dark mode.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        bg: AppColors.darkBg,
        surface: AppColors.darkSurface,
        elevated: AppColors.darkElevated,
        border: AppColors.darkBorder,
        text: AppColors.darkText,
        accent: AppColors.accentBright,
      );

  static ThemeData get light => _build(
        brightness: Brightness.light,
        bg: AppColors.lightBg,
        surface: AppColors.lightSurface,
        elevated: AppColors.lightElevated,
        border: AppColors.lightBorder,
        text: AppColors.lightText,
        accent: AppColors.accentDeep,
      );

  /// Display/heading style — Inter, heavy and tight, like modern editorial.
  static TextStyle display({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing ?? fontSize * -0.03,
        height: height,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color elevated,
    required Color border,
    required Color text,
    required Color accent,
  }) {
    final isDark = brightness == Brightness.dark;
    final onAccent = isDark ? AppColors.accentDeep : Colors.white;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      secondary: AppColors.blue,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: bg,
      onSurface: text,
      surfaceContainerLowest: bg,
      surfaceContainerLow: elevated,
      surfaceContainer: surface,
      surfaceContainerHigh: surface,
      surfaceContainerHighest: elevated,
      outline: border,
      outlineVariant: border,
      onSurfaceVariant: text.withValues(alpha: 0.6),
    );

    final baseText = GoogleFonts.interTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(bodyColor: text, displayColor: text);

    // One family, two voices: heavy tight display layer, calm body layer.
    final textTheme = baseText.copyWith(
      displayLarge: display(fontSize: 40, fontWeight: FontWeight.w800, color: text),
      displayMedium: display(fontSize: 32, fontWeight: FontWeight.w800, color: text),
      displaySmall: display(fontSize: 26, fontWeight: FontWeight.w800, color: text),
      headlineLarge: display(fontSize: 24, fontWeight: FontWeight.w800, color: text),
      headlineMedium: display(fontSize: 21, fontWeight: FontWeight.w700, color: text),
      headlineSmall: display(fontSize: 18, fontWeight: FontWeight.w700, color: text),
      titleLarge: display(fontSize: 17, fontWeight: FontWeight.w700, color: text),
      titleMedium: display(fontSize: 15, fontWeight: FontWeight.w600, color: text),
      titleSmall: display(fontSize: 13.5, fontWeight: FontWeight.w600, color: text),
    );

    final onMuted = text.withValues(alpha: 0.55);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: display(fontSize: 22, fontWeight: FontWeight.w800, color: text),
        iconTheme: IconThemeData(color: text),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: isDark ? BorderSide(color: border) : BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? elevated.withValues(alpha: 0.55) : elevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: TextStyle(
          color: text.withValues(alpha: 0.32),
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: TextStyle(color: text.withValues(alpha: 0.5), fontSize: 13.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: border.withValues(alpha: isDark ? 0.6 : 1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          minimumSize: const Size.fromHeight(52),
          textStyle: GoogleFonts.inter(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: isDark ? AppColors.darkBorderActive : AppColors.lightBorderActive, width: 1.2),
          minimumSize: const Size.fromHeight(48),
          textStyle: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: text.withValues(alpha: 0.8),
          textStyle: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: elevated,
        side: BorderSide.none,
        labelStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: text.withValues(alpha: 0.7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkElevated : AppColors.lightText,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark ? text : Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: text.withValues(alpha: 0.15),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: isDark ? BorderSide(color: border) : BorderSide.none,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: isDark ? AppColors.darkElevated : AppColors.lightElevated,
        circularTrackColor: isDark ? AppColors.darkElevated : AppColors.lightElevated,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: text,
        unselectedLabelColor: text.withValues(alpha: 0.45),
        indicatorColor: accent,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: border,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? onAccent
              : text.withValues(alpha: 0.55),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent
              : (isDark ? AppColors.darkElevated : AppColors.lightBorderActive),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 3,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
