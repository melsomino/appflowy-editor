import 'dart:math' as math;
import 'dart:ui';

/// Keep the lens clear of the finger and inside the screen's usable bounds.
Rect mobileMagnifierRect({
  required Size size,
  required Offset focalPoint,
  required Rect bounds,
}) {
  const clearance = 40.0;
  var left = focalPoint.dx - size.width / 2;
  var top = focalPoint.dy - clearance - size.height;
  if (top < bounds.top) {
    // When there is no room above the finger, place the lens beside it.
    final right = focalPoint.dx + clearance;
    final leftSide = focalPoint.dx - clearance - size.width;
    if (right + size.width <= bounds.right) {
      left = right;
      top = focalPoint.dy - size.height / 2;
    } else if (leftSide >= bounds.left) {
      left = leftSide;
      top = focalPoint.dy - size.height / 2;
    }
  }
  return Rect.fromLTWH(
    left.clamp(bounds.left, math.max(bounds.left, bounds.right - size.width)),
    top.clamp(bounds.top, math.max(bounds.top, bounds.bottom - size.height)),
    size.width,
    size.height,
  );
}
