import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reel_text/reel_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sho_almawdou3_multiplayer/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await configureLocalization();
  });

  testWidgets('renders the Arabic home screen with host and join actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byKey(const ValueKey('status_text')), findsOneWidget);
    expect(find.byKey(const ValueKey('host_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('join_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('manual_input')), findsOneWidget);
    expect(find.byKey(const ValueKey('message_input')), findsOneWidget);
    expect(find.byKey(const ValueKey('send_button')), findsOneWidget);
    expect(find.text('استضافة'), findsOneWidget);
    expect(find.text('انضام'), findsOneWidget);

    final ReelText status = tester.widget<ReelText>(
      find.byKey(const ValueKey('status_text')),
    );
    expect(status.text, 'جاهز — استضف أو انضم للبدء');
  });
}
