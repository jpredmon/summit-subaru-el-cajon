import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

// inventoryApiClientProvider has no override here yet -- it throws
// UnimplementedError until Task 15 supplies the real baseUrl/API-key
// resolution (a CORS-safe proxy deployment for the web build, direct-VINCUE
// for native). A same-origin dev proxy was tried and reverted: the existing
// React app's deployed /api/inventory sets no CORS headers, so it only works
// same-origin for that app -- calling it from this app's own dev server (a
// different origin) is rejected by the browser regardless of environment.
void main() {
  runApp(const ProviderScope(child: VincueMobileApp()));
}

class VincueMobileApp extends StatelessWidget {
  const VincueMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'VINCUE Inventory',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: buildAppRouter(),
    );
  }
}
