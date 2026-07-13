import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/widgets/photo_carousel.dart';
import 'package:vincue_mobile/widgets/vehicle_photo.dart';

/// Always resolves to invalid image bytes, so `Image`'s decoder rejects it
/// and `errorBuilder` fires — same deterministic-failure technique as
/// vehicle_photo_test.dart (Task 8).
ImageProvider _alwaysFailingImageProvider(String url) {
  return MemoryImage(Uint8List.fromList([1, 2, 3]));
}

ImageProvider _workingImageProvider(String url) {
  return MemoryImage(Uint8List.fromList(_onePixelPng));
}

/// Pumps [child] at a real simulated viewport [width] -- not just a local
/// `SizedBox` constraint. PhotoCarousel's compact-width ghost-chevron/swipe
/// behavior (Task 40) reads `MediaQuery.sizeOf(context).width` (the ambient
/// screen size, matching this app's `windowSizeClassOf` convention used
/// everywhere else, e.g. `_FilterBar`), not just its own layout box, so the
/// test viewport itself must shrink for compact-width tests to actually
/// exercise that path. Defaults to a realistic non-compact VDP content
/// width (>= 600, WindowSizeClass.medium) -- PhotoCarousel is never used at
/// full screen width.
Future<void> _pump(WidgetTester tester, Widget child, {double width = 700}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SizedBox(width: width, child: child))),
  );
}

final _nextButton = find.byKey(const Key('carousel-next-button'));
final _previousButton = find.byKey(const Key('carousel-previous-button'));
final _ghostNext = find.byKey(const Key('carousel-ghost-next'));
final _ghostPrevious = find.byKey(const Key('carousel-ghost-previous'));
const _swipeArea = Key('carousel-swipe-area');

void main() {
  testWidgets('renders a placeholder when photos is empty', (tester) async {
    await _pump(tester, const PhotoCarousel(photos: []));

    expect(find.bySemanticsLabel('No photo available'), findsOneWidget);
    expect(find.byType(VehiclePhoto), findsOneWidget);
  });

  testWidgets('renders the first photo when photos are present', (tester) async {
    await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg']));

    expect(tester.widget<VehiclePhoto>(find.byType(VehiclePhoto)).photoUrl, 'a.jpg');
  });

  testWidgets('shows a "1 of 3" counter when multiple photos are present', (tester) async {
    await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg']));

    expect(find.text('1 of 3'), findsOneWidget);
  });

  testWidgets('advances to the next photo when Next is tapped', (tester) async {
    await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg']));

    await tester.tap(_nextButton);
    await tester.pump();

    expect(tester.widget<VehiclePhoto>(find.byType(VehiclePhoto)).photoUrl, 'b.jpg');
    expect(find.text('2 of 3'), findsOneWidget);
  });

  testWidgets('goes back to the previous photo when Previous is tapped', (tester) async {
    await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg']));
    await tester.tap(_nextButton);
    await tester.pump();

    await tester.tap(_previousButton);
    await tester.pump();

    expect(tester.widget<VehiclePhoto>(find.byType(VehiclePhoto)).photoUrl, 'a.jpg');
    expect(find.text('1 of 3'), findsOneWidget);
  });

  testWidgets('disables the Next button on the last photo', (tester) async {
    await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg']));

    await tester.tap(_nextButton);
    await tester.pump();

    expect(tester.widget<IconButton>(_nextButton).onPressed, isNull);
  });

  testWidgets('disables the Previous button on the first photo', (tester) async {
    await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg']));

    expect(tester.widget<IconButton>(_previousButton).onPressed, isNull);
  });

  testWidgets('does not render Next/Previous buttons when there is only one photo', (tester) async {
    await _pump(tester, const PhotoCarousel(photos: ['a.jpg']));

    expect(_nextButton, findsNothing);
    expect(_previousButton, findsNothing);
    expect(find.textContaining(' of '), findsNothing);
  });

  testWidgets('falls back to the placeholder when the current photo fails to load', (tester) async {
    await _pump(
      tester,
      PhotoCarousel(photos: const ['a.jpg', 'b.jpg'], imageProvider: _alwaysFailingImageProvider),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('No photo available'), findsOneWidget);
  });

  testWidgets('recovers when navigating away from a failed photo to one that loads', (tester) async {
    var callCount = 0;
    ImageProvider provider(String url) {
      callCount++;
      // Only the first photo (first resolution) fails; every other
      // resolution (including a later revisit) succeeds -- proves the
      // retry is independent per navigation, not permanently "stuck".
      return callCount == 1 ? _alwaysFailingImageProvider(url) : _workingImageProvider(url);
    }

    await _pump(tester, PhotoCarousel(photos: const ['a.jpg', 'b.jpg'], imageProvider: provider));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('No photo available'), findsOneWidget);

    await tester.tap(_nextButton);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('No photo available'), findsNothing);
    expect(find.bySemanticsLabel('Vehicle photo 2 of 2'), findsOneWidget);
  });

  testWidgets(
    'revisiting the same index that previously failed retries independently '
    '(not just moving to a different index)',
    (tester) async {
      var aResolutionCount = 0;
      ImageProvider provider(String url) {
        if (url == 'a.jpg') {
          aResolutionCount++;
          // a.jpg fails only its first-ever resolution; a later revisit to
          // the *same* index must retry, not stay permanently placeholder.
          return aResolutionCount == 1 ? _alwaysFailingImageProvider(url) : _workingImageProvider(url);
        }
        return _workingImageProvider(url);
      }

      await _pump(tester, PhotoCarousel(photos: const ['a.jpg', 'b.jpg'], imageProvider: provider));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('No photo available'), findsOneWidget);

      await tester.tap(_nextButton);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Vehicle photo 2 of 2'), findsOneWidget);

      await tester.tap(_previousButton);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('No photo available'), findsNothing);
      expect(find.bySemanticsLabel('Vehicle photo 1 of 2'), findsOneWidget);
    },
  );

  testWidgets(
    'two different indices sharing the identical photo URL still retry independently '
    '(per-index tracking, not per-URL)',
    (tester) async {
      var callCount = 0;
      ImageProvider provider(String url) {
        callCount++;
        // Only the very first resolution (index 0's first attempt) fails;
        // every later resolution succeeds -- including index 1, which shares
        // the SAME url string as index 0.
        return callCount == 1 ? _alwaysFailingImageProvider(url) : _workingImageProvider(url);
      }

      await _pump(tester, PhotoCarousel(photos: const ['dup.jpg', 'dup.jpg'], imageProvider: provider));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('No photo available'), findsOneWidget);

      await tester.tap(_nextButton);
      await tester.pumpAndSettle();

      // Index 1 has the identical URL as the failed index 0, but is a
      // genuinely independent slot -- it must attempt its own fresh load
      // rather than immediately reusing index 0's cached failure.
      expect(find.bySemanticsLabel('No photo available'), findsNothing);
      expect(find.bySemanticsLabel('Vehicle photo 2 of 2'), findsOneWidget);
    },
  );

  group('compact width (< 600px): ghost chevrons + swipe replace the full button row (Task 40)', () {
    testWidgets('renders ghost chevrons over the photo, not the full Previous/Next row', (tester) async {
      await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg']), width: 320);

      expect(_nextButton, findsNothing);
      expect(_previousButton, findsNothing);
      expect(_ghostNext, findsOneWidget);
      expect(_ghostPrevious, findsOneWidget);
    });

    testWidgets('still shows the "X of Y" counter text below the photo', (tester) async {
      await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg']), width: 320);

      expect(find.text('1 of 3'), findsOneWidget);
    });

    testWidgets('tapping the ghost Next chevron advances to the next photo', (tester) async {
      await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg']), width: 320);

      await tester.tap(_ghostNext);
      await tester.pump();

      expect(tester.widget<VehiclePhoto>(find.byType(VehiclePhoto)).photoUrl, 'b.jpg');
      expect(find.text('2 of 3'), findsOneWidget);
    });

    testWidgets('tapping the ghost Previous chevron goes back to the previous photo', (tester) async {
      await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg']), width: 320);
      await tester.tap(_ghostNext);
      await tester.pump();

      await tester.tap(_ghostPrevious);
      await tester.pump();

      expect(tester.widget<VehiclePhoto>(find.byType(VehiclePhoto)).photoUrl, 'a.jpg');
      expect(find.text('1 of 3'), findsOneWidget);
    });

    testWidgets('disables the ghost Next chevron on the last photo', (tester) async {
      await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg']), width: 320);

      await tester.tap(_ghostNext);
      await tester.pump();

      expect(tester.widget<IconButton>(_ghostNext).onPressed, isNull);
    });

    testWidgets('disables the ghost Previous chevron on the first photo', (tester) async {
      await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg']), width: 320);

      expect(tester.widget<IconButton>(_ghostPrevious).onPressed, isNull);
    });

    testWidgets(
      'does not render ghost chevrons, the swipe area, or the counter when there is only one photo',
      (tester) async {
        await _pump(tester, const PhotoCarousel(photos: ['a.jpg']), width: 320);

        expect(_ghostNext, findsNothing);
        expect(_ghostPrevious, findsNothing);
        expect(find.byKey(_swipeArea), findsNothing);
        expect(find.textContaining(' of '), findsNothing);
      },
    );

    testWidgets('a leftward swipe past the velocity threshold advances to the next photo', (tester) async {
      await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg']), width: 320);

      await tester.fling(find.byKey(_swipeArea), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();

      expect(tester.widget<VehiclePhoto>(find.byType(VehiclePhoto)).photoUrl, 'b.jpg');
      expect(find.text('2 of 3'), findsOneWidget);
    });

    testWidgets('a rightward swipe past the velocity threshold goes back to the previous photo', (tester) async {
      await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg']), width: 320);
      await tester.fling(find.byKey(_swipeArea), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();

      await tester.fling(find.byKey(_swipeArea), const Offset(200, 0), 1000);
      await tester.pumpAndSettle();

      expect(tester.widget<VehiclePhoto>(find.byType(VehiclePhoto)).photoUrl, 'a.jpg');
      expect(find.text('1 of 3'), findsOneWidget);
    });

    testWidgets('a swipe below the velocity threshold does not change the photo', (tester) async {
      await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg']), width: 320);

      // Slow enough to read as an incidental drag (e.g. the VDP page's own
      // vertical scroll bleeding a few horizontal pixels), not an
      // intentional swipe -- below _swipeVelocityThreshold.
      await tester.fling(find.byKey(_swipeArea), const Offset(-50, 0), 100);
      await tester.pumpAndSettle();

      expect(tester.widget<VehiclePhoto>(find.byType(VehiclePhoto)).photoUrl, 'a.jpg');
      expect(find.text('1 of 3'), findsOneWidget);
    });

    testWidgets('a swipe past the last photo clamps instead of throwing', (tester) async {
      await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg']), width: 320);

      await tester.fling(find.byKey(_swipeArea), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();
      await tester.fling(find.byKey(_swipeArea), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();

      expect(tester.widget<VehiclePhoto>(find.byType(VehiclePhoto)).photoUrl, 'b.jpg');
      expect(find.text('2 of 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('recovers from a failed photo when navigating away via a ghost-chevron tap', (tester) async {
      var callCount = 0;
      ImageProvider provider(String url) {
        callCount++;
        return callCount == 1 ? _alwaysFailingImageProvider(url) : _workingImageProvider(url);
      }

      await _pump(
        tester,
        PhotoCarousel(photos: const ['a.jpg', 'b.jpg'], imageProvider: provider),
        width: 320,
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('No photo available'), findsOneWidget);

      await tester.tap(_ghostNext);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('No photo available'), findsNothing);
      expect(find.bySemanticsLabel('Vehicle photo 2 of 2'), findsOneWidget);
    });

    testWidgets('recovers from a failed photo when navigating away via a swipe', (tester) async {
      var callCount = 0;
      ImageProvider provider(String url) {
        callCount++;
        return callCount == 1 ? _alwaysFailingImageProvider(url) : _workingImageProvider(url);
      }

      await _pump(
        tester,
        PhotoCarousel(photos: const ['a.jpg', 'b.jpg'], imageProvider: provider),
        width: 320,
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('No photo available'), findsOneWidget);

      await tester.fling(find.byKey(_swipeArea), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('No photo available'), findsNothing);
      expect(find.bySemanticsLabel('Vehicle photo 2 of 2'), findsOneWidget);
    });
  });

  group('non-compact width (>= 600px): unchanged full button row, no ghost chevrons or swipe (Task 40)', () {
    testWidgets('renders the full Previous/Next row, not ghost chevrons', (tester) async {
      await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg']));

      expect(_nextButton, findsOneWidget);
      expect(_previousButton, findsOneWidget);
      expect(_ghostNext, findsNothing);
      expect(_ghostPrevious, findsNothing);
    });

    testWidgets('a horizontal fling does not change the photo (no swipe area outside compact width)', (
      tester,
    ) async {
      await _pump(tester, const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg']));

      await tester.fling(find.byType(VehiclePhoto), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();

      expect(tester.widget<VehiclePhoto>(find.byType(VehiclePhoto)).photoUrl, 'a.jpg');
    });
  });
}

/// A minimal valid 1x1 transparent PNG, so `Image`'s decoder succeeds.
const List<int> _onePixelPng = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];
