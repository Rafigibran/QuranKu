import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'screens/splash_screen.dart';
import 'screens/main_screen.dart';
import 'services/settings_service.dart';
import 'services/tasbih_service.dart';
import 'services/adhan_service.dart';
import 'services/khatam_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    initializeDateFormatting('id_ID', null),
    initializeDateFormatting('en_US', null),
  ]);
  await SettingsService().init();
  await TasbihService().init();
  try {
    await AdhanService().init();
  } catch (_) {}
  try {
    await KhatamService().init();
  } catch (_) {}
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SettingsService _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Malam-veranda world: restrained Material 3 tonal system.
  /// One binding accent (QuranKu green #2E9D6B); amber lamp reserved for the
  /// single live state (playing, next-prayer countdown). UI type is the
  /// platform workhorse sans; Amiri lives only in Arabic surfaces.
  /// Light is paper green, dark is deep veranda night — picked from the use
  /// scene (low-light reading at home/mosque), never by category default.
  ThemeData _buildTheme(Brightness brightness) {
    const accent = Color(0xFF2E9D6B);
    const lamp = Color(0xFFC98A2B);
    final isDark = brightness == Brightness.dark;
    var scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    );
    scheme = scheme.copyWith(
      primary: accent,
      onPrimary: Colors.white,
      tertiary: lamp,
      onTertiary: Colors.white,
      surface: isDark ? const Color(0xFF0B1411) : const Color(0xFFF4F6F1),
      surfaceContainerLowest: isDark
          ? const Color(0xFF080F0C)
          : const Color(0xFFFFFFFF),
      surfaceContainerLow: isDark
          ? const Color(0xFF101B16)
          : const Color(0xFFFFFFFF),
      surfaceContainer: isDark
          ? const Color(0xFF14211B)
          : const Color(0xFFECEFE8),
      surfaceContainerHigh: isDark
          ? const Color(0xFF182720)
          : const Color(0xFFE2E7DD),
      surfaceContainerHighest: isDark
          ? const Color(0xFF1E2F26)
          : const Color(0xFFD8DED3),
    );

    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      primaryColor: accent,
      colorScheme: scheme,
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textTheme: Typography.englishLike2018.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ).copyWith(
        titleLarge: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleMedium: TextStyle(
          color: scheme.onSurface,
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        bodyLarge: TextStyle(
          color: scheme.onSurface,
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: accent.withValues(alpha: 0.18),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? accent : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 26,
            color: selected ? accent : scheme.onSurfaceVariant,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accent, width: 1.6),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        iconColor: accent,
        textColor: scheme.onSurface,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          foregroundColor: accent,
        ),
      ),
      chipTheme: baseChipTheme(scheme, accent),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.45)
              : null,
        ),
      ),
    );

    return base;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: _settings.themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      locale: _settings.appLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supported) {
        for (final s in supported) {
          if (locale != null && s.languageCode == locale.languageCode) return s;
        }
        return AppLocalizations.supportedLocales.first;
      },
      home: const SplashScreen(nextScreen: MainScreen()),
    );
  }
}

ChipThemeData baseChipTheme(ColorScheme scheme, Color accent) {
  return ChipThemeData(
    backgroundColor: scheme.surfaceContainerHighest,
    selectedColor: accent.withValues(alpha: 0.18),
    labelStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
    secondaryLabelStyle: TextStyle(color: accent, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );
}
