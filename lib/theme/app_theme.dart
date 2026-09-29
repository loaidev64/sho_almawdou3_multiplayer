import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, system }

ThemeData appTheme(AppThemeMode mode, Brightness platformBrightness) {
  final Brightness brightness = switch (mode) {
    AppThemeMode.light => Brightness.light,
    AppThemeMode.dark => Brightness.dark,
    AppThemeMode.system => platformBrightness,
  };
  return ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: brightness,
    ),
  );
}
