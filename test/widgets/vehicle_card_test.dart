import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/models/body_category.dart';
import 'package:vincue_mobile/widgets/vehicle_card.dart';
import 'package:vincue_mobile/widgets/vehicle_photo.dart';

import '../support/vehicle_factory.dart';

// Constrained to a realistic grid-cell width — VehicleCard is always used
// inside a GridView cell, never at full screen width.
Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 220, child: child)),
    );

void main() {
  testWidgets('displays year, make, model, and trim', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VehicleCard(
          vehicle: vehicle(year: 2022, make: 'Toyota', model: 'Camry', trim: 'SE'),
          onTap: () {},
        ),
      ),
    );

    expect(find.text('2022 Toyota Camry SE'), findsOneWidget);
  });

  testWidgets('displays formatted mileage', (tester) async {
    await tester.pumpWidget(
      _wrap(VehicleCard(vehicle: vehicle(mileage: 45231), onTap: () {})),
    );

    expect(find.textContaining('45,231 mi'), findsOneWidget);
  });

  testWidgets('displays the body style', (tester) async {
    await tester.pumpWidget(
      _wrap(VehicleCard(vehicle: vehicle(bodyStyle: BodyCategory.suv), onTap: () {})),
    );

    expect(find.textContaining('SUV'), findsOneWidget);
  });

  testWidgets('displays a formatted price when price is set', (tester) async {
    await tester.pumpWidget(
      _wrap(VehicleCard(vehicle: vehicle(price: 20000), onTap: () {})),
    );

    expect(find.text(r'$20,000'), findsOneWidget);
  });

  testWidgets('displays "Call for price" when price is null', (tester) async {
    await tester.pumpWidget(
      _wrap(VehicleCard(vehicle: vehicle(price: null), onTap: () {})),
    );

    expect(find.text('Call for price'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('passes the first photo through to VehiclePhoto', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VehicleCard(
          vehicle: vehicle(photos: const ['https://example.com/car.jpg', 'https://example.com/2.jpg']),
          onTap: () {},
        ),
      ),
    );

    expect(tester.widget<VehiclePhoto>(find.byType(VehiclePhoto)).photoUrl, 'https://example.com/car.jpg');
  });

  testWidgets('passes a null photoUrl through to VehiclePhoto when photos is empty', (tester) async {
    await tester.pumpWidget(
      _wrap(VehicleCard(vehicle: vehicle(photos: const []), onTap: () {})),
    );

    expect(tester.widget<VehiclePhoto>(find.byType(VehiclePhoto)).photoUrl, isNull);
  });

  testWidgets(
    'a long make/model/trim does not overflow the grid tile (fixed height, matching '
    "srp_screen.dart's actual GridView tile dimensions)",
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 280,
              height: 340,
              child: VehicleCard(
                vehicle: vehicle(
                  make: 'Extended Super Duty Long-Bed',
                  model: 'High Roof Extended Cargo Van',
                  trim: 'Limited Ultimate Reserve 4WD Crew Cab',
                ),
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invokes onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(VehicleCard(vehicle: vehicle(), onTap: () => tapped = true)),
    );

    await tester.tap(find.byType(VehicleCard));

    expect(tapped, isTrue);
  });
}
