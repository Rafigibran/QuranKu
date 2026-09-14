import 'package:flutter/material.dart';
import 'screens/quran_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuranKuApp());
}

class QuranKuApp extends StatelessWidget {
  const QuranKuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuranKu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
      home: const QuranHomeScreen(),
    );
  }
}
