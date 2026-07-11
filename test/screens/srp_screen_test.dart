import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/models/body_category.dart';
import 'package:vincue_mobile/models/inventory.dart';
import 'package:vincue_mobile/providers/inventory_provider.dart';
import 'package:vincue_mobile/screens/srp_screen.dart';
import 'package:vincue_mobile/widgets/vehicle_card.dart';

import '../support/vehicle_factory.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows a loading indicator while inventory is loading', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ProviderScope(
          overrides: [inventoryProvider.overrideWith((ref) => Completer<Inventory>().future)],
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
          overrides: [inventoryProvider.overrideWith((ref) => Future<Inventory>.error(Exception('boom')))],
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
          overrides: [inventoryProvider.overrideWith((ref) => Future.value(inventory))],
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
            overrides: [inventoryProvider.overrideWith((ref) => Future.value(inventory))],
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
          overrides: [inventoryProvider.overrideWith((ref) => Future.value(inventory))],
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
          overrides: [inventoryProvider.overrideWith((ref) => Future.value(twelve))],
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
            overrides: [inventoryProvider.overrideWith((ref) => Future.value(thirteen))],
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
          overrides: [inventoryProvider.overrideWith((ref) => Future.value(inventory))],
          child: SrpScreen(onVehicleTap: (v) => tapped.add(v.id)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(VehicleCard));

    expect(tapped, [7]);
  });
}
