import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vincue_mobile/providers/theme_mode_provider.dart';
import 'package:vincue_mobile/widgets/app_shell.dart';
import 'package:vincue_mobile/widgets/theme_toggle_button.dart';

class _Boom extends StatelessWidget {
  const _Boom();

  @override
  Widget build(BuildContext context) => throw Exception('boom');
}

Widget _wrap(SharedPreferences prefs, Widget child) => ProviderScope(
  overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  child: MaterialApp(home: AppShell(child: child)),
);

void main() {
  testWidgets(
    'a build failure in the routed child renders the fallback without taking down '
    'the header/theme-toggle',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(_wrap(prefs, const _Boom()));
      await tester.pump();

      expect(find.text('Something went wrong. Please try again later.'), findsOneWidget);

      final themeToggle = find.byType(ThemeToggleButton);
      expect(themeToggle, findsOneWidget);
      await tester.tap(themeToggle);
      await tester.pump();
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);

      expect(tester.takeException(), isNotNull);
    },
  );

  testWidgets('renders the routed child normally when it does not throw', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_wrap(prefs, const Text('SRP content')));
    await tester.pump();

    expect(find.text('SRP content'), findsOneWidget);
    expect(find.byType(ThemeToggleButton), findsOneWidget);
  });
}
