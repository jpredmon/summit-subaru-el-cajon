import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/widgets/inventory_error_view.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows the failure message and a Retry button', (tester) async {
    await tester.pumpWidget(_wrap(InventoryErrorView(onRetry: () {})));

    expect(find.text('Failed to load inventory. Please try again later.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping Retry calls onRetry', (tester) async {
    var retried = false;
    await tester.pumpWidget(_wrap(InventoryErrorView(onRetry: () => retried = true)));

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(retried, isTrue);
  });
}
