import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vincue_mobile/models/inventory.dart';
import 'package:vincue_mobile/providers/inventory_provider.dart';
import 'package:vincue_mobile/providers/theme_mode_provider.dart';
import 'package:vincue_mobile/theme/breakpoints.dart';
import 'package:vincue_mobile/widgets/app_shell.dart';

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
    'the header',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(_wrap(prefs, const _Boom()));
      await tester.pump();

      expect(find.text('Something went wrong. Please try again later.'), findsOneWidget);
      // The header logo (this app's persistent chrome, now that dark mode's
      // ThemeToggleButton no longer lives here -- see docs/superpowers/specs,
      // dark-mode-disabled note) survives the child's build failure.
      expect(find.byType(Image), findsOneWidget);

      expect(tester.takeException(), isNotNull);
    },
  );

  testWidgets('renders the routed child normally when it does not throw', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_wrap(prefs, const Text('SRP content')));
    await tester.pump();

    expect(find.text('SRP content'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  // NOTE (Task 22): the two tests formerly here -- "shows the live dealer
  // name in the AppBar title" and "caps the dealer name title to one line
  // with an ellipsis" -- asserted a Text(dealerName) AppBar title that Task
  // 22 deliberately replaced with a fixed logo image (see
  // docs/superpowers/specs/2026-07-12-header-logo-design.md). That title
  // Text widget no longer exists, so those assertions no longer have
  // anything to test; the live-dealerName behavior they cared about now
  // lives on as the Semantics label assertion in the test below.

  testWidgets('shows the dealer logo image with the live dealer name as its '
      'accessibility label', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          inventoryProvider.overrideWith(
            (ref) => Future.value(
              const Inventory(vehicles: [], dealerName: 'Summit Subaru El Cajon'),
            ),
          ),
        ],
        child: MaterialApp(home: AppShell(child: const Text('SRP content'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.bySemanticsLabel('Summit Subaru El Cajon'), findsOneWidget);
  });

  group('logoSizingFor', () {
    test('compact width', () {
      final sizing = logoSizingFor(WindowSizeClass.compact);
      expect(sizing.logoHeight, 68);
      expect(sizing.toolbarHeight, 104);
    });

    test('medium width', () {
      final sizing = logoSizingFor(WindowSizeClass.medium);
      expect(sizing.logoHeight, 80);
      expect(sizing.toolbarHeight, 116);
    });

    test('expanded width', () {
      final sizing = logoSizingFor(WindowSizeClass.expanded);
      expect(sizing.logoHeight, 92);
      expect(sizing.toolbarHeight, 128);
    });
  });

  testWidgets('AppBar title is horizontally centered', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_wrap(prefs, const Text('SRP content')));
    await tester.pump();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.centerTitle, isTrue);
  });

  testWidgets('grows the logo/toolbar height at expanded width', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(prefs, const Text('SRP content')));
    await tester.pump();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.toolbarHeight, 128);
  });

  testWidgets('logo still shows below the compact breakpoint (600px) -- kHideLogoAtCompact reverted', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          inventoryProvider.overrideWith(
            (ref) => Future.value(
              const Inventory(vehicles: [], dealerName: 'Test Dealer'),
            ),
          ),
        ],
        child: MaterialApp(home: AppShell(child: const Text('SRP content'))),
      ),
    );
    await tester.pumpAndSettle();

    // Task 35 added kHideLogoAtCompact to hide the logo below 600px; JP
    // decided to keep it visible at every width after seeing it hidden, so
    // this now confirms the logo still renders here rather than the
    // opposite. The mechanism (single boolean flag in app_shell.dart) is
    // unchanged -- flipping it back to `true` restores the hide behavior.
    expect(find.byType(Image), findsOneWidget);
    expect(find.bySemanticsLabel('Test Dealer'), findsOneWidget);
  });

  testWidgets('logo is still shown at 600px and above', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          inventoryProvider.overrideWith(
            (ref) => Future.value(
              const Inventory(vehicles: [], dealerName: 'Test Dealer'),
            ),
          ),
        ],
        child: MaterialApp(home: AppShell(child: const Text('SRP content'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });
}
