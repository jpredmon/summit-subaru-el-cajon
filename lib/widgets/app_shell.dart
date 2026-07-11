import 'package:flutter/material.dart';

import 'error_boundary.dart';
import 'theme_toggle_button.dart';

/// The single persistent chrome (header + theme toggle) around every route,
/// wired in via a go_router `ShellRoute` (see `app_router.dart`) rather than
/// `MaterialApp.router`'s `builder` — that `builder` sits *above* the
/// Router's own `Navigator`/`Overlay`, which breaks `Tooltip`s like
/// [ThemeToggleButton]'s; `ShellRoute` nests this shell inside that Navigator
/// instead. (SPEC "Resilience UX" — a build failure in [child] must not take
/// the header/theme-toggle down with it.) Individual screens no longer own
/// their own `Scaffold`/`AppBar`.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: const [ThemeToggleButton()]),
      body: ErrorBoundary(child: child),
    );
  }
}
