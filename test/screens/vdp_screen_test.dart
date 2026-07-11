import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vincue_mobile/models/inventory.dart';
import 'package:vincue_mobile/providers/inventory_provider.dart';
import 'package:vincue_mobile/providers/theme_mode_provider.dart';
import 'package:vincue_mobile/screens/vdp_screen.dart';

import '../support/vehicle_factory.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('loading state: shows a loading indicator', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Completer<Inventory>().future)],
          child: const VdpScreen(vehicleId: 1),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state: shows the same message as SRP', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future<Inventory>.error(Exception('boom')))],
          child: const VdpScreen(vehicleId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load inventory. Please try again later.'), findsOneWidget);
  });

  testWidgets(
    'not-found state: loaded inventory with no matching id shows a message and a link back',
    (tester) async {
      var tapped = false;
      final inventory = Inventory(vehicles: [vehicle(id: 1)], dealerName: 'Test Dealer');
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
            child: VdpScreen(vehicleId: 999, onBackToResults: () => tapped = true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vehicle not found.'), findsOneWidget);
      expect(find.text('Back to search results'), findsOneWidget);

      await tester.tap(find.text('Back to search results'));
      expect(tapped, isTrue);
    },
  );

  testWidgets('loaded state: shows header, spec table, price, mileage, and stock', (tester) async {
    final loadedVehicle = vehicle(
      id: 1,
      year: 2021,
      make: 'Honda',
      model: 'Civic',
      price: 24500,
      mileage: 12000,
    );
    final inventory = Inventory(vehicles: [loadedVehicle], dealerName: 'Test Dealer');
    await tester.pumpWidget(
      _wrap(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
          child: const VdpScreen(vehicleId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2021 Honda Civic EX-L'), findsOneWidget);
    expect(find.text('\$24,500'), findsOneWidget);
    expect(find.textContaining('12,000 mi'), findsOneWidget);
    expect(find.textContaining('Stock #S1'), findsOneWidget);
    expect(find.text('V6'), findsOneWidget); // engine
    expect(find.text('Automatic'), findsOneWidget); // transmission
    expect(find.text('FWD'), findsOneWidget); // drivetrain
    expect(find.text('25.0 / 32.0'), findsOneWidget); // mpg city/hwy
    expect(find.text('Black'), findsOneWidget); // exterior color
    expect(find.text('Gray'), findsOneWidget); // interior color
    expect(find.text('No'), findsOneWidget); // not certified
  });

  testWidgets(
    'does not show an automatic back arrow when reachable via a pushed route -- the only '
    'supported way back is the "Back to search results" button, which resets filters by '
    'design; a default AppBar back arrow would instead pop the raw route and preserve them, '
    'a second, inconsistent back path',
    (tester) async {
      final inventory = Inventory(vehicles: [vehicle(id: 1)], dealerName: 'Test Dealer');
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              inventoryProvider.overrideWith((ref) => Future.value(inventory)),
            ],
            child: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const VdpScreen(vehicleId: 1)),
                    ),
                    child: const Text('push'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsNothing);
      expect(find.text('Back to search results'), findsOneWidget);
    },
  );

  testWidgets('loaded state: also offers a working link back to the SRP', (tester) async {
    var tapped = false;
    final inventory = Inventory(vehicles: [vehicle(id: 1)], dealerName: 'Test Dealer');
    await tester.pumpWidget(
      _wrap(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
          child: VdpScreen(vehicleId: 1, onBackToResults: () => tapped = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Back to search results'), findsOneWidget);

    await tester.tap(find.text('Back to search results'));
    expect(tapped, isTrue);
  });

  testWidgets('shows "Call for price" when price is null', (tester) async {
    final inventory = Inventory(vehicles: [vehicle(id: 1, price: null)], dealerName: 'Test Dealer');
    await tester.pumpWidget(
      _wrap(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
          child: const VdpScreen(vehicleId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Call for price'), findsOneWidget);
  });

  testWidgets('shows "—" for a null mpgCity/mpgHwy instead of crashing or printing "null"', (tester) async {
    final inventory = Inventory(
      vehicles: [vehicle(id: 1, mpgCity: null, mpgHwy: null)],
      dealerName: 'Test Dealer',
    );
    await tester.pumpWidget(
      _wrap(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
          child: const VdpScreen(vehicleId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('— / —'), findsOneWidget);
  });

  testWidgets('shows a Certified badge when isCertified is true', (tester) async {
    final inventory = Inventory(vehicles: [vehicle(id: 1, isCertified: true)], dealerName: 'Test Dealer');
    await tester.pumpWidget(
      _wrap(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
          child: const VdpScreen(vehicleId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // One "Certified" for the spec-table row label, one for the badge value.
    expect(find.text('Certified'), findsNWidgets(2));
  });

  group('features boundary', () {
    testWidgets('no Features section at all when features is empty', (tester) async {
      final inventory = Inventory(vehicles: [vehicle(id: 1, features: const [])], dealerName: 'Test Dealer');
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
            child: const VdpScreen(vehicleId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Features'), findsNothing);
    });

    testWidgets('exactly 10 features: all shown, no Show all/less button', (tester) async {
      final features = List.generate(10, (i) => 'Feature $i');
      final inventory = Inventory(vehicles: [vehicle(id: 1, features: features)], dealerName: 'Test Dealer');
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
            child: const VdpScreen(vehicleId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Features'), findsOneWidget);
      for (final feature in features) {
        expect(find.textContaining(feature), findsOneWidget);
      }
      expect(find.textContaining('Show all'), findsNothing);
      expect(find.text('Show less'), findsNothing);
    });

    testWidgets(
      '12 features: first 10 shown with "Show all (12)"; tapping expands to all 12 and shows '
      '"Show less"; tapping again collapses back to 10',
      (tester) async {
        final features = List.generate(12, (i) => 'Feature $i');
        final inventory = Inventory(vehicles: [vehicle(id: 1, features: features)], dealerName: 'Test Dealer');
        await tester.pumpWidget(
          _wrap(
            ProviderScope(
              overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
              child: const VdpScreen(vehicleId: 1),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Feature 9'), findsOneWidget);
        expect(find.textContaining('Feature 10'), findsNothing);
        expect(find.textContaining('Feature 11'), findsNothing);
        expect(find.text('Show all (12)'), findsOneWidget);

        await tester.ensureVisible(find.text('Show all (12)'));
        await tester.tap(find.text('Show all (12)'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Feature 10'), findsOneWidget);
        expect(find.textContaining('Feature 11'), findsOneWidget);
        expect(find.text('Show less'), findsOneWidget);

        await tester.ensureVisible(find.text('Show less'));
        await tester.tap(find.text('Show less'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Feature 11'), findsNothing);
        expect(find.text('Show all (12)'), findsOneWidget);
      },
    );
  });

  group('two-pane layout', () {
    testWidgets('expanded width: renders the two-pane Row layout', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final inventory = Inventory(vehicles: [vehicle(id: 1)], dealerName: 'Test Dealer');
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              inventoryProvider.overrideWith((ref) => Future.value(inventory)),
            ],
            child: const VdpScreen(vehicleId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vdp-two-pane-row')), findsOneWidget);
      // Two-pane content is centered (web-parity: mx-auto), not left-aligned.
      expect(
        find.ancestor(
          of: find.byKey(const Key('vdp-two-pane-row')),
          matching: find.byType(Center),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sub-expanded (medium) width: does not render the two-pane Row layout', (tester) async {
      tester.view.physicalSize = const Size(700, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final inventory = Inventory(vehicles: [vehicle(id: 1)], dealerName: 'Test Dealer');
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              inventoryProvider.overrideWith((ref) => Future.value(inventory)),
            ],
            child: const VdpScreen(vehicleId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vdp-two-pane-row')), findsNothing);
    });
  });

  group('description', () {
    testWidgets('shown when non-empty', (tester) async {
      final inventory = Inventory(
        vehicles: [vehicle(id: 1, description: 'A very clean, one-owner vehicle.')],
        dealerName: 'Test Dealer',
      );
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
            child: const VdpScreen(vehicleId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Description'), findsOneWidget);
      expect(find.text('A very clean, one-owner vehicle.'), findsOneWidget);
    });

    testWidgets('omitted entirely when empty', (tester) async {
      final inventory = Inventory(vehicles: [vehicle(id: 1, description: '')], dealerName: 'Test Dealer');
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
            child: const VdpScreen(vehicleId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Description'), findsNothing);
    });
  });
}
