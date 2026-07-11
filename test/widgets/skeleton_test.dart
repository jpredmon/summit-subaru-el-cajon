import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/widgets/skeleton.dart';

void main() {
  testWidgets(
    'does not repeat the pulse animation when disableAnimations is set '
    '(a repeating animation would make pumpAndSettle time out)',
    (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(body: SkeletonPulse(child: SkeletonBox(width: 100, height: 20))),
          ),
        ),
      );

      await tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
    },
  );

  testWidgets('keeps repeating the pulse animation when disableAnimations is not set', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SkeletonPulse(child: SkeletonBox(width: 100, height: 20))),
      ),
    );

    await expectLater(
      () => tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      ),
      throwsA(isA<FlutterError>()),
    );
  });
}
