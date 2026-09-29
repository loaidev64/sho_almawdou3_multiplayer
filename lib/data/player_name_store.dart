import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_locale.dart';

const int maxPlayerNameLength = 24;

String? validatePlayerName(String raw) {
  final String value = raw.trim();
  if (value.isEmpty) return AppLocale.nameRequired;
  if (value.length > maxPlayerNameLength) return AppLocale.nameTooLong;
  return null;
}

class PlayerNameStore {
  static const String key = 'player_name';

  Future<String?> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String value = (prefs.getString(key) ?? '').trim();
    return value.isEmpty ? null : value;
  }

  Future<void> save(String name) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, name.trim());
  }
}
