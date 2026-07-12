import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/inventory_provider.dart';
import '../theme/breakpoints.dart';
import 'error_boundary.dart';
import 'theme_toggle_button.dart';

/// Header logo/AppBar sizing per window size class -- grows the logo (and
/// the AppBar height around it) on wider screens rather than staying a
/// fixed size regardless of viewport, per the same [WindowSizeClass] tiers
/// already used for VDP's two-pane layout and SRP's width cap. Each tier
/// keeps a consistent 36px gap between logoHeight and toolbarHeight for
/// even vertical padding around the logo.
({double logoHeight, double toolbarHeight}) logoSizingFor(WindowSizeClass sizeClass) {
  switch (sizeClass) {
    case WindowSizeClass.compact:
      return (logoHeight: 68, toolbarHeight: 104);
    case WindowSizeClass.medium:
      return (logoHeight: 80, toolbarHeight: 116);
    case WindowSizeClass.expanded:
      return (logoHeight: 92, toolbarHeight: 128);
  }
}

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
    final sizing = logoSizingFor(windowSizeClassOf(MediaQuery.sizeOf(context).width));

    return Scaffold(
      appBar: AppBar(
        // Above-and-beyond branding (docs/superpowers/specs/2026-07-12-
        // header-logo-design.md): the header always shows the fixed Summit
        // Subaru El Cajon logo, a deliberate divergence from SPEC's "live
        // dealer name in the header" text requirement. dealerName is kept
        // (not deleted) and now only feeds this Semantics label, so screen
        // readers still announce the live value even though sighted users
        // see the fixed graphic. centerTitle is explicit because AppBar's
        // default title alignment is platform-dependent (centered on iOS,
        // left-aligned on Android) -- this app wants the logo centered
        // everywhere. Sizing grows with window size class (logoSizingFor
        // above) instead of staying fixed regardless of viewport width.
        toolbarHeight: sizing.toolbarHeight,
        centerTitle: true,
        title: Semantics(
          label: dealerName,
          child: Image.asset(
            'assets/images/summit_subaru_logo.png',
            height: sizing.logoHeight,
            fit: BoxFit.contain,
          ),
        ),
        actions: const [ThemeToggleButton()],
      ),
      body: ErrorBoundary(child: child),
    );
  }
}
