import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vincue_mobile/main.dart';
import 'package:vincue_mobile/models/inventory.dart';
import 'package:vincue_mobile/providers/inventory_provider.dart';
import 'package:vincue_mobile/screens/srp_screen.dart';

void main() {
  testWidgets('App renders the SRP screen at the root route without crashing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryProvider.overrideWith(
            (ref) => Future.value(const Inventory(vehicles: [], dealerName: 'Test Dealer')),
          ),
        ],
        child: const VincueMobileApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SrpScreen), findsOneWidget);
  });
}
