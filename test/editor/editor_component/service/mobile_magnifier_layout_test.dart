import 'dart:ui';

import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile_magnifier_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(72, 48);
  const bounds = Rect.fromLTRB(8, 32, 392, 700);

  Rect lens(Offset focalPoint) => mobileMagnifierRect(
        size: size,
        focalPoint: focalPoint,
        bounds: bounds,
      );

  test('lens clears the finger by forty pixels', () {
    final rect = lens(const Offset(200, 200));
    expect(rect, const Rect.fromLTWH(164, 112, 72, 48));
    expect(200 - rect.bottom, 40);
  });

  test('near the top the lens moves beside the finger', () {
    final rect = lens(const Offset(100, 50));
    expect(rect.left, 140);
    expect(rect.top, bounds.top);
    expect(rect.contains(const Offset(100, 50)), isFalse);
  });

  test('near the top right the lens moves to the left', () {
    final rect = lens(const Offset(380, 50));
    expect(rect.right, 340);
    expect(rect.top, bounds.top);
  });

  test('all screen edges keep the complete lens inside usable bounds', () {
    for (final point in [
      const Offset(-20, 200),
      const Offset(420, 200),
      const Offset(200, -20),
      const Offset(200, 900),
    ]) {
      final rect = lens(point);
      expect(rect.size, size);
      expect(rect.left, greaterThanOrEqualTo(bounds.left));
      expect(rect.top, greaterThanOrEqualTo(bounds.top));
      expect(rect.right, lessThanOrEqualTo(bounds.right));
      expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
    }
  });
}
