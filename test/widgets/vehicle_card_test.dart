import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/models/body_category.dart';
import 'package:vincue_mobile/theme/app_theme.dart';
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

  testWidgets(
    'shows a themed focus-highlight border matching the card corner radius when focused, '
    'and none when not',
    (tester) async {
      // onShowFocusHighlight only reports true in FocusHighlightMode.traditional
      // (keyboard-style nav) -- force it rather than relying on the test
      // harness's default input-history heuristic (which defaults to touch).
      final previousStrategy = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = previousStrategy);

      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _wrap(VehicleCard(vehicle: vehicle(), onTap: () {}, focusNode: focusNode)),
      );

      BoxDecoration decorationOf() => tester
          .widget<Container>(find.byKey(const ValueKey('vehicle-card-focus-ring-1')))
          .decoration! as BoxDecoration;

      expect(decorationOf().borderRadius, BorderRadius.circular(kCardRadius));
      expect((decorationOf().border as Border).top.color, Colors.transparent);

      focusNode.requestFocus();
      await tester.pump();

      final theme = Theme.of(tester.element(find.byType(VehicleCard)));
      expect((decorationOf().border as Border).top.color, theme.colorScheme.primary);
    },
  );

  testWidgets(
    'invokes onTap on Enter while focused -- taking focus away from InkWell (so there is '
    'only one tab stop per card) also takes its default keyboard-activation with it, so '
    'this has to be re-wired explicitly',
    (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      var tapped = false;
      await tester.pumpWidget(
        _wrap(VehicleCard(vehicle: vehicle(), onTap: () => tapped = true, focusNode: focusNode)),
      );

      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(tapped, isTrue);
    },
  );

  testWidgets(
    'also invokes onTap on ButtonActivateIntent while focused -- Flutter Web maps Enter to '
    'ButtonActivateIntent specifically (WidgetsApp._defaultWebShortcuts), not ActivateIntent, '
    "so both intents need a handler or the card is unreachable by Enter on the web build "
    '(flutter test always runs with kIsWeb == false, so sendKeyEvent(enter) alone -- the '
    'previous test -- cannot exercise the web shortcut mapping; invoking the intent directly '
    'is the only way to test the actions map itself)',
    (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      var tapped = false;
      await tester.pumpWidget(
        _wrap(VehicleCard(vehicle: vehicle(), onTap: () => tapped = true, focusNode: focusNode)),
      );

      focusNode.requestFocus();
      await tester.pump();
      // maybeInvoke's return value can't distinguish "handled, callback
      // returned null" from "no handler found" -- both the ActivateIntent and
      // ButtonActivateIntent callbacks above intentionally return null, same
      // as CallbackAction's onInvoke convention elsewhere in this file. tapped
      // is the only reliable signal that a handler actually ran.
      Actions.maybeInvoke<ButtonActivateIntent>(focusNode.context!, const ButtonActivateIntent());
      await tester.pump();

      expect(tapped, isTrue);
    },
  );

  testWidgets(
    'Tab order across a row of cards lands on each card exactly once, in order -- proof '
    "that canRequestFocus: false genuinely removes InkWell's own focus node from traversal "
    'rather than leaving a second, invisible tab stop behind',
    (tester) async {
      final nodes = List.generate(3, (_) => FocusNode());
      for (final node in nodes) {
        addTearDown(node.dispose);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    SizedBox(
                      width: 200,
                      child: VehicleCard(vehicle: vehicle(id: i), onTap: () {}, focusNode: nodes[i]),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      nodes[0].requestFocus();
      await tester.pump();
      expect(nodes[0].hasFocus, isTrue);

      primaryFocus!.nextFocus();
      await tester.pump();
      expect(nodes[1].hasFocus, isTrue);
      expect(nodes[0].hasFocus, isFalse);

      primaryFocus!.nextFocus();
      await tester.pump();
      expect(nodes[2].hasFocus, isTrue);
      expect(nodes[1].hasFocus, isFalse);
    },
  );

  testWidgets('suppresses the tap-ripple animation when disableAnimations is set', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _wrap(VehicleCard(vehicle: vehicle(), onTap: () {})),
      ),
    );

    expect(tester.widget<InkWell>(find.byType(InkWell)).splashFactory, NoSplash.splashFactory);
  });

  testWidgets('uses the normal ripple animation when disableAnimations is not set', (tester) async {
    await tester.pumpWidget(_wrap(VehicleCard(vehicle: vehicle(), onTap: () {})));

    expect(tester.widget<InkWell>(find.byType(InkWell)).splashFactory, isNot(NoSplash.splashFactory));
  });
}
