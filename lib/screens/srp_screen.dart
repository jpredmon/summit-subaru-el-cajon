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
import '../utils/format.dart';
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

    return Scaffold(
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

class _SrpBody extends ConsumerWidget {
  const _SrpBody({required this.inventory, this.onVehicleTap});

  final Inventory inventory;
  final void Function(Vehicle vehicle)? onVehicleTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final srpState = ref.watch(srpStateProvider);
    final notifier = ref.read(srpStateProvider.notifier);
    final options = getFilterOptions(inventory.vehicles);
    final filtered = filterVehicles(inventory.vehicles, srpState.filters);
    final paged = paginate(filtered, srpState.page, _pageSize);

    return Padding(
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
                        onTap: () => onVehicleTap?.call(vehicle),
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
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        Semantics(
          label: 'Make',
          child: DropdownButton<String?>(
            key: const Key('make-filter'),
            value: filters.make,
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
            value: filters.body,
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
            value: filters.minPrice,
            items: [
              const DropdownMenuItem<double?>(value: null, child: Text('Min price')),
              ...minPriceOptions(filters.maxPrice)
                  .map((threshold) => DropdownMenuItem<double?>(value: threshold, child: Text(formatPrice(threshold)))),
            ],
            onChanged: notifier.setMinPrice,
          ),
        ),
        Semantics(
          label: 'Maximum price',
          child: DropdownButton<double?>(
            key: const Key('max-price-filter'),
            value: filters.maxPrice,
            items: [
              const DropdownMenuItem<double?>(value: null, child: Text('Max price')),
              ...maxPriceOptions(filters.minPrice)
                  .map((threshold) => DropdownMenuItem<double?>(value: threshold, child: Text(formatPrice(threshold)))),
            ],
            onChanged: notifier.setMaxPrice,
          ),
        ),
      ],
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
