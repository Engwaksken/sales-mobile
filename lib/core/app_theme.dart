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

  // Surface ladder. The page (surface / scaffold) is a tinted neutral so cards,
  // bars and sheets (surfaceContainerLowest) clearly sit on top of it:
  //   light: page #F1F4F9  ->  cards #FFFFFF
  //   dark:  page #0A0F1A  ->  cards #141C2B
  // The higher containers are filled panels (chips, thumbnails, search
  // fields) that must still read on both the page and a card.
  final scheme = ColorScheme.fromSeed(seedColor: brand, brightness: brightness).copyWith(
    primary: primary,
    onPrimary: onPrimary,
    secondary: dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
    surface: dark ? const Color(0xFF0A0F1A) : const Color(0xFFF1F4F9),
    onSurface: dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
    onSurfaceVariant: dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
    outline: dark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
    outlineVariant: dark ? const Color(0xFF263247) : const Color(0xFFE1E7EF),
    surfaceContainerLowest: dark ? const Color(0xFF141C2B) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF182133) : const Color(0xFFF7F9FC),
    surfaceContainer: dark ? const Color(0xFF1B2538) : const Color(0xFFEEF2F7),
    surfaceContainerHigh: dark ? const Color(0xFF1F2A3F) : const Color(0xFFEAEEF4),
    surfaceContainerHighest: dark ? const Color(0xFF233047) : const Color(0xFFE6EBF2),
    error: dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
    onError: dark ? const Color(0xFF450A0A) : Colors.white,
  );

  final ink = scheme.onSurface;
  final body = dark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
  final bodyMedium = dark ? const Color(0xFFB6C2D2) : const Color(0xFF475569);
  final card = scheme.surfaceContainerLowest;
  // Fields stay distinct from the card they sit on: white with a firmer
  // border in light mode, a slightly lifted fill in dark mode.
  final fieldFill = dark ? scheme.surfaceContainerLow : card;
  final fieldBorder = dark ? const Color(0xFF2E3B53) : const Color(0xFFD5DCE6);
  // Soft drop shadow for raised surfaces; dark mode relies on fill and border.
  final shadow = dark ? const Color(0x66000000) : const Color(0x140F172A);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    shadowColor: shadow,
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
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: TextStyle(color: dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 14),
      labelStyle: TextStyle(color: bodyMedium, fontWeight: FontWeight.w500),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fieldBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fieldBorder)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.outlineVariant)),
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
      surfaceTintColor: Colors.transparent,
      shadowColor: shadow,
      elevation: dark ? 0 : 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    tabBarTheme: TabBarThemeData(dividerColor: scheme.outlineVariant, unselectedLabelColor: scheme.onSurfaceVariant),
    popupMenuTheme: PopupMenuThemeData(color: card, surfaceTintColor: Colors.transparent, shadowColor: shadow),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(card),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    drawerTheme: DrawerThemeData(backgroundColor: card, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: card, modalBackgroundColor: card, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(backgroundColor: card, surfaceTintColor: Colors.transparent),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shadowColor: shadow,
      elevation: 3,
    ),
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
