import 'package:flutter/material.dart';

/// Shared error state for a failed inventory fetch -- SRP and VDP both
/// show the same message and recovery action. Above-and-beyond fix (G1,
/// docs/superpowers/plans/above-and-beyond-candidates.md): previously a
/// static message with no recovery besides a full page reload.
class InventoryErrorView extends StatelessWidget {
  const InventoryErrorView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Failed to load inventory. Please try again later.'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
