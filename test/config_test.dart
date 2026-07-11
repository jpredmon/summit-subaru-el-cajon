import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/config.dart';
import 'package:vincue_mobile/models/inventory.dart';
import 'package:vincue_mobile/providers/inventory_provider.dart';

void main() {
  test(
    'inventoryApiClientProvider.overrideWith(buildInventoryApiClient) is lazy -- constructing '
    'the ProviderContainer with an unconfigured build does not throw; only reading the '
    'provider does. This is the property that lets an unconfigured/misconfigured build fail '
    'gracefully (caught by inventoryProvider\'s FutureProvider) instead of crashing at app '
    'bootstrap, before ProviderScope/runApp even exist.',
    () {
      late ProviderContainer container;
      expect(
        () => container = ProviderContainer(
          overrides: [
            inventoryApiClientProvider.overrideWith(
              (ref) => buildInventoryApiClient(isWeb: true, apiBaseUrl: '', apiKey: ''),
            ),
          ],
        ),
        returnsNormally,
      );
      addTearDown(container.dispose);

      // Riverpod wraps a Provider's creation-time throw in its own
      // ProviderException when read via container.read -- the original
      // UnimplementedError is its .exception field, not the thrown type
      // itself. This wrapping doesn't affect the real app: it's still a
      // regular exception, so inventoryProvider's FutureProvider body still
      // catches it and surfaces an AsyncError the same as any other
      // inventory-fetch failure.
      expect(
        () => container.read(inventoryApiClientProvider),
        throwsA(
          isA<ProviderException>().having((e) => e.exception, 'exception', isA<UnimplementedError>()),
        ),
      );
    },
  );

  test(
    'an unconfigured inventoryApiClientProvider surfaces as a graceful AsyncError through '
    'inventoryProvider -- the same FutureProvider real screens read -- rather than an '
    'uncaught exception, proving the laziness above actually degrades gracefully end-to-end',
    () {
      final container = ProviderContainer(
        overrides: [
          inventoryApiClientProvider.overrideWith(
            (ref) => buildInventoryApiClient(isWeb: true, apiBaseUrl: '', apiKey: ''),
          ),
        ],
      );
      addTearDown(container.dispose);

      // The throw is synchronous (no await needed to build the client), so
      // inventoryProvider's FutureProvider body throws synchronously too --
      // Riverpod represents that as AsyncError immediately, no async gap.
      expect(container.read(inventoryProvider), isA<AsyncError<Inventory>>());
    },
  );

  group('buildInventoryApiClient', () {
    test(
      'throws UnimplementedError when API_BASE_URL is not supplied (unconfigured build) -- '
      'must throw lazily (only when called), not eagerly at app bootstrap, so Riverpod\'s '
      'FutureProvider machinery can catch it and surface a graceful in-app error instead of '
      'crashing before any UI renders',
      () {
        expect(
          () => buildInventoryApiClient(isWeb: true, apiBaseUrl: '', apiKey: ''),
          throwsUnimplementedError,
        );
      },
    );

    test('throws UnimplementedError when API_BASE_URL is whitespace-only', () {
      expect(
        () => buildInventoryApiClient(isWeb: true, apiBaseUrl: '   ', apiKey: ''),
        throwsUnimplementedError,
      );
    });

    test(
      'propagates InventoryApiClient\'s own ArgumentError for a native build missing its key '
      '-- a real misconfiguration, not "unconfigured", so it must fail loudly and specifically '
      'rather than being swallowed into the generic "unconfigured" message',
      () {
        expect(
          () => buildInventoryApiClient(
            isWeb: false,
            apiBaseUrl: 'https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222',
            apiKey: '',
          ),
          throwsArgumentError,
        );
      },
    );

    test('builds a working web client (no api key header) when configured', () {
      final client = buildInventoryApiClient(
        isWeb: true,
        apiBaseUrl: 'https://vincue-mobile-proxy.example.vercel.app/api/inventory',
        apiKey: '',
      );

      expect(client.baseUrl, 'https://vincue-mobile-proxy.example.vercel.app/api/inventory');
      expect(client.attachApiKeyHeader, isFalse);
    });

    test('builds a working native client (with api key header) when configured', () {
      final client = buildInventoryApiClient(
        isWeb: false,
        apiBaseUrl: 'https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222',
        apiKey: 'secret-key-123',
      );

      expect(client.baseUrl, 'https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222');
      expect(client.attachApiKeyHeader, isTrue);
      expect(client.apiKey, 'secret-key-123');
    });
  });

  group('resolveApiBuildConfig', () {
    test('web build: does not attach the api key header, regardless of a supplied key', () {
      final config = resolveApiBuildConfig(
        isWeb: true,
        apiBaseUrl: 'https://vincue-mobile-proxy.example.vercel.app/api/inventory',
        apiKey: '',
      );

      expect(config.baseUrl, 'https://vincue-mobile-proxy.example.vercel.app/api/inventory');
      expect(config.attachApiKeyHeader, isFalse);
      expect(config.apiKey, isNull);
    });

    test('native build: attaches the api key header and carries the supplied key through', () {
      final config = resolveApiBuildConfig(
        isWeb: false,
        apiBaseUrl: 'https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222',
        apiKey: 'secret-key-123',
      );

      expect(config.baseUrl, 'https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222');
      expect(config.attachApiKeyHeader, isTrue);
      expect(config.apiKey, 'secret-key-123');
    });

    test('normalizes an empty (unsupplied) api key define to null rather than an empty string', () {
      final config = resolveApiBuildConfig(
        isWeb: false,
        apiBaseUrl: 'https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222',
        apiKey: '',
      );

      expect(config.apiKey, isNull);
    });
  });
}
