import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

bool isAtomicBlock(Node node) =>
    const ['test_image', 'test_password'].contains(node.type);
Position? cursorTarget(
  Document document,
  Selection selection,
  AtomicBlockArrow arrow, {
  Position? verticalTarget,
}) =>
    atomicBlockCursorTarget(
      document,
      selection,
      arrow,
      isAtomicBlock: isAtomicBlock,
      verticalTarget: verticalTarget,
    );
Selection? arrowSelection(
  Document document,
  Selection selection,
  AtomicBlockArrow arrow, {
  bool extend = false,
  Position? verticalTarget,
}) =>
    atomicBlockArrowSelection(
      document,
      selection,
      arrow,
      isAtomicBlock: isAtomicBlock,
      extend: extend,
      verticalTarget: verticalTarget,
    );

void main() {
  Document document() => Document(
        root: pageNode(
          children: [
            paragraphNode(text: 'Before'),
            Node(type: 'test_image'),
            Node(type: 'test_password'),
            paragraphNode(text: 'After'),
          ],
        ),
      );
  Position? move(int index, int offset, AtomicBlockArrow arrow) => cursorTarget(
        document(),
        Selection.collapsed(Position(path: [index], offset: offset)),
        arrow,
      );

  test('arrows walk both sides of adjacent atomic attachments', () {
    expect(move(0, 6, AtomicBlockArrow.right), Position(path: [1]));
    expect(move(1, 0, AtomicBlockArrow.right), Position(path: [1], offset: 1));
    expect(move(1, 1, AtomicBlockArrow.right), Position(path: [2]));
    expect(move(2, 0, AtomicBlockArrow.right), Position(path: [2], offset: 1));
    expect(move(2, 1, AtomicBlockArrow.right), Position(path: [3]));
    expect(move(3, 0, AtomicBlockArrow.left), Position(path: [2], offset: 1));
    expect(move(2, 1, AtomicBlockArrow.left), Position(path: [2]));
    expect(move(2, 0, AtomicBlockArrow.left), Position(path: [1], offset: 1));
    expect(move(1, 0, AtomicBlockArrow.left), Position(path: [0], offset: 6));
  });

  test('ordinary text movement stays with AppFlowy', () {
    expect(move(0, 2, AtomicBlockArrow.left), isNull);
    expect(move(0, 2, AtomicBlockArrow.right), isNull);
  });

  test('up and down leave the atomic block for an adjacent node', () {
    expect(move(1, 1, AtomicBlockArrow.up), Position(path: [0], offset: 6));
    expect(move(2, 0, AtomicBlockArrow.down), Position(path: [3]));
  });

  test('vertical movement into an attachment uses the near boundary', () {
    expect(
      cursorTarget(
        document(),
        Selection.collapsed(Position(path: [0], offset: 3)),
        AtomicBlockArrow.down,
        verticalTarget: Position(path: [1], offset: 1),
      ),
      Position(path: [1]),
    );
  });

  test('range selection is left to AppFlowy', () {
    expect(
      cursorTarget(
        document(),
        Selection.single(path: [1], startOffset: 0, endOffset: 1),
        AtomicBlockArrow.right,
      ),
      isNull,
    );
  });

  test('Shift right continues beyond an attachment without moving the anchor',
      () {
    final anchor = Position(path: [0], offset: 2);
    final selection = Selection(
      start: anchor,
      end: Position(path: [1], offset: 1),
    );
    final result = arrowSelection(
      document(),
      selection,
      AtomicBlockArrow.right,
      extend: true,
    );
    expect(result!.start, anchor);
    expect(result.end, Position(path: [2]));
  });

  test('backwards Shift selection keeps its original anchor', () {
    final anchor = Position(path: [3], offset: 2);
    final selection = Selection(start: anchor, end: Position(path: [1]));
    final result = arrowSelection(
      document(),
      selection,
      AtomicBlockArrow.left,
      extend: true,
    );
    expect(result!.start, anchor);
    expect(result.end, Position(path: [0], offset: 6));
  });

  test('changing Shift direction shrinks the range through the attachment', () {
    final anchor = Position(path: [0], offset: 2);
    var selection =
        Selection(start: anchor, end: Position(path: [1], offset: 1));
    selection = arrowSelection(
      document(),
      selection,
      AtomicBlockArrow.left,
      extend: true,
    )!;
    expect(selection.start, anchor);
    expect(selection.end, Position(path: [1]));
    selection = arrowSelection(
      document(),
      selection,
      AtomicBlockArrow.right,
      extend: true,
    )!;
    expect(selection.start, anchor);
    expect(selection.end, Position(path: [1], offset: 1));
  });
}
