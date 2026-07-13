import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/find_vehicle.dart';
import '../models/vdp_page_title.dart';
import '../models/vehicle.dart';
import '../providers/inventory_provider.dart';
import '../theme/app_theme.dart';
import '../utils/document_title.dart';
import '../utils/format.dart';
import '../widgets/inventory_error_view.dart';
import '../widgets/photo_carousel.dart';
import '../widgets/skeleton.dart';

const int _kFeatureBound = 10;

/// Viewport width at which the photo starts shrinking (below this, it's
/// full content width as before). Deliberately independent from
/// `kMediumBreakpoint`/`kExpandedBreakpoint` (`lib/theme/breakpoints.dart`)
/// -- this is a VDP-only concern, not part of the shared window-size-class
/// system those drive.
const double _kVdpPhotoShrinkBreakpoint = 500;

/// The photo's capped width at/above [_kVdpPhotoShrinkBreakpoint] -- chosen
/// so its `AspectRatio(4/3)` height shrinks enough (~600px down to ~300px)
/// that the price is visible without scrolling on typical viewport heights,
/// without touching anything else in the single-column layout below it.
const double _kVdpShrunkPhotoWidth = 400;

/// Vehicle Detail Page — reads the [vehicleId] vehicle from the same
/// [inventoryProvider] cache the SRP populated (a local find-by-id, never a
/// second fetch). Four distinct states: loading, error (same message as
/// SRP), not-found (loaded but no cached vehicle matches the id — e.g. a
/// stale link), and loaded.
class VdpScreen extends ConsumerWidget {
  const VdpScreen({super.key, required this.vehicleId, this.onBackToResults});

  final int vehicleId;
  final VoidCallback? onBackToResults;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final dealerName = ref.watch(dealerNameProvider);
    final vehicle =
        inventoryAsync.value != null ? findVehicleById(inventoryAsync.value!.vehicles, vehicleId) : null;

    setDocumentTitle(
      vdpPageTitle(
        vehicle: vehicle,
        hasData: inventoryAsync.hasValue,
        dealerName: dealerName,
      ),
    );

    // The screen's own "Back to search results" control (below, inside
    // _VdpBody/_NotFound) is the one supported way back -- it resets to '/'
    // with no query params by design. The shared AppShell's AppBar has no
    // back arrow at all (it's shared chrome, not per-route), so there's no
    // second "back" control with a materially different outcome to guard
    // against here.
    return inventoryAsync.when(
      loading: () => const _VdpSkeleton(),
      error: (error, stackTrace) => InventoryErrorView(onRetry: () => ref.invalidate(inventoryProvider)),
      data: (inventory) => vehicle == null
          ? _NotFound(onBackToResults: onBackToResults)
          : _VdpBody(vehicle: vehicle, onBackToResults: onBackToResults),
    );
  }
}

/// Loading placeholder for the VDP — a skeleton photo block above a stack of
/// skeleton spec rows, matching the loaded layout's single-column shape
/// (maxWidth 800) at every viewport width.
class _VdpSkeleton extends StatelessWidget {
  const _VdpSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SkeletonBox(width: 160, height: 20),
              const SizedBox(height: 16),
              const SkeletonBox(height: 280, borderRadius: 12),
              const SizedBox(height: 24),
              const SkeletonBox(width: 220, height: 28),
              const SizedBox(height: 16),
              for (var i = 0; i < 5; i++) ...[
                const SkeletonBox(height: 16),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({this.onBackToResults});

  final VoidCallback? onBackToResults;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Vehicle not found.', style: Theme.of(context).textTheme.bodyLarge),
          TextButton(
            style: persistentLinkButtonStyle(context),
            onPressed: onBackToResults,
            child: const Text('Back to search results'),
          ),
        ],
      ),
    );
  }
}

class _VdpBody extends StatefulWidget {
  const _VdpBody({required this.vehicle, this.onBackToResults});

  final Vehicle vehicle;
  final VoidCallback? onBackToResults;

  @override
  State<_VdpBody> createState() => _VdpBodyState();
}

class _VdpBodyState extends State<_VdpBody> {
  bool _featuresExpanded = false;

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final backButton = TextButton(
      style: persistentLinkButtonStyle(context),
      onPressed: widget.onBackToResults,
      child: const Text('Back to search results'),
    );
    // Only the photo (and the title/price/mileage block above the spec
    // table) shrink/center at wider viewports -- everything else in this
    // single-column layout (spec table, features, description) is
    // untouched, deliberately not the earlier-considered two-pane
    // restructure. Narrower than _kVdpPhotoShrinkBreakpoint: both stay
    // exactly as before (full content width, left-aligned).
    final shrinkPhoto = MediaQuery.sizeOf(context).width >= _kVdpPhotoShrinkBreakpoint;
    final details = _VdpDetails(
      vehicle: vehicle,
      featuresExpanded: _featuresExpanded,
      onToggleFeatures: () => setState(() => _featuresExpanded = !_featuresExpanded),
      centerTopInfo: shrinkPhoto,
    );

    // Always single-pane, at every viewport width: photo/carousel full-width
    // on top, details below. A side-by-side two-pane layout at expanded
    // widths (Tasks 17-19) was tried and reverted -- reviewed on a real
    // wide browser window and judged worse than a wide single column, and
    // the reference web app never had a two-pane VDP either.
    final photoCarousel = PhotoCarousel(key: ValueKey(vehicle.id), photos: vehicle.photos);
    // Center, not left-align, once the photo is narrower than the content
    // column -- left-aligned would otherwise look lopsided against the
    // still-full-width spec table/features/description below it.
    final photo = shrinkPhoto
        ? Center(child: SizedBox(width: _kVdpShrunkPhotoWidth, child: photoCarousel))
        : photoCarousel;

    final content = ConstrainedBox(
      key: const Key('vdp-content'),
      constraints: const BoxConstraints(maxWidth: 800),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          backButton,
          const SizedBox(height: 8),
          photo,
          const SizedBox(height: 16),
          details,
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(child: content),
    );
  }
}

class _VdpDetails extends StatelessWidget {
  const _VdpDetails({
    required this.vehicle,
    required this.featuresExpanded,
    required this.onToggleFeatures,
    required this.centerTopInfo,
  });

  final Vehicle vehicle;
  final bool featuresExpanded;
  final VoidCallback onToggleFeatures;

  // Centers the title/price/mileage block (below) once the photo above it
  // has shrunk narrower than the content column -- left-aligned there would
  // read as offset from the now-centered photo. Left everything else in
  // this Column (spec table onward) untouched either way.
  final bool centerTopInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final topInfo = Column(
      crossAxisAlignment: centerTopInfo ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${vehicle.year} ${vehicle.make} ${vehicle.model} ${vehicle.trim}',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        vehicle.price != null
            ? Text(
                formatPrice(vehicle.price!),
                style: tabularNumsStyle(theme.textTheme.titleLarge!).copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              )
            : Text(
                'Call for price',
                style: theme.textTheme.titleLarge!.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        const SizedBox(height: 4),
        Text(
          '${formatMileage(vehicle.mileage)} · Stock #${vehicle.stock}',
          style: tabularNumsStyle(theme.textTheme.bodyMedium!).copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        centerTopInfo ? Center(child: topInfo) : topInfo,
        const Divider(height: 32),
        _SpecTable(vehicle: vehicle),
        if (vehicle.features.isNotEmpty) ...[
          const Divider(height: 32),
          Text('Features', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _FeatureList(
            features: vehicle.features,
            expanded: featuresExpanded,
            onToggle: onToggleFeatures,
          ),
        ],
        if (vehicle.description.isNotEmpty) ...[
          const Divider(height: 32),
          Text('Description', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Text(vehicle.description, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _SpecTable extends StatelessWidget {
  const _SpecTable({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final entries = [
      ('Engine', Text(vehicle.engine)),
      ('Transmission', Text(vehicle.transmission)),
      ('Drivetrain', Text(vehicle.drivetrain)),
      (
        'MPG (City/Hwy)',
        Text(
          '${vehicle.mpgCity ?? '—'} / ${vehicle.mpgHwy ?? '—'}',
          style: tabularNumsStyle(theme.textTheme.bodyMedium!),
        ),
      ),
      ('Exterior Color', Text(vehicle.exteriorColor)),
      ('Interior Color', Text(vehicle.interiorColor)),
      ('Certified', vehicle.isCertified ? const _CertifiedBadge() : const Text('No')),
    ];

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: entries.map((entry) {
        final (label, value) = entry;
        return SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: labelStyle),
              value,
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CertifiedBadge extends StatelessWidget {
  const _CertifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: kCertifiedColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Certified',
        style: TextStyle(color: kCertifiedColor, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.features, required this.expanded, required this.onToggle});

  final List<String> features;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isBounded = features.length > _kFeatureBound;
    final visible = expanded || !isBounded ? features : features.take(_kFeatureBound).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: visible.map((feature) => Text('• $feature')).toList(),
        ),
        if (isBounded)
          TextButton(
            style: persistentLinkButtonStyle(context),
            onPressed: onToggle,
            child: Text(expanded ? 'Show less' : 'Show all (${features.length})'),
          ),
      ],
    );
  }
}
