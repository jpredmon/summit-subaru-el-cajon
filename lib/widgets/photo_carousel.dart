import 'package:flutter/material.dart';

import '../models/carousel.dart';
import '../theme/breakpoints.dart';
import 'vehicle_photo.dart';

/// Minimum horizontal fling velocity (logical px/s) for a swipe to change
/// photos -- below this, treat it as an incidental drag (e.g. the VDP
/// page's own vertical scroll bleeding a few horizontal pixels) rather than
/// an intentional navigation gesture. Tuned by feel against a real phone-
/// width viewport (Task 40), not derived from a platform constant.
const double _swipeVelocityThreshold = 300;

/// Ghost-chevron icon size at compact width -- deliberately smaller than
/// the full button row's default 24px `IconButton`, so it reads as a
/// lightweight overlay hint rather than a primary control.
const double _ghostChevronIconSize = 20;

/// VDP photo carousel — current-index state, Previous/Next (clamped, not
/// wrapped), an "X of Y" counter, and per-photo failure recovery. The
/// failure/placeholder behavior itself lives entirely in [VehiclePhoto]
/// (Task 8): swapping [VehiclePhoto.photoUrl] as the index changes is
/// enough for a failed photo to retry independently when navigated back to,
/// since [VehiclePhoto] keys its underlying `Image` per URL.
///
/// Below the compact breakpoint (Task 40), the full Previous/Next
/// `IconButton` row is replaced by small semi-transparent chevrons
/// overlaid on the photo itself plus a horizontal swipe gesture, both
/// driving the exact same index transitions as the row does above compact
/// width -- no `PageView`, since that would manage its own child lifecycle
/// and risk breaking the per-index failure-retry isolation described above.
class PhotoCarousel extends StatefulWidget {
  const PhotoCarousel({
    super.key,
    required this.photos,
    this.imageProvider = defaultVehiclePhotoProvider,
  });

  final List<String> photos;
  final VehiclePhotoProviderBuilder imageProvider;

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  int _index = 0;

  void _goToPrevious() {
    if (_index == 0) return;
    setState(() => _index = prevPhotoIndex(_index));
  }

  void _goToNext(int length) {
    if (_index == length - 1) return;
    setState(() => _index = nextPhotoIndex(_index, length));
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;

    if (photos.isEmpty) {
      return VehiclePhoto(photoUrl: null, semanticLabel: 'No photo available');
    }

    final hasMultiple = photos.length > 1;
    final isCompact = windowSizeClassOf(MediaQuery.sizeOf(context).width) == WindowSizeClass.compact;

    final photo = VehiclePhoto(
      // Keyed by index, not just relying on VehiclePhoto's own per-URL
      // key: two different indices can share the identical URL (dealer
      // feed duplication), and per-index failure tracking must stay
      // independent regardless -- an index-based key forces a fresh
      // VehiclePhoto (and its whole subtree, including the inner
      // Image's error state) on every index change, even when the URL
      // repeats.
      key: ValueKey(_index),
      photoUrl: photos[_index],
      semanticLabel: 'Vehicle photo ${_index + 1} of ${photos.length}',
      imageProvider: widget.imageProvider,
    );

    Widget photoArea = photo;
    if (hasMultiple && isCompact) {
      photoArea = GestureDetector(
        key: const Key('carousel-swipe-area'),
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity <= -_swipeVelocityThreshold) {
            _goToNext(photos.length);
          } else if (velocity >= _swipeVelocityThreshold) {
            _goToPrevious();
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            photo,
            Positioned(
              left: 4,
              child: _GhostChevron(
                buttonKey: const Key('carousel-ghost-previous'),
                icon: Icons.chevron_left,
                tooltip: 'Previous photo',
                onPressed: _index > 0 ? _goToPrevious : null,
              ),
            ),
            Positioned(
              right: 4,
              child: _GhostChevron(
                buttonKey: const Key('carousel-ghost-next'),
                icon: Icons.chevron_right,
                tooltip: 'Next photo',
                onPressed: _index < photos.length - 1 ? () => _goToNext(photos.length) : null,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        photoArea,
        if (hasMultiple) ...[
          const SizedBox(height: 8),
          if (isCompact)
            Text('${_index + 1} of ${photos.length}')
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  key: const Key('carousel-previous-button'),
                  onPressed: _index > 0 ? _goToPrevious : null,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous photo',
                ),
                Text('${_index + 1} of ${photos.length}'),
                IconButton(
                  key: const Key('carousel-next-button'),
                  onPressed: _index < photos.length - 1 ? () => _goToNext(photos.length) : null,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next photo',
                ),
              ],
            ),
        ],
      ],
    );
  }
}

/// A small, semi-transparent chevron overlaid directly on the carousel
/// photo at compact width (Task 40) -- a lighter-weight navigation
/// affordance than the full [IconButton] row shown above the compact
/// breakpoint, so the photo reads as swipeable at a glance without relying
/// on the "X of Y" counter text alone. Still a real [IconButton]
/// underneath (same tap target, disabled state, and tooltip semantics as
/// the full row), just restyled.
class _GhostChevron extends StatelessWidget {
  const _GhostChevron({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  // Applied to the inner IconButton itself, not this wrapper -- tests find
  // it via `tester.widget<IconButton>(find.byKey(...))` the same way the
  // full-width row's Previous/Next buttons already are, so the disabled-
  // state assertions (`.onPressed == null`) work identically either side of
  // the compact breakpoint.
  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: IconButton(
        key: buttonKey,
        iconSize: _ghostChevronIconSize,
        color: Colors.white,
        disabledColor: Colors.white38,
        onPressed: onPressed,
        icon: Icon(icon),
        tooltip: tooltip,
      ),
    );
  }
}
