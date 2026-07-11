import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'providers/inventory_provider.dart';
import 'providers/theme_mode_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

// `String.fromEnvironment` reads `--dart-define` values at compile time --
// resolved once here as top-level consts (not per-call) since they can't
// change at runtime. Empty string (not null) when a define isn't supplied.
const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const String _apiKey = String.fromEnvironment('VINCUE_API_KEY');

// SharedPreferences is awaited here (once) so themeModeProvider's build()
// runs synchronously off an already-resolved instance -- ThemeMode is
// correct on the very first frame, no flash-of-wrong-theme workaround needed.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // overrideWith (not overrideWithValue) defers buildInventoryApiClient
        // to the first actual read of this provider -- inside
        // inventoryProvider's FutureProvider body -- rather than running it
        // eagerly here in main(), before runApp()/ProviderScope even exist.
        // Any throw (unconfigured build, or a native build missing its key)
        // is then caught the same way any other inventory-fetch failure is,
        // surfacing as this app's existing in-app error state instead of an
        // uncaught exception crashing the process before any UI renders.
        inventoryApiClientProvider.overrideWith(
          (ref) => buildInventoryApiClient(isWeb: kIsWeb, apiBaseUrl: _apiBaseUrl, apiKey: _apiKey),
        ),
      ],
      child: const VincueMobileApp(),
    ),
  );
}

class VincueMobileApp extends ConsumerWidget {
  const VincueMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'VINCUE Inventory',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
