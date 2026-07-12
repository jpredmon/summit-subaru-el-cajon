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
/// `dealerNameProvider` for the title) -- safe from the [child]-only
/// failure guarantee above only because `dealerNameProvider` is designed to
/// never throw (it reads `.value`, never `.requireValue`); it is not itself
/// wrapped in [ErrorBoundary].
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // SPEC "Dealer name" -- the header shows the live dealer name (falling
    // back to kFallbackDealerName while loading/on error, via
    // dealerNameProvider), matching the reference app's App.tsx header span.
    final dealerName = ref.watch(dealerNameProvider);

    return Scaffold(
      appBar: AppBar(
        // dealerName is unbounded external API data (no length cap) -- same
        // reasoning as VehicleCard's title (lib/widgets/vehicle_card.dart)
        // for why an unguarded Text here would risk an AppBar overflow.
        title: Text(dealerName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: const [ThemeToggleButton()],
      ),
      body: ErrorBoundary(child: child),
    );
  }
}
