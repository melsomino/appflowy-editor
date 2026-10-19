import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

bool isAtomicBlock(Node node) => node.type == 'test_media';

void main() {
  EditorState create(List<Node> nodes, Position position) {
    final editor =
        EditorState(document: Document(root: pageNode(children: nodes)));
    editor.selection = Selection.collapsed(position);
    addTearDown(editor.dispose);
    return editor;
  }

  for (final offset in [0, 1]) {
    test('Enter at atomic edge $offset inserts an empty paragraph', () async {
      final media = Node(type: 'test_media');
      final editor = create([media], Position(path: [0], offset: offset));
      await editor.apply(
        atomicBlockEnterTransaction(editor, isAtomicBlock: isAtomicBlock)!,
      );
      expect(editor.document.root.children[offset].delta!.toPlainText(), '');
      expect(editor.document.root.children[1 - offset].id, media.id);
      expect(editor.selection, Selection.collapsed(Position(path: [offset])));
    });

    test('typing at atomic edge $offset inserts adjacent text', () async {
      final media = Node(type: 'test_media');
      final editor = create([media], Position(path: [0], offset: offset));
      await editor.apply(
        atomicBlockEnterTransaction(
          editor,
          isAtomicBlock: isAtomicBlock,
          text: 'Typed',
        )!,
      );
      expect(
        editor.document.root.children[offset].delta!.toPlainText(),
        'Typed',
      );
      expect(
        editor.selection,
        Selection.collapsed(Position(path: [offset], offset: 5)),
      );
    });
  }

  test('unregistered non-text nodes keep standard behaviour', () {
    final editor = create([Node(type: 'other_widget')], Position(path: [0]));
    expect(
      atomicBlockEnterTransaction(editor, isAtomicBlock: isAtomicBlock),
      isNull,
    );
    expect(
      atomicBlockBackspaceTransaction(editor, isAtomicBlock: isAtomicBlock),
      isNull,
    );
    expect(
      atomicBlockCursorTarget(
        editor.document,
        editor.selection!,
        AtomicBlockArrow.right,
        isAtomicBlock: isAtomicBlock,
      ),
      isNull,
    );
  });

  test('ranges and ordinary text keep standard Enter behaviour', () {
    final editor = create(
      [paragraphNode(text: 'Text'), Node(type: 'test_media')],
      Position(path: [0], offset: 2),
    );
    expect(
      atomicBlockEnterTransaction(editor, isAtomicBlock: isAtomicBlock),
      isNull,
    );
    editor.selection =
        Selection.single(path: [1], startOffset: 0, endOffset: 1);
    expect(
      atomicBlockEnterTransaction(editor, isAtomicBlock: isAtomicBlock),
      isNull,
    );
  });

  test('insertion splits formatted text and one undo restores it', () async {
    final editor = create(
      [
        paragraphNode(
          delta: Delta()..insert('BeforeAfter', attributes: {'bold': true}),
        ),
      ],
      Position(path: [0], offset: 6),
    );
    final media = Node(type: 'test_media', attributes: {'custom': 'payload'});
    await editor.apply(
      atomicBlockInsertTransaction(
        editor,
        media,
        position: editor.selection!.start,
        isAtomicBlock: isAtomicBlock,
      ),
    );
    final children = editor.document.root.children;
    expect(
      children.map((node) => node.type),
      ['paragraph', 'test_media', 'paragraph'],
    );
    expect(children.first.delta!.toPlainText(), 'Before');
    expect(children.last.delta!.toPlainText(), 'After');
    expect(children.last.delta!.toJson().first['attributes'], {'bold': true});
    expect(children[1].attributes['custom'], 'payload');
    expect(
      editor.selection,
      Selection.collapsed(Position(path: [1], offset: 1)),
    );
    editor.undoManager.undo();
    expect(
      editor.document.root.children.single.delta!.toPlainText(),
      'BeforeAfter',
    );
  });

  test('append index leaves a host placeholder after the block', () async {
    final editor = create(
      [paragraphNode(text: 'Text'), paragraphNode()],
      Position(path: [0]),
    );
    await editor.apply(
      atomicBlockInsertTransaction(
        editor,
        Node(type: 'test_media'),
        isAtomicBlock: isAtomicBlock,
        appendIndex: 1,
      ),
    );
    expect(editor.document.root.children[1].type, 'test_media');
    expect(editor.document.root.children.last.delta!.isEmpty, isTrue);
    expect(editor.selection, isNull);
  });

  test('insertion rejects text or a container as an atomic block', () {
    final editor = create([paragraphNode()], Position(path: [0]));
    for (final node in [
      paragraphNode(),
      Node(type: 'test_media', children: [paragraphNode()]),
    ]) {
      expect(
        () => atomicBlockInsertTransaction(
          editor,
          node,
          isAtomicBlock: isAtomicBlock,
        ),
        throwsArgumentError,
      );
    }
  });
}
