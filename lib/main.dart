import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: VincueMobileApp()));
}

class VincueMobileApp extends StatelessWidget {
  const VincueMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VINCUE Inventory',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const Scaffold(
        body: Center(child: Text('vincue_mobile')),
      ),
    );
  }
}
