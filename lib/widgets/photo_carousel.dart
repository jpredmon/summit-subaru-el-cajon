import 'package:flutter/material.dart';

import '../models/carousel.dart';
import 'vehicle_photo.dart';

/// VDP photo carousel — current-index state, Previous/Next (clamped, not
/// wrapped), an "X of Y" counter, and per-photo failure recovery. The
/// failure/placeholder behavior itself lives entirely in [VehiclePhoto]
/// (Task 8): swapping [VehiclePhoto.photoUrl] as the index changes is
/// enough for a failed photo to retry independently when navigated back to,
/// since [VehiclePhoto] keys its underlying `Image` per URL.
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

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;

    if (photos.isEmpty) {
      return VehiclePhoto(photoUrl: null, semanticLabel: 'No photo available');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        VehiclePhoto(
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
        ),
        if (photos.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _index > 0 ? () => setState(() => _index = prevPhotoIndex(_index)) : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous photo',
              ),
              Text('${_index + 1} of ${photos.length}'),
              IconButton(
                onPressed: _index < photos.length - 1
                    ? () => setState(() => _index = nextPhotoIndex(_index, photos.length))
                    : null,
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
