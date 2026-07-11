import 'package:flutter/material.dart';

import '../models/body_category.dart';
import '../models/vehicle.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'vehicle_photo.dart';

/// SRP grid card for one [Vehicle]. Tapping invokes [onTap] — the SRP screen
/// wires this to VDP navigation once routing exists (Task 10).
///
/// [FocusableActionDetector] owns the one [FocusNode] this card can be
/// focused through, and draws the themed focus-ring border (SPEC lines
/// 349–351 — matching the card's actual corner radius directly via Flutter's
/// own focus mechanism, rather than the web app's CSS-outline-can't-follow-
/// border-radius workaround, which Flutter doesn't need). The inner
/// [InkWell] keeps its own, separate `FocusNode` internally but is given
/// `canRequestFocus: false`, which stops that node from ever actually being
/// focusable — so there's exactly one keyboard tab stop per card, not two,
/// even though the two widgets never share a node. Taking focus away from
/// InkWell also takes its default keyboard-activation handling with it, so
/// Enter/Space activation is re-wired explicitly via `Actions`. Both
/// `ActivateIntent` (Space, and Enter on non-web platforms) and
/// `ButtonActivateIntent` (Enter specifically on Flutter web —
/// `WidgetsApp._defaultWebShortcuts`) must be bound, or the card is
/// unreachable by Enter on web.
class VehicleCard extends StatefulWidget {
  const VehicleCard({super.key, required this.vehicle, required this.onTap, this.focusNode});

  final Vehicle vehicle;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  @override
  State<VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends State<VehicleCard> {
  bool _showFocusHighlight = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vehicle = widget.vehicle;
    final hasPhoto = vehicle.photos.isNotEmpty;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    void activate() => widget.onTap();

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      onShowFocusHighlight: (show) => setState(() => _showFocusHighlight = show),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          activate();
          return null;
        }),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) {
          activate();
          return null;
        }),
      },
      child: Container(
        key: ValueKey('vehicle-card-focus-ring-${vehicle.id}'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kCardRadius),
          border: Border.all(
            color: _showFocusHighlight ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: widget.onTap,
            canRequestFocus: false,
            splashFactory: disableAnimations ? NoSplash.splashFactory : null,
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
        ),
      ),
    );
  }
}
