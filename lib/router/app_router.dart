import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/vehicle.dart';
import '../providers/srp_state_provider.dart';
import '../screens/srp_screen.dart';
import '../screens/vdp_screen.dart';
import 'srp_query_params.dart';

/// App-wide route table: SRP at `/` (filter/page state synced to query
/// parameters — see [_SrpRoute]), VDP at `/vehicle/:id` (stub; Task 12
/// replaces [VdpScreen]'s body with the real four-state page).
GoRouter buildAppRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => _SrpRoute(queryParameters: state.uri.queryParameters),
      ),
      GoRoute(
        path: '/vehicle/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return VdpScreen(vehicleId: id);
        },
      ),
    ],
  );
}

/// Bridges [srpStateProvider] to the route's query parameters in both
/// directions: restores state from the URL on load/back-forward navigation,
/// and pushes state changes (from the filter/pagination controls) back onto
/// the URL. `_lastSyncedParams` breaks the feedback loop this would
/// otherwise create between the two directions.
class _SrpRoute extends ConsumerStatefulWidget {
  const _SrpRoute({required this.queryParameters});

  final Map<String, String> queryParameters;

  @override
  ConsumerState<_SrpRoute> createState() => _SrpRouteState();
}

class _SrpRouteState extends ConsumerState<_SrpRoute> {
  Map<String, String>? _lastSyncedParams;

  @override
  void initState() {
    super.initState();
    _restoreFromUrl(widget.queryParameters);
  }

  @override
  void didUpdateWidget(covariant _SrpRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.queryParameters, widget.queryParameters)) {
      _restoreFromUrl(widget.queryParameters);
    }
  }

  void _restoreFromUrl(Map<String, String> queryParameters) {
    final restored = parseSrpQueryParams(queryParameters);
    _lastSyncedParams = srpStateToQueryParams(restored);
    // Riverpod forbids modifying a provider during a widget lifecycle method
    // (initState/build/didUpdateWidget) -- defer to right after the current
    // frame. A post-frame callback (not a bare microtask/Future) is required
    // here: WidgetTester.pumpAndSettle() drains scheduled frames, not
    // arbitrary microtasks, so a bare `Future(() {})` can be left unflushed
    // when this update happens to be the last thing that runs in a settle
    // loop -- found via a test that simulated a second in-app navigation and
    // observed the restore silently never applying.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(srpStateProvider.notifier).restoreFrom(restored);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(srpStateProvider, (previous, next) {
      final params = srpStateToQueryParams(next);
      if (!mapEquals(params, _lastSyncedParams)) {
        _lastSyncedParams = params;
        final uri = Uri(path: '/', queryParameters: params.isEmpty ? null : params);
        context.go(uri.toString());
      }
    });

    return SrpScreen(
      onVehicleTap: (Vehicle vehicle) => context.push('/vehicle/${vehicle.id}'),
    );
  }
}
