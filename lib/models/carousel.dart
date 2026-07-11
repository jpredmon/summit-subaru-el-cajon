/// Advances to the next photo index, clamping at the last photo rather than
/// wrapping to the first — matches the web app's `nextIndex`.
int nextPhotoIndex(int current, int length) {
  final last = length - 1;
  return current + 1 > last ? last : current + 1;
}

/// Goes back to the previous photo index, clamping at the first photo
/// rather than wrapping to the last — matches the web app's `prevIndex`.
int prevPhotoIndex(int current) {
  return current - 1 < 0 ? 0 : current - 1;
}
