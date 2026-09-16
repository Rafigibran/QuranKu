import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'surah_list_screen.dart';

class SplashScreen extends StatefulWidget {
  final Widget? nextScreen;
  const SplashScreen({super.key, this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2, milliseconds: 500), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => widget.nextScreen ?? const SurahListScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          Center(
            child: Image.asset(
              'assets/splash.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                context.l10n.appTitle,
                style: TextStyle(
                  color: const Color(0xFF888888),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
