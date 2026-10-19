import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboard;

  setUp(() {
    clipboard = null;
    AppFlowyClipboard.mockSetData(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map<Object?, Object?>)['text'] as String;
      } else if (call.method == 'Clipboard.getData') {
        return {'text': clipboard};
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  EditorState create(List<Node> nodes, Selection selection) {
    final editor =
        EditorState(document: Document(root: pageNode(children: nodes)));
    editor.selection = selection;
    addTearDown(editor.dispose);
    return editor;
  }

  Node media() => Node(type: 'test_media', attributes: {'content': 'image-id'});

  test(
      'external paste retains the cursor while clipboard permission is pending',
      () async {
    final editor = create(
      [paragraphNode(text: 'BeforeAfter')],
      Selection.collapsed(Position(path: [0], offset: 6)),
    );
    final requested = Completer<void>();
    final response = Completer<Map<String, String>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        requested.complete();
        return response.future;
      }
      return null;
    });

    final paste = handlePaste(editor);
    await requested.future;
    // iOS can take focus to request access to another app's clipboard.
    editor.selection = null;
    response.complete({'text': 'Wikipedia selection'});
    await paste;

    expect(
      editor.document.root.children.single.delta!.toPlainText(),
      'BeforeWikipedia selectionAfter',
    );
    expect(
      editor.selection,
      Selection.collapsed(Position(path: [0], offset: 25)),
    );
  });

  test('copy and paste a single atomic block between editors', () async {
    final source = create(
      [media()],
      Selection.single(path: [0], startOffset: 0, endOffset: 1),
    );
    await handleCopy(source);
    final target = create(
      [paragraphNode(text: 'BeforeAfter')],
      Selection.collapsed(Position(path: [0], offset: 6)),
    );
    await handlePaste(target);
    final nodes = target.document.root.children.toList();
    expect(
      nodes.map((node) => node.type),
      ['paragraph', 'test_media', 'paragraph'],
    );
    expect(nodes.first.delta!.toPlainText(), 'Before');
    expect(nodes.last.delta!.toPlainText(), 'After');
    expect(nodes[1].attributes['content'], 'image-id');
    expect(nodes[1].id, isNot(source.document.root.children.first.id));
    expect(
      target.selection,
      Selection.collapsed(Position(path: [1], offset: 1)),
    );
  });

  test('mixed selection retains formatted text and atomic payload', () async {
    final source = create(
      [
        paragraphNode(
          delta: Delta()..insert('Before', attributes: {'bold': true}),
        ),
        media(),
        Node(
          type: 'test_password',
          attributes: {'content': 'password-payload'},
        ),
        paragraphNode(text: 'After'),
      ],
      Selection(
        start: Position(path: [0], offset: 2),
        end: Position(path: [3], offset: 3),
      ),
    );
    await handleCopy(source);
    final target = create(
      [paragraphNode()],
      Selection.collapsed(Position(path: [0])),
    );
    await handlePaste(target);
    final nodes = target.document.root.children.toList();
    expect(
      nodes.map((node) => node.type),
      ['paragraph', 'test_media', 'test_password', 'paragraph'],
    );
    expect(nodes.first.delta!.toPlainText(), 'fore');
    expect(nodes.first.delta!.toJson().first['attributes'], {'bold': true});
    expect(nodes[2].attributes['content'], 'password-payload');
    expect(nodes[3].delta!.toPlainText(), 'Aft');
  });

  test('paste replaces an atomic selection and keeps adjacent text', () async {
    final editor = create(
      [paragraphNode(text: 'Before'), media(), paragraphNode(text: 'After')],
      Selection.single(path: [1], startOffset: 0, endOffset: 1),
    );
    await editor.apply(atomicBlockPasteTransaction(editor, [media()]));
    expect(editor.document.root.children.length, 3);
    expect(editor.document.root.children.first.delta!.toPlainText(), 'Before');
    expect(editor.document.root.children.last.delta!.toPlainText(), 'After');
  });

  test('paste over a mixed range preserves unselected text and supports undo',
      () async {
    final editor = create(
      [paragraphNode(text: 'Before'), media(), paragraphNode(text: 'After')],
      Selection(
        start: Position(path: [0], offset: 2),
        end: Position(path: [2], offset: 3),
      ),
    );
    await editor.apply(
      atomicBlockPasteTransaction(editor, [Node(type: 'other_media')]),
    );
    expect(
      editor.document.root.children.map((node) => node.type),
      ['paragraph', 'other_media', 'paragraph'],
    );
    expect(editor.document.root.children.first.delta!.toPlainText(), 'Be');
    expect(editor.document.root.children.last.delta!.toPlainText(), 'er');
    editor.undoManager.undo();
    expect(
      editor.document.root.children.map((node) => node.type),
      ['paragraph', 'test_media', 'paragraph'],
    );
    expect(editor.document.root.children.first.delta!.toPlainText(), 'Before');
    expect(editor.document.root.children.last.delta!.toPlainText(), 'After');
  });

  test('copy excludes atomic blocks outside the selected boundaries', () async {
    final editor = create(
      [media(), paragraphNode(text: 'Text'), media()],
      Selection(
        start: Position(path: [0], offset: 1),
        end: Position(path: [2]),
      ),
    );
    await handleCopy(editor);
    final data = await AppFlowyClipboard.getData();
    expect(data.nodes, isNull);
    expect(data.text, contains('Text'));
  });

  for (final offset in [0, 1]) {
    test('paste at atomic boundary $offset preserves the original block',
        () async {
      final original = media();
      final editor = create(
        [original],
        Selection.collapsed(Position(path: [0], offset: offset)),
      );
      await editor.apply(
        atomicBlockPasteTransaction(editor, [Node(type: 'other_media')]),
      );
      expect(
        editor.document.root.children.map((node) => node.type),
        offset == 0
            ? ['other_media', 'test_media']
            : ['test_media', 'other_media'],
      );
    });
  }

  test('external clipboard text invalidates local block payload', () async {
    await AppFlowyClipboard.setData(text: '', nodes: [media()]);
    clipboard = 'External text';
    final data = await AppFlowyClipboard.getData();
    expect(data.text, 'External text');
    expect(data.nodes, isNull);
  });

  test('atomic-only clipboard replaces a selected text range', () async {
    await AppFlowyClipboard.setData(text: '', nodes: [media()]);
    final editor = create(
      [paragraphNode(text: 'Keep')],
      Selection.single(path: [0], startOffset: 0, endOffset: 4),
    );
    await handlePaste(editor);
    expect(editor.document.root.children.single.type, 'test_media');
    expect(
      editor.selection,
      Selection.collapsed(Position(path: [0], offset: 1)),
    );
  });
}
