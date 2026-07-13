import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/theme/app_theme.dart';

void main() {
  group('tabularNumsStyle', () {
    test('overrides an Anton-family base back to a readable font for digit '
        'sequences (prices, mileage, mpg, page counters) -- Anton\'s '
        'condensed numeral glyphs look scrunched under tabular alignment', () {
      const antonBase = TextStyle(fontFamily: 'Anton', fontSize: 20);
      final result = tabularNumsStyle(antonBase);
      expect(result.fontFamily, isNot('Anton'));
    });

    test('still applies tabular figure alignment', () {
      const base = TextStyle(fontFamily: 'Anton', fontSize: 20);
      final result = tabularNumsStyle(base);
      expect(result.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    test('preserves fontSize from the base style', () {
      const base = TextStyle(fontFamily: 'Anton', fontSize: 24);
      final result = tabularNumsStyle(base);
      expect(result.fontSize, 24);
    });
  });

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

  group('persistentLinkButtonStyle', () {
    Future<BuildContext> pumpAt(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return capturedContext;
    }

    testWidgets('is null above the compact breakpoint (600px) -- plain-link '
        'styling is left untouched at wider widths', (tester) async {
      final context = await pumpAt(tester, 600);
      expect(persistentLinkButtonStyle(context), isNull);
    });

    testWidgets('fills the background with the theme\'s primaryContainer at '
        'compact widths, so the button reads as tappable at rest instead of '
        'only flashing color on the press ripple', (tester) async {
      final context = await pumpAt(tester, 599);
      final style = persistentLinkButtonStyle(context);
      final scheme = Theme.of(context).colorScheme;
      expect(style, isNotNull);
      expect(style!.backgroundColor?.resolve({}), scheme.primaryContainer);
      expect(style.foregroundColor?.resolve({}), scheme.onPrimaryContainer);
    });

    testWidgets('a disabled button does not get the full-opacity fill -- it '
        'must still read as disabled, not indistinguishable from an enabled '
        'button next to it', (tester) async {
      final context = await pumpAt(tester, 599);
      final style = persistentLinkButtonStyle(context);
      final enabledColor = style!.backgroundColor?.resolve({});
      final disabledColor = style.backgroundColor?.resolve({WidgetState.disabled});
      expect(disabledColor, isNot(enabledColor));
    });
  });
}
