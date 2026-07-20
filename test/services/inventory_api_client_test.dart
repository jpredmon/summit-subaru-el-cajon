import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:vincue_mobile/services/inventory_api_client.dart';
import 'package:vincue_mobile/services/inventory_response_parser.dart';

class _MockHttpClient extends Mock implements http.Client {}

/// A minimal but complete raw record — enough for `RawVehicle.fromJson`.
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

void main() {
  const baseUrl = 'https://proxy.example.com/api/inventory';
  late _MockHttpClient httpClient;

  setUpAll(() => registerFallbackValue(Uri.parse('https://example.com')));
  setUp(() => httpClient = _MockHttpClient());

  void stub(String body, int status) {
    when(() => httpClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response(body, status));
  }

  InventoryApiClient client({bool attachKey = false, String? apiKey}) =>
      InventoryApiClient(
        baseUrl: baseUrl,
        attachApiKeyHeader: attachKey,
        apiKey: apiKey,
        httpClient: httpClient,
      );

  String okBody({String dealerName = 'Summit Subaru El Cajon', int count = 1}) =>
      jsonEncode({
        'result': [for (var i = 0; i < count; i++) _rawJson(dealerName: dealerName)],
      });

  group('construction', () {
    test(
      'throws when attachApiKeyHeader is true but no apiKey is supplied, as a real runtime '
      'check (not an assert, which is stripped in release/profile builds)',
      () {
        expect(
          () => InventoryApiClient(
            baseUrl: baseUrl,
            attachApiKeyHeader: true,
            httpClient: httpClient,
          ),
          throwsArgumentError,
        );
      },
    );

    test('does not throw when attachApiKeyHeader is true and apiKey is supplied', () {
      expect(
        () => InventoryApiClient(
          baseUrl: baseUrl,
          attachApiKeyHeader: true,
          apiKey: 'secret-key',
          httpClient: httpClient,
        ),
        returnsNormally,
      );
    });

    test('does not throw when attachApiKeyHeader is false, regardless of apiKey', () {
      expect(
        () => InventoryApiClient(baseUrl: baseUrl, attachApiKeyHeader: false, httpClient: httpClient),
        returnsNormally,
      );
    });
  });

  group('headers', () {
    test('omits x-api-key when attachApiKeyHeader is false (proxy build)', () async {
      stub(okBody(), 200);
      await client(attachKey: false).fetchInventory();
      final headers = verify(
        () => httpClient.get(any(), headers: captureAny(named: 'headers')),
      ).captured.single as Map<String, String>;
      expect(headers.containsKey('x-api-key'), isFalse);
    });

    test('attaches x-api-key when attachApiKeyHeader is true (native build)', () async {
      stub(okBody(), 200);
      await client(attachKey: true, apiKey: 'secret-key').fetchInventory();
      final headers = verify(
        () => httpClient.get(any(), headers: captureAny(named: 'headers')),
      ).captured.single as Map<String, String>;
      expect(headers['x-api-key'], 'secret-key');
    });
  });

  group('request', () {
    test('GETs the configured baseUrl verbatim', () async {
      stub(okBody(), 200);
      await client().fetchInventory();
      final uri = verify(
        () => httpClient.get(captureAny(), headers: any(named: 'headers')),
      ).captured.single as Uri;
      expect(uri.toString(), baseUrl);
    });
  });

  group('parsing', () {
    test('parses the result array and surfaces the dealer name', () async {
      stub(okBody(dealerName: 'Summit Subaru El Cajon', count: 2), 200);
      final result = await client().fetchInventory();
      expect(result.records, hasLength(2));
      expect(result.records.first.make, 'Make');
      expect(result.dealerName, 'Summit Subaru El Cajon');
    });
  });

  group('error handling', () {
    test('throws on a non-200 status', () {
      stub('{}', 500);
      expect(client().fetchInventory(), throwsA(isA<InventoryApiException>()));
    });

    test('throws when the request itself fails', () {
      when(() => httpClient.get(any(), headers: any(named: 'headers')))
          .thenThrow(Exception('network down'));
      expect(client().fetchInventory(), throwsA(isA<InventoryApiException>()));
    });

    test('throws on a body that is not valid JSON', () {
      stub('not json', 200);
      expect(client().fetchInventory(), throwsA(isA<InventoryApiException>()));
    });

    test('throws when the result key is missing or not a list', () {
      stub(jsonEncode({'notResult': 1}), 200);
      expect(client().fetchInventory(), throwsA(isA<InventoryApiException>()));
    });
  });
}
