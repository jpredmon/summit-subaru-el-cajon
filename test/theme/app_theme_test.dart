import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/theme/app_theme.dart';

void main() {
  group('header/title font (matches the Summit Subaru logo lettering)', () {
    test('light theme: headline/title roles use Anton', () {
      final textTheme = AppTheme.light().textTheme;
      expect(textTheme.headlineSmall!.fontFamily, 'Anton');
      expect(textTheme.titleLarge!.fontFamily, 'Anton');
      expect(textTheme.titleMedium!.fontFamily, 'Anton');
    });

    test('light theme: body/label roles are left on the default font', () {
      final textTheme = AppTheme.light().textTheme;
      expect(textTheme.bodyMedium!.fontFamily, isNot('Anton'));
      expect(textTheme.bodySmall!.fontFamily, isNot('Anton'));
      expect(textTheme.bodyLarge!.fontFamily, isNot('Anton'));
    });

    test('dark theme: headline/title roles use Anton too (kept consistent '
        'even though dark mode is currently force-disabled)', () {
      final textTheme = AppTheme.dark().textTheme;
      expect(textTheme.headlineSmall!.fontFamily, 'Anton');
      expect(textTheme.titleLarge!.fontFamily, 'Anton');
      expect(textTheme.titleMedium!.fontFamily, 'Anton');
    });
  });
}
