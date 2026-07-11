import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/find_vehicle.dart';
import '../models/vdp_page_title.dart';
import '../models/vehicle.dart';
import '../providers/inventory_provider.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import '../utils/document_title.dart';
import '../utils/format.dart';
import '../widgets/photo_carousel.dart';
import '../widgets/theme_toggle_button.dart';

const int _kFeatureBound = 10;

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

    return Scaffold(
      // The screen's own "Back to search results" control (below) is the
      // one supported way back -- it resets to '/' with no query params by
      // design. A default AppBar back-arrow would instead pop the raw
      // Navigator route, which restores the SRP's prior filters/page
      // instead of resetting them: two visually adjacent "back" controls
      // with materially different outcomes.
      appBar: AppBar(automaticallyImplyLeading: false, actions: const [ThemeToggleButton()]),
      body: inventoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Failed to load inventory. Please try again later.'),
          ),
        ),
        data: (inventory) => vehicle == null
            ? _NotFound(onBackToResults: onBackToResults)
            : _VdpBody(vehicle: vehicle, onBackToResults: onBackToResults),
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
          TextButton(onPressed: onBackToResults, child: const Text('Back to search results')),
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
    final windowSizeClass = windowSizeClassOf(MediaQuery.sizeOf(context).width);
    final backButton = TextButton(
      onPressed: widget.onBackToResults,
      child: const Text('Back to search results'),
    );
    final details = _VdpDetails(
      vehicle: vehicle,
      featuresExpanded: _featuresExpanded,
      onToggleFeatures: () => setState(() => _featuresExpanded = !_featuresExpanded),
    );

    final Widget content;
    if (windowSizeClass == WindowSizeClass.expanded) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            backButton,
            const SizedBox(height: 8),
            Row(
              key: const Key('vdp-two-pane-row'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 440,
                  child: PhotoCarousel(key: ValueKey(vehicle.id), photos: vehicle.photos),
                ),
                const SizedBox(width: 24),
                Expanded(child: details),
              ],
            ),
          ],
        ),
      );
    } else {
      content = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            backButton,
            const SizedBox(height: 8),
            PhotoCarousel(key: ValueKey(vehicle.id), photos: vehicle.photos),
            const SizedBox(height: 16),
            details,
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }
}

class _VdpDetails extends StatelessWidget {
  const _VdpDetails({required this.vehicle, required this.featuresExpanded, required this.onToggleFeatures});

  final Vehicle vehicle;
  final bool featuresExpanded;
  final VoidCallback onToggleFeatures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            onPressed: onToggle,
            child: Text(expanded ? 'Show less' : 'Show all (${features.length})'),
          ),
      ],
    );
  }
}
