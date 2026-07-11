import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/models/carousel.dart';

void main() {
  group('nextPhotoIndex', () {
    test('advances to the next photo', () {
      expect(nextPhotoIndex(0, 5), 1);
    });

    test('clamps at the last photo instead of wrapping to the first', () {
      expect(nextPhotoIndex(4, 5), 4);
    });
  });

  group('prevPhotoIndex', () {
    test('goes back to the previous photo', () {
      expect(prevPhotoIndex(2), 1);
    });

    test('clamps at the first photo instead of wrapping to the last', () {
      expect(prevPhotoIndex(0), 0);
    });
  });
}
