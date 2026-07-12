import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models/body_category.dart';
import '../models/filter_vehicles.dart';
import '../models/inventory.dart';
import '../models/paginate.dart';
import '../models/vehicle.dart';
import '../providers/inventory_provider.dart';
import '../providers/srp_state_provider.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import '../utils/document_title.dart';
import '../utils/format.dart';
import '../widgets/inventory_error_view.dart';
import '../widgets/skeleton.dart';
import '../widgets/vehicle_card.dart';
import '../widgets/vehicle_photo.dart';

const int _pageSize = 12;

/// The 16px gutter shared by the real card grid and the skeleton loading
/// grid, so the two can't silently drift apart the way two independent `16`
/// literals could.
const double _srpGridSpacing = 16;

/// [SliverSimpleGridDelegateWithMaxCrossAxisExtent.getCrossAxisCount] (unlike
/// the Flutter SDK's own [SliverGridDelegateWithMaxCrossAxisExtent], which
/// this replaced) doesn't clamp its result to at least 1 -- a transient
/// zero-or-negative `crossAxisExtent` (e.g. a zero-width layout pass during a
/// resize) would divide by zero downstream in `RenderSliverMasonryGrid`.
/// Match the SDK's own guard here.
class _ClampedMaxCrossAxisExtentDelegate extends SliverSimpleGridDelegateWithMaxCrossAxisExtent {
  const _ClampedMaxCrossAxisExtentDelegate({required super.maxCrossAxisExtent});

  @override
  int getCrossAxisCount(SliverConstraints constraints, double crossAxisSpacing) {
    return math.max(1, super.getCrossAxisCount(constraints, crossAxisSpacing));
  }
}

/// Shared by the real card grid and the skeleton loading grid so the loading
/// placeholder lays out with the identical column count.
///
/// A masonry layout, not a fixed-cell [GridView] -- [VehicleCard]'s photo
/// scales proportionally with column width (its `AspectRatio(4/3)`) while
/// its text block does not (fixed line count, occasionally wrapping an
/// extra line at narrow widths), so no single fixed cell height or
/// `childAspectRatio` can fit every card at every column width without
/// either leaving a gap (too tall) or overflowing (too short). Each card
/// sizing to its own real content height sidesteps that entirely.
const _ClampedMaxCrossAxisExtentDelegate _srpGridDelegate =
    _ClampedMaxCrossAxisExtentDelegate(maxCrossAxisExtent: 280);

/// Search Results Page — grid of active inventory, wired to the cached
/// [inventoryProvider] (Task 5) plus local filter/page state (Task 9;
/// Task 10 moves that state to `go_router` query parameters without
/// changing this screen's shape).
class SrpScreen extends ConsumerWidget {
  const SrpScreen({super.key, this.onVehicleTap});

  final void Function(Vehicle vehicle)? onVehicleTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryProvider);
    setDocumentTitle(ref.watch(dealerNameProvider));

    return inventoryAsync.when(
      loading: () => const _SrpSkeleton(),
      error: (error, stackTrace) => InventoryErrorView(onRetry: () => ref.invalidate(inventoryProvider)),
      data: (inventory) => _SrpBody(inventory: inventory, onVehicleTap: onVehicleTap),
    );
  }
}

class _SrpBody extends ConsumerStatefulWidget {
  const _SrpBody({required this.inventory, this.onVehicleTap});

  final Inventory inventory;
  final void Function(Vehicle vehicle)? onVehicleTap;

  @override
  ConsumerState<_SrpBody> createState() => _SrpBodyState();
}

class _SrpBodyState extends ConsumerState<_SrpBody> {
  @override
  Widget build(BuildContext context) {
    final srpState = ref.watch(srpStateProvider);
    final notifier = ref.read(srpStateProvider.notifier);
    final options = ref.watch(filterOptionsProvider);
    final filtered = filterVehicles(widget.inventory.vehicles, srpState.filters);
    final paged = paginate(filtered, srpState.page, _pageSize);

    // A page restored from a URL (or otherwise set directly) can be beyond
    // the real total for the current filtered result -- paginate() already
    // clamps it for *this* render, but the stored state itself would keep
    // claiming the out-of-range page (and re-serialize it back onto the URL)
    // until the user happened to click Previous/Next. Self-correct the
    // stored value to match what's actually being shown.
    if (srpState.page != paged.currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) notifier.setPage(paged.currentPage);
      });
    }

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${filtered.length} vehicles', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          _FilterBar(filters: srpState.filters, options: options, notifier: notifier),
          const SizedBox(height: 16),
          Expanded(
            child: paged.items.isEmpty
                ? _EmptyResults(onClearFilters: notifier.clearFilters)
                : MasonryGridView.custom(
                    gridDelegate: _srpGridDelegate,
                    crossAxisSpacing: _srpGridSpacing,
                    mainAxisSpacing: _srpGridSpacing,
                    // MasonryGridView.custom (unlike .builder, which derives
                    // this from itemCount automatically) doesn't default
                    // semanticChildCount from the delegate's own childCount --
                    // without this, a screen reader loses the grid's total
                    // item count announcement.
                    semanticChildCount: paged.items.length,
                    childrenDelegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final vehicle = paged.items[index];
                        return VehicleCard(
                          key: ValueKey(vehicle.id),
                          vehicle: vehicle,
                          onTap: () => widget.onVehicleTap?.call(vehicle),
                        );
                      },
                      childCount: paged.items.length,
                      // A `key:` on the built VehicleCard alone is not enough --
                      // SliverChildBuilderDelegate.findIndexByKey returns null
                      // and falls back to positional reconciliation unless
                      // findChildIndexCallback is also supplied. Without this,
                      // a filter/page change that drops a vehicle from view can
                      // silently carry VehicleCard's focus-highlight State over
                      // to a different vehicle now occupying the same grid slot.
                      findChildIndexCallback: (key) {
                        final id = (key as ValueKey<int>).value;
                        final index = paged.items.indexWhere((v) => v.id == id);
                        return index == -1 ? null : index;
                      },
                    ),
                  ),
          ),
          if (paged.totalPages > 1) ...[
            const SizedBox(height: 16),
            _PaginationControls(
              currentPage: paged.currentPage,
              totalPages: paged.totalPages,
              onPageChange: notifier.setPage,
            ),
          ],
        ],
      ),
    );

    final windowSizeClass = windowSizeClassOf(MediaQuery.sizeOf(context).width);
    return windowSizeClass == WindowSizeClass.expanded
        ? Center(
            child: ConstrainedBox(
              key: const Key('srp-width-cap'),
              constraints: const BoxConstraints(maxWidth: 1200),
              child: content,
            ),
          )
        : content;
  }
}

/// Loading placeholder for the SRP — mirrors the real body's shape (heading,
/// filter bar, card grid) with pulsing skeleton blocks, reusing
/// [_srpGridDelegate] so the placeholder grid matches the real grid's layout.
class _SrpSkeleton extends StatelessWidget {
  const _SrpSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 140, height: 28),
            const SizedBox(height: 16),
            const SkeletonBox(height: 48),
            const SizedBox(height: 16),
            Expanded(
              child: MasonryGridView.builder(
                gridDelegate: _srpGridDelegate,
                crossAxisSpacing: _srpGridSpacing,
                mainAxisSpacing: _srpGridSpacing,
                itemCount: 6,
                itemBuilder: (context, index) => const _SkeletonCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One placeholder card matching [VehicleCard]'s shape: photo block above
/// three stacked text lines.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AspectRatio(aspectRatio: kVehiclePhotoAspectRatio, child: SkeletonBox(borderRadius: 0)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(height: 16),
                SizedBox(height: 8),
                SkeletonBox(width: 120, height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 80, height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.onClearFilters});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('No vehicles match these filters. '),
        TextButton(onPressed: onClearFilters, child: const Text('Clear filters')),
      ],
    );
  }
}

class _FilterBar extends StatefulWidget {
  const _FilterBar({required this.filters, required this.options, required this.notifier});

  final VehicleFilters filters;
  final FilterOptions options;
  final SrpStateNotifier notifier;

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  bool _compactFiltersOpen = false;

  static const double _dropdownChromeAllowance = 24;
  static const double _dropdownMinWidth = 72;
  static const double _makeMaxWidth = 234;
  static const double _bodyMaxWidth = 266;
  static const double _priceMaxWidth = 169;

  @override
  Widget build(BuildContext context) {
    final windowSizeClass = windowSizeClassOf(MediaQuery.sizeOf(context).width);
    final make = _buildMakeDropdown(context);
    final body = _buildBodyDropdown(context);
    final minPrice = _buildMinPriceDropdown(context);
    final maxPrice = _buildMaxPriceDropdown(context);

    switch (windowSizeClass) {
      case WindowSizeClass.expanded:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [make, const SizedBox(width: 12), body, const SizedBox(width: 12), minPrice, const SizedBox(width: 12), maxPrice],
        );
      case WindowSizeClass.medium:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [make, const SizedBox(width: 12), body]),
            const SizedBox(height: 12),
            Row(mainAxisSize: MainAxisSize.min, children: [minPrice, const SizedBox(width: 12), maxPrice]),
          ],
        );
      case WindowSizeClass.compact:
        if (!_compactFiltersOpen) {
          return Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('apply-filters-toggle'),
              onPressed: () => setState(() => _compactFiltersOpen = true),
              child: const Text('Apply filters'),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            make,
            const SizedBox(height: 12),
            body,
            const SizedBox(height: 12),
            minPrice,
            const SizedBox(height: 12),
            maxPrice,
            const SizedBox(height: 12),
            TextButton(
              key: const Key('apply-filters-toggle'),
              onPressed: () => setState(() => _compactFiltersOpen = false),
              child: const Text('Hide filters'),
            ),
          ],
        );
    }
  }

  double _dropdownContentWidth(String text, TextStyle style, {required double maxWidth}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return (painter.width + _dropdownChromeAllowance).clamp(_dropdownMinWidth, maxWidth);
  }

  static T? _validValue<T>(T? candidate, List<T> validOptions) {
    return candidate != null && validOptions.contains(candidate) ? candidate : null;
  }

  Widget _buildMakeDropdown(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge!;
    final value = _validValue(widget.filters.make, widget.options.makes);
    final text = value ?? 'All makes';
    return Semantics(
      label: 'Make',
      child: SizedBox(
        width: _dropdownContentWidth(text, style, maxWidth: _makeMaxWidth),
        child: DropdownButton<String?>(
          isExpanded: true,
          style: style,
          key: const Key('make-filter'),
          value: value,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('All makes', overflow: TextOverflow.ellipsis)),
            ...widget.options.makes.map(
              (make) => DropdownMenuItem<String?>(value: make, child: Text(make, overflow: TextOverflow.ellipsis)),
            ),
          ],
          onChanged: widget.notifier.setMake,
        ),
      ),
    );
  }

  Widget _buildBodyDropdown(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge!;
    final value = _validValue(widget.filters.body, widget.options.bodyStyles);
    final text = value?.displayName ?? 'All body styles';
    return Semantics(
      label: 'Body style',
      child: SizedBox(
        width: _dropdownContentWidth(text, style, maxWidth: _bodyMaxWidth),
        child: DropdownButton<BodyCategory?>(
          isExpanded: true,
          style: style,
          key: const Key('body-filter'),
          value: value,
          items: [
            const DropdownMenuItem<BodyCategory?>(
              value: null,
              child: Text('All body styles', overflow: TextOverflow.ellipsis),
            ),
            ...widget.options.bodyStyles.map(
              (body) => DropdownMenuItem<BodyCategory?>(
                value: body,
                child: Text(body.displayName, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: widget.notifier.setBody,
        ),
      ),
    );
  }

  Widget _buildMinPriceDropdown(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge!;
    final minPriceItems = minPriceOptions(widget.filters.maxPrice);
    final value = _validValue(widget.filters.minPrice, minPriceItems);
    final text = value != null ? formatPrice(value) : 'Min price';
    return Semantics(
      label: 'Minimum price',
      child: SizedBox(
        width: _dropdownContentWidth(text, style, maxWidth: _priceMaxWidth),
        child: DropdownButton<double?>(
          isExpanded: true,
          style: style,
          key: const Key('min-price-filter'),
          value: value,
          items: [
            const DropdownMenuItem<double?>(value: null, child: Text('Min price', overflow: TextOverflow.ellipsis)),
            ...minPriceItems.map(
              (threshold) => DropdownMenuItem<double?>(
                value: threshold,
                child: Text(formatPrice(threshold), overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: widget.notifier.setMinPrice,
        ),
      ),
    );
  }

  Widget _buildMaxPriceDropdown(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge!;
    final maxPriceItems = maxPriceOptions(widget.filters.minPrice);
    final value = _validValue(widget.filters.maxPrice, maxPriceItems);
    final text = value != null ? formatPrice(value) : 'Max price';
    return Semantics(
      label: 'Maximum price',
      child: SizedBox(
        width: _dropdownContentWidth(text, style, maxWidth: _priceMaxWidth),
        child: DropdownButton<double?>(
          isExpanded: true,
          style: style,
          key: const Key('max-price-filter'),
          value: value,
          items: [
            const DropdownMenuItem<double?>(value: null, child: Text('Max price', overflow: TextOverflow.ellipsis)),
            ...maxPriceItems.map(
              (threshold) => DropdownMenuItem<double?>(
                value: threshold,
                child: Text(formatPrice(threshold), overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: widget.notifier.setMaxPrice,
        ),
      ),
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChange,
  });

  final int currentPage;
  final int totalPages;
  final void Function(int page) onPageChange;

  @override
  Widget build(BuildContext context) {
    // A Row's non-flexible children render at their own natural size
    // regardless of available width -- two TextButtons (Material's minimum
    // tap-target width) plus the page-count text together need ~400px
    // (measured), more than many phone viewports leave after the page's
    // 16px padding, which overflowed rather than adapting. Wrap -- the same
    // pattern already used above by _FilterBar and _EmptyResults for the
    // same class of problem -- drops to a second line at narrow widths
    // instead. Unlike Row (mainAxisSize.max fills its parent, then centers
    // within that), Wrap shrink-wraps to its own content width, so it must
    // be explicitly centered within the page via the outer Center --
    // WrapAlignment.center alone only centers content within Wrap's own
    // already-shrunk box, which is a no-op when nothing has wrapped.
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: currentPage > 1 ? () => onPageChange(currentPage - 1) : null,
            child: const Text('Previous'),
          ),
          Text('Page $currentPage of $totalPages', style: tabularNumsStyle(Theme.of(context).textTheme.bodyMedium!)),
          TextButton(
            onPressed: currentPage < totalPages ? () => onPageChange(currentPage + 1) : null,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
