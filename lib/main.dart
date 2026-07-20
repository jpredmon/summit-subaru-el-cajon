import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/theme_mode_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

// SharedPreferences is awaited here (once) so themeModeProvider's build()
// runs synchronously off an already-resolved instance -- ThemeMode is
// correct on the very first frame, no flash-of-wrong-theme workaround needed.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
      // Deliberate branding decision (docs/superpowers/specs, dark-mode-
      // disabled note): forced light-only for now -- the header logo's
      // palette doesn't read well against the dark theme yet, and no time
      // budgeted to also tune dark-mode contrast for it. Deliberately NOT
      // ref.watch(themeModeProvider) -- that provider (and ThemeModeNotifier,
      // and its shared_preferences persistence) is kept fully working and
      // untouched, just not wired to this app's actual theme, so re-enabling
      // dark mode later is a one-line change back to
      // ref.watch(themeModeProvider), not a rebuild of the mechanism.
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
