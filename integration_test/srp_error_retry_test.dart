import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vincue_mobile/models/inventory.dart';
import 'package:vincue_mobile/providers/inventory_provider.dart';
import 'package:vincue_mobile/providers/theme_mode_provider.dart';
import 'package:vincue_mobile/screens/srp_screen.dart';

import '../test/support/vehicle_factory.dart';
import 'support/pump_until.dart';

/// Real-device E2E coverage (Task 39 follow-up) for the fetch-failure ->
/// Retry -> loaded flow. Same real-device rationale as
/// srp_large_inventory_test.dart -- covers a second, independent flow
/// rather than expanding the first test's scope.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'SRP shows the error message on fetch failure, then tapping Retry loads real content, on a '
    'real device',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      var attempt = 0;
      final inventory = Inventory(vehicles: [vehicle(id: 1)], dealerName: 'Integration Test Dealer');

      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            // Same reasoning as the widget-test equivalent
            // (test/screens/srp_screen_test.dart): Riverpod 3.x's own
            // backoff-retry Timer would otherwise race ahead of this
            // test's controlled attempt-1-fails/attempt-2-succeeds
            // sequencing.
            retry: (retryCount, error) => null,
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              inventoryProvider.overrideWith((ref) {
                attempt++;
                if (attempt == 1) return Future<Inventory>.error(Exception('boom'));
                return Future.value(inventory);
              }),
            ],
            child: const Scaffold(body: SrpScreen()),
          ),
        ),
      );
      // Not pumpAndSettle() -- the screen starts in a loading state
      // (SkeletonPulse), whose animation repeats forever on a real device
      // and never lets pumpAndSettle() observe "no more frames scheduled".
      await pumpUntilFound(tester, find.text('Failed to load inventory. Please try again later.'));
      expect(tester.takeException(), isNull);
      expect(find.text('Failed to load inventory. Please try again later.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      // Same reasoning -- tapping Retry re-enters a loading state before
      // the second (successful) fetch resolves.
      await pumpUntilFound(tester, find.text('1 vehicle'));
      expect(tester.takeException(), isNull);

      expect(find.text('Failed to load inventory. Please try again later.'), findsNothing);
      expect(find.text('1 vehicle'), findsOneWidget);
    },
  );
}
