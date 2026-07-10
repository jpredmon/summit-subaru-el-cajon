/// A single page slice of [items] plus the paging metadata needed to render
/// pagination controls.
class PaginatedResult<T> {
  final List<T> items;
  final int currentPage;
  final int totalPages;

  const PaginatedResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
  });
}

/// Slices [items] into a single page of [pageSize] entries.
///
/// [page] clamps into `[1, totalPages]` rather than erroring or returning an
/// empty slice — a page below 1 or beyond the last page silently resolves to
/// the nearest valid page. An empty [items] list still reports `totalPages:
/// 1` (never 0), so page 1 of nothing is a valid, in-range request.
PaginatedResult<T> paginate<T>(List<T> items, int page, int pageSize) {
  final totalPages = (items.length / pageSize).ceil().clamp(1, double.infinity).toInt();
  final currentPage = page.clamp(1, totalPages);
  final start = (currentPage - 1) * pageSize;
  final end = (start + pageSize).clamp(0, items.length);
  return PaginatedResult(
    items: items.sublist(start, end),
    currentPage: currentPage,
    totalPages: totalPages,
  );
}
