import 'package:appflowy_editor/appflowy_editor.dart';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final blocks = <BlockDropBounds>[
    (index: 0, rect: const Rect.fromLTWH(0, 0, 400, 100)),
    (index: 1, rect: const Rect.fromLTWH(0, 100, 400, 100)),
    (index: 2, rect: const Rect.fromLTWH(0, 600, 400, 100)),
  ];
  const slot = Rect.fromLTWH(0, 200, 400, 400);

  int target(double top) => blockDropIndex(
        Rect.fromLTWH(0, top, 400, 400),
        blocks,
        currentIndex: 2,
        slot: slot,
      );

  test('upper edge chooses before only in the upper forty percent', () {
    expect(target(139), 1);
    expect(target(140), 2);
    expect(target(180), 2);
    expect(target(39), 0);
    expect(target(40), 1);
  });

  test('lower edge chooses after in the lower forty percent', () {
    expect(target(201), 2);
    expect(target(259), 2);
    expect(target(260), 3);
    expect(target(299), 3);
  });

  test('direction follows the last slot rather than local movement', () {
    expect(target(120), 1);
    expect(target(130), 1);
    expect(target(280), 3);
    expect(target(270), 3);
  });

  test('equal tops preserve the slot and gaps preserve the target', () {
    expect(target(200), 2);
    expect(
      blockDropIndex(
        const Rect.fromLTWH(0, 250, 400, 100),
        blocks,
        currentIndex: 2,
        slot: slot,
      ),
      2,
    );
  });

  test('outside the document chooses the first or last position', () {
    expect(target(-20), 0);
    expect(target(400), 3);
  });

  test('no rendered neighbours keeps the current position', () {
    expect(
      blockDropIndex(
        const Rect.fromLTWH(0, 0, 400, 800),
        [],
        currentIndex: 2,
        slot: slot,
      ),
      2,
    );
  });
}
