enum WindowSizeClass { compact, medium, expanded }

const double kMediumBreakpoint = 600;
const double kExpandedBreakpoint = 840;

WindowSizeClass windowSizeClassOf(double width) {
  if (width < kMediumBreakpoint) {
    return WindowSizeClass.compact;
  } else if (width < kExpandedBreakpoint) {
    return WindowSizeClass.medium;
  } else {
    return WindowSizeClass.expanded;
  }
}
