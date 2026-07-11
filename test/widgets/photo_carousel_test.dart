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

// Constrained to a realistic VDP content width — PhotoCarousel is never used
// at full screen width.
Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 320, child: child)),
    );

final _nextButton = find.widgetWithIcon(IconButton, Icons.chevron_right);
final _previousButton = find.widgetWithIcon(IconButton, Icons.chevron_left);

void main() {
  testWidgets('renders a placeholder when photos is empty', (tester) async {
    await tester.pumpWidget(_wrap(const PhotoCarousel(photos: [])));

    expect(find.bySemanticsLabel('No photo available'), findsOneWidget);
    expect(find.byType(VehiclePhoto), findsOneWidget);
  });

  testWidgets('renders the first photo when photos are present', (tester) async {
    await tester.pumpWidget(
      _wrap(const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg'])),
    );

    expect(tester.widget<VehiclePhoto>(find.byType(VehiclePhoto)).photoUrl, 'a.jpg');
  });

  testWidgets('shows a "1 of 3" counter when multiple photos are present', (tester) async {
    await tester.pumpWidget(
      _wrap(const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg'])),
    );

    expect(find.text('1 of 3'), findsOneWidget);
  });

  testWidgets('advances to the next photo when Next is tapped', (tester) async {
    await tester.pumpWidget(
      _wrap(const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg'])),
    );

    await tester.tap(_nextButton);
    await tester.pump();

    expect(tester.widget<VehiclePhoto>(find.byType(VehiclePhoto)).photoUrl, 'b.jpg');
    expect(find.text('2 of 3'), findsOneWidget);
  });

  testWidgets('goes back to the previous photo when Previous is tapped', (tester) async {
    await tester.pumpWidget(
      _wrap(const PhotoCarousel(photos: ['a.jpg', 'b.jpg', 'c.jpg'])),
    );
    await tester.tap(_nextButton);
    await tester.pump();

    await tester.tap(_previousButton);
    await tester.pump();

    expect(tester.widget<VehiclePhoto>(find.byType(VehiclePhoto)).photoUrl, 'a.jpg');
    expect(find.text('1 of 3'), findsOneWidget);
  });

  testWidgets('disables the Next button on the last photo', (tester) async {
    await tester.pumpWidget(_wrap(const PhotoCarousel(photos: ['a.jpg', 'b.jpg'])));

    await tester.tap(_nextButton);
    await tester.pump();

    expect(tester.widget<IconButton>(_nextButton).onPressed, isNull);
  });

  testWidgets('disables the Previous button on the first photo', (tester) async {
    await tester.pumpWidget(_wrap(const PhotoCarousel(photos: ['a.jpg', 'b.jpg'])));

    expect(tester.widget<IconButton>(_previousButton).onPressed, isNull);
  });

  testWidgets('does not render Next/Previous buttons when there is only one photo', (tester) async {
    await tester.pumpWidget(_wrap(const PhotoCarousel(photos: ['a.jpg'])));

    expect(_nextButton, findsNothing);
    expect(_previousButton, findsNothing);
    expect(find.textContaining(' of '), findsNothing);
  });

  testWidgets('falls back to the placeholder when the current photo fails to load', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PhotoCarousel(photos: const ['a.jpg', 'b.jpg'], imageProvider: _alwaysFailingImageProvider),
      ),
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

    await tester.pumpWidget(
      _wrap(PhotoCarousel(photos: const ['a.jpg', 'b.jpg'], imageProvider: provider)),
    );
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

      await tester.pumpWidget(
        _wrap(PhotoCarousel(photos: const ['a.jpg', 'b.jpg'], imageProvider: provider)),
      );
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
