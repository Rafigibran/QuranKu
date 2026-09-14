import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/main_screen.dart';
import 'services/settings_service.dart';
import 'services/app_language_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().init();
  await AppLanguageService().init();
  // Feature services are initialized lazily by the features that use them.
  // This prevents startup dialogs/overlays from covering the Quran screen.
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SettingsService _settings = SettingsService();
  final AppLanguageService _language = AppLanguageService();

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onChanged);
    _language.addListener(_onChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onChanged);
    _language.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuranKu',
      debugShowCheckedModeBanner: false,
      locale: _language.locale,
      supportedLocales: const [Locale('id'), Locale('en')],
      themeMode: _settings.themeMode,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        primaryColor: const Color(0xFF40B779),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF40B779),
          surface: Color(0xFF0A0A0A),
          onSurface: Colors.white,
          outline: Color(0xFF2A2A2A),
        ),
        useMaterial3: true,
      ),
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        primaryColor: const Color(0xFF40B779),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF40B779),
          surface: Color(0xFFF5F5F5),
          onSurface: Color(0xFF1A1A1A),
          outline: Color(0xFFE0E0E0),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(nextScreen: MainScreen()),
    );
  }
}
