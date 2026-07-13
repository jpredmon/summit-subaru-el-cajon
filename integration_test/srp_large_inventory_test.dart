import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vincue_mobile/models/body_category.dart';
import 'package:vincue_mobile/models/inventory.dart';
import 'package:vincue_mobile/providers/inventory_provider.dart';
import 'package:vincue_mobile/providers/theme_mode_provider.dart';
import 'package:vincue_mobile/screens/srp_screen.dart';
import 'package:vincue_mobile/widgets/vehicle_card.dart';

import '../test/support/vehicle_factory.dart';
import 'support/pump_until.dart';

/// Real-device/browser E2E coverage (Task 39) -- unlike `flutter_test`'s
/// simulated widget-tree environment, `integration_test` runs the compiled
/// app for real: real network/image-decode timing, real device scroll
/// physics and layout. Added specifically to close the gap that let Task
/// 38's SliverMasonryGrid crash through -- three targeted `flutter_test`
/// repro attempts during that debugging session could not reproduce it,
/// because every existing widget-test fixture tops out at 13 vehicles with
/// empty `photos` lists, nowhere near the production shape (142+ vehicles,
/// a scrolled grid, real photos) that actually triggered it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'SRP against a large, heterogeneous inventory survives scroll + filter + clear on a real '
    'device/browser -- the closest automated equivalent of the Task 38 report (make=Dodge + '
    'minPrice=\$10k on a real Android device)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Interleaved makes/bodies (like real dealer inventory, unlike this
      // project's other fixtures' same-make-prefix lists) so a filter's
      // matches land at scattered indices in the unfiltered list -- the
      // shape that exposed the real bug. Non-empty `photos` with real
      // reachable URLs so `cached_network_image`'s async network/decode
      // timing is genuinely exercised, not skipped.
      final makes = ['Honda', 'Toyota', 'Ford', 'Subaru', 'Nissan', 'Mazda', 'Kia', 'Jeep', 'Dodge', 'Chevrolet'];
      final bodies = BodyCategory.values;
      final inventory = Inventory(
        vehicles: List.generate(150, (i) {
          return vehicle(
            id: i,
            make: makes[i % makes.length],
            bodyStyle: bodies[i % bodies.length],
            price: 8000.0 + (i * 500),
            photos: ['https://picsum.photos/seed/vincue-integration-$i/400/300'],
          );
        }),
        dealerName: 'Integration Test Dealer',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              inventoryProvider.overrideWith((ref) => Future.value(inventory)),
            ],
            child: const Scaffold(body: SrpScreen()),
          ),
        ),
      );
      // Not pumpAndSettle() -- the screen starts in a loading state
      // (SkeletonPulse), whose animation repeats forever on a real device
      // and never lets pumpAndSettle() observe "no more frames scheduled".
      await pumpUntilFound(tester, find.byType(VehicleCard));
      expect(tester.takeException(), isNull);

      // Scroll the grid down partway -- matches the real report's
      // "scrolled results" condition, and is where Task 38's investigation
      // suspected (but couldn't confirm synthetically) the crash's
      // insertAndLayoutLeadingChild code path was involved.
      await tester.fling(find.byType(Scrollable).first, const Offset(0, -600), 2000);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);

      // Real device widths are compact -- the filter dropdowns start
      // collapsed behind "Apply filters".
      final applyToggle = find.byKey(const Key('apply-filters-toggle'));
      if (applyToggle.evaluate().isNotEmpty) {
        await tester.tap(applyToggle);
        await tester.pumpAndSettle();
      }

      // Apply make + min price, matching the exact real report
      // (make=Dodge + minPrice=$10k) -- real UI taps, not direct provider
      // manipulation, so this also exercises real gesture/dropdown-menu
      // rendering, not just state.
      await tester.tap(find.byKey(const Key('make-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dodge').last);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('min-price-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('\$10,000').last);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);

      // Clear back to the full 150-vehicle set -- the original Task 38
      // trigger, now reached through the make dropdown itself (the
      // filter-bar's standalone Clear-filters button was reverted). The
      // dropdown's "no filter" option reads "Makes" at compact width
      // (Task 42) or "All makes" wider -- check both so this test isn't
      // tied to one device width.
      await tester.tap(find.byKey(const Key('make-filter')));
      await tester.pumpAndSettle();
      final clearMakeOption = find.text('Makes').evaluate().isNotEmpty ? find.text('Makes') : find.text('All makes');
      await tester.tap(clearMakeOption.last);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );
}
