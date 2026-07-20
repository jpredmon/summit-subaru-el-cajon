import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/services/inventory_response_parser.dart';

Map<String, dynamic> _rawJson({String dealerName = 'Summit Subaru El Cajon'}) => {
      'inventoryID': 1,
      'vin': 'V',
      'stock': 'S',
      'newUsed': 'U',
      'year': '2020',
      'make': 'Make',
      'model': 'Model',
      'trim': 'Trim',
      'body': 'Sedan',
      'transmission': 'Automatic',
      'engine': 'V6',
      'drivetrain': 'FWD',
      'extColor': 'Black',
      'intColor': 'Gray',
      'miles': '1000',
      'sellingPrice': '20000.00',
      'certified': 'N',
      'mpgCity': '25',
      'mpgHwy': '30',
      'vehiclePhotos': <String>[],
      'photoCount': 0,
      'features': <String>['A'],
      'description': 'x',
      'vdpUrl': null,
      'dealerName': dealerName,
    };

String _okBody({String dealerName = 'Summit Subaru El Cajon', int count = 1}) => jsonEncode({
      'result': [for (var i = 0; i < count; i++) _rawJson(dealerName: dealerName)],
    });

void main() {
  group('parseInventoryResponse', () {
    test('parses the result array and surfaces the dealer name', () {
      final result = parseInventoryResponse(_okBody(count: 2));
      expect(result.records, hasLength(2));
      expect(result.records.first.make, 'Make');
      expect(result.dealerName, 'Summit Subaru El Cajon');
    });

    test('throws on a body that is not valid JSON', () {
      expect(() => parseInventoryResponse('not json'), throwsA(isA<InventoryApiException>()));
    });

    test('throws when the result key is missing or not a list', () {
      expect(
        () => parseInventoryResponse(jsonEncode({'notResult': 1})),
        throwsA(isA<InventoryApiException>()),
      );
    });

    test('throws when a record is missing a required field', () {
      final malformed = jsonEncode({
        'result': [
          {'inventoryID': 1},
        ],
      });
      expect(() => parseInventoryResponse(malformed), throwsA(isA<InventoryApiException>()));
    });
  });
}
