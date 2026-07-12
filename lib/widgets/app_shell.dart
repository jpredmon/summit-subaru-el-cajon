import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/inventory_provider.dart';
import 'error_boundary.dart';
import 'theme_toggle_button.dart';

/// The single persistent chrome (header + theme toggle) around every route,
/// wired in via a go_router `ShellRoute` (see `app_router.dart`) rather than
/// `MaterialApp.router`'s `builder` — that `builder` sits *above* the
/// Router's own `Navigator`/`Overlay`, which breaks `Tooltip`s like
/// [ThemeToggleButton]'s; `ShellRoute` nests this shell inside that Navigator
/// instead. (SPEC "Resilience UX" — a build failure in [child] must not take
/// the header/theme-toggle down with it.) Individual screens no longer own
/// their own `Scaffold`/`AppBar`. Requires a `ProviderScope` ancestor (reads
/// `dealerNameProvider` for the header logo's accessibility label) -- safe
/// from the [child]-only failure guarantee above only because
/// `dealerNameProvider` is designed to never throw (it reads `.value`,
/// never `.requireValue`); it is not itself wrapped in [ErrorBoundary].
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // SPEC "Dealer name" -- kept live (falling back to kFallbackDealerName
    // while loading/on error, via dealerNameProvider) even though the header
    // itself now shows a fixed logo (see comment below): this value still
    // drives the logo's Semantics label for accessibility.
    final dealerName = ref.watch(dealerNameProvider);

    return Scaffold(
      appBar: AppBar(
        // Above-and-beyond branding (docs/superpowers/specs/2026-07-12-
        // header-logo-design.md): the header always shows the fixed Summit
        // Subaru El Cajon logo, a deliberate divergence from SPEC's "live
        // dealer name in the header" text requirement. dealerName is kept
        // (not deleted) and now only feeds this Semantics label, so screen
        // readers still announce the live value even though sighted users
        // see the fixed graphic.
        toolbarHeight: 76,
        title: Semantics(
          label: dealerName,
          child: Image.asset('assets/images/summit_subaru_logo.png', fit: BoxFit.contain),
        ),
        actions: const [ThemeToggleButton()],
      ),
      body: ErrorBoundary(child: child),
    );
  }
}
