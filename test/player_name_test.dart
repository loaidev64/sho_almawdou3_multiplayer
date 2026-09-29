import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sho_almawdou3_multiplayer/data/player_name_store.dart';
import 'package:sho_almawdou3_multiplayer/l10n/app_locale.dart';
import 'package:sho_almawdou3_multiplayer/main.dart';

Future<void> _pumpFrames(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await configureLocalization();
  });

  group('validatePlayerName', () {
    test('rejects blank names', () {
      expect(validatePlayerName(''), AppLocale.nameRequired);
      expect(validatePlayerName('   '), AppLocale.nameRequired);
    });

    test('trims and accepts a normal name', () {
      expect(validatePlayerName('  سارة  '), isNull);
    });

    test('rejects names above the length limit', () {
      expect(
        validatePlayerName('ع' * (maxPlayerNameLength + 1)),
        AppLocale.nameTooLong,
      );
      expect(validatePlayerName('ع' * maxPlayerNameLength), isNull);
    });
  });

  testWidgets('asks for a name on first launch and stores it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await _pumpFrames(tester);

    expect(find.byKey(const ValueKey('name_entry_title')), findsOneWidget);
    expect(find.byKey(const ValueKey('name_input')), findsOneWidget);
    expect(find.byKey(const ValueKey('name_continue_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('host_button')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('name_input')), '   ');
    await tester.tap(find.byKey(const ValueKey('name_continue_button')));
    await _pumpFrames(tester);

    expect(find.text('لا يمكن أن يكون الاسم فارغًا'), findsOneWidget);
    expect(find.byKey(const ValueKey('host_button')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('name_input')),
      '  سارة  ',
    );
    await tester.tap(find.byKey(const ValueKey('name_continue_button')));
    await _pumpFrames(tester);

    expect(find.byKey(const ValueKey('host_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings_button')), findsOneWidget);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('player_name'), 'سارة');
  });

  testWidgets('opens settings from home and saves a renamed player', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'player_name': 'أحمد',
    });
    await tester.pumpWidget(const MyApp());
    await _pumpFrames(tester);

    expect(find.byKey(const ValueKey('host_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings_button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings_button')));
    await _pumpFrames(tester);

    expect(find.byKey(const ValueKey('name_save_button')), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('name_input')), ' علي ');
    await tester.tap(find.byKey(const ValueKey('name_save_button')));
    await _pumpFrames(tester);

    expect(find.byKey(const ValueKey('settings_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('name_save_button')), findsNothing);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('player_name'), 'علي');
  });
}
