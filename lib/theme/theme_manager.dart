import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static const String _themePrefKey = 'zipr_theme_mode_v1';
  static final ThemeManager instance = ThemeManager._internal();

  ThemeManager._internal();

  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

  ThemeMode get currentThemeMode => themeModeNotifier.value;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_themePrefKey);
    if (savedMode == 'dark') {
      themeModeNotifier.value = ThemeMode.dark;
    } else if (savedMode == 'light') {
      themeModeNotifier.value = ThemeMode.light;
    } else {
      themeModeNotifier.value = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.dark) {
      await prefs.setString(_themePrefKey, 'dark');
    } else if (mode == ThemeMode.light) {
      await prefs.setString(_themePrefKey, 'light');
    } else {
      await prefs.setString(_themePrefKey, 'system');
    }
  }
}
