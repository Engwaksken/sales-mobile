import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Light and dark themes built from the admin's brand colour.
///
/// Screens take colours from the theme (see [AppColors]) instead of fixed
/// values, so they read well in both modes.
ThemeData buildAppTheme(Color brand, Brightness brightness) {
  final dark = brightness == Brightness.dark;

  // A dark brand colour (e.g. navy) disappears on a dark background; lift it for dark mode.
  final primary = dark && brand.computeLuminance() < .18 ? Color.lerp(brand, Colors.white, .45)! : brand;
  final onPrimary = _readableOn(primary);

  final scheme = ColorScheme.fromSeed(seedColor: brand, brightness: brightness).copyWith(
    primary: primary,
    onPrimary: onPrimary,
    secondary: dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
    surface: dark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC),
    onSurface: dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
    onSurfaceVariant: dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
    outline: dark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
    outlineVariant: dark ? const Color(0xFF243044) : const Color(0xFFE2E8F0),
    surfaceContainerLowest: dark ? const Color(0xFF111A2B) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF142035) : const Color(0xFFF8FAFC),
    surfaceContainer: dark ? const Color(0xFF17233A) : const Color(0xFFF1F5F9),
    surfaceContainerHigh: dark ? const Color(0xFF1B2840) : const Color(0xFFF1F5F9),
    surfaceContainerHighest: dark ? const Color(0xFF1E2B44) : const Color(0xFFF1F5F9),
    error: dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
    onError: dark ? const Color(0xFF450A0A) : Colors.white,
  );

  final ink = scheme.onSurface;
  final body = dark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
  final bodyMedium = dark ? const Color(0xFFB6C2D2) : const Color(0xFF475569);
  final card = scheme.surfaceContainerLowest;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.standard,
    textTheme: TextTheme(
      headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: ink),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: ink),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
      bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: body),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: bodyMedium),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: card,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: TextStyle(color: dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 14),
      labelStyle: TextStyle(color: bodyMedium, fontWeight: FontWeight.w500),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.outlineVariant)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 1.6)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.error, width: 1.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outline),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: dark ? const Color(0xFF223047) : const Color(0xFFE8EDF3)),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: card, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(backgroundColor: card, surfaceTintColor: Colors.transparent),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: card, surfaceTintColor: Colors.transparent),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

Color _readableOn(Color background) {
  double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (( la > lb ? la : lb) + .05) / ((la > lb ? lb : la) + .05);
  }

  const darkText = Color(0xFF0F172A);
  return contrast(Colors.white, background) >= contrast(darkText, background) ? Colors.white : darkText;
}

/// Theme-aware colours for screens. Use these instead of fixed colours.
extension AppColors on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Main text.
  Color get ink => colors.onSurface;

  /// Secondary text: captions, helper lines.
  Color get muted => colors.onSurfaceVariant;

  /// Least important text and placeholder icons.
  Color get faint => isDark ? const Color(0xFF7A879B) : const Color(0xFF94A3B8);

  /// Thin borders and separators.
  Color get hairline => colors.outlineVariant;

  /// Filled backgrounds behind fields, thumbnails and chips.
  Color get fieldFill => colors.surfaceContainerHighest;

  /// Cards, sheets and bubbles.
  Color get card => colors.surfaceContainerLowest;

  /// A very light panel inside a card.
  Color get panel => colors.surfaceContainerLow;

  Color get danger => colors.error;
  Color get dangerSoft => isDark ? const Color(0xFF3B1418) : const Color(0xFFFEF2F2);
  Color get success => isDark ? const Color(0xFF4ADE80) : const Color(0xFF047857);
  Color get warningSoft => isDark ? const Color(0xFF3A2410) : const Color(0xFFFFF7ED);
  Color get warningBorder => isDark ? const Color(0xFF7C4A12) : const Color(0xFFFED7AA);
  Color get warningInk => isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412);
}

/// The user's appearance choice (System, Light or Dark), remembered on the phone.
class ThemeModeStore extends ChangeNotifier {
  ThemeModeStore(this.storage);

  final FlutterSecureStorage storage;
  static const _key = 'theme_mode';

  ThemeMode mode = ThemeMode.system;

  Future<void> load() async {
    try {
      final saved = await storage.read(key: _key);
      mode = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
    } catch (_) {
      mode = ThemeMode.system;
    }
  }

  Future<void> set(ThemeMode value) async {
    if (value == mode) return;
    mode = value;
    notifyListeners();
    try {
      await storage.write(key: _key, value: value.name);
    } catch (_) {
      // Still applies for this session.
    }
  }
}
