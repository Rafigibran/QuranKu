import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/splash_screen.dart';
import 'screens/main_screen.dart';
import 'services/settings_service.dart';
import 'services/surah_naming_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await SettingsService().init();
  await SurahNamingService().init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SettingsService _settings = SettingsService();
  final SurahNamingService _naming = SurahNamingService();

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onChanged);
    _naming.addListener(_onChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onChanged);
    _naming.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    // Terang: warm paper-like reading surface.
    // Gelap: dark blue-grey that avoids pure black and pure white.
    // Reference-inspired visual system: clean white reading surfaces,
    // deep navy navigation/chrome, and restrained gold accents.
    const lightBackground = Color(0xFFF5F6F8);
    const lightSurface = Color(0xFFFFFFFF);
    const lightText = Color(0xFF25364B);
    const lightMuted = Color(0xFF6E7886);
    const lightOutline = Color(0xFFDDE2E8);
    const lightAccent = Color(0xFF25364B);

    const darkBackground = Color(0xFF10161D);
    const darkSurface = Color(0xFF182330);
    const darkText = Color(0xFFE9EEF3);
    const darkMuted = Color(0xFFABB5C0);
    const darkOutline = Color(0xFF2C3948);
    const darkAccent = Color(0xFFD2B66D);

    final background = dark ? darkBackground : lightBackground;
    final surface = dark ? darkSurface : lightSurface;
    final onSurface = dark ? darkText : lightText;
    final muted = dark ? darkMuted : lightMuted;
    final outline = dark ? darkOutline : lightOutline;
    final primary = dark ? darkAccent : lightAccent;

    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
      ).copyWith(
        primary: primary,
        onPrimary: dark ? const Color(0xFF22231A) : Colors.white,
        secondary: dark ? const Color(0xFFD2B66D) : const Color(0xFFB89A5C),
        onSecondary: dark ? const Color(0xFF27251F) : Colors.white,
        surface: surface,
        onSurface: onSurface,
        surfaceContainer: surface,
        surfaceContainerHighest: dark ? const Color(0xFF292931) : const Color(0xFFF1E8D8),
        onSurfaceVariant: muted,
        outline: outline,
        error: const Color(0xFFB24A3E),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF25364B),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: Colors.white,
          fontSize: 27,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: onSurface, size: 24),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: UnderlineInputBorder(borderSide: BorderSide(color: outline)),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: outline)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primary, width: 1.6)),
        hintStyle: GoogleFonts.ebGaramond(
          color: muted,
          fontSize: 17,
          fontWeight: FontWeight.w400,
        ),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 8,
        contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        iconColor: primary,
        textColor: onSurface,
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 0.7, space: 0.7),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        // Only sheets that explicitly opt in may show a handle.
        showDragHandle: false,
        dragHandleColor: outline,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: const Color(0xFF25364B),
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.white.withValues(alpha: .14),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.spaceGrotesk(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.15,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? Colors.white : Colors.white.withValues(alpha: .62),
            size: selected ? 23 : 21,
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: GoogleFonts.ebGaramond(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          foregroundColor: primary,
          textStyle: GoogleFonts.ebGaramond(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface,
        contentTextStyle: GoogleFonts.ebGaramond(color: onSurface, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.ebGaramondTextTheme(base.textTheme).apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuranKu',
      debugShowCheckedModeBanner: false,
      themeMode: _settings.themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const SplashScreen(nextScreen: MainScreen()),
    );
  }
}
