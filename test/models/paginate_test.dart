import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/models/paginate.dart';

void main() {
  group('paginate', () {
    test('slices the first page correctly', () {
      final items = List<int>.generate(25, (i) => i);
      final result = paginate(items, 1, 12);
      expect(result.items, List<int>.generate(12, (i) => i));
    });

    test('reports totalPages based on item count and page size', () {
      final items = List<int>.generate(25, (i) => i);
      final result = paginate(items, 1, 12);
      expect(result.totalPages, 3);
    });

    test('slices the last, partial page correctly', () {
      final items = List<int>.generate(25, (i) => i);
      final result = paginate(items, 3, 12);
      expect(result.items, [24]);
    });

    test('handles an exact multiple of page size with no trailing empty page', () {
      final items = List<int>.generate(24, (i) => i);
      expect(paginate(items, 1, 12).totalPages, 2);
    });

    test('clamps a page number beyond the last page to the last page', () {
      final items = List<int>.generate(25, (i) => i);
      final result = paginate(items, 99, 12);
      expect(result.currentPage, 3);
      expect(result.items, [24]);
    });

    test('clamps a zero or negative page number to page 1', () {
      final items = List<int>.generate(25, (i) => i);
      expect(paginate(items, 0, 12).currentPage, 1);
      expect(paginate(items, -5, 12).currentPage, 1);
    });

    test('returns totalPages of 1 (not 0) for an empty list', () {
      final result = paginate<int>(const [], 1, 12);
      expect(result.items, isEmpty);
      expect(result.totalPages, 1);
      expect(result.currentPage, 1);
    });
  });
}
