import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/widgets/vehicle_photo.dart';

/// Always resolves to a 1x1 transparent PNG's worth of *invalid* bytes, so
/// `Image`'s decoder rejects it and `errorBuilder` fires — deterministic,
/// offline simulation of a dead photo URL. Real network loading uses
/// [NetworkImage] in production (the widget's default `imageProvider`).
ImageProvider _alwaysFailingImageProvider(String url) {
  return MemoryImage(Uint8List.fromList([1, 2, 3]));
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows the placeholder when photoUrl is null', (tester) async {
    await tester.pumpWidget(
      _wrap(const VehiclePhoto(photoUrl: null, semanticLabel: 'Vehicle photo')),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.bySemanticsLabel('No photo available'), findsOneWidget);
  });

  testWidgets('shows the placeholder when photoUrl is empty', (tester) async {
    await tester.pumpWidget(
      _wrap(const VehiclePhoto(photoUrl: '', semanticLabel: 'Vehicle photo')),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.bySemanticsLabel('No photo available'), findsOneWidget);
  });

  testWidgets('renders the photo when a valid image loads successfully', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VehiclePhoto(
          photoUrl: 'https://example.com/car.jpg',
          semanticLabel: '2020 Honda Accord',
          imageProvider: (url) => MemoryImage(Uint8List.fromList(_onePixelPng)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.bySemanticsLabel('No photo available'), findsNothing);
    expect(find.bySemanticsLabel('2020 Honda Accord'), findsOneWidget);
  });

  testWidgets('falls back to the placeholder when the photo fails to load', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VehiclePhoto(
          photoUrl: 'https://example.com/dead-link.jpg',
          semanticLabel: '2020 Honda Accord',
          imageProvider: _alwaysFailingImageProvider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('No photo available'), findsOneWidget);
    expect(find.bySemanticsLabel('2020 Honda Accord'), findsNothing);
  });
}

/// A minimal valid 1x1 transparent PNG, so [Image]'s decoder succeeds.
const List<int> _onePixelPng = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];
