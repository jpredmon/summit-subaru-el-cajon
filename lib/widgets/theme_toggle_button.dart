import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_mode_provider.dart';

/// Manual light/dark toggle (SPEC.md's dark-mode design-polish item). Shows
/// the icon for the mode a tap *switches to*, not the current mode.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final switchingToLight = mode == ThemeMode.dark;

    return IconButton(
      icon: Icon(switchingToLight ? Icons.light_mode : Icons.dark_mode),
      tooltip: switchingToLight
          ? 'Switch to light mode'
          : 'Switch to dark mode',
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
    );
  }
}
