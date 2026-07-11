import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../widgets/theme_toggle_button.dart';
import '../widgets/vehicle_card.dart';

const int _pageSize = 12;

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

    return Scaffold(
      appBar: AppBar(actions: const [ThemeToggleButton()]),
      body: inventoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Failed to load inventory. Please try again later.'),
          ),
        ),
        data: (inventory) => _SrpBody(inventory: inventory, onVehicleTap: onVehicleTap),
      ),
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
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      mainAxisExtent: 340,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: paged.items.length,
                    itemBuilder: (context, index) {
                      final vehicle = paged.items[index];
                      return VehicleCard(
                        vehicle: vehicle,
                        onTap: () => widget.onVehicleTap?.call(vehicle),
                      );
                    },
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filters, required this.options, required this.notifier});

  final VehicleFilters filters;
  final FilterOptions options;
  final SrpStateNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final minPriceItems = minPriceOptions(filters.maxPrice);
    final maxPriceItems = maxPriceOptions(filters.minPrice);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        Semantics(
          label: 'Make',
          child: DropdownButton<String?>(
            key: const Key('make-filter'),
            value: _validValue(filters.make, options.makes),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All makes')),
              ...options.makes.map((make) => DropdownMenuItem<String?>(value: make, child: Text(make))),
            ],
            onChanged: notifier.setMake,
          ),
        ),
        Semantics(
          label: 'Body style',
          child: DropdownButton<BodyCategory?>(
            key: const Key('body-filter'),
            value: _validValue(filters.body, options.bodyStyles),
            items: [
              const DropdownMenuItem<BodyCategory?>(value: null, child: Text('All body styles')),
              ...options.bodyStyles.map(
                (body) => DropdownMenuItem<BodyCategory?>(value: body, child: Text(body.displayName)),
              ),
            ],
            onChanged: notifier.setBody,
          ),
        ),
        Semantics(
          label: 'Minimum price',
          child: DropdownButton<double?>(
            key: const Key('min-price-filter'),
            value: _validValue(filters.minPrice, minPriceItems),
            items: [
              const DropdownMenuItem<double?>(value: null, child: Text('Min price')),
              ...minPriceItems
                  .map((threshold) => DropdownMenuItem<double?>(value: threshold, child: Text(formatPrice(threshold)))),
            ],
            onChanged: notifier.setMinPrice,
          ),
        ),
        Semantics(
          label: 'Maximum price',
          child: DropdownButton<double?>(
            key: const Key('max-price-filter'),
            value: _validValue(filters.maxPrice, maxPriceItems),
            items: [
              const DropdownMenuItem<double?>(value: null, child: Text('Max price')),
              ...maxPriceItems
                  .map((threshold) => DropdownMenuItem<double?>(value: threshold, child: Text(formatPrice(threshold)))),
            ],
            onChanged: notifier.setMaxPrice,
          ),
        ),
      ],
    );
  }

  /// Guards against Flutter's `DropdownButton` "value must match exactly one
  /// item" invariant: a filter value can arrive from outside this widget's
  /// own controls (restored from a URL via `SrpStateNotifier.restoreFrom`)
  /// referencing a make/body/price no longer offered by [validOptions] --
  /// e.g. a stale deep link, or a price not in the fixed threshold list.
  /// Falls back to "no constraint" for display rather than crashing; the
  /// underlying stored filter value is untouched, so it still participates
  /// in `filterVehicles` as given.
  static T? _validValue<T>(T? candidate, List<T> validOptions) {
    return candidate != null && validOptions.contains(candidate) ? candidate : null;
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: currentPage > 1 ? () => onPageChange(currentPage - 1) : null,
          child: const Text('Previous'),
        ),
        const SizedBox(width: 16),
        Text('Page $currentPage of $totalPages', style: tabularNumsStyle(Theme.of(context).textTheme.bodyMedium!)),
        const SizedBox(width: 16),
        TextButton(
          onPressed: currentPage < totalPages ? () => onPageChange(currentPage + 1) : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}
