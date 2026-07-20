import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vincue_mobile/services/inventory_response_parser.dart';
import 'package:vincue_mobile/services/static_inventory_data_source.dart';

class _MockAssetBundle extends Mock implements AssetBundle {}

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
  late _MockAssetBundle bundle;

  setUp(() => bundle = _MockAssetBundle());

  group('loadInventory', () {
    test('loads the configured asset path and parses it via the shared parser', () async {
      when(() => bundle.loadString(any())).thenAnswer((_) async => _okBody(count: 2));

      final result = await StaticInventoryDataSource(bundle: bundle).loadInventory();

      verify(() => bundle.loadString(StaticInventoryDataSource.assetPath)).called(1);
      expect(result.records, hasLength(2));
      expect(result.dealerName, 'Summit Subaru El Cajon');
    });

    test('throws InventoryApiException when the asset fails to load', () {
      when(() => bundle.loadString(any())).thenThrow(Exception('asset not found'));

      expect(
        StaticInventoryDataSource(bundle: bundle).loadInventory(),
        throwsA(isA<InventoryApiException>()),
      );
    });
  });

  group('real bundled asset', () {
    test('loads and parses the actual assets/data/inventory.json', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final result = await StaticInventoryDataSource().loadInventory();

      expect(result.records, isNotEmpty);
      expect(result.dealerName, isNotEmpty);
    });
  });
}
