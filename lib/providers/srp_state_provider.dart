import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/body_category.dart';
import '../models/filter_vehicles.dart';

/// SRP filter selections plus the current page. Local widget state for now
/// (Task 9); Task 10 swaps the persistence layer to `go_router` query
/// parameters without changing this shape or the notifier's API.
class SrpFilterState {
  const SrpFilterState({this.filters = const VehicleFilters(), this.page = 1});

  final VehicleFilters filters;
  final int page;
}

/// Any filter change resets [SrpFilterState.page] to 1 — matches the web
/// app's `useSrpState` (`setFilter` always resets to page 1; only `setPage`
/// leaves the page as given).
class SrpStateNotifier extends Notifier<SrpFilterState> {
  @override
  SrpFilterState build() => const SrpFilterState();

  void setMake(String? make) => _setFilters(
        VehicleFilters(
          make: make,
          body: state.filters.body,
          minPrice: state.filters.minPrice,
          maxPrice: state.filters.maxPrice,
        ),
      );

  void setBody(BodyCategory? body) => _setFilters(
        VehicleFilters(
          make: state.filters.make,
          body: body,
          minPrice: state.filters.minPrice,
          maxPrice: state.filters.maxPrice,
        ),
      );

  void setMinPrice(double? minPrice) => _setFilters(
        VehicleFilters(
          make: state.filters.make,
          body: state.filters.body,
          minPrice: minPrice,
          maxPrice: state.filters.maxPrice,
        ),
      );

  void setMaxPrice(double? maxPrice) => _setFilters(
        VehicleFilters(
          make: state.filters.make,
          body: state.filters.body,
          minPrice: state.filters.minPrice,
          maxPrice: maxPrice,
        ),
      );

  void setPage(int page) {
    state = SrpFilterState(filters: state.filters, page: page);
  }

  void clearFilters() {
    state = const SrpFilterState();
  }

  void _setFilters(VehicleFilters filters) {
    state = SrpFilterState(filters: filters, page: 1);
  }
}

final srpStateProvider = NotifierProvider<SrpStateNotifier, SrpFilterState>(SrpStateNotifier.new);
