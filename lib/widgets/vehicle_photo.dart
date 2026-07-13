import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared with the SRP skeleton loading card ([lib/screens/srp_screen.dart])
/// so its placeholder photo block matches the real photo's proportions
/// instead of an independent guessed value.
const double kVehiclePhotoAspectRatio = 4 / 3;

/// Builds the [ImageProvider] for a given photo URL. Defaults to
/// [CachedNetworkImageProvider] in production; tests inject a builder that
/// fails deterministically to exercise the placeholder fallback without
/// hitting the network. [maxWidth], when given, is a resize-on-disk hint
/// (G4) — passed through to [CachedNetworkImageProvider.maxWidth], which
/// actually shrinks what's cached on disk, not just the in-memory decode.
typedef VehiclePhotoProviderBuilder = ImageProvider Function(String url, {int? maxWidth});

/// Default [VehiclePhotoProviderBuilder] — [CachedNetworkImageProvider],
/// which persists a downloaded photo to disk (Task 36 / G2) instead of only
/// Flutter's automatic in-memory `ImageCache`, so it isn't re-fetched from
/// Vincue's CDN on every app relaunch. Public so other widgets embedding
/// [VehiclePhoto] (e.g. [PhotoCarousel], Task 11) can reference the same
/// default rather than duplicating it.
ImageProvider defaultVehiclePhotoProvider(String url, {int? maxWidth}) =>
    CachedNetworkImageProvider(url, maxWidth: maxWidth);

/// Shared photo widget for the SRP card (Task 9) and VDP carousel (Task 11).
/// Shows a placeholder when [photoUrl] is null/empty *or* when the photo
/// fails to load (dead link) — both are real, distinct cases per SPEC.md.
class VehiclePhoto extends StatelessWidget {
  const VehiclePhoto({
    super.key,
    required this.photoUrl,
    required this.semanticLabel,
    this.imageProvider = defaultVehiclePhotoProvider,
    this.maxWidth,
  });

  final String? photoUrl;
  final String semanticLabel;
  final VehiclePhotoProviderBuilder imageProvider;

  /// Resize-on-disk hint (G4) forwarded to [imageProvider] — null (the
  /// default) means no cap, full quality. [VehicleCard] (an SRP grid
  /// thumbnail) passes a smaller value; [PhotoCarousel] (the larger VDP
  /// display) leaves this null.
  final int? maxWidth;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final hasUrl = url != null && url.isNotEmpty;

    return AspectRatio(
      aspectRatio: kVehiclePhotoAspectRatio,
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
                image: imageProvider(url, maxWidth: maxWidth),
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
    return Semantics(
      label: 'No photo available',
      image: true,
      child: Container(
        // Literal white, not the theme's adaptive surface color -- matches
        // the logo's own white canvas it was designed/exported against
        // (branding decision, docs/superpowers/specs, header-logo
        // design note).
        color: Colors.white,
        alignment: Alignment.center,
        // The outer Semantics above already carries the one meaningful
        // label ("No photo available") for this whole placeholder -- the
        // logo image and "Vehicle Image Not Available" text underneath are
        // purely decorative/redundant restatements of that same fact, not
        // separate content. Without ExcludeSemantics here, the Text's own
        // auto-generated semantics node conflicts with the outer
        // `image: true` node and the compiled semantics tree silently
        // drops the label entirely (found via direct semantics-tree
        // inspection, not guessed) rather than throwing a catchable error.
        child: const ExcludeSemantics(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: FittedBox(
              // Scales the whole logo+text block down together at small
              // sizes (an SRP card thumbnail) without overflowing, and up
              // at large ones (VDP's carousel) -- one widget, both contexts.
              fit: BoxFit.contain,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image(image: AssetImage('assets/images/summit_subaru_logo.png')),
                  SizedBox(height: 12),
                  // Sized to 80% of the logo's own 1460px intrinsic width --
                  // a touch narrower than the red ribbon itself (1308px,
                  // ~90% of 1460, measured directly from the asset), so this
                  // reads as "as wide as the ribbon, a little smaller than
                  // SUMMIT SUBARU" rather than a hand-guessed font size.
                  // FittedBox(fitWidth) scales the text to exactly fill that
                  // width regardless of its own fontSize.
                  SizedBox(
                    width: 1460 * 0.80,
                    child: FittedBox(
                      fit: BoxFit.fitWidth,
                      child: Text(
                        'Vehicle Image Not Available',
                        style: TextStyle(fontFamily: 'Anton', color: Color(0xFF122847)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
