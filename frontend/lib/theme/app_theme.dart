import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// DartStream brand palette + theme + reusable brand widgets.
class AppColors {
  AppColors._();

  static const bg = Color(0xFF0A0E1A);
  static const bgMid = Color(0xFF0D1B3E);
  static const surface = Color(0xFF141C30);
  static const accent = Color(0xFF3DBEFF);
  static const violet = Color(0xFF7C5CFF);
  static const success = Color(0xFF22D39A);
  static const warning = Color(0xFFFFC857);
  static const danger = Color(0xFFFF5C7A);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, violet],
  );

  static const pageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bg, bgMid, Color(0xFF091428)],
  );
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.accent,
    secondary: AppColors.violet,
    surface: AppColors.surface,
    error: AppColors.danger,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
  );

  final text = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: Colors.white.withValues(alpha: 0.92),
    displayColor: Colors.white,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: text,
    dividerColor: Colors.white.withValues(alpha: 0.08),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      foregroundColor: Colors.white,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: AppColors.accent.withValues(alpha: 0.16),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      selectedIconTheme: const IconThemeData(color: AppColors.accent),
      unselectedIconTheme: IconThemeData(
        color: Colors.white.withValues(alpha: 0.55),
      ),
      selectedLabelTextStyle: GoogleFonts.inter(
        color: AppColors.accent,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: GoogleFonts.inter(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 12,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.bgMid),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      helperStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      border: _inputBorder(Colors.white.withValues(alpha: 0.12)),
      enabledBorder: _inputBorder(Colors.white.withValues(alpha: 0.12)),
      focusedBorder: _inputBorder(AppColors.accent, width: 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: const Color(0xFF051018),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );

class DartStreamLogo extends StatelessWidget {
  const DartStreamLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: AppColors.brandGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.45),
            blurRadius: size * 0.5,
            spreadRadius: 0,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(Icons.bolt_rounded, color: Colors.white, size: size * 0.64),
    );
  }
}

class DartStreamWordmark extends StatelessWidget {
  const DartStreamWordmark({super.key, this.logoSize = 28, this.subtitle});
  final double logoSize;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DartStreamLogo(size: logoSize),
        const SizedBox(width: 10),
        Text(
          'DartStream',
          style: GoogleFonts.inter(
            fontSize: logoSize * 0.62,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          Text(
            '  ·  ',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          ),
          Text(
            subtitle!,
            style: GoogleFonts.inter(
              fontSize: logoSize * 0.5,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ],
    );
  }
}

class BrandBackground extends StatelessWidget {
  const BrandBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.pageGradient),
      child: child,
    );
  }
}
