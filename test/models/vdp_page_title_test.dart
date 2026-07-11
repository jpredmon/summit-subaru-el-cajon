import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/models/vdp_page_title.dart';

import '../support/vehicle_factory.dart';

void main() {
  test('loaded branch: "year make model trim | dealerName"', () {
    final title = vdpPageTitle(
      vehicle: vehicle(year: 2021, make: 'Honda', model: 'Civic'),
      hasData: true,
      dealerName: 'Test Dealer',
    );

    expect(title, '2021 Honda Civic EX-L | Test Dealer');
  });

  test('not-found branch: loaded data but no matching vehicle', () {
    final title = vdpPageTitle(
      vehicle: null,
      hasData: true,
      dealerName: 'Test Dealer',
    );

    expect(title, 'Vehicle Not Found | Test Dealer');
  });

  test('loading branch falls back to plain dealerName', () {
    final title = vdpPageTitle(
      vehicle: null,
      hasData: false,
      dealerName: 'Test Dealer',
    );

    expect(title, 'Test Dealer');
  });

  test('error branch (no data) shares the plain dealerName title with loading', () {
    final title = vdpPageTitle(
      vehicle: null,
      hasData: false,
      dealerName: 'Test Dealer',
    );

    expect(title, 'Test Dealer');
  });
}
