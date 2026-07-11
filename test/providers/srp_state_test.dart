import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/models/body_category.dart';
import 'package:vincue_mobile/models/filter_vehicles.dart';
import 'package:vincue_mobile/providers/srp_state_provider.dart';

void main() {
  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('starts with no active filters and page 1', () {
    final c = container();

    final state = c.read(srpStateProvider);

    expect(state.filters.make, isNull);
    expect(state.filters.body, isNull);
    expect(state.filters.minPrice, isNull);
    expect(state.filters.maxPrice, isNull);
    expect(state.page, 1);
  });

  test('setMake updates make and resets page to 1', () {
    final c = container();
    c.read(srpStateProvider.notifier).setPage(3);

    c.read(srpStateProvider.notifier).setMake('Honda');

    expect(c.read(srpStateProvider).filters.make, 'Honda');
    expect(c.read(srpStateProvider).page, 1);
  });

  test('setBody updates body and resets page to 1, leaving make untouched', () {
    final c = container();
    c.read(srpStateProvider.notifier)
      ..setMake('Honda')
      ..setPage(2);

    c.read(srpStateProvider.notifier).setBody(BodyCategory.suv);

    final state = c.read(srpStateProvider);
    expect(state.filters.make, 'Honda');
    expect(state.filters.body, BodyCategory.suv);
    expect(state.page, 1);
  });

  test('setMinPrice and setMaxPrice each reset page to 1 and leave other filters untouched', () {
    final c = container();
    c.read(srpStateProvider.notifier)
      ..setMake('Honda')
      ..setPage(2);

    c.read(srpStateProvider.notifier).setMinPrice(10000);
    expect(c.read(srpStateProvider).filters.minPrice, 10000);
    expect(c.read(srpStateProvider).filters.make, 'Honda');
    expect(c.read(srpStateProvider).page, 1);

    c.read(srpStateProvider.notifier)
      ..setPage(2)
      ..setMaxPrice(20000);
    expect(c.read(srpStateProvider).filters.maxPrice, 20000);
    expect(c.read(srpStateProvider).filters.minPrice, 10000);
    expect(c.read(srpStateProvider).page, 1);
  });

  test('setPage changes only the page, leaving filters untouched', () {
    final c = container();
    c.read(srpStateProvider.notifier).setMake('Honda');

    c.read(srpStateProvider.notifier).setPage(4);

    expect(c.read(srpStateProvider).page, 4);
    expect(c.read(srpStateProvider).filters.make, 'Honda');
  });

  test('restoreFrom replaces the whole state as given, without resetting page', () {
    final c = container();
    c.read(srpStateProvider.notifier).setPage(5);

    c.read(srpStateProvider.notifier).restoreFrom(
          const SrpFilterState(filters: VehicleFilters(make: 'Honda'), page: 3),
        );

    final state = c.read(srpStateProvider);
    expect(state.filters.make, 'Honda');
    expect(state.page, 3);
  });

  test('clearFilters resets both filters and page to defaults', () {
    final c = container();
    c.read(srpStateProvider.notifier)
      ..setMake('Honda')
      ..setBody(BodyCategory.suv)
      ..setMinPrice(10000)
      ..setPage(3);

    c.read(srpStateProvider.notifier).clearFilters();

    final state = c.read(srpStateProvider);
    expect(state.filters.make, isNull);
    expect(state.filters.body, isNull);
    expect(state.filters.minPrice, isNull);
    expect(state.page, 1);
  });
}
