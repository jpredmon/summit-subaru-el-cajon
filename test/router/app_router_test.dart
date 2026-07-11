import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/models/body_category.dart';
import 'package:vincue_mobile/models/inventory.dart';
import 'package:vincue_mobile/providers/inventory_provider.dart';
import 'package:vincue_mobile/providers/srp_state_provider.dart';
import 'package:vincue_mobile/router/app_router.dart';
import 'package:vincue_mobile/screens/srp_screen.dart';
import 'package:vincue_mobile/screens/vdp_screen.dart';
import 'package:vincue_mobile/widgets/vehicle_card.dart';

import '../support/vehicle_factory.dart';

void main() {
  testWidgets('renders SrpScreen at the root path', (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryProvider.overrideWith(
            (ref) => Future.value(const Inventory(vehicles: [], dealerName: 'Test Dealer')),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SrpScreen), findsOneWidget);
  });

  testWidgets('renders VdpScreen with the parsed vehicle id at /vehicle/:id', (tester) async {
    final router = buildAppRouter(initialLocation: '/vehicle/42');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryProvider.overrideWith(
            (ref) => Future.value(const Inventory(vehicles: [], dealerName: 'Test Dealer')),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(VdpScreen), findsOneWidget);
    expect(find.textContaining('42'), findsOneWidget);
  });

  testWidgets('restores srpStateProvider from the initial URL query parameters', (tester) async {
    // The filter dropdowns only offer values actually present in the loaded
    // inventory, so the restored make/body must exist on at least one
    // vehicle here or DropdownButton's "exactly one matching item" invariant
    // fails.
    final router = buildAppRouter(initialLocation: '/?make=Honda&body=SUV&page=2');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryProvider.overrideWith(
            (ref) => Future.value(
              Inventory(
                vehicles: [vehicle(id: 1, make: 'Honda', bodyStyle: BodyCategory.suv)],
                dealerName: 'Test Dealer',
              ),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SrpScreen));
    final state = ProviderScope.containerOf(context).read(srpStateProvider);

    expect(state.filters.make, 'Honda');
    expect(state.filters.body, BodyCategory.suv);
    expect(state.page, 2);
  });

  testWidgets('updates the URL when srpStateProvider changes', (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryProvider.overrideWith(
            (ref) => Future.value(
              Inventory(vehicles: [vehicle(id: 1, make: 'Toyota')], dealerName: 'Test Dealer'),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SrpScreen));
    ProviderScope.containerOf(context).read(srpStateProvider.notifier).setMake('Toyota');
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.queryParameters['make'], 'Toyota');
  });

  testWidgets(
    'a later in-app navigation to a different query string restores that state too '
    '(the same code path a real back/forward-button press exercises)',
    (tester) async {
      final router = buildAppRouter();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryProvider.overrideWith(
              (ref) => Future.value(
                Inventory(
                  vehicles: [vehicle(id: 1, make: 'Honda'), vehicle(id: 2, make: 'Toyota')],
                  dealerName: 'Test Dealer',
                ),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SrpScreen));
      final container = ProviderScope.containerOf(context);
      expect(container.read(srpStateProvider).filters.make, isNull);

      // Simulates a browser forward navigation (e.g. a shared link, or a
      // forward-button press) landing on the same route with new query
      // parameters -- this is the didUpdateWidget path, not initState.
      router.go('/?make=Honda&page=2');
      await tester.pumpAndSettle();
      expect(container.read(srpStateProvider).filters.make, 'Honda');
      expect(container.read(srpStateProvider).page, 2);

      // Simulates a back-button press returning to the plain route.
      router.go('/');
      await tester.pumpAndSettle();
      expect(container.read(srpStateProvider).filters.make, isNull);
      expect(container.read(srpStateProvider).page, 1);
    },
  );

  testWidgets(
    'a deep-linked filter is applied by the very first frame, with no visible flash of '
    'the unfiltered list',
    (tester) async {
      final router = buildAppRouter(initialLocation: '/?make=Honda');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryProvider.overrideWith(
              (ref) => Future.value(
                Inventory(
                  vehicles: [vehicle(id: 1, make: 'Honda'), vehicle(id: 2, make: 'Toyota')],
                  dealerName: 'Test Dealer',
                ),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      // A single pump (not pumpAndSettle) renders exactly one frame -- if the
      // deferred restore leaked an unfiltered frame to the screen, it would
      // show here.
      await tester.pump();

      expect(find.text('1 vehicles'), findsOneWidget);
      expect(find.text('2 vehicles'), findsNothing);
    },
  );

  testWidgets('tapping a card navigates to /vehicle/:id', (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryProvider.overrideWith(
            (ref) => Future.value(Inventory(vehicles: [vehicle(id: 7)], dealerName: 'Test Dealer')),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(VehicleCard));
    await tester.pumpAndSettle();

    expect(find.byType(VdpScreen), findsOneWidget);
    expect(find.textContaining('7'), findsOneWidget);
  });
}
