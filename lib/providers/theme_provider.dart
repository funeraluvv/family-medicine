
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/theme_model.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'app_theme_mode';

  ThemeModel _themeModel = ThemeModel.initial();

  ThemeModel get themeModel => _themeModel;

  bool get isDark => _themeModel.isDark;

  ThemeProvider() {
    _loadThemeFromPreferences();
  }

  Future<void> _loadThemeFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString(_themeModeKey);

    if (modeString != null) {
      final mode = AppThemeMode.values.firstWhere(
            (e) => e.toString() == modeString,
        orElse: () => AppThemeMode.light,
      );
      _updateThemeMode(mode, saveToPrefs: false);
    } else {
      // Определяем системную тему
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final isDark = brightness == Brightness.dark;
      _themeModel = ThemeModel(mode: AppThemeMode.system, isDark: isDark);
      notifyListeners();
    }
  }

  Future<void> _saveThemeModeToPreferences(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.toString());
  }

  void _updateThemeMode(AppThemeMode mode, {bool saveToPrefs = true}) {
    final isDark = mode == AppThemeMode.dark ||
        (mode == AppThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

    _themeModel = ThemeModel(mode: mode, isDark: isDark);

    if (saveToPrefs) {
      _saveThemeModeToPreferences(mode);
    }

    notifyListeners();
  }

  void setThemeMode(AppThemeMode mode) {
    _updateThemeMode(mode);
  }

  void toggleTheme() {
    final newMode = _themeModel.isDark ? AppThemeMode.light : AppThemeMode.dark;
    setThemeMode(newMode);
  }

  void updateSystemTheme(Brightness brightness) {
    if (_themeModel.mode == AppThemeMode.system) {
      final isDark = brightness == Brightness.dark;
      _themeModel = ThemeModel(mode: AppThemeMode.system, isDark: isDark);
      notifyListeners();
    }
  }
}