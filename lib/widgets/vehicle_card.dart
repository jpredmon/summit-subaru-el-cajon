import 'package:flutter/material.dart';

import '../models/body_category.dart';
import '../models/vehicle.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'vehicle_photo.dart';

/// SRP grid card for one [Vehicle]. Tapping invokes [onTap] — the SRP screen
/// wires this to VDP navigation once routing exists (Task 10).
class VehicleCard extends StatelessWidget {
  const VehicleCard({super.key, required this.vehicle, required this.onTap});

  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto = vehicle.photos.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            VehiclePhoto(
              photoUrl: hasPhoto ? vehicle.photos.first : null,
              semanticLabel: hasPhoto
                  ? '${vehicle.year} ${vehicle.make} ${vehicle.model}'
                  : 'No photo available',
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehicle.year} ${vehicle.make} ${vehicle.model} ${vehicle.trim}',
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatMileage(vehicle.mileage)} · ${vehicle.bodyStyle.displayName}',
                    style: tabularNumsStyle(theme.textTheme.bodySmall!).copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  vehicle.price != null
                      ? Text(
                          formatPrice(vehicle.price!),
                          style: tabularNumsStyle(theme.textTheme.titleMedium!).copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : Text(
                          'Call for price',
                          style: theme.textTheme.titleMedium!.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
