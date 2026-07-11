import 'package:flutter/material.dart';

/// A single skeleton placeholder block — a rounded rectangle filled with the
/// same neutral surface color the "no photo" placeholder uses, so loading
/// states read as the same design language. Static on its own; wrap a group
/// of these in [SkeletonPulse] for the shimmer/pulse animation.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Wraps a subtree of [SkeletonBox]es in a single subtle opacity pulse, driven
/// by one repeating controller for the whole group (not one ticker per box).
/// The pulse is skipped when `MediaQuery.disableAnimations` is set (SPEC
/// "Reduced motion") — the skeleton renders fully opaque and static instead.
///
/// NOTE: when animating, the pulse repeats forever, so a widget test must not
/// call `pumpAndSettle()` while a loading skeleton is on screen — it will
/// time out. Use `pump()` (optionally with a fixed duration) to assert on
/// loading states.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final Animation<double> _opacity = Tween<double>(begin: 0.4, end: 1).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
