import 'package:appflowy_editor/appflowy_editor.dart';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Rect resisted(double top) => blockDragBounds(
        Rect.fromLTWH(20, top, 300, 200),
        minTop: 100,
        maxTop: 900,
        viewportHeight: 600,
      );

  test('movement inside the document is unchanged', () {
    for (final top in [100.0, 400.0, 900.0]) {
      expect(resisted(top), Rect.fromLTWH(20, top, 300, 200));
    }
  });

  test('both edges resist symmetrically without a hard stop', () {
    for (final distance in [10.0, 100.0, 1000.0]) {
      final upper = 100 - resisted(100 - distance).top;
      final lower = resisted(900 + distance).top - 900;
      expect(upper, greaterThan(0));
      expect(upper, lessThan(distance));
      expect(lower, closeTo(upper, 0.000001));
      expect(resisted(100 - distance).size, const Size(300, 200));
    }
  });

  test('resistance increases with distance and reverses without hysteresis',
      () {
    final near = 100 - resisted(0).top;
    final far = 100 - resisted(-100).top;
    expect(far, greaterThan(near));
    expect(far - near, lessThan(near));
    expect(resisted(100).top, 100);
    expect(resisted(100 - 0.0001).top, closeTo(100, 0.0001));
  });
}
