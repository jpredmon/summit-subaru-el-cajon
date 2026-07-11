import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vincue_mobile/providers/theme_mode_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container(SharedPreferences prefs) {
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('defaults to dark when no theme preference is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    expect(container(prefs).read(themeModeProvider), ThemeMode.dark);
  });

  test('persists a toggle and restores it on the next app start', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = container(prefs);

    c.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
    expect(c.read(themeModeProvider), ThemeMode.light);

    // Simulate an app restart: a fresh container reading the same
    // mock-backed SharedPreferences storage the toggle wrote to.
    final restoredPrefs = await SharedPreferences.getInstance();
    final restored = container(restoredPrefs);

    expect(restored.read(themeModeProvider), ThemeMode.light);
  });
}
