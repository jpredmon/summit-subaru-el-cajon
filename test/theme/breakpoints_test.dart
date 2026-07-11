import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/theme/breakpoints.dart';

void main() {
  group('windowSizeClassOf', () {
    test('returns compact for width 599', () {
      expect(
        windowSizeClassOf(599),
        equals(WindowSizeClass.compact),
      );
    });

    test('returns medium for width 600', () {
      expect(
        windowSizeClassOf(600),
        equals(WindowSizeClass.medium),
      );
    });

    test('returns medium for width 839', () {
      expect(
        windowSizeClassOf(839),
        equals(WindowSizeClass.medium),
      );
    });

    test('returns expanded for width 840', () {
      expect(
        windowSizeClassOf(840),
        equals(WindowSizeClass.expanded),
      );
    });
  });
}
