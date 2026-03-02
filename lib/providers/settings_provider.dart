// settings_provider.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static Locale _currentLocale = const Locale('km', 'KH');

  // Static getter
  static Locale get currentLocale => _currentLocale;

  // Instance getter for the widget tree
  Locale get instanceCurrentLocale => _currentLocale;

  SettingsProvider() {
    _loadLocale();
  }

  void changeLocale(Locale locale) async {
    _currentLocale = locale;
    Intl.defaultLocale =
        locale.languageCode == 'km' ? 'km_KH' : locale.languageCode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', locale.languageCode);
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('languageCode');

    if (languageCode != null) {
      _currentLocale = Locale(languageCode);
      Intl.defaultLocale = languageCode == 'km' ? 'km_KH' : languageCode;
      notifyListeners();
    }
  }
}
