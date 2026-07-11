import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/utils/format.dart';

void main() {
  group('formatPrice', () {
    test('formats a whole-dollar price with thousands separators and no cents', () {
      expect(formatPrice(20000), r'$20,000');
    });

    test('formats a price under 1000 without a separator', () {
      expect(formatPrice(500), r'$500');
    });

    test('rounds fractional cents to the nearest whole dollar', () {
      expect(formatPrice(8994.5), r'$8,995');
    });
  });

  group('formatMileage', () {
    test('formats mileage with thousands separators and an "mi" suffix', () {
      expect(formatMileage(45231), '45,231 mi');
    });

    test('formats zero mileage', () {
      expect(formatMileage(0), '0 mi');
    });
  });
}
