import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/client.dart';

/// Identité visuelle TeriyaScore — indigo / cobalt.
class TsTokens {
  /// Défaut clair — évite un flash sombre avant la 1ʳᵉ synchro.
  static Brightness brightness = Brightness.light;

  static bool get isDark => brightness == Brightness.dark;

  // ── Dark (indigo night) ──
  static const Color _bgDark = Color(0xFF070B16);
  static const Color _bgMidDark = Color(0xFF0C1224);
  static const Color _surfaceDark = Color(0xFF121A30);
  static const Color _elevatedDark = Color(0xFF1A2440);
  static const Color _lineDark = Color(0x3390A8E0);
  static const Color _textDark = Color(0xFFE8EEF9);
  static const Color _textMuteDark = Color(0xFF93A4C7);
  static const Color _card2Dark = Color(0xFF0E1528);

  // ── Light (cool day) ──
  static const Color _bgLight = Color(0xFFF3F5FB);
  static const Color _bgMidLight = Color(0xFFE8ECF6);
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _elevatedLight = Color(0xFFFFFFFF);
  static const Color _lineLight = Color(0x333D7EFF);
  static const Color _textLight = Color(0xFF0C1224);
  static const Color _textMuteLight = Color(0xFF4A5878);
  static const Color _card2Light = Color(0xFFDDE3F2);

  static Color get bg => isDark ? _bgDark : _bgLight;
  static Color get bgMid => isDark ? _bgMidDark : _bgMidLight;
  static Color get surface => isDark ? _surfaceDark : _surfaceLight;
  static Color get elevated => isDark ? _elevatedDark : _elevatedLight;
  static Color get line => isDark ? _lineDark : _lineLight;
  static Color get text => isDark ? _textDark : _textLight;
  static Color get textMute => isDark ? _textMuteDark : _textMuteLight;
  static Color get card2 => isDark ? _card2Dark : _card2Light;

  static const Color brand = Color(0xFF3D7EFF);
  static const Color brandSoft = Color(0xFF7AA8FF);
  static const Color sand = Color(0xFFE0A45A);
  static const Color warn = Color(0xFFE0A45A);
  static const Color danger = Color(0xFFE05A5A);
  static const Color ok = Color(0xFF3DB8A0);

  /// Contraste sur boutons brand.
  static const Color onBrand = Color(0xFF071018);

  static String appName = 'TeriyaScore';
  static String? logoUrl;
  static String? supportPhone;

  static Color? primaryOverride;
  static Color? secondaryOverride;

  static Color get primary => primaryOverride ?? brand;
  static Color get secondary => secondaryOverride ?? brandSoft;

  static Brightness resolveBrightness(
    String theme, {
    Brightness? platformBrightness,
  }) {
    if (theme == 'light') return Brightness.light;
    if (theme == 'dark') return Brightness.dark;
    return platformBrightness ??
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  static void applyThemeMode(String theme, {Brightness? platformBrightness}) {
    brightness =
        resolveBrightness(theme, platformBrightness: platformBrightness);
  }

  static void syncFromThemeBrightness(Brightness themeBrightness) {
    brightness = themeBrightness;
  }

  static void applyBranding({
    String? appName,
    String? primaryColor,
    String? secondaryColor,
    String? logoUrl,
    String? supportPhone,
  }) {
    if (appName != null && appName.isNotEmpty) TsTokens.appName = appName;
    if (primaryColor != null) {
      primaryOverride = _parseColor(primaryColor);
    }
    if (secondaryColor != null) {
      secondaryOverride = _parseColor(secondaryColor);
    }
    TsTokens.logoUrl = logoUrl;
    TsTokens.supportPhone = supportPhone;
  }

  static Color? _parseColor(String raw) {
    var hex = raw.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(value);
  }

  static Color _bgOf(Brightness b) =>
      b == Brightness.dark ? _bgDark : _bgLight;
  static Color _surfaceOf(Brightness b) =>
      b == Brightness.dark ? _surfaceDark : _surfaceLight;
  static Color _elevatedOf(Brightness b) =>
      b == Brightness.dark ? _elevatedDark : _elevatedLight;
  static Color _lineOf(Brightness b) =>
      b == Brightness.dark ? _lineDark : _lineLight;
  static Color _textOf(Brightness b) =>
      b == Brightness.dark ? _textDark : _textLight;
  static Color _textMuteOf(Brightness b) =>
      b == Brightness.dark ? _textMuteDark : _textMuteLight;
}

final brandingProvider = FutureProvider<void>((ref) async {
  try {
    final data = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
          '/branding',
          parse: (d) => Map<String, dynamic>.from(d as Map),
        );
    final remoteName = data['appName']?.toString().trim();
    final isForeignBrand = remoteName != null &&
        remoteName.toLowerCase().contains('neoforma');
    final appName =
        (remoteName == null || remoteName.isEmpty || isForeignBrand)
            ? 'TeriyaScore'
            : remoteName;
    TsTokens.applyBranding(
      appName: appName,
      // Ignorer une marque étrangère (NeoForma) si un serveur mal configuré la renvoie.
      primaryColor: isForeignBrand ? null : data['primaryColor']?.toString(),
      secondaryColor:
          isForeignBrand ? null : data['secondaryColor']?.toString(),
      logoUrl: isForeignBrand ? null : data['logoUrl']?.toString(),
      supportPhone: data['supportPhone']?.toString(),
    );
  } catch (_) {
    // Défaut TeriyaScore
  }
});

/// Construit un ThemeData sans muter [TsTokens.brightness].
ThemeData buildTeriyaScoreTheme([Brightness brightness = Brightness.light]) {
  final primary = TsTokens.primary;
  final secondary = TsTokens.secondary;
  final bg = TsTokens._bgOf(brightness);
  final surface = TsTokens._surfaceOf(brightness);
  final elevated = TsTokens._elevatedOf(brightness);
  final line = TsTokens._lineOf(brightness);
  final text = TsTokens._textOf(brightness);
  final textMute = TsTokens._textMuteOf(brightness);
  const radius = 10.0;

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: bg,
    colorScheme: brightness == Brightness.dark
        ? ColorScheme.dark(
            primary: primary,
            secondary: secondary,
            surface: surface,
            error: TsTokens.danger,
            onPrimary: TsTokens.onBrand,
            onSurface: text,
          )
        : ColorScheme.light(
            primary: primary,
            secondary: secondary,
            surface: surface,
            error: TsTokens.danger,
            onPrimary: TsTokens.onBrand,
            onSurface: text,
          ),
  );

  return base.copyWith(
    textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: text,
      displayColor: text,
    ),
    primaryTextTheme: GoogleFonts.outfitTextTheme(base.primaryTextTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: text,
      elevation: 0,
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: text,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: elevated,
      hintStyle: TextStyle(color: textMute),
      labelStyle: TextStyle(color: textMute),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: TsTokens.onBrand,
        minimumSize: const Size.fromHeight(40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        textStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: TsTokens.onBrand,
        minimumSize: const Size.fromHeight(40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        textStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        textStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: secondary),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primary,
      unselectedItemColor: textMute,
      type: BottomNavigationBarType.fixed,
    ),
    cardTheme: CardThemeData(
      color: elevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: primary.withValues(alpha: 0.22),
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
