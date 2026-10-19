import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

bool isAtomicBlock(Node node) =>
    const ['test_image', 'test_password'].contains(node.type);
Transaction? backspace(EditorState editor) =>
    atomicBlockBackspaceTransaction(editor, isAtomicBlock: isAtomicBlock);

void main() {
  EditorState create(List<Node> nodes, {int index = 1, int offset = 0}) {
    final editor =
        EditorState(document: Document(root: pageNode(children: nodes)));
    editor.selection =
        Selection.collapsed(Position(path: [index], offset: offset));
    addTearDown(editor.dispose);
    return editor;
  }

  Node attachment() => Node(type: 'test_image');

  test('before image moves to preceding text end without deleting', () {
    final image = attachment();
    final editor = create([paragraphNode(text: 'Fff'), image]);
    final transaction = backspace(editor)!;
    expect(transaction.operations, isEmpty);
    expect(editor.document.root.children.first.delta!.toPlainText(), 'Fff');
    expect(editor.document.root.children.last.id, image.id);
    expect(
      transaction.afterSelection,
      Selection.collapsed(Position(path: [0], offset: 3)),
    );
    expect(editor.undoManager.undoStack.isEmpty, isTrue);
  });

  test('retains complete Unicode text and attributes', () {
    final editor = create([
      paragraphNode(
        delta: Delta()..insert('F👨‍👩‍👧‍👦', attributes: {'bold': true}),
      ),
      attachment(),
    ]);
    final transaction = backspace(editor)!;
    expect(transaction.operations, isEmpty);
    final delta = editor.document.root.children.first.delta!;
    expect(delta.toPlainText(), 'F👨‍👩‍👧‍👦');
    expect(delta.toJson().first['attributes'], {'bold': true});
    expect(
      transaction.afterSelection,
      Selection.collapsed(Position(path: [0], offset: delta.length)),
    );
  });

  test('first attachment handles backspace without deleting anything', () {
    final editor = create([attachment()], index: 0);
    expect(backspace(editor)!.operations, isEmpty);
  });

  test('empty preceding paragraph is retained and receives the caret', () {
    final image = attachment();
    final editor = create([paragraphNode(), image]);
    final transaction = backspace(editor)!;
    expect(transaction.operations, isEmpty);
    expect(editor.document.root.children.length, 2);
    expect(editor.document.root.children.last.id, image.id);
    expect(
      transaction.afterSelection,
      Selection.collapsed(Position(path: [0])),
    );
  });

  test('preceding attachment receives the caret without deletion', () {
    final image = attachment();
    final editor = create([attachment(), image]);
    final transaction = backspace(editor)!;
    expect(transaction.operations, isEmpty);
    expect(editor.document.root.children.length, 2);
    expect(editor.document.root.children.last.id, image.id);
    expect(
      transaction.afterSelection,
      Selection.collapsed(Position(path: [0], offset: 1)),
    );
  });

  test('text, ranges and the trailing attachment edge use standard handling',
      () {
    final editor =
        create([paragraphNode(text: 'Fff'), attachment()], offset: 1);
    expect(backspace(editor), isNull);
    editor.selection =
        Selection.single(path: [1], startOffset: 0, endOffset: 1);
    expect(backspace(editor), isNull);
    editor.selection = Selection.collapsed(Position(path: [0], offset: 1));
    expect(backspace(editor), isNull);
  });

  for (final type in [
    'test_image',
    'test_password',
  ]) {
    for (final text in ['', 'After']) {
      test('start of "$text" after $type only moves the caret to its end', () {
        final previous = Node(type: type);
        final editor = create([previous, paragraphNode(text: text)]);
        final transaction = backspace(editor)!;
        expect(transaction.operations, isEmpty);
        expect(
          transaction.afterSelection,
          Selection.collapsed(Position(path: [0], offset: 1)),
        );
        expect(editor.document.root.children.length, 2);
        expect(editor.undoManager.undoStack.isEmpty, isTrue);
      });
    }
  }
}
