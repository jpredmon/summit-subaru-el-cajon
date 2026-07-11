import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themeModePrefsKey = 'themeMode';
const String _lightValue = 'light';
const String _darkValue = 'dark';

/// Supplies the resolved [SharedPreferences] instance. Reading it is async,
/// so it has no usable default -- the app root awaits it once before
/// `runApp` (so [ThemeModeNotifier.build] resolves synchronously, pre-first-
/// frame) and overrides this provider with the result. Tests override it
/// with an instance from [SharedPreferences.setMockInitialValues].
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden at the app root (main.dart) or in tests.',
  );
});

/// Manual (not OS-driven) light/dark toggle, persisted via
/// [sharedPreferencesProvider]. Defaults to [ThemeMode.dark] whenever no
/// value -- or an unrecognized one -- is stored, which covers first launch.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref
        .watch(sharedPreferencesProvider)
        .getString(_themeModePrefsKey);
    return stored == _lightValue ? ThemeMode.light : ThemeMode.dark;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    ref
        .read(sharedPreferencesProvider)
        .setString(
          _themeModePrefsKey,
          mode == ThemeMode.light ? _lightValue : _darkValue,
        );
  }

  void toggle() =>
      setThemeMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
