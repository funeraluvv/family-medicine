
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ========== СВЕТЛАЯ ТЕМА ==========
  /// Основной фон
  static const lightBackground = Color(0xFFF7F7FB);

  /// Поверхности (карточки) - светлая тема
  static const lightSurface = Colors.white;

  /// Основной акцент (мягкий фиолетово-синий)
  static const primary = Color(0xFF6C63FF);

  /// Вторичный акцент (голубой)
  static const secondary = Color(0xFF4DA3FF);

  /// Розовый акцент (для предупреждений/важного)
  static const accentPink = Color(0xFFFF6B8B);

  /// Уведомления (экспирация/опасность)
  static const warning = Color(0xFFFFB020);
  static const error = Color(0xFFFF4D4D);
  static const success = Color(0xFF3DDC97);

  static const onPrimary = Colors.white;

  /// Текст - светлая тема
  static const lightTextPrimary = Color(0xFF1F1F2C);
  static const lightTextSecondary = Color(0xFF6B6B7A);

  /// Поля ввода - светлая тема
  static const lightInputFill = Color(0xFFF1F2F8);
  static const lightInputBorder = Color(0xFFE4E6F1);

  /// Иконки / неактивные элементы
  static const inactive = Color(0xFFBEC0CA);

  // ========== ТЁМНАЯ ТЕМА ==========
  /// Основной фон - тёмная тема
  static const darkBackground = Color(0xFF121212);

  /// Поверхности (карточки) - тёмная тема
  static const darkSurface = Color(0xFF1E1E1E);

  /// Поверхности второго уровня
  static const darkSurfaceVariant = Color(0xFF2D2D2D);

  /// Текст - тёмная тема
  static const darkTextPrimary = Color(0xFFEDEDED);
  static const darkTextSecondary = Color(0xFF9E9E9E);

  /// Поля ввода - тёмная тема
  static const darkInputFill = Color(0xFF2C2C2C);
  static const darkInputBorder = Color(0xFF3D3D3D);

  /// Акценты для тёмной темы
  static const darkPrimary = Color(0xFF8B85FF);
  static const darkSecondary = Color(0xFF6DB5FF);
}

/// Цветовая схема для светлой темы
const ColorScheme _lightColorScheme = ColorScheme.light(
  primary: AppColors.primary,
  secondary: AppColors.secondary,
  surface: AppColors.lightSurface,
  background: AppColors.lightBackground,
  error: AppColors.error,
  onPrimary: AppColors.onPrimary,
  onSurface: AppColors.lightTextPrimary,
  onBackground: AppColors.lightTextPrimary,
);

/// Цветовая схема для тёмной темы
const ColorScheme _darkColorScheme = ColorScheme.dark(
  primary: AppColors.darkPrimary,
  secondary: AppColors.darkSecondary,
  surface: AppColors.darkSurface,
  background: AppColors.darkBackground,
  error: AppColors.error,
  onPrimary: AppColors.onPrimary,
  onSurface: AppColors.darkTextPrimary,
  onBackground: AppColors.darkTextPrimary,
);

/// Базовый стиль текста (Inter)
TextTheme _baseTextTheme(TextTheme base) {
  return GoogleFonts.interTextTheme(base).copyWith(
    headlineMedium: base.headlineMedium?.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: base.bodyLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontSize: 14,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
  );
}

/// Карточка для светлой темы
CardThemeData _lightCardTheme = CardThemeData(
  color: AppColors.lightSurface,
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
  ),
);

/// Карточка для тёмной темы
CardThemeData _darkCardTheme = CardThemeData(
  color: AppColors.darkSurface,
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
  ),
);

/// InputDecorationTheme для светлой темы
InputDecorationTheme _lightInputDecorationTheme = InputDecorationTheme(
  filled: true,
  fillColor: AppColors.lightInputFill,
  labelStyle: const TextStyle(
    color: AppColors.lightTextSecondary,
    fontSize: 14,
  ),
  hintStyle: const TextStyle(
    color: AppColors.inactive,
    fontSize: 14,
  ),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(
      color: AppColors.lightInputBorder,
      width: 1,
    ),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(
      color: AppColors.primary,
      width: 1.2,
    ),
  ),
);

/// InputDecorationTheme для тёмной темы
InputDecorationTheme _darkInputDecorationTheme = InputDecorationTheme(
  filled: true,
  fillColor: AppColors.darkInputFill,
  labelStyle: const TextStyle(
    color: AppColors.darkTextSecondary,
    fontSize: 14,
  ),
  hintStyle: const TextStyle(
    color: AppColors.darkTextSecondary,
    fontSize: 14,
  ),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(
      color: AppColors.darkInputBorder,
      width: 1,
    ),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(
      color: AppColors.darkPrimary,
      width: 1.2,
    ),
  ),
);

/// ElevatedButtonTheme для светлой темы
ElevatedButtonThemeData _lightElevatedButtonTheme = ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.onPrimary,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    minimumSize: const Size(double.infinity, 52),
  ),
);

/// ElevatedButtonTheme для тёмной темы
ElevatedButtonThemeData _darkElevatedButtonTheme = ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.darkPrimary,
    foregroundColor: AppColors.onPrimary,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    minimumSize: const Size(double.infinity, 52),
  ),
);

/// Светлая тема
ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.lightBackground,
  colorScheme: _lightColorScheme,
  cardTheme: _lightCardTheme,
  textTheme: _baseTextTheme(ThemeData.light().textTheme),
  elevatedButtonTheme: _lightElevatedButtonTheme,
  inputDecorationTheme: _lightInputDecorationTheme,
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.lightSurface,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.inactive,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.lightSurface,
    foregroundColor: AppColors.lightTextPrimary,
    elevation: 0,
    centerTitle: true,
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.lightInputBorder,
    thickness: 1,
  ),
);

/// Тёмная тема
ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.darkBackground,
  colorScheme: _darkColorScheme,
  cardTheme: _darkCardTheme,
  textTheme: _baseTextTheme(ThemeData.dark().textTheme),
  elevatedButtonTheme: _darkElevatedButtonTheme,
  inputDecorationTheme: _darkInputDecorationTheme,
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.darkSurface,
    selectedItemColor: AppColors.darkPrimary,
    unselectedItemColor: AppColors.darkTextSecondary,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.darkSurface,
    foregroundColor: AppColors.darkTextPrimary,
    elevation: 0,
    centerTitle: true,
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.darkInputBorder,
    thickness: 1,
  ),
);

/// Получение темы в зависимости от режима
ThemeData getAppTheme(bool isDark) {
  return isDark ? darkTheme : lightTheme;
}