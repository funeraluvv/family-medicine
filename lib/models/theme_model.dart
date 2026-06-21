
import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, system }

class ThemeModel {
  final AppThemeMode mode;
  final bool isDark;

  ThemeModel({
    required this.mode,
    required this.isDark,
  });

  factory ThemeModel.initial() {
    return ThemeModel(
      mode: AppThemeMode.light,
      isDark: false,
    );
  }

  ThemeModel copyWith({
    AppThemeMode? mode,
    bool? isDark,
  }) {
    return ThemeModel(
      mode: mode ?? this.mode,
      isDark: isDark ?? this.isDark,
    );
  }
}