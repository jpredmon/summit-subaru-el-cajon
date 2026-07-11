import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vincue_mobile/providers/theme_mode_provider.dart';
import 'package:vincue_mobile/widgets/theme_toggle_button.dart';

Widget _wrap(SharedPreferences prefs) => ProviderScope(
  overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  child: const MaterialApp(home: Scaffold(body: ThemeToggleButton())),
);

void main() {
  testWidgets(
    'shows a light-mode icon and switches to light on tap when starting dark',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(_wrap(prefs));

      expect(find.byIcon(Icons.light_mode), findsOneWidget);

      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pump();

      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
      expect(prefs.getString('themeMode'), 'light');
    },
  );
}
