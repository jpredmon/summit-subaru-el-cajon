import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Vehicle Detail Page route target. Stub for Task 10 (routing) — Task 12
/// replaces this body with the real four-state VDP (loading/error/not-found/
/// loaded) reading from [inventoryProvider]'s cache by [vehicleId].
class VdpScreen extends StatelessWidget {
  const VdpScreen({super.key, required this.vehicleId});

  final int vehicleId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Vehicle $vehicleId'),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to inventory'),
            ),
          ],
        ),
      ),
    );
  }
}
