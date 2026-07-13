import 'package:flutter_test/flutter_test.dart';

/// Pumps [tester] in short, fixed-duration steps until [finder] matches at
/// least one widget, instead of `pumpAndSettle()`.
///
/// `SkeletonPulse` (`lib/widgets/skeleton.dart`) repeats its pulse animation
/// forever whenever a screen starts in a loading state and the platform
/// hasn't requested reduced motion -- true by default on a real device.
/// `pumpAndSettle()` waits for *no* frames to be scheduled, which a forever-
/// repeating animation never satisfies, so it spins until its internal
/// 10-minute timeout. This bounded, condition-based poll sidesteps that
/// entirely -- confirmed the hard way (a real ~10-minute hang) when this
/// project's own integration tests first called `pumpAndSettle()` right
/// after mounting a screen that starts in a loading state.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 250),
  int maxSteps = 40,
}) async {
  for (var i = 0; i < maxSteps; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(step);
  }
  // Final attempt so the caller's own `expect` reports a clear failure
  // (`findsOneWidget` etc.) instead of this helper silently giving up.
  await tester.pump(step);
}
