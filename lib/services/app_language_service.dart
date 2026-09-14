import 'package:flutter/material.dart';

/// Internal compatibility shim for existing widgets that still expose
/// language-dependent labels. The app no longer supports language switching;
/// all UI is fixed to Indonesian.
class AppLanguageService extends ChangeNotifier {
  static final AppLanguageService _instance = AppLanguageService._internal();
  factory AppLanguageService() => _instance;
  AppLanguageService._internal();

  bool get isEnglish => false;
}
