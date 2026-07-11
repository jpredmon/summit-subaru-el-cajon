import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Builds the [ImageProvider] for a given photo URL. Defaults to
/// [NetworkImage] in production; tests inject a builder that fails
/// deterministically to exercise the placeholder fallback without hitting
/// the network.
typedef VehiclePhotoProviderBuilder = ImageProvider Function(String url);

/// Default [VehiclePhotoProviderBuilder] — plain [NetworkImage]. Public so
/// other widgets embedding [VehiclePhoto] (e.g. [PhotoCarousel], Task 11) can
/// reference the same default rather than duplicating it.
ImageProvider defaultVehiclePhotoProvider(String url) => NetworkImage(url);

/// Shared photo widget for the SRP card (Task 9) and VDP carousel (Task 11).
/// Shows a placeholder when [photoUrl] is null/empty *or* when the photo
/// fails to load (dead link) — both are real, distinct cases per SPEC.md.
class VehiclePhoto extends StatelessWidget {
  const VehiclePhoto({
    super.key,
    required this.photoUrl,
    required this.semanticLabel,
    this.imageProvider = defaultVehiclePhotoProvider,
  });

  final String? photoUrl;
  final String semanticLabel;
  final VehiclePhotoProviderBuilder imageProvider;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final hasUrl = url != null && url.isNotEmpty;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius),
        child: hasUrl
            ? Image(
                // A distinct key per URL forces Flutter to discard the old
                // _ImageState (and its cached error) instead of reusing it —
                // without this, recovering from a failed photo to a working
                // one can get stuck showing the stale placeholder. Same
                // reason the web app's PhotoCarousel keys its <img> by index.
                key: ValueKey(url),
                image: imageProvider(url),
                fit: BoxFit.cover,
                semanticLabel: semanticLabel,
                errorBuilder: (context, error, stackTrace) => const _PlaceholderPhoto(),
              )
            : const _PlaceholderPhoto(),
      ),
    );
  }
}

class _PlaceholderPhoto extends StatelessWidget {
  const _PlaceholderPhoto();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'No photo available',
      image: true,
      child: Container(
        color: colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.directions_car_filled_outlined,
          size: 48,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
