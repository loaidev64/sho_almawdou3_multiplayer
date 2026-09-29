import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class ThemeStore {
  static const String key = 'theme_mode';

  Future<AppThemeMode> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(key);
    for (final AppThemeMode mode in AppThemeMode.values) {
      if (mode.name == stored) return mode;
    }
    return AppThemeMode.system;
  }

  Future<void> save(AppThemeMode mode) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, mode.name);
  }
}
