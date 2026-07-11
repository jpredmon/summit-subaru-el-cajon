import 'package:flutter/material.dart';

/// Catches a build failure in [child] and shows a fallback instead, without
/// affecting anything outside its own subtree (SPEC "Resilience UX" — Flutter
/// equivalent of the web app's `ErrorBoundary` restricted to `<Routes>`).
///
/// Flutter already substitutes [ErrorWidget.builder]'s output for any
/// descendant Element whose `build()` throws, rather than letting the
/// exception propagate to (and take down) ancestors — but that builder is a
/// single process-wide static, so leaving it at its default produces the raw
/// debug red-screen everywhere. Overriding it for the app's entire lifetime
/// while this boundary is mounted (not just for one frame) gives a
/// consistent, friendly fallback for any build failure under [child],
/// however many frames later it happens.
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({super.key, required this.child});

  final Widget child;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  late final ErrorWidgetBuilder _previousBuilder;

  @override
  void initState() {
    super.initState();
    _previousBuilder = ErrorWidget.builder;
    ErrorWidget.builder = _buildFallback;
  }

  @override
  void dispose() {
    ErrorWidget.builder = _previousBuilder;
    super.dispose();
  }

  Widget _buildFallback(FlutterErrorDetails details) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('Something went wrong. Please try again later.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
