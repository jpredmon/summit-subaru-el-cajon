import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vincue_mobile/models/body_category.dart';
import 'package:vincue_mobile/models/filter_vehicles.dart';
import 'package:vincue_mobile/models/inventory.dart';
import 'package:vincue_mobile/providers/inventory_provider.dart';
import 'package:vincue_mobile/providers/srp_state_provider.dart';
import 'package:vincue_mobile/providers/theme_mode_provider.dart';
import 'package:vincue_mobile/screens/srp_screen.dart';
import 'package:vincue_mobile/widgets/skeleton.dart';
import 'package:vincue_mobile/widgets/vehicle_card.dart';

import '../support/vehicle_factory.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('shows a skeleton loading state (not a spinner) while inventory is loading', (tester) async {
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

    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.byType(SkeletonPulse), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skeleton loading grid matches the real grid cross-axis extent', (tester) async {
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

    final gridView = tester.widget<MasonryGridView>(find.byType(MasonryGridView));
    final delegate = gridView.gridDelegate as SliverSimpleGridDelegateWithMaxCrossAxisExtent;
    expect(delegate.maxCrossAxisExtent, 280);
  });

  testWidgets('grid cards size to their own content height at narrow column widths -- a '
      'masonry layout (not a fixed-height GridView cell) so a card whose mileage/body-style '
      'line wraps to two lines doesn\'t overflow, and a card that fits on one line doesn\'t '
      'leave a gap underneath a taller neighbor', (tester) async {
    // 360-wide viewport -> ~156px-wide columns after the 16px grid padding
    // and cross-axis spacing -- narrow enough that "45,231 mi · Sedan"
    // (the default vehicle_factory fixture) wraps to two lines, which is
    // exactly the width range that overflowed a fixed-height GridView cell.
    tester.view.physicalSize = const Size(360, 800);
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

    expect(find.byType(VehicleCard), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The exception check above only proves the card didn't overflow --
    // it doesn't prove the originally-reported bug (a gap between the
    // price and the bottom of the card) is actually gone. Prove that
    // directly: the grid gives this single-column layout a ~156px-wide
    // cell (360 viewport - 32 padding = 328, one column since
    // ceil(328/296)=... two columns of (328-16)/2=156 each). Compare the
    // card's rendered height inside the real masonry grid against the
    // same card's own natural (unconstrained-height) size at that exact
    // width -- if the grid were still forcing a taller fixed cell, these
    // would differ; under masonry they must be identical.
    final renderedHeight = tester.getSize(find.byType(VehicleCard)).height;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SizedBox(width: 156, child: VehicleCard(vehicle: vehicle(id: 1), onTap: () {}))),
      ),
    );
    final naturalHeight = tester.getSize(find.byType(VehicleCard)).height;

    expect(renderedHeight, closeTo(naturalHeight, 0.5));
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
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping Retry re-fetches and shows loaded content on success', (tester) async {
    var attempt = 0;
    await tester.pumpWidget(
      _wrap(
        ProviderScope(
          // Riverpod 3.x auto-retries a failed provider with a backoff
          // Timer by default -- while a retry is pending, the provider's
          // AsyncValue is AsyncLoading(retrying: true), not AsyncError, so
          // .when() routes to loading:, not error:, until retries are
          // exhausted. That races against (and defeats) this test's own
          // controlled attempt-1-fails/attempt-2-succeeds sequencing, so
          // auto-retry is disabled here to isolate the manual Retry
          // button's behavior specifically.
          retry: (retryCount, error) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) {
              attempt++;
              if (attempt == 1) return Future<Inventory>.error(Exception('boom'));
              return Future.value(Inventory(vehicles: [vehicle(id: 1)], dealerName: 'Test Dealer'));
            }),
          ],
          child: const SrpScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Failed to load inventory. Please try again later.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to load inventory. Please try again later.'), findsNothing);
    expect(find.text('1 vehicles'), findsOneWidget);
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

      // The filter bar's own Clear filters control is suppressed while
      // results are empty -- the empty-results panel's control is the only
      // one on screen, so there's no duplicate/ambiguous control.
      expect(find.text('Clear filters'), findsOneWidget);
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

  testWidgets(
    'a filter change that drops a vehicle from view does not carry its VehicleCard state over '
    'to a different vehicle now occupying the same grid slot -- VehicleCard is Stateful '
    '(focus-highlight state, Task 14c) and MasonryGridView.custom reconciles by list position '
    'unless each item carries a stable identity key',
    (tester) async {
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
              inventoryProvider.overrideWith((ref) => Future.value(inventory)),
            ],
            child: const SrpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Finder cardFor(int id) => find.byWidgetPredicate((w) => w is VehicleCard && w.vehicle.id == id);
      final hondaElementBefore = tester.element(cardFor(1));
      final toyotaElementBefore = tester.element(cardFor(2));

      await tester.tap(find.byKey(const Key('make-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toyota').last);
      await tester.pumpAndSettle();

      expect(find.byType(VehicleCard), findsOneWidget);
      final toyotaElementAfter = tester.element(find.byType(VehicleCard));

      expect(
        identical(toyotaElementAfter, toyotaElementBefore),
        isTrue,
        reason: "Toyota's own card should keep its identity/state across the filter change",
      );
      expect(
        identical(toyotaElementAfter, hondaElementBefore),
        isFalse,
        reason: 'Toyota\'s card at the now-first grid slot must not be Honda\'s old Element/State '
            'reused by position -- that would carry Honda\'s focus-highlight state onto Toyota',
      );
    },
  );

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

      // MasonryGridView.custom only builds items within its viewport, so a raw
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

  testWidgets(
    'pagination controls stay horizontally centered on the page when they fit on one line '
    '-- a Wrap (unlike the Row it replaced) shrink-wraps to its content width instead of '
    'filling its parent, so WrapAlignment.center alone only centers within that narrow '
    "shrink-wrapped box, not within the page's actual content width",
    (tester) async {
      // 800px viewport (this file's default test surface) -- wide enough
      // that Previous/"Page N of M"/Next fit on a single Wrap run, so this
      // exercises the common case (not the narrow-width wrapping case the
      // G3 test above covers).
      final thirteen = Inventory(
        vehicles: List.generate(13, (i) => vehicle(id: i, make: 'Make$i')),
        dealerName: 'Test Dealer',
      );
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              inventoryProvider.overrideWith((ref) => Future.value(thirteen)),
            ],
            child: const SrpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final paginationControls = find.ancestor(
        of: find.widgetWithText(TextButton, 'Previous'),
        matching: find.byType(Wrap),
      );
      final rect = tester.getRect(paginationControls);

      // Page content spans the full 800px test surface minus 16px of
      // Padding on each side (lib/screens/srp_screen.dart's outer
      // Padding(all: 16)), so its horizontal center is at x=400.
      expect(rect.center.dx, closeTo(400, 0.5));
    },
  );

  testWidgets(
    'filter dropdowns do not overflow at narrow viewport widths -- DropdownButton reserves '
    "width for its widest item across ALL options (e.g. \"All body styles\"), not just the "
    'currently selected value, so even a short selection can overflow once the dropdown is '
    'alone on its own Wrap line at a narrow width',
    (tester) async {
      // 220px -- confirmed reproducible (measured directly: overflows by
      // 78px at this width on the un-fixed widget) without needing
      // pagination controls in view at all, keeping this test focused on
      // the dropdowns alone.
      tester.view.physicalSize = const Size(220, 800);
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

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'filter dropdowns stay compact (do not each claim the full row width) at a wide viewport '
    '-- isExpanded lets a DropdownButton shrink to fit a narrow Wrap line, but without an '
    'upper bound it also greedily fills a wide one, stacking all four vertically instead of '
    'sitting side by side the way they did before the narrow-width fix',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
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

      // Measured naturally (unbounded) with realistic longer data: make
      // ~234px, body style ~266px, price dropdowns ~169px each -- 300px is
      // comfortably above all four, so this asserts "did not expand to
      // fill the whole 1168px content width" without being so tight it'd
      // fail on legitimate content.
      for (final key in ['make-filter', 'body-filter', 'min-price-filter', 'max-price-filter']) {
        final width = tester.getRect(find.byKey(Key(key))).width;
        expect(width, lessThanOrEqualTo(300),
            reason: '$key claimed $width px -- expected a bounded width, not the full row');
      }
    },
  );

  testWidgets(
    'pagination controls do not overflow at narrow viewport widths (G3) -- Previous/Next '
    'buttons plus the page-count text have a combined natural width (measured ~400px) that '
    'exceeds what many phone viewports leave available after the 16px page padding',
    (tester) async {
      // 320px -- confirmed the pre-fix Row overflowed by 118px here; narrow
      // enough to reproduce G3 without also triggering a separate
      // DropdownButton overflow below ~300px, fixed in Task 30 (see the
      // "filter dropdowns do not overflow" test below).
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final thirteen = Inventory(
        vehicles: List.generate(13, (i) => vehicle(id: i, make: 'Make$i')),
        dealerName: 'Test Dealer',
      );
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              inventoryProvider.overrideWith((ref) => Future.value(thirteen)),
            ],
            child: const SrpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Page 1 of 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

  group('dropdown width tracks selected content (Task 33)', () {
    testWidgets('a short make selection renders narrower than a long one', (tester) async {
      final shortInventory = Inventory(vehicles: [vehicle(id: 1, make: 'Kia')], dealerName: 'Test Dealer');
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              inventoryProvider.overrideWith((ref) => Future.value(shortInventory)),
            ],
            child: const SrpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      var context = tester.element(find.byType(SrpScreen));
      ProviderScope.containerOf(context).read(srpStateProvider.notifier).restoreFrom(
            const SrpFilterState(filters: VehicleFilters(make: 'Kia')),
          );
      await tester.pumpAndSettle();
      final shortWidth = tester.getSize(find.byKey(const Key('make-filter'))).width;

      final longInventory = Inventory(vehicles: [vehicle(id: 1, make: 'Volkswagen')], dealerName: 'Test Dealer');
      await tester.pumpWidget(
        _wrap(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              inventoryProvider.overrideWith((ref) => Future.value(longInventory)),
            ],
            child: const SrpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      context = tester.element(find.byType(SrpScreen));
      ProviderScope.containerOf(context).read(srpStateProvider.notifier).restoreFrom(
            const SrpFilterState(filters: VehicleFilters(make: 'Volkswagen')),
          );
      await tester.pumpAndSettle();
      final longWidth = tester.getSize(find.byKey(const Key('make-filter'))).width;

      expect(shortWidth, lessThan(longWidth));
    });

    testWidgets('an unusually long make is clamped to the max width, not left to overflow', (tester) async {
      const pathologicalMake = 'A Pathologically Long Make Name That Should Never Really Occur';
      final inventory = Inventory(vehicles: [vehicle(id: 1, make: pathologicalMake)], dealerName: 'Test Dealer');
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
      final context = tester.element(find.byType(SrpScreen));
      ProviderScope.containerOf(context).read(srpStateProvider.notifier).restoreFrom(
            const SrpFilterState(filters: VehicleFilters(make: pathologicalMake)),
          );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const Key('make-filter'))).width, lessThanOrEqualTo(234));
    });
  });

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

  group('filter bar tiers (Task 34)', () {
    Future<void> pumpAt(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 900);
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
    }

    testWidgets('expanded (1400px): all 4 dropdowns share one row, no Apply-filters button', (tester) async {
      await pumpAt(tester, 1400);
      expect(find.byKey(const Key('apply-filters-toggle')), findsNothing);
      final makeTop = tester.getTopLeft(find.byKey(const Key('make-filter'))).dy;
      final bodyTop = tester.getTopLeft(find.byKey(const Key('body-filter'))).dy;
      final maxPriceTop = tester.getTopLeft(find.byKey(const Key('max-price-filter'))).dy;
      expect(makeTop, equals(bodyTop));
      expect(makeTop, equals(maxPriceTop));
    });

    testWidgets(
      'medium (700px): dropdowns reflow organically -- as many as fit share a row, the rest wrap',
      (tester) async {
        await pumpAt(tester, 700);
        expect(find.byKey(const Key('apply-filters-toggle')), findsNothing);
        final makeTop = tester.getTopLeft(find.byKey(const Key('make-filter'))).dy;
        final bodyTop = tester.getTopLeft(find.byKey(const Key('body-filter'))).dy;
        final minPriceTop = tester.getTopLeft(find.byKey(const Key('min-price-filter'))).dy;
        final maxPriceTop = tester.getTopLeft(find.byKey(const Key('max-price-filter'))).dy;
        // With the default (unselected) fixture data at 700px, make+body+min
        // price together (631.5px) fit within the ~668px available content
        // width, but adding max price (812.5px total) doesn't -- so max price
        // wraps to its own row while the other three share the first. This is
        // Wrap's organic packing, not a hardcoded "2 and 2" split: the exact
        // grouping depends on each dropdown's actual current content width,
        // not a fixed count per tier.
        expect(makeTop, equals(bodyTop));
        expect(minPriceTop, equals(makeTop));
        expect(maxPriceTop, greaterThan(makeTop));
      },
    );

    testWidgets('compact (360px): dropdowns start hidden behind an Apply-filters button', (tester) async {
      await pumpAt(tester, 360);
      expect(find.byKey(const Key('apply-filters-toggle')), findsOneWidget);
      expect(find.text('Apply filters'), findsOneWidget);
      expect(find.byKey(const Key('make-filter')), findsNothing);
    });

    testWidgets('compact (360px): tapping Apply filters reveals all 4 stacked, live-filters, and folds back away', (tester) async {
      await pumpAt(tester, 360);

      await tester.tap(find.byKey(const Key('apply-filters-toggle')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('make-filter')), findsOneWidget);
      expect(find.byKey(const Key('body-filter')), findsOneWidget);
      final makeTop = tester.getTopLeft(find.byKey(const Key('make-filter'))).dy;
      final bodyTop = tester.getTopLeft(find.byKey(const Key('body-filter'))).dy;
      expect(bodyTop, greaterThan(makeTop));

      // Live filtering unchanged: selecting a make while the panel is open
      // updates the grid immediately, no separate commit step.
      await tester.tap(find.byKey(const Key('make-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Honda').last);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(SrpScreen));
      expect(
        ProviderScope.containerOf(context).read(srpStateProvider).filters.make,
        'Honda',
      );

      await tester.tap(find.byKey(const Key('apply-filters-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('make-filter')), findsNothing);
    });
  });

  group('Clear filters control in the empty-results panel', () {
    Future<BuildContext> pumpEmptyResultsAt(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // Same zero-overlap pairing as the top-level empty-results test: Honda
      // is a sedan, Toyota is an SUV, so make=Honda AND body=SUV matches
      // nothing.
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
              inventoryProvider.overrideWith((ref) => Future.value(inventory)),
            ],
            child: const SrpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.element(find.byType(SrpScreen));
    }

    testWidgets('compact (360px) collapsed: shown when filtered results are empty', (tester) async {
      final context = await pumpEmptyResultsAt(tester, 360);

      ProviderScope.containerOf(context).read(srpStateProvider.notifier)
        ..setMake('Honda')
        ..setBody(BodyCategory.suv);
      await tester.pumpAndSettle();

      expect(find.textContaining('No vehicles match these filters'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
    });

    testWidgets('compact (360px) open: shown when filtered results are empty', (tester) async {
      final context = await pumpEmptyResultsAt(tester, 360);

      await tester.tap(find.byKey(const Key('apply-filters-toggle')));
      await tester.pumpAndSettle();

      ProviderScope.containerOf(context).read(srpStateProvider.notifier)
        ..setMake('Honda')
        ..setBody(BodyCategory.suv);
      await tester.pumpAndSettle();

      expect(find.text('Hide filters'), findsOneWidget);
      expect(find.textContaining('No vehicles match these filters'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
    });
  });
}
