import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sho_almawdou3_multiplayer/main.dart';

Future<void> _pumpFrames(WidgetTester tester, {int frames = 8}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

ThemeData _appTheme(WidgetTester tester) {
  return tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'player_name': 'سارة',
    });
    await configureLocalization();
  });

  testWidgets('applies the stored dark theme on launch', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'player_name': 'سارة',
      'theme_mode': 'dark',
    });
    await tester.pumpWidget(const MyApp());
    await _pumpFrames(tester);

    expect(_appTheme(tester).brightness, Brightness.dark);
  });

  testWidgets('falls back to the light system theme when nothing is stored', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await _pumpFrames(tester);

    expect(_appTheme(tester).brightness, Brightness.light);
  });

  testWidgets('switches the theme from the settings page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await _pumpFrames(tester);
    expect(_appTheme(tester).brightness, Brightness.light);

    await tester.tap(find.byKey(const ValueKey('settings_button')));
    await _pumpFrames(tester);

    expect(find.byKey(const ValueKey('theme_section_title')), findsOneWidget);
    expect(find.byKey(const ValueKey('theme_mode_light')), findsOneWidget);
    expect(find.byKey(const ValueKey('theme_mode_dark')), findsOneWidget);
    expect(find.byKey(const ValueKey('theme_mode_system')), findsOneWidget);
    expect(find.text('تلقائي'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('theme_mode_dark')));
    await _pumpFrames(tester);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
    expect(_appTheme(tester).brightness, Brightness.dark);
  });
}
