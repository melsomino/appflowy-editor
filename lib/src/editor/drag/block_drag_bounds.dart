import 'dart:ui';

/// Keep normal movement inside the document and progressively resist overshoot.
Rect blockDragBounds(
  Rect dragged, {
  required double minTop,
  required double maxTop,
  required double viewportHeight,
}) {
  assert(maxTop >= minTop);
  assert(viewportHeight > 0);
  final boundary = dragged.top.clamp(minTop, maxTop);
  final overshoot = dragged.top - boundary;
  if (overshoot == 0) return dragged;
  final distance = overshoot.abs();
  final resisted =
      viewportHeight * 0.55 * distance / (viewportHeight + 0.55 * distance);
  return dragged
      .shift(Offset(0, boundary + overshoot.sign * resisted - dragged.top));
}
