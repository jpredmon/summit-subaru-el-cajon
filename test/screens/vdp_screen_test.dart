import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/screens/vdp_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('displays the vehicle id from the route', (tester) async {
    await tester.pumpWidget(_wrap(const VdpScreen(vehicleId: 42)));

    expect(find.textContaining('42'), findsOneWidget);
  });

  testWidgets('offers a way back to the SRP', (tester) async {
    await tester.pumpWidget(_wrap(const VdpScreen(vehicleId: 1)));

    expect(find.text('Back to inventory'), findsOneWidget);
  });
}
