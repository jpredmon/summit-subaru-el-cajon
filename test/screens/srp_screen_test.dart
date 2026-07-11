import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vincue_mobile/models/body_category.dart';
import 'package:vincue_mobile/models/filter_vehicles.dart';
import 'package:vincue_mobile/models/inventory.dart';
import 'package:vincue_mobile/providers/inventory_provider.dart';
import 'package:vincue_mobile/providers/srp_state_provider.dart';
import 'package:vincue_mobile/providers/theme_mode_provider.dart';
import 'package:vincue_mobile/screens/srp_screen.dart';
import 'package:vincue_mobile/widgets/vehicle_card.dart';

import '../support/vehicle_factory.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('shows a loading indicator while inventory is loading', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Completer<Inventory>().future)],
          child: const SrpScreen(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows an error message when inventory fails to load', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future<Inventory>.error(Exception('boom')))],
          child: const SrpScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load inventory. Please try again later.'), findsOneWidget);
  });

  testWidgets('shows the vehicle count and a card per vehicle once loaded', (tester) async {
    final inventory = Inventory(
      vehicles: [
        vehicle(id: 1, make: 'Honda'),
        vehicle(id: 2, make: 'Toyota', price: null),
      ],
      dealerName: 'Test Dealer',
    );
    await tester.pumpWidget(
      _wrap(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
          child: const SrpScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 vehicles'), findsOneWidget);
    expect(find.byType(VehicleCard), findsNWidgets(2));
    expect(find.text('Call for price'), findsOneWidget);
  });

  testWidgets(
    'shows "No vehicles match these filters" with a Clear filters control when filtered '
    'results are empty, and tapping it restores all vehicles',
    (tester) async {
      // Honda is a sedan, Toyota is an SUV — selecting make=Honda AND
      // body=SUV is an AND across dimensions that no single vehicle
      // satisfies, giving genuinely zero results (every make/body value
      // offered by the dropdowns exists on at least one vehicle, so a
      // single-dimension selection alone can never reach zero).
      final inventory = Inventory(
        vehicles: [
          vehicle(id: 1, make: 'Honda', bodyStyle: BodyCategory.sedan),
          vehicle(id: 2, make: 'Toyota', bodyStyle: BodyCategory.suv),
        ],
        dealerName: 'Test Dealer',
      );
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
            child: const SrpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('make-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Honda').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('body-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SUV').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('No vehicles match these filters'), findsOneWidget);
      expect(find.byType(VehicleCard), findsNothing);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(find.byType(VehicleCard), findsNWidgets(2));
    },
  );

  testWidgets('selecting a make in the filter dropdown narrows the visible cards', (tester) async {
    final inventory = Inventory(
      vehicles: [
        vehicle(id: 1, make: 'Honda'),
        vehicle(id: 2, make: 'Toyota'),
      ],
      dealerName: 'Test Dealer',
    );
    await tester.pumpWidget(
      _wrap(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
          child: const SrpScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VehicleCard), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('make-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Honda').last);
    await tester.pumpAndSettle();

    expect(find.text('1 vehicles'), findsOneWidget);
    expect(find.byType(VehicleCard), findsOneWidget);
  });

  testWidgets('hides pagination controls when everything fits on one page (12 vehicles)', (tester) async {
    final twelve = Inventory(
      vehicles: List.generate(12, (i) => vehicle(id: i, make: 'Make$i')),
      dealerName: 'Test Dealer',
    );
    await tester.pumpWidget(
      _wrap(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(twelve))],
          child: const SrpScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Page'), findsNothing);
  });

  testWidgets(
    'shows pagination controls beyond 12 vehicles, with Next/Previous navigating pages '
    'and disabling at the boundaries',
    (tester) async {
      final thirteen = Inventory(
        vehicles: List.generate(13, (i) => vehicle(id: i, make: 'Make$i')),
        dealerName: 'Test Dealer',
      );
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(thirteen))],
            child: const SrpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // GridView.builder only builds items within its viewport, so a raw
      // VehicleCard count would depend on the test surface's size rather
      // than paging logic. Check vehicle identity instead: item 12
      // ("Make12", the 13th vehicle) is only reachable on page 2, and
      // item 0 ("Make0") only exists in page 1's slice.
      expect(find.text('Page 1 of 2'), findsOneWidget);
      expect(find.textContaining('Make0 '), findsOneWidget);
      expect(find.textContaining('Make12 '), findsNothing);

      final previousButton = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Previous'));
      expect(previousButton.onPressed, isNull);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Page 2 of 2'), findsOneWidget);
      expect(find.byType(VehicleCard), findsOneWidget);
      expect(find.textContaining('Make12 '), findsOneWidget);
      expect(find.textContaining('Make0 '), findsNothing);
      final nextButton = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Next'));
      expect(nextButton.onPressed, isNull);
    },
  );

  testWidgets('tapping a card invokes onVehicleTap with that vehicle', (tester) async {
    final tapped = <int>[];
    final inventory = Inventory(vehicles: [vehicle(id: 7)], dealerName: 'Test Dealer');
    await tester.pumpWidget(
      _wrap(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
          child: SrpScreen(onVehicleTap: (v) => tapped.add(v.id)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(VehicleCard));

    expect(tapped, [7]);
  });

  group('regression: filter state restored from a URL that no longer matches reality', () {
    // A deep link, bookmark, or shared URL can carry a make/body/price that
    // isn't actually offered by the currently loaded inventory (stale link,
    // different dealer, inventory turnover). DropdownButton requires its
    // `value` to match exactly one item or throw -- restoring such state
    // must not crash the screen.
    Future<BuildContext> pumpWithInventory(WidgetTester tester, Inventory inventory) async {
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
            child: const SrpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.element(find.byType(SrpScreen));
    }

    testWidgets('a restored make absent from the loaded inventory does not crash', (tester) async {
      final inventory = Inventory(vehicles: [vehicle(id: 1, make: 'Honda')], dealerName: 'Test Dealer');
      final context = await pumpWithInventory(tester, inventory);

      ProviderScope.containerOf(context).read(srpStateProvider.notifier).restoreFrom(
            const SrpFilterState(filters: VehicleFilters(make: 'Tesla')),
          );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final dropdown = tester.widget<DropdownButton<String?>>(find.byKey(const Key('make-filter')));
      expect(dropdown.value, isNull);
    });

    testWidgets('a restored body style absent from the loaded inventory does not crash', (tester) async {
      final inventory = Inventory(
        vehicles: [vehicle(id: 1, bodyStyle: BodyCategory.sedan)],
        dealerName: 'Test Dealer',
      );
      final context = await pumpWithInventory(tester, inventory);

      ProviderScope.containerOf(context).read(srpStateProvider.notifier).restoreFrom(
            const SrpFilterState(filters: VehicleFilters(body: BodyCategory.truck)),
          );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final dropdown = tester.widget<DropdownButton<BodyCategory?>>(find.byKey(const Key('body-filter')));
      expect(dropdown.value, isNull);
    });

    testWidgets('a restored minPrice not in the fixed threshold list does not crash', (tester) async {
      final inventory = Inventory(vehicles: [vehicle(id: 1, price: 20000)], dealerName: 'Test Dealer');
      final context = await pumpWithInventory(tester, inventory);

      ProviderScope.containerOf(context).read(srpStateProvider.notifier).restoreFrom(
            const SrpFilterState(filters: VehicleFilters(minPrice: 22000)),
          );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final dropdown = tester.widget<DropdownButton<double?>>(find.byKey(const Key('min-price-filter')));
      expect(dropdown.value, isNull);
    });

    testWidgets('a restored inverted minPrice/maxPrice range does not crash', (tester) async {
      final inventory = Inventory(vehicles: [vehicle(id: 1, price: 20000)], dealerName: 'Test Dealer');
      final context = await pumpWithInventory(tester, inventory);

      ProviderScope.containerOf(context).read(srpStateProvider.notifier).restoreFrom(
            const SrpFilterState(filters: VehicleFilters(minPrice: 50000, maxPrice: 20000)),
          );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final minDropdown = tester.widget<DropdownButton<double?>>(find.byKey(const Key('min-price-filter')));
      final maxDropdown = tester.widget<DropdownButton<double?>>(find.byKey(const Key('max-price-filter')));
      expect(minDropdown.value, isNull);
      expect(maxDropdown.value, isNull);
    });

    testWidgets('a restored non-finite minPrice (Infinity) does not crash', (tester) async {
      final inventory = Inventory(vehicles: [vehicle(id: 1, price: 20000)], dealerName: 'Test Dealer');
      final context = await pumpWithInventory(tester, inventory);

      ProviderScope.containerOf(context).read(srpStateProvider.notifier).restoreFrom(
            SrpFilterState(filters: VehicleFilters(minPrice: double.infinity)),
          );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final dropdown = tester.widget<DropdownButton<double?>>(find.byKey(const Key('min-price-filter')));
      expect(dropdown.value, isNull);
    });

    testWidgets(
      'a restored page number beyond the real total is self-corrected, so the URL/state '
      "doesn't keep claiming an out-of-range page until the user clicks Previous/Next",
      (tester) async {
        // 13 vehicles / 12 per page = 2 real total pages.
        final inventory = Inventory(
          vehicles: List.generate(13, (i) => vehicle(id: i)),
          dealerName: 'Test Dealer',
        );
        final context = await pumpWithInventory(tester, inventory);

        ProviderScope.containerOf(context).read(srpStateProvider.notifier).restoreFrom(
              const SrpFilterState(page: 50),
            );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(ProviderScope.containerOf(context).read(srpStateProvider).page, 2);
        expect(find.text('Page 2 of 2'), findsOneWidget);
      },
    );
  });

  testWidgets(
    'filter options are not recomputed on a page-only state change (only the loaded '
    'inventory should invalidate them, not srpStateProvider)',
    (tester) async {
      final inventory = Inventory(
        vehicles: List.generate(13, (i) => vehicle(id: i)),
        dealerName: 'Test Dealer',
      );
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) => Future.value(inventory))],
            child: const SrpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SrpScreen));
      final container = ProviderScope.containerOf(context);
      final before = container.read(filterOptionsProvider);

      container.read(srpStateProvider.notifier).setPage(2);
      await tester.pumpAndSettle();

      final after = container.read(filterOptionsProvider);
      expect(identical(before, after), isTrue);
    },
  );

  group('width cap at expanded viewport', () {
    testWidgets('expanded width: wraps content in a 1200-max-width ConstrainedBox', (tester) async {
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
            child: const SrpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('srp-width-cap')), findsOneWidget);
      final constrainedBox = tester.widget<ConstrainedBox>(find.byKey(const Key('srp-width-cap')));
      expect(constrainedBox.constraints.maxWidth, 1200);
      // Capped content is centered (web-parity: mx-auto), not left-aligned.
      expect(
        find.ancestor(
          of: find.byKey(const Key('srp-width-cap')),
          matching: find.byType(Center),
        ),
        findsOneWidget,
      );
    });

    testWidgets('medium width: does not wrap content in the width-cap ConstrainedBox', (tester) async {
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
            child: const SrpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('srp-width-cap')), findsNothing);
    });
  });
}
