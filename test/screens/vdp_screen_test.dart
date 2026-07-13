import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vincue_mobile/models/inventory.dart';
import 'package:vincue_mobile/providers/inventory_provider.dart';
import 'package:vincue_mobile/providers/theme_mode_provider.dart';
import 'package:vincue_mobile/screens/vdp_screen.dart';
import 'package:vincue_mobile/widgets/photo_carousel.dart';
import 'package:vincue_mobile/widgets/skeleton.dart';

import '../support/vehicle_factory.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('loading state: shows a skeleton (not a spinner)', (tester) async {
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

    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.byType(SkeletonPulse), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
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
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping Retry re-fetches and shows loaded content on success', (tester) async {
    var attempt = 0;
    await tester.pumpWidget(
      _wrap(
        ProviderScope(
          // See srp_screen_test.dart's identical test for why auto-retry
          // is disabled here -- Riverpod 3.x's own backoff-retry Timer
          // would otherwise race ahead of this test's controlled
          // attempt-1-fails/attempt-2-succeeds sequencing.
          retry: (retryCount, error) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            inventoryProvider.overrideWith((ref) {
              attempt++;
              if (attempt == 1) return Future<Inventory>.error(Exception('boom'));
              return Future.value(Inventory(vehicles: [vehicle(id: 1)], dealerName: 'Test Dealer'));
            }),
          ],
          child: const VdpScreen(vehicleId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Failed to load inventory. Please try again later.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to load inventory. Please try again later.'), findsNothing);
    // Confirms the retry genuinely loaded the requested vehicle (id: 1),
    // not just any non-error state -- e.g. distinct from the not-found
    // state, which would also make the error text disappear.
    expect(find.text('Vehicle not found.'), findsNothing);
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

  group('single-pane layout at every width', () {
    // Reverses Tasks 17-19's expanded-width two-pane VDP layout (approved
    // 2026-07-11, docs/superpowers/specs/2026-07-11-responsive-layout-design.md):
    // JP reviewed the running app and found the side-by-side result read
    // worse than a wide single column -- the reference web app (docs/context
    // screenshot) never had a two-pane VDP at all, just one centered column
    // at any width. Photo/carousel must always render above the details,
    // never beside them, regardless of viewport width.
    testWidgets('expanded width: photo stays above details, no side-by-side Row', (tester) async {
      tester.view.physicalSize = const Size(1400, 800);
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

      final photoTop = tester.getTopLeft(find.byType(PhotoCarousel)).dy;
      final detailsTop = tester.getTopLeft(find.text('Engine')).dy;
      expect(photoTop, lessThan(detailsTop));
    });

    testWidgets('medium width: photo stays above details, no side-by-side Row', (tester) async {
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

  group('photo shrinks at wider viewports (single column otherwise unchanged)', () {
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
            child: const VdpScreen(vehicleId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('below 500px: photo spans the full available content width, as before', (tester) async {
      await pumpAt(tester, 450);

      final photoWidth = tester.getSize(find.byType(PhotoCarousel)).width;
      // 450px viewport minus the page's 16px-each-side padding (SPEC).
      expect(photoWidth, closeTo(450 - 32, 1));
    });

    testWidgets('at and above 500px: photo is capped to a smaller fixed width', (tester) async {
      await pumpAt(tester, 500);

      final photoWidth = tester.getSize(find.byType(PhotoCarousel)).width;
      expect(photoWidth, closeTo(400, 1));
    });

    testWidgets('at the largest widths: photo stays capped, does not grow back to full width', (tester) async {
      await pumpAt(tester, 1400);

      final photoWidth = tester.getSize(find.byType(PhotoCarousel)).width;
      expect(photoWidth, closeTo(400, 1));
    });

    testWidgets(
      'the details column keeps its own full (up to 800px) content width, unaffected by the photo cap',
      (tester) async {
        await pumpAt(tester, 1400);

        final contentWidth = tester.getSize(find.byKey(const Key('vdp-content'))).width;
        final photoWidth = tester.getSize(find.byType(PhotoCarousel)).width;
        expect(contentWidth, closeTo(800, 1));
        expect(photoWidth, lessThan(contentWidth));
      },
    );

    testWidgets('at and above 500px: the photo is horizontally centered within the content column', (
      tester,
    ) async {
      await pumpAt(tester, 1400);

      final contentRect = tester.getRect(find.byKey(const Key('vdp-content')));
      final photoRect = tester.getRect(find.byType(PhotoCarousel));
      final leftGap = photoRect.left - contentRect.left;
      final rightGap = contentRect.right - photoRect.right;
      expect(leftGap, closeTo(rightGap, 1));
    });

    testWidgets(
      'at and above 500px: the title/price/mileage block is horizontally centered within the content column',
      (tester) async {
        await pumpAt(tester, 1400);

        final contentRect = tester.getRect(find.byKey(const Key('vdp-content')));
        final titleRect = tester.getRect(find.text('2020 Honda Accord EX-L'));
        final titleCenter = titleRect.left + titleRect.width / 2;
        expect(titleCenter, closeTo(contentRect.left + contentRect.width / 2, 1));
      },
    );

    testWidgets('at and above 500px: the spec table stays left-aligned, not centered', (tester) async {
      await pumpAt(tester, 1400);

      final contentRect = tester.getRect(find.byKey(const Key('vdp-content')));
      final specTableRect = tester.getRect(find.byType(Wrap).first);
      expect(specTableRect.left, closeTo(contentRect.left, 1));
    });

    testWidgets('below 500px: the title stays left-aligned, unaffected by the wider-width centering', (
      tester,
    ) async {
      await pumpAt(tester, 450);

      final contentRect = tester.getRect(find.byKey(const Key('vdp-content')));
      final titleRect = tester.getRect(find.text('2020 Honda Accord EX-L'));
      expect(titleRect.left, closeTo(contentRect.left, 1));
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
