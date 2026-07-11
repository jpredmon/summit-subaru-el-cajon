import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vincue_mobile/main.dart';
import 'package:vincue_mobile/models/inventory.dart';
import 'package:vincue_mobile/providers/inventory_provider.dart';
import 'package:vincue_mobile/providers/theme_mode_provider.dart';
import 'package:vincue_mobile/screens/srp_screen.dart';
import 'package:vincue_mobile/screens/vdp_screen.dart';
import 'package:vincue_mobile/widgets/vehicle_card.dart';

import 'support/vehicle_factory.dart';

void main() {
  testWidgets('App renders the SRP screen at the root route without crashing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryProvider.overrideWith(
            (ref) => Future.value(const Inventory(vehicles: [], dealerName: 'Test Dealer')),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const VincueMobileApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SrpScreen), findsOneWidget);
  });

  testWidgets(
    'toggling the theme while on the VDP does not reset navigation back to the SRP '
    '(regression: VincueMobileApp.build must not rebuild the GoRouter on an unrelated '
    'provider change)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryProvider.overrideWith(
              (ref) => Future.value(Inventory(vehicles: [vehicle(id: 1)], dealerName: 'Test Dealer')),
            ),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const VincueMobileApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(VehicleCard));
      await tester.pumpAndSettle();
      expect(find.byType(VdpScreen), findsOneWidget);

      final container = ProviderScope.containerOf(tester.element(find.byType(VdpScreen)));
      container.read(themeModeProvider.notifier).toggle();
      await tester.pumpAndSettle();

      expect(find.byType(VdpScreen), findsOneWidget);
      expect(find.byType(SrpScreen), findsNothing);
    },
  );
}
