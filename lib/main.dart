import 'package:fdb_helper/fdb_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:google_fonts/google_fonts.dart';

import 'l10n/app_locale.dart';
import 'screens/chat_page.dart';

final FlutterLocalization localization = FlutterLocalization.instance;

Future<void> main() async {
  if (!kReleaseMode) {
    FdbBinding.ensureInitialized();
  }
  await configureLocalization();
  runApp(const MyApp());
}

Future<void> configureLocalization() async {
  WidgetsFlutterBinding.ensureInitialized();
  await localization.ensureInitialized();
  localization.init(
    initLanguageCode: 'ar',
    source: LocalizationSource.map,
    mapLocales: const [MapLocale('ar', AppLocale.ar)],
  );
}

TextTheme cairoTextTheme(TextTheme base) {
  TextStyle cairo(TextStyle? style) => GoogleFonts.cairo(textStyle: style);
  return TextTheme(
    displayLarge: cairo(base.displayLarge),
    displayMedium: cairo(base.displayMedium),
    displaySmall: cairo(base.displaySmall),
    headlineLarge: cairo(base.headlineLarge),
    headlineMedium: cairo(base.headlineMedium),
    headlineSmall: cairo(base.headlineSmall),
    titleLarge: cairo(base.titleLarge),
    titleMedium: cairo(base.titleMedium),
    titleSmall: cairo(base.titleSmall),
    bodyLarge: cairo(base.bodyLarge),
    bodyMedium: cairo(base.bodyMedium),
    bodySmall: cairo(base.bodySmall),
    labelLarge: cairo(base.labelLarge),
    labelMedium: cairo(base.labelMedium),
    labelSmall: cairo(base.labelSmall),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
    );
    return MaterialApp(
      title: AppLocale.appName,
      locale: localization.currentLocale,
      supportedLocales: localization.supportedLocales,
      localizationsDelegates: localization.localizationsDelegates,
      theme: base.copyWith(textTheme: cairoTextTheme(base.textTheme)),
      home: const ChatPage(),
    );
  }
}
