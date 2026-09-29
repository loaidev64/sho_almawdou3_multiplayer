import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:fdb_helper/fdb_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data/player_name_store.dart';
import 'data/theme_store.dart';
import 'l10n/app_locale.dart';
import 'screens/chat_page.dart';
import 'screens/name_entry_page.dart';
import 'theme/app_theme.dart';

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
  Widget build(BuildContext context) => const _AppRoot();
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> with WidgetsBindingObserver {
  final PlayerNameStore _nameStore = PlayerNameStore();
  final ThemeStore _themeStore = ThemeStore();

  bool _loading = true;
  String? _name;
  AppThemeMode _themeMode = AppThemeMode.system;
  ThemeSwitcherState? _rootSwitcher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Brightness get _platformBrightness =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  Future<void> _load() async {
    final String? name = await _nameStore.load();
    final AppThemeMode themeMode = await _themeStore.load();
    if (!mounted) return;
    setState(() {
      _name = name;
      _themeMode = themeMode;
      _loading = false;
    });
  }

  void _setName(String name) {
    setState(() => _name = name);
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode != AppThemeMode.system) return;
    final ThemeSwitcherState? switcher = _rootSwitcher;
    if (switcher == null || !switcher.mounted) return;
    switcher.changeTheme(
      theme: appTheme(AppThemeMode.system, _platformBrightness),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(key: ValueKey('app_loading')),
          ),
        ),
      );
    }
    return ThemeProvider(
      initTheme: appTheme(_themeMode, _platformBrightness),
      builder: (BuildContext context, ThemeData theme) {
        return ThemeSwitcher(
          builder: (BuildContext switcherContext) {
            _rootSwitcher = ThemeSwitcher.of(switcherContext);
            return MaterialApp(
              title: AppLocale.appName,
              locale: localization.currentLocale,
              supportedLocales: localization.supportedLocales,
              localizationsDelegates: localization.localizationsDelegates,
              theme: theme.copyWith(textTheme: cairoTextTheme(theme.textTheme)),
              home: _buildHome(),
            );
          },
        );
      },
    );
  }

  Widget _buildHome() {
    final String? name = _name;
    if (name == null) {
      return NameEntryPage(onSaved: _setName);
    }
    return ChatPage(playerName: name, onNameChanged: _setName);
  }
}
